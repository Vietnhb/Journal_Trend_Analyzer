import { Router } from "express";

import { writeMutationAudit } from "../audit.js";
import { sendData } from "../errors.js";
import { getAdminRemoteConfig } from "../firebase.js";
import {
  getRemoteConfigData,
  getRemoteConfigVersionData,
  rollbackRemoteConfig,
  updateRemoteConfig,
} from "../remote-config-service.js";
import { serializeRemoteConfigVersion } from "../serializers.js";
import {
  remoteConfigUpdateSchema,
  remoteConfigVersionParamSchema,
  rollbackSchema,
  singleQueryValue,
  versionsQuerySchema,
} from "../validation.js";

export const remoteConfigRouter = Router();

remoteConfigRouter.get("/", async (_req, res) => {
  sendData(res, await getRemoteConfigData());
});

remoteConfigRouter.put("/", async (req, res) => {
  const input = remoteConfigUpdateSchema.parse(req.body as unknown);
  const data = await updateRemoteConfig(input);
  await writeMutationAudit(req, {
    action: "remote_config.update",
    targetType: "remote_config",
    targetId: "client-template",
    summary: "Published journal and keyword limits.",
    details: {
      maxJournals: input.maxJournals,
      maxKeywords: input.maxKeywords,
      description: input.description,
    },
  });
  sendData(res, data);
});

remoteConfigRouter.get("/versions", async (req, res) => {
  const { limit, pageToken } = versionsQuerySchema.parse({
    limit: singleQueryValue(req.query.limit),
    pageToken: singleQueryValue(req.query.pageToken),
  });
  const result = await getAdminRemoteConfig().listVersions({
    pageSize: limit,
    ...(pageToken === undefined ? {} : { pageToken }),
  });
  sendData(res, {
    versions: result.versions.map(serializeRemoteConfigVersion),
    nextPageToken: result.nextPageToken ?? null,
  });
});

remoteConfigRouter.get("/versions/:versionNumber", async (req, res) => {
  const { versionNumber } = remoteConfigVersionParamSchema.parse(req.params);
  sendData(res, await getRemoteConfigVersionData(versionNumber));
});

remoteConfigRouter.post("/rollback", async (req, res) => {
  const input = rollbackSchema.parse(req.body as unknown);
  const published = await rollbackRemoteConfig(input);
  await writeMutationAudit(req, {
    action: "remote_config.rollback",
    targetType: "remote_config",
    targetId: String(input.versionNumber),
    summary: `Rolled back Remote Config to version ${input.versionNumber}.`,
  });
  sendData(res, published);
});
