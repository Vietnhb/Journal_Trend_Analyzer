import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentReference,
} from "firebase-admin/firestore";
import type { Message } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

import { CAMPAIGN_COLLECTION } from "./constants.js";
import { ApiError, safeErrorDetails } from "./errors.js";
import { adminFirestore, adminMessaging } from "./firebase.js";

export const CAMPAIGN_AUDIENCES = {
  all_users: "all_users",
  platform_android: "platform_android",
  platform_ios: "platform_ios",
  language_vi: "language_vi",
  language_en: "language_en",
} as const;

export type CampaignAudience = keyof typeof CAMPAIGN_AUDIENCES;
export type CampaignStatus = "scheduled" | "sending" | "sent" | "failed" | "canceled";

export interface CreateCampaignInput {
  name: string;
  title: string;
  body: string;
  data?: Record<string, string> | undefined;
  audience: CampaignAudience;
  scheduleAt?: string | null | undefined;
  ttlSeconds: number;
  sound: boolean;
}

interface StoredCampaign {
  name: string;
  title: string;
  body: string;
  data: Record<string, string>;
  audience: CampaignAudience;
  ttlSeconds: number;
  sound: boolean;
  status: CampaignStatus;
  scheduleAt: Timestamp | null;
  createdAt: Timestamp | FieldValue;
  createdByUid: string;
  createdByEmail: string | null;
  sentAt: Timestamp | null;
  canceledAt: Timestamp | null;
  messageId: string | null;
  errorCode: string | null;
}

