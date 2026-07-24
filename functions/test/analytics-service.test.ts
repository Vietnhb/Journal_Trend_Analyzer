import { describe, expect, it } from "vitest";

import {
  analyticsStreamFilter,
  formatAnalyticsDate,
  selectAndroidStreamId,
} from "../src/analytics-service.js";

describe("Analytics Data API date formatting", () => {
  it("converts GA4 compact dates to ISO dates", () => {
    expect(formatAnalyticsDate("20260724")).toBe("2026-07-24");
  });

  it("preserves unknown date values safely", () => {
    expect(formatAnalyticsDate("not-a-date")).toBe("not-a-date");
    expect(formatAnalyticsDate(undefined)).toBe("");
  });
});

describe("Analytics stream scoping", () => {
  it("creates an exact GA4 streamId dimension filter", () => {
    expect(analyticsStreamFilter("15254447622")).toEqual({
      filter: {
        fieldName: "streamId",
        stringFilter: { matchType: "EXACT", value: "15254447622" },
      },
    });
  });

  it("selects the Android stream matching the Journal Trend package", () => {
    expect(selectAndroidStreamId([
      {
        name: "properties/542374527/dataStreams/111",
        type: "WEB_DATA_STREAM",
      },
      {
        name: "properties/542374527/dataStreams/222",
        type: "ANDROID_APP_DATA_STREAM",
        androidAppStreamData: {
          packageName: "com.prm393.journal_trend_analyzer",
        },
      },
    ])).toBe("222");
  });

  it("uses the only Android stream when package metadata is unavailable", () => {
    expect(selectAndroidStreamId([
      {
        name: "properties/542374527/dataStreams/333",
        type: "ANDROID_APP_DATA_STREAM",
      },
    ])).toBe("333");
  });

  it("does not guess when multiple Android streams do not match", () => {
    expect(selectAndroidStreamId([
      {
        name: "properties/542374527/dataStreams/444",
        type: "ANDROID_APP_DATA_STREAM",
        androidAppStreamData: { packageName: "com.example.first" },
      },
      {
        name: "properties/542374527/dataStreams/555",
        type: "ANDROID_APP_DATA_STREAM",
        androidAppStreamData: { packageName: "com.example.second" },
      },
    ])).toBeNull();
  });
});
