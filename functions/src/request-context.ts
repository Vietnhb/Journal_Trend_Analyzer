import type { Request } from "express";
import type { DecodedIdToken } from "firebase-admin/auth";

export interface RequestContext {
  requestId: string;
  actor?: DecodedIdToken;
}

const contexts = new WeakMap<Request, RequestContext>();

export function initializeRequestContext(req: Request, requestId: string): void {
  contexts.set(req, { requestId });
}

export function setRequestActor(req: Request, actor: DecodedIdToken): void {
  const context = getRequestContext(req);
  context.actor = actor;
}

export function getRequestContext(req: Request): RequestContext {
  const context = contexts.get(req);
  if (context === undefined) {
    throw new Error("Request context has not been initialized.");
  }
  return context;
}

export function requireRequestActor(req: Request): DecodedIdToken {
  const actor = getRequestContext(req).actor;
  if (actor === undefined) {
    throw new Error("Authenticated actor is not available.");
  }
  return actor;
}
