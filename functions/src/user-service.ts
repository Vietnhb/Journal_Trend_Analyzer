import type { UserRecord } from "firebase-admin/auth";

import { adminAuth } from "./firebase.js";
import { ApiError } from "./errors.js";

let adminInvariantTail: Promise<void> = Promise.resolve();

export async function withAdminInvariantLock<T>(operation: () => Promise<T>): Promise<T> {
  let release = (): void => undefined;
  const currentTurn = new Promise<void>((resolve) => {
    release = resolve;
  });
  const previousTurn = adminInvariantTail;
  adminInvariantTail = currentTurn;
  await previousTurn;
  try {
    return await operation();
  } finally {
    release();
  }
}

export async function listAllUsers(): Promise<UserRecord[]> {
  const users: UserRecord[] = [];
  let pageToken: string | undefined;
  do {
    const page = await adminAuth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken !== undefined);
  return users;
}

export interface AuthAdminState {
  uid: string;
  disabled: boolean;
  customClaims?: Readonly<Record<string, unknown>>;
}

export function isActiveAdmin(user: AuthAdminState): boolean {
  return !user.disabled && user.customClaims?.admin === true;
}

export function hasAnotherActiveAdmin(
  users: readonly AuthAdminState[],
  targetUid: string,
): boolean {
  return users.some((user) => user.uid !== targetUid && isActiveAdmin(user));
}

export async function assertNotLastActiveAdmin(target: UserRecord): Promise<void> {
  if (!isActiveAdmin(target)) return;
  const users = await listAllUsers();
  if (!hasAnotherActiveAdmin(users, target.uid)) {
    throw new ApiError(
      409,
      "last_admin_protection",
      "The last active administrator cannot be disabled, demoted, or deleted.",
    );
  }
}
