import { Router } from "express";

import {
  cancelCampaign,
  createCampaign,
  listCampaigns,
} from "../campaign-service.js";
import { writeMutationAudit } from "../audit.js";
import { sendData } from "../errors.js";
import { requireRequestActor } from "../request-context.js";
import {
  campaignCreateSchema,
  campaignIdParamSchema,
  campaignsQuerySchema,
  singleQueryValue,
} from "../validation.js";

export const campaignsRouter = Router();

campaignsRouter.get("/", async (req, res) => {
  const { limit } = campaignsQuerySchema.parse({
    limit: singleQueryValue(req.query.limit),
  });
  sendData(res, { campaigns: await listCampaigns(limit) });
});

campaignsRouter.post("/", async (req, res) => {
  const input = campaignCreateSchema.parse(req.body as unknown);
  const actor = requireRequestActor(req);
  const campaign = await createCampaign(input, actor);
  await writeMutationAudit(req, {
    action: input.scheduleAt == null ? "message.campaign.send" : "message.campaign.schedule",
    targetType: "fcm_campaign",
    targetId: String(campaign.id),
    summary: input.scheduleAt == null
      ? "Created and sent an FCM campaign."
      : "Created a scheduled FCM campaign.",
    details: { audience: input.audience, scheduleAt: input.scheduleAt ?? null },
  });
  sendData(res, campaign, 201);
});

campaignsRouter.post("/:campaignId/cancel", async (req, res) => {
  const { campaignId } = campaignIdParamSchema.parse(req.params);
  const campaign = await cancelCampaign(campaignId);
  await writeMutationAudit(req, {
    action: "message.campaign.cancel",
    targetType: "fcm_campaign",
    targetId: campaignId,
    summary: "Canceled a scheduled FCM campaign.",
  });
  sendData(res, campaign);
});
