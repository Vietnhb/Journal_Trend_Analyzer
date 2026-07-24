import { MAX_REPORT_BYTES, REPORT_PREFIX } from "./constants.js";
import { adminAuth, adminStorage } from "./firebase.js";
import { ApiError } from "./errors.js";
import { isValidReportPath, parseReportPath } from "./validation.js";

interface ReportPageOptions {
  pageSize: number;
  pageToken?: string;
}

type StorageFile = ReturnType<ReturnType<typeof adminStorage.bucket>["file"]>;

async function metadataFor(file: StorageFile) {
  const [metadata] = await file.getMetadata();
  return metadata;
}

type StorageMetadata = Awaited<ReturnType<typeof metadataFor>>;

function pageTokenFrom(nextQuery: unknown): string | undefined {
  if (typeof nextQuery !== "object" || nextQuery === null || !("pageToken" in nextQuery)) {
    return undefined;
  }
  return typeof nextQuery.pageToken === "string" ? nextQuery.pageToken : undefined;
}

export interface ReportFileSummary {
  path: string;
  name: string;
  viewUrl: string | null;
  ownerUid: string;
  ownerEmail: string | null;
  topic: string | null;
  sizeBytes: number;
  contentType: string | null;
  generation: string;
  createdAt: string | null;
  updatedAt: string | null;
}

export function firebaseStorageViewUrl(options: {
  bucket: string;
  path: string;
  generation: string | number;
  downloadTokens: unknown;
}): string | null {
  if (typeof options.downloadTokens !== "string") return null;
  const token = options.downloadTokens
    .split(",")
    .map((value) => value.trim())
    .find((value) => /^[A-Za-z0-9_-]{16,256}$/u.test(value));
  if (token === undefined) return null;

  const url = new URL(
    `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(options.bucket)}/o/${encodeURIComponent(options.path)}`,
  );
  url.searchParams.set("alt", "media");
  url.searchParams.set("token", token);
  url.searchParams.set("generation", String(options.generation));
  return url.toString();
}

export interface ValidatedReportMetadata {
  sizeBytes: number;
  generation: string | number;
}

export function validatePdfSignature(bytes: Uint8Array): void {
  const signature = Buffer.from("%PDF-", "ascii");
  const searchable = Buffer.from(
    bytes.buffer,
    bytes.byteOffset,
    Math.min(bytes.byteLength, 1024),
  );
  if (searchable.indexOf(signature) === -1) {
    throw new ApiError(
      409,
      "invalid_report_content",
      "The stored object does not contain a valid PDF signature.",
    );
  }
}

function validatedGeneration(metadata: { generation?: unknown }): string | number {
  const generation = metadata.generation;
  if (
    (typeof generation !== "string" || !/^[1-9]\d*$/u.test(generation)) &&
    (
      typeof generation !== "number" ||
      !Number.isSafeInteger(generation) ||
      generation <= 0
    )
  ) {
    throw new ApiError(
      409,
      "invalid_report_generation",
      "The report metadata is incomplete.",
    );
  }
  return generation;
}

export function validateReportDownloadMetadata(
  metadata: Pick<StorageMetadata, "contentEncoding" | "contentType" | "generation" | "size">,
): ValidatedReportMetadata {
  const sizeBytes = validatedNumericSize(metadata);
  if (metadata.contentType !== "application/pdf") {
    throw new ApiError(409, "invalid_report_content_type", "The stored object is not a PDF.");
  }
  if (
    metadata.contentEncoding !== undefined &&
    metadata.contentEncoding !== "identity"
  ) {
    throw new ApiError(
      409,
      "encoded_report_not_allowed",
      "Encoded report objects cannot be downloaded.",
    );
  }
  if (sizeBytes > MAX_REPORT_BYTES) {
    throw new ApiError(413, "report_too_large", "The report exceeds the 10 MiB limit.");
  }
  const generation = validatedGeneration(metadata);
  return { sizeBytes, generation };
}

