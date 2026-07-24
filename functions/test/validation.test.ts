import { describe, expect, it } from "vitest";

import {
  broadcastMessageSchema,
  campaignCreateSchema,
  fcmDataSizeBytes,
  fcmPayloadSizeBytes,
  isValidReportPath,
  messageSchema,
  parseCrashlyticsTable,
  parseReportPath,
  reportDeleteSchema,
  remoteConfigUpdateSchema,
  rollbackSchema,
  versionsQuerySchema,
} from "../src/validation.js";

describe("report path validation", () => {
  it("accepts only the mobile report layout", () => {
    expect(parseReportPath("report/firebase-uid/analysis/dashboard_ai_123.pdf")).toEqual({
      path: "report/firebase-uid/analysis/dashboard_ai_123.pdf",
      ownerUid: "firebase-uid",
      name: "dashboard_ai_123.pdf",
    });
  });

  it.each([
    "report/firebase-uid/dashboard.pdf",
    "report/firebase-uid/analysis/not-a-pdf.txt",
    "report/firebase-uid/analysis/nested/file.pdf",
    "report/../analysis/file.pdf",
    "/report/firebase-uid/analysis/file.pdf",
    "report/firebase-uid/analysis/file.PDF",
    `report/firebase-uid/analysis/${"😀".repeat(300)}.pdf`,
  ])("rejects unsafe path %s", (path) => {
    expect(isValidReportPath(path)).toBe(false);
    expect(() => parseReportPath(path)).toThrow();
  });

  it("accepts a legacy app filename longer than 240 characters", () => {
    const path = `report/firebase-uid/analysis/dashboard_${"topic_".repeat(50)}123.pdf`;
    expect(path.length).toBeGreaterThan(240);
    expect(isValidReportPath(path)).toBe(true);
  });

  it("requires the listed object generation when deleting a report", () => {
    const path = "report/firebase-uid/analysis/dashboard_ai_123.pdf";
    expect(reportDeleteSchema.safeParse({ path }).success).toBe(false);
    expect(reportDeleteSchema.safeParse({
      path,
      generation: "1700000000000000",
    }).success).toBe(true);
    expect(reportDeleteSchema.safeParse({
      path,
      generation: 1_700_000_000_000_000,
    }).success).toBe(false);
  });
});

describe("request validation", () => {
  it("enforces Remote Config bounds", () => {
    expect(() => remoteConfigUpdateSchema.parse({
      maxJournals: 0,
      maxKeywords: 101,
      expectedEtag: "etag",
      description: "change",
    })).toThrow();
  });

  it("requires an expected ETag for Remote Config rollback", () => {
    expect(rollbackSchema.safeParse({ versionNumber: 7 }).success).toBe(false);
    expect(rollbackSchema.safeParse({
      versionNumber: 7,
      expectedEtag: "etag-from-read",
    }).success).toBe(true);
  });

  it("accepts a bounded Remote Config versions page token", () => {
    expect(versionsQuerySchema.parse({
      limit: "20",
      pageToken: "next-page-token",
    })).toEqual({
      limit: 20,
      pageToken: "next-page-token",
    });
  });

  it("accepts a fully qualified Crashlytics table", () => {
    expect(parseCrashlyticsTable("journal-trend-analyzer.firebase_crashlytics.com_app_ANDROID"))
      .toBe("journal-trend-analyzer.firebase_crashlytics.com_app_ANDROID");
  });

  it.each([
    "dataset.table",
    "project.dataset.table;DROP TABLE x",
    "project.dataset.`table`",
    "UPPER_PROJECT.dataset.table",
  ])("rejects unsafe BigQuery identifier %s", (value) => {
    expect(() => parseCrashlyticsTable(value)).toThrow();
  });

  it("limits custom FCM data fields", () => {
    const data = Object.fromEntries(
      Array.from({ length: 51 }, (_, index) => [`key${index}`, "value"]),
    );
    expect(() => messageSchema.parse({
      target: "x".repeat(30),
      title: "Test",
      body: "Body",
      data,
    })).toThrow();
  });

  it("accepts a broadcast message without a device target", () => {
    expect(broadcastMessageSchema.parse({
      title: "System update",
      body: "A new report feature is available.",
      data: { source: "admin-web" },
    })).toEqual({
      title: "System update",
      body: "A new report feature is available.",
      data: { source: "admin-web" },
    });
  });

  it("does not allow clients to override the broadcast topic", () => {
    expect(broadcastMessageSchema.safeParse({
      topic: "unexpected-topic",
      title: "System update",
      body: "Body",
    }).success).toBe(false);
  });

  it("validates campaign audience and delivery options", () => {
    expect(campaignCreateSchema.parse({
      name: "July release",
      title: "New report",
      body: "Monthly reports are now available.",
      audience: "platform_android",
      scheduleAt: "2026-07-25T08:00:00+07:00",
      ttlSeconds: 86_400,
      sound: true,
    })).toMatchObject({
      audience: "platform_android",
      ttlSeconds: 86_400,
      sound: true,
    });
    expect(campaignCreateSchema.safeParse({
      name: "Invalid audience",
      title: "Title",
      body: "Body",
      audience: "arbitrary_topic",
    }).success).toBe(false);
  });

  it.each(["from", "message_type", "google.analytics", "gcm.notification"])(
    "rejects reserved FCM data key %s",
    (key) => {
      expect(() => messageSchema.parse({
        target: "x".repeat(30),
        title: "Test",
        body: "Body",
        data: { [key]: "value" },
      })).toThrow();
    },
  );

  it("enforces the 4096-byte combined FCM notification and data boundary", () => {
    const baseMessage = {
      target: "x".repeat(30),
      title: "Test",
      body: "Body",
    };
    const emptyEnvelopeBytes = fcmPayloadSizeBytes({
      ...baseMessage,
      data: { first: "", second: "" },
    });
    const availableBytes = 4096 - emptyEnvelopeBytes;
    const firstLength = Math.floor(availableBytes / 2);
    const withinLimit = {
      first: "a".repeat(firstLength),
      second: "b".repeat(availableBytes - firstLength),
    };
    const overLimit = { ...withinLimit, second: `${withinLimit.second}b` };

    expect(fcmDataSizeBytes(withinLimit)).toBeLessThan(4096);
    expect(fcmPayloadSizeBytes({ ...baseMessage, data: withinLimit })).toBe(4096);
    expect(messageSchema.safeParse({ ...baseMessage, data: withinLimit }).success).toBe(true);
    expect(fcmPayloadSizeBytes({ ...baseMessage, data: overLimit })).toBe(4097);
    expect(messageSchema.safeParse({ ...baseMessage, data: overLimit }).success).toBe(false);
  });

  it("counts multi-byte FCM data as UTF-8 bytes", () => {
    const data = { emoji: "😀".repeat(1024) };
    expect(fcmDataSizeBytes(data)).toBeGreaterThan(4096);
    expect(messageSchema.safeParse({
      target: "x".repeat(30),
      title: "Test",
      body: "Body",
      data,
    }).success).toBe(false);
  });
});
