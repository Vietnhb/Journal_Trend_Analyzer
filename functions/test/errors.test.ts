import { describe, expect, it } from "vitest";

import { mapExternalError } from "../src/errors.js";

function sdkError(code: string): Error {
  return Object.assign(new Error("sensitive SDK detail"), { code });
}

describe("external SDK error mapping", () => {
  it.each([
    Object.assign(
      new Error(
        "7 PERMISSION_DENIED: Cloud Firestore API has not been used in project before or it is disabled. Enable it at firestore.googleapis.com.",
      ),
      { code: 7 },
    ),
    Object.assign(
      new Error("5 NOT_FOUND: The database (default) does not exist for project."),
      { code: 5 },
    ),
  ])("maps an unconfigured Firestore service to an actionable error", (error) => {
    const mapped = mapExternalError(error);
    expect(mapped.status).toBe(503);
    expect(mapped.code).toBe("firestore_not_configured");
    expect(mapped.message).toContain("Cloud Firestore");
    expect(mapped.message).not.toContain("PERMISSION_DENIED");
  });

  it("maps a Remote Config failed precondition to conflict", () => {
    const mapped = mapExternalError(sdkError("remote-config/failed-precondition"));
    expect(mapped.status).toBe(409);
    expect(mapped.code).toBe("conflict");
  });

  it.each([
    ["messaging/payload-size-limit-exceeded", 413, "message_payload_too_large"],
    ["messaging/invalid-data-payload-key", 400, "invalid_message_payload"],
    ["messaging/installation-id-not-registered", 410, "message_target_not_registered"],
    ["messaging/registration-token-not-registered", 410, "message_target_not_registered"],
  ] as const)("maps %s to HTTP %i", (sdkCode, status, apiCode) => {
    const mapped = mapExternalError(sdkError(sdkCode));
    expect(mapped.status).toBe(status);
    expect(mapped.code).toBe(apiCode);
    expect(mapped.message).not.toContain("sensitive SDK detail");
  });
});
