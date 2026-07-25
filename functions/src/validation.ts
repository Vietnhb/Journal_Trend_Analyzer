import { z } from "zod";

import { ApiError } from "./errors.js";

export const uidParamSchema = z.object({
  uid: z.string().trim().min(1).max(128),
});

export const usersQuerySchema = z.object({
  pageToken: z.string().min(1).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
  query: z.string().trim().min(1).max(320).optional(),
});

export type FirebaseUserLookupKind = "email" | "phone" | "uid";

export function firebaseUserLookupKind(query: string): FirebaseUserLookupKind {
  if (query.includes("@")) return "email";
  if (/^\+[1-9]\d{1,14}$/u.test(query)) return "phone";
  return "uid";
}

export const updateUserSchema = z
  .object({
    displayName: z.string().trim().min(1).max(256).nullable().optional(),
    email: z.email().max(320).optional(),
    emailVerified: z.boolean().optional(),
    disabled: z.boolean().optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, {
    message: "At least one user field is required.",
  });

export const roleSchema = z.object({ admin: z.boolean() }).strict();

export const remoteConfigUpdateSchema = z
  .object({
    maxJournals: z.number().int().min(1).max(100),
    maxKeywords: z.number().int().min(1).max(100),
    expectedEtag: z.string().trim().min(1).max(512),
    description: z.string().trim().min(1).max(300),
  })
  .strict();

export const versionsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  pageToken: z.string().min(1).max(2048).optional(),
});

export const remoteConfigVersionParamSchema = z.object({
  versionNumber: z.string().regex(/^[1-9]\d*$/),
});

export const rollbackSchema = z
  .object({
    versionNumber: z.union([
      z.number().int().positive(),
      z.string().regex(/^[1-9]\d*$/),
    ]),
    expectedEtag: z.string().trim().min(1).max(512),
  })
  .strict();

export const reportsQuerySchema = z.object({
  pageToken: z.string().min(1).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});

const storageObjectPathSchema = z
  .string()
  .min(1)
  .max(1024)
  .refine((path) => Buffer.byteLength(path, "utf8") <= 1024, {
    message: "Storage object path must not exceed 1024 UTF-8 bytes.",
  });

export const reportDownloadQuerySchema = z.object({
  path: storageObjectPathSchema,
  generation: z.string().regex(/^[1-9]\d*$/).max(32),
});
export const reportDeleteSchema = z
  .object({
    path: storageObjectPathSchema,
    generation: z.string().regex(/^[1-9]\d*$/).max(32),
  })
  .strict();

export const reportsBulkDeleteSchema = z
  .object({
    reports: z.array(reportDeleteSchema).min(1).max(100),
  })
  .strict();

export const reportsDeleteAllSchema = z
  .object({
    confirmation: z.literal("XOA TOAN BO BAO CAO"),
  })
  .strict();

const RESERVED_FCM_DATA_KEYS = new Set(["from", "message_type"]);
const RESERVED_FCM_DATA_PREFIXES = ["google.", "gcm."];

export function fcmDataSizeBytes(data: Readonly<Record<string, string>>): number {
  return Buffer.byteLength(JSON.stringify(data), "utf8");
}

export function isReservedFcmDataKey(key: string): boolean {
  return (
    RESERVED_FCM_DATA_KEYS.has(key) ||
    RESERVED_FCM_DATA_PREFIXES.some((prefix) => key.startsWith(prefix))
  );
}

export function fcmPayloadSizeBytes(value: {
  title: string;
  body: string;
  data?: Readonly<Record<string, string>> | undefined;
}): number {
  return Buffer.byteLength(JSON.stringify({
    notification: { title: value.title, body: value.body },
    data: value.data ?? {},
  }), "utf8");
}

const messageContentShape = {
    title: z.string().trim().min(1).max(100),
    body: z.string().trim().min(1).max(500),
    data: z.record(z.string().max(128), z.string().max(2048)).optional(),
};

function validateMessageContent(
  value: { title: string; body: string; data?: Record<string, string> | undefined },
  context: z.RefinementCtx,
): void {
    const data = value.data ?? {};

    if (Object.keys(data).length > 50) {
      context.addIssue({
        code: "custom",
        path: ["data"],
        message: "At most 50 data fields are allowed.",
      });
    }

    for (const key of Object.keys(data)) {
      if (isReservedFcmDataKey(key)) {
        context.addIssue({
          code: "custom",
          path: ["data", key],
          message: `Data key '${key}' is reserved by FCM.`,
        });
      }
    }

    if (fcmDataSizeBytes(data) > 4096) {
      context.addIssue({
        code: "custom",
        path: ["data"],
        message: "Data must not exceed 4096 UTF-8 bytes.",
      });
    }

    if (fcmPayloadSizeBytes(value) > 4096) {
      context.addIssue({
        code: "custom",
        message: "Notification and data must not exceed 4096 UTF-8 bytes.",
      });
    }
}

