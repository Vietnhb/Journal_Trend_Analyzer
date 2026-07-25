#!/usr/bin/env node
import { parseArgs } from "node:util";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

function usage() {
  return [
    "Usage:",
    "  npm run set-admin -- --email admin@example.com --project PROJECT_ID",
    "  npm run set-admin -- --uid FIREBASE_UID --project PROJECT_ID",
    "  npm run set-admin -- --email admin@example.com --revoke --project PROJECT_ID",
    "",
    "--revoke removes only the admin claim, preserves all other claims, and revokes sessions.",
  ].join("\n");
}

const { values } = parseArgs({
  options: {
    email: { type: "string" },
    uid: { type: "string" },
    project: { type: "string" },
    revoke: { type: "boolean", default: false },
    help: { type: "boolean", short: "h", default: false },
  },
  strict: true,
});

if (values.help) {
  console.log(usage());
  process.exitCode = 0;
} else if ((values.email === undefined) === (values.uid === undefined)) {
  console.error("Provide exactly one of --email or --uid.\n\n" + usage());
  process.exitCode = 2;
} else if (values.project === undefined || values.project.trim().length === 0) {
  console.error(
    "--project is required to prevent granting admin access in the wrong Firebase project.\n\n" +
      usage(),
  );
  process.exitCode = 2;
} else {
  try {
    await run();
  } catch (error) {
    const safeMessage = error instanceof Error &&
      error.message === "Refusing to revoke the last active administrator."
      ? error.message
      : "Admin role update failed. Check ADC, project ID, IAM access, and the user selector.";
    const code = error instanceof Error && "code" in error &&
      (typeof error.code === "string" || typeof error.code === "number")
      ? ` (${String(error.code)})`
      : "";
    console.error(`${safeMessage}${code}`);
    process.exitCode = 1;
  }
}

async function allUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken !== undefined);
  return users;
}

async function assertAnotherActiveAdmin(auth, user, claims) {
  if (user.disabled || claims.admin !== true) return;
  const activeAdmins = (await allUsers(auth)).filter(
    (candidate) => !candidate.disabled && candidate.customClaims?.admin === true,
  );
  if (activeAdmins.length <= 1) {
    throw new Error("Refusing to revoke the last active administrator.");
  }
}

async function run() {
  const app = initializeApp({
    credential: applicationDefault(),
    projectId: values.project.trim(),
  });
  const auth = getAuth(app);
  const user = values.uid === undefined
    ? await auth.getUserByEmail(values.email)
    : await auth.getUser(values.uid);
  const claims = { ...user.customClaims };

  if (values.revoke) {
    await assertAnotherActiveAdmin(auth, user, claims);
    delete claims.admin;
  } else {
    claims.admin = true;
  }

  await auth.setCustomUserClaims(user.uid, claims);
  await auth.revokeRefreshTokens(user.uid);

  const action = values.revoke ? "bootstrap.role.revoke_admin" : "bootstrap.role.grant_admin";
  try {
    await getFirestore(app).collection("admin_audit_logs").add({
      requestId: `bootstrap-${Date.now()}`,
      actorUid: "bootstrap-script",
      actorEmail: null,
      action,
      targetType: "user",
      targetId: user.uid,
      summary: values.revoke
        ? "Revoked administrator role using trusted bootstrap script."
        : "Granted administrator role using trusted bootstrap script.",
      details: {},
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    const code = error instanceof Error && "code" in error ? String(error.code) : "unknown";
    console.warn(`Role changed, but audit logging failed (${code}).`);
  }

  console.log(`${values.revoke ? "Revoked" : "Granted"} admin role for UID ${user.uid}.`);
  console.log("Existing refresh tokens were revoked; the user must sign in again.");
}
