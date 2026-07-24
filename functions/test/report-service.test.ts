import { describe, expect, it } from "vitest";

import {
  firebaseStorageViewUrl,
  mapReportDeleteError,
  summarizeListedReportFiles,
  validateReportDownloadMetadata,
  validatePdfSignature,
} from "../src/report-service.js";

describe("Firebase Storage view URL", () => {
  it("builds a generation-pinned URL from object metadata", () => {
    const result = firebaseStorageViewUrl({
      bucket: "example.firebasestorage.app",
      path: "report/user/analysis/report name.pdf",
      generation: "1700000000000000",
      downloadTokens: "valid_download-token_123",
    });
    const url = new URL(result!);

    expect(url.origin).toBe("https://firebasestorage.googleapis.com");
    expect(url.pathname).toContain("report%2Fuser%2Fanalysis%2Freport%20name.pdf");
    expect(url.searchParams.get("alt")).toBe("media");
    expect(url.searchParams.get("generation")).toBe("1700000000000000");
    expect(url.searchParams.get("token")).toBe("valid_download-token_123");
  });

  it("does not expose a URL when the object has no valid token", () => {
    expect(firebaseStorageViewUrl({
      bucket: "example.firebasestorage.app",
      path: "report/user/analysis/report.pdf",
      generation: "1700000000000000",
      downloadTokens: undefined,
    })).toBeNull();
  });
});

describe("report overview aggregation", () => {
  it("uses metadata returned by the Storage listing and ignores invalid paths", () => {
    const result = summarizeListedReportFiles([
      {
        name: "report/user-1/analysis/first.pdf",
        metadata: { size: "125" },
      },
      {
        name: `report/user-2/analysis/${"topic_".repeat(50)}second.pdf`,
        metadata: { size: 75 },
      },
      {
        name: "report/user-3/analysis/not-a-report.txt",
        metadata: { size: 10_000 },
      },
    ]);

    expect(result).toEqual({ count: 2, totalBytes: 200 });
  });
});

describe("generation-safe report deletion", () => {
  it("maps a stale generation precondition to a conflict", () => {
    const storageError = Object.assign(new Error("precondition failed"), { code: 412 });
    expect(mapReportDeleteError(storageError)).toMatchObject({
      status: 409,
      code: "report_generation_conflict",
    });
  });
});

describe("report download metadata", () => {
  it.each([undefined, "identity"])("accepts safe content encoding %s", (contentEncoding) => {
    expect(validateReportDownloadMetadata({
      ...(contentEncoding === undefined ? {} : { contentEncoding }),
      contentType: "application/pdf",
      generation: "1700000000000000",
      size: "1024",
    })).toEqual({
      generation: "1700000000000000",
      sizeBytes: 1024,
    });
  });

  it("rejects encoded objects before opening a download stream", () => {
    expect(() => validateReportDownloadMetadata({
      contentEncoding: "gzip",
      contentType: "application/pdf",
      generation: "1700000000000000",
      size: "1024",
    })).toThrowError(/Encoded report objects cannot be downloaded/u);
  });

  it("requires a generation so the validated object cannot be swapped before streaming", () => {
    expect(() => validateReportDownloadMetadata({
      contentType: "application/pdf",
      size: "1024",
    })).toThrowError(/metadata is incomplete/u);
  });

  it("rejects missing size metadata instead of treating it as an empty object", () => {
    expect(() => validateReportDownloadMetadata({
      contentType: "application/pdf",
      generation: "1700000000000000",
    })).toThrowError(/metadata is incomplete/u);
  });
});

describe("report PDF signature", () => {
  it("accepts a PDF signature in the first 1024 bytes", () => {
    expect(() => validatePdfSignature(
      Buffer.from([0, 0, ...Buffer.from("%PDF-1.7", "ascii")]),
    )).not.toThrow();
  });

  it("rejects a non-PDF payload even when metadata claims it is a PDF", () => {
    expect(() => validatePdfSignature(
      Buffer.from("{\"error\":\"not a PDF\"}", "utf8"),
    )).toThrowError(/valid PDF signature/u);
  });
});
