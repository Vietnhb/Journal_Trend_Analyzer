import { Router } from "express";

import { writeMutationAudit } from "../audit.js";
import { adminAuth } from "../firebase.js";
import { sendData } from "../errors.js";
import { requireRequestActor } from "../request-context.js";
import { assertNotSelf, mergeAdminClaim } from "../security.js";
import { serializeUser } from "../serializers.js";
import {
  assertNotLastActiveAdmin,
  withAdminInvariantLock,
} from "../user-service.js";
import {
  roleSchema,
  singleQueryValue,
  uidParamSchema,
  updateUserSchema,
  usersQuerySchema,
} from "../validation.js";

export const usersRouter = Router();

function codeOf(error: unknown): string {
  if (!(error instanceof Error) || !("code" in error)) return "";
  const code = error.code;
  return typeof code === "string" || typeof code === "number" ? String(code) : "";
}

usersRouter.get("/", async (req, res) => {
  const query = usersQuerySchema.parse({
    pageToken: singleQueryValue(req.query.pageToken),
    pageSize: singleQueryValue(req.query.pageSize),
    query: singleQueryValue(req.query.query),
  });

  if (query.query !== undefined) {
    try {
      const user = query.query.includes("@")
        ? await adminAuth.getUserByEmail(query.query)
        : await adminAuth.getUser(query.query);
      sendData(res, { users: [serializeUser(user)], nextPageToken: null });
    } catch (error) {
      if (codeOf(error).endsWith("/user-not-found")) {
        sendData(res, { users: [], nextPageToken: null });
        return;
      }
      throw error;
    }
    return;
  }

  const page = await adminAuth.listUsers(query.pageSize, query.pageToken);
  sendData(res, {
    users: page.users.map(serializeUser),
    nextPageToken: page.pageToken ?? null,
  });
});

usersRouter.patch("/:uid", async (req, res) => {
  const { uid } = uidParamSchema.parse(req.params);
  const input = updateUserSchema.parse(req.body as unknown);
  const actor = requireRequestActor(req);
  const updateRequest = {
    ...(input.displayName === undefined ? {} : { displayName: input.displayName }),
    ...(input.email === undefined ? {} : { email: input.email }),
    ...(input.emailVerified === undefined ? {} : { emailVerified: input.emailVerified }),
    ...(input.disabled === undefined ? {} : { disabled: input.disabled }),
  };
  const update = async () => {
    if (input.disabled === true) {
      const current = await adminAuth.getUser(uid);
      assertNotSelf(actor.uid, uid, "disable");
      await assertNotLastActiveAdmin(current);
    }
    return adminAuth.updateUser(uid, updateRequest);
  };
  const updated = input.disabled === true
    ? await withAdminInvariantLock(update)
    : await update();
  const changedFields = Object.keys(input).sort();
  await writeMutationAudit(req, {
    action: "user.update",
    targetType: "user",
    targetId: uid,
    summary: `Updated user fields: ${changedFields.join(", ")}.`,
    details: { changedFields },
  });
  sendData(res, serializeUser(updated));
});

usersRouter.put("/:uid/role", async (req, res) => {
  const { uid } = uidParamSchema.parse(req.params);
  const { admin } = roleSchema.parse(req.body as unknown);
  const actor = requireRequestActor(req);
  const result = await withAdminInvariantLock(async () => {
    const current = await adminAuth.getUser(uid);
    const wasAdmin = current.customClaims?.admin === true;
    if (!admin) {
      assertNotSelf(actor.uid, uid, "demote");
      await assertNotLastActiveAdmin(current);
    }
    if (wasAdmin !== admin) {
      await adminAuth.setCustomUserClaims(
        uid,
        mergeAdminClaim(current.customClaims, admin),
      );
      if (!admin) await adminAuth.revokeRefreshTokens(uid);
    }
    return { wasAdmin, user: await adminAuth.getUser(uid) };
  });

  if (result.wasAdmin !== admin) {
    await writeMutationAudit(req, {
      action: admin ? "user.role.grant_admin" : "user.role.revoke_admin",
      targetType: "user",
      targetId: uid,
      summary: admin ? "Granted administrator role." : "Revoked administrator role and sessions.",
      details: { previousAdmin: result.wasAdmin, admin },
    });
  }

  sendData(res, serializeUser(result.user));
});

usersRouter.post("/:uid/revoke", async (req, res) => {
  const { uid } = uidParamSchema.parse(req.params);
  await adminAuth.getUser(uid);
  await adminAuth.revokeRefreshTokens(uid);
  await writeMutationAudit(req, {
    action: "user.sessions.revoke",
    targetType: "user",
    targetId: uid,
    summary: "Revoked all refresh tokens.",
  });
  sendData(res, { uid, revoked: true });
});

usersRouter.delete("/:uid", async (req, res) => {
  const { uid } = uidParamSchema.parse(req.params);
  const actor = requireRequestActor(req);
  assertNotSelf(actor.uid, uid, "delete");
  await withAdminInvariantLock(async () => {
    const current = await adminAuth.getUser(uid);
    await assertNotLastActiveAdmin(current);
    await adminAuth.deleteUser(uid);
  });
  await writeMutationAudit(req, {
    action: "user.delete",
    targetType: "user",
    targetId: uid,
    summary: "Deleted Firebase Authentication user.",
  });
  sendData(res, { uid, deleted: true });
});