function numericSize(metadata: { size?: unknown }): number {
  const parsed = Number(metadata.size ?? 0);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

function validatedNumericSize(metadata: { size?: unknown }): number {
  const value = metadata.size;
  const parsed = Number(value);
  if (
    (typeof value !== "string" && typeof value !== "number") ||
    (typeof value === "string" && !/^\d+$/u.test(value)) ||
    !Number.isSafeInteger(parsed) ||
    parsed < 0
  ) {
    throw new ApiError(409, "invalid_report_size", "The report metadata is incomplete.");
  }
  return parsed;
}

export interface ListedReportFile {
  name: string;
  metadata: { size?: unknown };
}

export function summarizeListedReportFiles(
  files: readonly ListedReportFile[],
): { count: number; totalBytes: number } {
  const validFiles = files.filter((file) => isValidReportPath(file.name));
  return {
    count: validFiles.length,
    totalBytes: validFiles.reduce(
      (sum, file) => sum + numericSize(file.metadata),
      0,
    ),
  };
}

function customTopic(metadata: StorageMetadata): string | null {
  const topic = metadata.metadata?.topic;
  return typeof topic === "string" ? topic : null;
}

export async function listReportPage(options: ReportPageOptions): Promise<{
  reports: ReportFileSummary[];
  nextPageToken: string | null;
}> {
  const bucket = adminStorage.bucket();
  const query = {
    autoPaginate: false as const,
    maxResults: options.pageSize,
    prefix: REPORT_PREFIX,
    ...(options.pageToken === undefined ? {} : { pageToken: options.pageToken }),
  };
  const [files, nextQuery] = await bucket.getFiles(query);
  const validFiles = files.filter((file) => isValidReportPath(file.name));
  const metadata = validFiles.map((file) => file.metadata);
  const ownerUids = [...new Set(validFiles.map((file) => parseReportPath(file.name).ownerUid))];
  const ownerRecords = ownerUids.length === 0
    ? []
    : (await adminAuth.getUsers(ownerUids.map((uid) => ({ uid })))).users;
  const ownerEmails = new Map(
    ownerRecords.map((user) => [user.uid, user.email ?? null] as const),
  );

  const reports = validFiles.map((file, index) => {
    const parsedPath = parseReportPath(file.name);
    const itemMetadata = metadata[index];
    if (itemMetadata === undefined) {
      throw new Error("Storage metadata result was incomplete.");
    }
    return {
      path: file.name,
      name: parsedPath.name,
      viewUrl: firebaseStorageViewUrl({
        bucket: bucket.name,
        path: file.name,
        generation: validatedGeneration(itemMetadata),
        downloadTokens: itemMetadata.metadata?.firebaseStorageDownloadTokens,
      }),
      ownerUid: parsedPath.ownerUid,
      ownerEmail: ownerEmails.get(parsedPath.ownerUid) ?? null,
      topic: customTopic(itemMetadata),
      sizeBytes: numericSize(itemMetadata),
      contentType: itemMetadata.contentType ?? null,
      generation: String(validatedGeneration(itemMetadata)),
      createdAt: itemMetadata.timeCreated ?? null,
      updatedAt: itemMetadata.updated ?? null,
    };
  });

  return {
    reports,
    nextPageToken: pageTokenFrom(nextQuery) ?? null,
  };
}

export async function scanReportTotals(): Promise<{ count: number; totalBytes: number }> {
  const bucket = adminStorage.bucket();
  let count = 0;
  let totalBytes = 0;
  let pageToken: string | undefined;
  do {
    const [files, nextQuery] = await bucket.getFiles({
      autoPaginate: false,
      maxResults: 1000,
      prefix: REPORT_PREFIX,
      ...(pageToken === undefined ? {} : { pageToken }),
    });
    const page = summarizeListedReportFiles(files);
    count += page.count;
    totalBytes += page.totalBytes;
    pageToken = pageTokenFrom(nextQuery);
  } while (pageToken !== undefined);
  return { count, totalBytes };
}

export async function getValidatedPdf(path: string): Promise<{
  file: StorageFile;
  name: string;
  sizeBytes: number;
}> {
  const parsed = parseReportPath(path);
  const file = adminStorage.bucket().file(path);
  let metadata: StorageMetadata;
  try {
    metadata = await metadataFor(file);
  } catch (error) {
    const code = (error as { code?: unknown }).code;
    if (code === 404) throw new ApiError(404, "not_found", "The report was not found.");
    throw error;
  }
  const validated = validateReportDownloadMetadata(metadata);
  const versionedFile = adminStorage.bucket().file(path, {
    generation: validated.generation,
  });
  try {
    const [prefix] = await versionedFile.download({
      start: 0,
      end: Math.min(validated.sizeBytes, 1024) - 1,
    });
    validatePdfSignature(prefix);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    const code = (error as { code?: unknown }).code;
    if (code === 404) throw new ApiError(404, "not_found", "The report was not found.");
    throw error;
  }
  return { file: versionedFile, name: parsed.name, sizeBytes: validated.sizeBytes };
}

export async function deleteReport(path: string, generation: string): Promise<void> {
  parseReportPath(path);
  try {
    await adminStorage.bucket().file(path).delete({ ifGenerationMatch: generation });
  } catch (error) {
    throw mapReportDeleteError(error);
  }
}

export function mapReportDeleteError(error: unknown): unknown {
  const rawCode = error instanceof Error && "code" in error
    ? (error as { code?: unknown }).code
    : undefined;
  const code = typeof rawCode === "string" || typeof rawCode === "number"
    ? String(rawCode)
    : "";
  if (code === "404") return new ApiError(404, "not_found", "The report was not found.");
  if (code === "412") {
    return new ApiError(
      409,
      "report_generation_conflict",
      "The report changed since it was loaded. Refresh and try again.",
    );
  }
  return error;
}
