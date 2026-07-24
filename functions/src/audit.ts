import type { Request } from "express";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { AUDIT_COLLECTION } from "./constants.js";
import { adminFirestore } from "./firebase.js";
import { safeErrorDetails } from "./errors.js";
import { getRequestContext, requireRequestActor } from "./request-context.js";

export interface AuditInput {
  action: string;
  targetType: string;
  targetId: string;
  summary: string;
  details?: Record<string, unknown>;
}

export async function writeMutationAudit(req: Request, input: AuditInput): Promise<void> {
  const actor = requireRequestActor(req);
  const { requestId } = getRequestContext(req);
  const record = {
    requestId,
    actorUid: actor.uid,
    actorEmail: typeof actor.email === "string" ? actor.email : null,
    action: input.action,
    targetType: input.targetType,
    targetId: input.targetId,
    summary: input.summary,
    details: input.details ?? {},
    createdAt: FieldValue.serverTimestamp(),
  };

  logger.info("admin_mutation", {
    requestId,
    actorUid: actor.uid,
    action: input.action,
    targetType: input.targetType,
    targetId: input.targetId,
    summary: input.summary,
  });

  try {
    await adminFirestore.collection(AUDIT_COLLECTION).add(record);
  } catch (error) {
    logger.error("admin_audit_write_failed", {
      requestId,
      actorUid: actor.uid,
      action: input.action,
      ...safeErrorDetails(error),
    });
  }
}

export function timestampToIso(value: unknown): string | null {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return typeof value === "string" ? value : null;
}