function timestampIso(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

export function serializeCampaign(id: string, value: DocumentData): Record<string, unknown> {
  return {
    id,
    name: typeof value.name === "string" ? value.name : "",
    title: typeof value.title === "string" ? value.title : "",
    body: typeof value.body === "string" ? value.body : "",
    data: typeof value.data === "object" && value.data !== null ? value.data : {},
    audience: typeof value.audience === "string" ? value.audience : "all_users",
    ttlSeconds: typeof value.ttlSeconds === "number" ? value.ttlSeconds : 86_400,
    sound: value.sound !== false,
    status: typeof value.status === "string" ? value.status : "failed",
    scheduleAt: timestampIso(value.scheduleAt),
    createdAt: timestampIso(value.createdAt),
    sentAt: timestampIso(value.sentAt),
    canceledAt: timestampIso(value.canceledAt),
    messageId: typeof value.messageId === "string" ? value.messageId : null,
    errorCode: typeof value.errorCode === "string" ? value.errorCode : null,
  };
}

function fcmMessage(campaign: StoredCampaign): Message {
  const expiration = Math.floor(Date.now() / 1000) + campaign.ttlSeconds;
  return {
    topic: CAMPAIGN_AUDIENCES[campaign.audience],
    notification: { title: campaign.title, body: campaign.body },
    ...(Object.keys(campaign.data).length === 0 ? {} : { data: campaign.data }),
    android: {
      ttl: campaign.ttlSeconds * 1000,
      notification: campaign.sound ? { sound: "default" } : {},
    },
    apns: {
      headers: { "apns-expiration": String(expiration) },
      payload: { aps: campaign.sound ? { sound: "default" } : {} },
    },
  };
}

async function finishSend(
  reference: DocumentReference,
  campaign: StoredCampaign,
): Promise<void> {
  try {
    const messageId = await adminMessaging.send(fcmMessage(campaign));
    await reference.update({
      status: "sent",
      sentAt: FieldValue.serverTimestamp(),
      messageId,
      errorCode: null,
    });
  } catch (error) {
    const details = safeErrorDetails(error);
    await reference.update({
      status: "failed",
      errorCode: typeof details.errorCode === "string" ? details.errorCode : "unknown",
    });
    throw error;
  }
}

export async function createCampaign(
  input: CreateCampaignInput,
  actor: { uid: string; email?: string | undefined },
): Promise<Record<string, unknown>> {
  const scheduleDate = input.scheduleAt == null ? null : new Date(input.scheduleAt);
  if (scheduleDate !== null) {
    if (!Number.isFinite(scheduleDate.getTime())) {
      throw new ApiError(400, "invalid_schedule", "The campaign schedule is invalid.");
    }
    if (scheduleDate.getTime() < Date.now() + 60_000) {
      throw new ApiError(
        400,
        "invalid_schedule",
        "A scheduled campaign must be at least one minute in the future.",
      );
    }
    if (scheduleDate.getTime() > Date.now() + 366 * 24 * 60 * 60 * 1000) {
      throw new ApiError(
        400,
        "invalid_schedule",
        "A campaign cannot be scheduled more than one year ahead.",
      );
    }
  }

  const status: CampaignStatus = scheduleDate === null ? "sending" : "scheduled";
  const campaign: StoredCampaign = {
    name: input.name,
    title: input.title,
    body: input.body,
    data: input.data ?? {},
    audience: input.audience,
    ttlSeconds: input.ttlSeconds,
    sound: input.sound,
    status,
    scheduleAt: scheduleDate === null ? null : Timestamp.fromDate(scheduleDate),
    createdAt: FieldValue.serverTimestamp(),
    createdByUid: actor.uid,
    createdByEmail: actor.email ?? null,
    sentAt: null,
    canceledAt: null,
    messageId: null,
    errorCode: null,
  };
  const reference = adminFirestore.collection(CAMPAIGN_COLLECTION).doc();
  await reference.create(campaign);
  if (scheduleDate === null) {
    await finishSend(reference, campaign);
  }
  const snapshot = await reference.get();
  return serializeCampaign(snapshot.id, snapshot.data() ?? campaign);
}

export async function listCampaigns(limit: number): Promise<Record<string, unknown>[]> {
  const snapshot = await adminFirestore
    .collection(CAMPAIGN_COLLECTION)
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();
  return snapshot.docs.map((document) => serializeCampaign(document.id, document.data()));
}

export async function cancelCampaign(campaignId: string): Promise<Record<string, unknown>> {
  const reference = adminFirestore.collection(CAMPAIGN_COLLECTION).doc(campaignId);
  await adminFirestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) {
      throw new ApiError(404, "campaign_not_found", "The campaign does not exist.");
    }
    if (snapshot.data()?.status !== "scheduled") {
      throw new ApiError(
        409,
        "campaign_not_cancelable",
        "Only a scheduled campaign can be canceled.",
      );
    }
    transaction.update(reference, {
      status: "canceled",
      canceledAt: FieldValue.serverTimestamp(),
    });
  });
  const snapshot = await reference.get();
  return serializeCampaign(snapshot.id, snapshot.data() ?? {});
}

async function claimScheduledCampaign(reference: DocumentReference): Promise<StoredCampaign | null> {
  return adminFirestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() as StoredCampaign | undefined;
    if (
      data === undefined ||
      data.status !== "scheduled" ||
      !(data.scheduleAt instanceof Timestamp) ||
      data.scheduleAt.toMillis() > Date.now()
    ) {
      return null;
    }
    transaction.update(reference, { status: "sending" });
    return { ...data, status: "sending" };
  });
}

export async function processDueCampaigns(): Promise<void> {
  const snapshot = await adminFirestore
    .collection(CAMPAIGN_COLLECTION)
    .where("status", "==", "scheduled")
    .where("scheduleAt", "<=", Timestamp.now())
    .orderBy("scheduleAt")
    .limit(100)
    .get();

  for (const document of snapshot.docs) {
    const campaign = await claimScheduledCampaign(document.ref);
    if (campaign === null) continue;
    try {
      await finishSend(document.ref, campaign);
    } catch (error) {
      logger.error("scheduled_campaign_send_failed", {
        campaignId: document.id,
        ...safeErrorDetails(error),
      });
    }
  }
}
