import { describe, expect, it } from "vitest";

import {
  analyticsStreamFilter,
  formatAnalyticsDate,
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
});
