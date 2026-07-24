import { describe, expect, it } from "vitest";

import { selectCrashlyticsTableNames } from "../src/crash-service.js";

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
});
