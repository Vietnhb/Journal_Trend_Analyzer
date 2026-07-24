import { describe, expect, it } from "vitest";

import { mapExternalError } from "../src/errors.js";

function sdkError(code: string): Error {
  return Object.assign(new Error("sensitive SDK detail"), { code });
}

describe("external SDK error mapping", () => {
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