export const messageSchema = z
  .object({
    target: z.string().trim().min(20).max(4096),
    ...messageContentShape,
  })
  .strict()
  .superRefine(validateMessageContent);

export const broadcastMessageSchema = z
  .object(messageContentShape)
  .strict()
  .superRefine(validateMessageContent);

export const campaignCreateSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    audience: z.enum([
      "all_users",
      "platform_android",
      "platform_ios",
      "language_vi",
      "language_en",
    ]),
    scheduleAt: z.iso.datetime({ offset: true }).nullable().optional(),
    ttlSeconds: z.number().int().min(0).max(2_419_200).default(86_400),
    sound: z.boolean().default(true),
    ...messageContentShape,
  })
  .strict()
  .superRefine(validateMessageContent);

export const campaignsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export const campaignIdParamSchema = z.object({
  campaignId: z.string().trim().regex(/^[A-Za-z0-9_-]{1,128}$/),
});

export const daysQuerySchema = z.object({
  days: z.coerce.number().pipe(z.union([z.literal(7), z.literal(30), z.literal(90)])).default(30),
});

export const dateRangeQuerySchema = z
  .object({
    days: z.coerce.number().pipe(
      z.union([z.literal(7), z.literal(30), z.literal(90)]),
    ).default(30),
    start: z.iso.datetime({ offset: true }).optional(),
    end: z.iso.datetime({ offset: true }).optional(),
  })
  .superRefine((value, context) => {
    if ((value.start === undefined) !== (value.end === undefined)) {
      context.addIssue({
        code: "custom",
        message: "start and end must be provided together.",
      });
      return;
    }
    if (value.start !== undefined && value.end !== undefined) {
      const start = Date.parse(value.start);
      const end = Date.parse(value.end);
      if (start >= end) {
        context.addIssue({
          code: "custom",
          message: "start must be before end.",
        });
      } else if (end - start > 366 * 24 * 60 * 60 * 1000) {
        context.addIssue({
          code: "custom",
          message: "The selected range cannot exceed 366 days.",
        });
      }
    }
  })
  .transform((value) => {
    const end = value.end ?? new Date().toISOString();
    const start = value.start ??
      new Date(Date.parse(end) - value.days * 24 * 60 * 60 * 1000)
        .toISOString();
    return { start, end };
  });

export const auditQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

const reportPathPattern = /^report\/([^/]{1,128})\/analysis\/([^/]+\.pdf)$/;
const bigQueryTablePattern =
  /^[a-z][a-z0-9-]{4,28}[a-z0-9]\.[A-Za-z_]\w{0,1023}\.[A-Za-z_][\w$-]{0,1023}$/;

export interface ParsedReportPath {
  path: string;
  ownerUid: string;
  name: string;
}

export function parseReportPath(path: string): ParsedReportPath {
  const match = reportPathPattern.exec(path);
  const ownerUid = match?.[1];
  const name = match?.[2];
  const containsControlCharacter = [...path].some(
    (character) => character.codePointAt(0)! < 32,
  );
  if (
    ownerUid === undefined ||
    name === undefined ||
    ownerUid === "." ||
    ownerUid === ".." ||
    name === "." ||
    name === ".." ||
    containsControlCharacter ||
    Buffer.byteLength(path, "utf8") > 1024
  ) {
    throw new ApiError(
      400,
      "invalid_report_path",
      "Report path must match report/{uid}/analysis/{name}.pdf.",
    );
  }
  return { path, ownerUid, name };
}

export function isValidReportPath(path: string): boolean {
  try {
    parseReportPath(path);
    return true;
  } catch {
    return false;
  }
}

export function parseCrashlyticsTable(value: string): string {
  const trimmed = value.trim();
  if (!bigQueryTablePattern.test(trimmed)) {
    throw new ApiError(
      503,
      "invalid_crashlytics_configuration",
      "Crashlytics reporting is not configured correctly.",
    );
  }
  return trimmed;
}

export function singleQueryValue(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}
