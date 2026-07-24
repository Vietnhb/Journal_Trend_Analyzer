import { createHash } from "node:crypto";

import { Router } from "express";

import { timestampToIso, writeMutationAudit } from "./audit.js";
import { loadAnalytics } from "./analytics-service.js";
import { AUDIT_COLLECTION, BROADCAST_TOPIC } from "./constants.js";
import { loadCrashes } from "./crash-service.js";
import { sendData } from "./errors.js";
import {
  adminAuth,
  adminFirestore,
  adminMessaging,
  getAdminRemoteConfig,
} from "./firebase.js";
import { scanReportTotals } from "./report-service.js";
import { requireRequestActor } from "./request-context.js";
import { remoteConfigRouter } from "./routes/remote-config.js";
import { reportsRouter } from "./routes/reports.js";
import { campaignsRouter } from "./routes/campaigns.js";
import { usersRouter } from "./routes/users.js";
import { isFirebaseInstallationId } from "./security.js";
import { listAllUsers } from "./user-service.js";
import {
  auditQuerySchema,
  broadcastMessageSchema,
  dateRangeQuerySchema,
  messageSchema,
  singleQueryValue,
} from "./validation.js";

export const apiRouter = Router();

apiRouter.get("/me", async (req, res) => {
  const actor = requireRequestActor(req);
  const user = await adminAuth.getUser(actor.uid);
  sendData(res, {
    uid: user.uid,
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    photoURL: user.photoURL ?? null,
    admin: user.customClaims?.admin === true,
  });
});

apiRouter.get("/overview", async (_req, res) => {
  const [users, reports, template] = await Promise.all([
    listAllUsers(),
    scanReportTotals(),
    getAdminRemoteConfig().getTemplate(),
  ]);
  const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
  sendData(res, {
    users: {
      total: users.length,
      admins: users.filter((user) => user.customClaims?.admin === true).length,
      disabled: users.filter((user) => user.disabled).length,
      newLast30Days: users.filter(
        (user) => new Date(user.metadata.creationTime).getTime() >= thirtyDaysAgo,
      ).length,
    },
    reports,
    remoteConfig: {
      versionNumber: template.version?.versionNumber ?? null,
      updatedAt: template.version?.updateTime ?? null,
    },
  });
});

apiRouter.use("/users", usersRouter);
apiRouter.use("/remote-config", remoteConfigRouter);
apiRouter.use("/reports", reportsRouter);
apiRouter.use("/campaigns", campaignsRouter);

apiRouter.post("/messages/test", async (req, res) => {
  const input = messageSchema.parse(req.body as unknown);
  const targetFingerprint = createHash("sha256")
    .update(input.target)
    .digest("hex")
    .slice(0, 16);
  const messageId = await adminMessaging.send({
    ...(isFirebaseInstallationId(input.target)
      ? { fid: input.target }
      : { token: input.target }),
    notification: { title: input.title, body: input.body },
    ...(input.data === undefined ? {} : { data: input.data }),
  });
  await writeMutationAudit(req, {
    action: "message.test.send",
    targetType: "fcm_target",
    targetId: targetFingerprint,
    summary: "Sent a test Firebase Cloud Messaging notification.",
    details: { targetFingerprint, dataFieldCount: Object.keys(input.data ?? {}).length },
  });
  sendData(res, { messageId, targetFingerprint });
});

apiRouter.post("/messages/broadcast", async (req, res) => {
  const input = broadcastMessageSchema.parse(req.body as unknown);
  const messageId = await adminMessaging.send({
    topic: BROADCAST_TOPIC,
    notification: { title: input.title, body: input.body },
    ...(input.data === undefined ? {} : { data: input.data }),
  });
  await writeMutationAudit(req, {
    action: "message.broadcast.send",
    targetType: "fcm_topic",
    targetId: BROADCAST_TOPIC,
    summary: "Sent a Firebase Cloud Messaging broadcast notification.",
    details: {
      topic: BROADCAST_TOPIC,
      dataFieldCount: Object.keys(input.data ?? {}).length,
    },
  });
  sendData(res, { messageId, topic: BROADCAST_TOPIC });
});

apiRouter.get("/analytics", async (req, res) => {
  const range = dateRangeQuerySchema.parse({
    days: singleQueryValue(req.query.days),
    start: singleQueryValue(req.query.start),
    end: singleQueryValue(req.query.end),
  });
  sendData(
    res,
    await loadAnalytics(range, req.get("x-google-analytics-token")),
  );
});

apiRouter.get("/crashes", async (req, res) => {
  const range = dateRangeQuerySchema.parse({
    days: singleQueryValue(req.query.days),
    start: singleQueryValue(req.query.start),
    end: singleQueryValue(req.query.end),
  });
  sendData(res, await loadCrashes(range));
});

apiRouter.get("/audit-logs", async (req, res) => {
  const { limit } = auditQuerySchema.parse({
    limit: singleQueryValue(req.query.limit),
  });
  const snapshot = await adminFirestore
    .collection(AUDIT_COLLECTION)
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  sendData(res, {
    logs: snapshot.docs.map((document) => {
      const data = document.data();
      return {
        id: document.id,
        actorUid: typeof data.actorUid === "string" ? data.actorUid : null,
        actorEmail: typeof data.actorEmail === "string" ? data.actorEmail : null,
        action: typeof data.action === "string" ? data.action : "unknown",
        targetType: typeof data.targetType === "string" ? data.targetType : "unknown",
        targetId: typeof data.targetId === "string" ? data.targetId : "unknown",
        summary: typeof data.summary === "string" ? data.summary : "",
        createdAt: timestampToIso(data.createdAt),
      };
    }),
  });
});
