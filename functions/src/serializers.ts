import type { UserRecord } from "firebase-admin/auth";
import type { Version } from "firebase-admin/remote-config";

export function serializeUser(user: UserRecord): Record<string, unknown> {
  return {
    uid: user.uid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    photoURL: user.photoURL ?? null,
    disabled: user.disabled,
    emailVerified: user.emailVerified,
    admin: user.customClaims?.admin === true,
    providers: user.providerData.map((provider) => provider.providerId),
    createdAt: user.metadata.creationTime,
    lastSignInAt: user.metadata.lastSignInTime ?? null,
    lastRefreshAt: user.metadata.lastRefreshTime ?? null,
  };
}

export function serializeRemoteConfigVersion(version: Version | undefined): Record<string, unknown> {
  const updateUser = version?.updateUser as { email?: unknown; name?: unknown } | undefined;
  const email = typeof updateUser?.email === "string" && updateUser.email.trim().length > 0
    ? updateUser.email.trim()
    : null;
  const name = typeof updateUser?.name === "string" && updateUser.name.trim().length > 0
    ? updateUser.name.trim()
    : null;
  return {
    versionNumber: version?.versionNumber ?? null,
    updatedAt: version?.updateTime ?? null,
    description: version?.description ?? null,
    updateOrigin: version?.updateOrigin ?? null,
    updateType: version?.updateType ?? null,
    updatedBy: email ?? name,
    rollbackSource: version?.rollbackSource ?? null,
  };
}
