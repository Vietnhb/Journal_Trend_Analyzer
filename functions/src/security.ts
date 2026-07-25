import type { DecodedIdToken } from "firebase-admin/auth";

import { ApiError } from "./errors.js";

export type ProtectedSelfOperation = "disable" | "delete" | "demote";

export function assertNotSelf(
  actorUid: string,
  targetUid: string,
  operation: ProtectedSelfOperation,
): void {
  if (actorUid === targetUid) {
    throw new ApiError(
      409,
      "self_protection",
      `Administrators cannot ${operation} their own account.`,
    );
  }
}

export function mergeAdminClaim(
  existingClaims: Readonly<Record<string, unknown>> | undefined,
  admin: boolean,
): Record<string, unknown> {
  const claims = { ...existingClaims };
  if (admin) claims.admin = true;
  else delete claims.admin;
  return claims;
}

export function hasAdminClaim(token: DecodedIdToken | Record<string, unknown>): boolean {
  return token.admin === true;
}

export function isFirebaseInstallationId(target: string): boolean {
  return /^[A-Za-z0-9_-]{22}$/.test(target);
}
