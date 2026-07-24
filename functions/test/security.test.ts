import { describe, expect, it } from "vitest";

import { ApiError } from "../src/errors.js";
import {
  assertNotSelf,
  isFirebaseInstallationId,
  mergeAdminClaim,
} from "../src/security.js";
import { hasAnotherActiveAdmin } from "../src/user-service.js";

describe("admin claim safeguards", () => {
  it("preserves unrelated claims when granting admin", () => {
    expect(mergeAdminClaim({ plan: "pro", reviewer: true }, true)).toEqual({
      plan: "pro",
      reviewer: true,
      admin: true,
    });
  });

  it("removes only the admin claim when demoting", () => {
    expect(mergeAdminClaim({ admin: true, plan: "pro" }, false)).toEqual({
      plan: "pro",
    });
  });

  it.each(["disable", "delete", "demote"] as const)(
    "denies self %s",
    (operation) => {
      expect(() => assertNotSelf("same-user", "same-user", operation)).toThrowError(ApiError);
    },
  );

  it("allows a protected operation against a different user", () => {
    expect(() => assertNotSelf("admin-1", "user-2", "delete")).not.toThrow();
  });

  it("distinguishes a Firebase installation ID from a legacy registration token", () => {
    expect(isFirebaseInstallationId("cdefghijklmnopqrstuvwx")).toBe(true);
    expect(isFirebaseInstallationId("long-registration-token:with-more-data")).toBe(false);
  });

  it("protects the last active administrator", () => {
    const users = [
      { uid: "admin-1", disabled: false, customClaims: { admin: true } },
      { uid: "disabled-admin", disabled: true, customClaims: { admin: true } },
      { uid: "ordinary-user", disabled: false, customClaims: {} },
    ];
    expect(hasAnotherActiveAdmin(users, "admin-1")).toBe(false);
    expect(hasAnotherActiveAdmin(
      [...users, { uid: "admin-2", disabled: false, customClaims: { admin: true } }],
      "admin-1",
    )).toBe(true);
  });
});
