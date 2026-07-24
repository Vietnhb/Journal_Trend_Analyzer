import { describe, expect, it } from "vitest";

import {
  crashlyticsTablePrefix,
  selectCrashlyticsTableNames,
} from "../src/crash-service.js";

describe("Crashlytics table discovery", () => {
  it("combines batch and realtime tables for stitched reporting", () => {
    expect(selectCrashlyticsTableNames([
      "com_example_app_ANDROID",
      "com_example_app_ANDROID_REALTIME",
      "firebase_sessions_ANDROID",
    ])).toEqual([
      "com_example_app_ANDROID",
      "com_example_app_ANDROID_REALTIME",
    ]);
  });

  it("uses realtime tables while no batch table exists", () => {
    expect(selectCrashlyticsTableNames([
      "com_example_app_IOS_REALTIME",
      "unsupported_table",
    ])).toEqual(["com_example_app_IOS_REALTIME"]);
  });

  it("converts an Android package name to its Crashlytics table prefix", () => {
    expect(crashlyticsTablePrefix("com.prm393.journal_trend_analyzer"))
      .toBe("com_prm393_journal_trend_analyzer_ANDROID");
  });

  it("selects only batch and realtime tables for the configured Android app", () => {
    expect(selectCrashlyticsTableNames([
      "com_laundrylocker_mobile_ANDROID",
      "com_prm393_journal_trend_analyzer_ANDROID_REALTIME",
      "com_prm393_journal_trend_analyzer_ANDROID",
      "com_other_app_IOS",
    ], "com.prm393.journal_trend_analyzer")).toEqual([
      "com_prm393_journal_trend_analyzer_ANDROID",
      "com_prm393_journal_trend_analyzer_ANDROID_REALTIME",
    ]);
  });
});
