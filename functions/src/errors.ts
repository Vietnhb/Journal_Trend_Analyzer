import type { NextFunction, Request, Response } from "express";
import { logger } from "firebase-functions";
import { ZodError } from "zod";

import { getRequestContext } from "./request-context.js";

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

interface CodedError extends Error {
  code?: string | number;
  status?: number;
  type?: string;
}

function errorCode(error: unknown): string | undefined {
  if (!(error instanceof Error)) return undefined;
  const value = (error as CodedError).code;
  return value === undefined ? undefined : String(value);
}

export function safeErrorDetails(error: unknown): Record<string, unknown> {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorCode: errorCode(error),
  };
}

export function mapExternalError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  if (error instanceof ZodError) {
    const issue = error.issues[0];
    const field = issue?.path.join(".");
    return new ApiError(
      400,
      "invalid_argument",
      `${field ? `${field}: ` : ""}${issue?.message ?? "Invalid request."}`,
    );
  }

  if (
    error instanceof Error &&
    ((error as CodedError).status === 400 || (error as CodedError).type === "entity.parse.failed")
  ) {
    return new ApiError(400, "invalid_json", "The request body is not valid JSON.");
  }
  if (error instanceof Error && (error as CodedError).status === 413) {
    return new ApiError(413, "payload_too_large", "The request body is too large.");
  }

  const code = errorCode(error) ?? "";
  if (code.endsWith("/user-not-found") || code === "404") {
    return new ApiError(404, "not_found", "The requested resource was not found.");
  }
  if (
    code.endsWith("/email-already-exists") ||
    code.includes("etag-mismatch") ||
    code === "remote-config/failed-precondition" ||
    code === "412"
  ) {
    return new ApiError(409, "conflict", "The resource changed or already exists.");
  }

  if (code === "messaging/payload-size-limit-exceeded") {
    return new ApiError(413, "message_payload_too_large", "The message payload is too large.");
  }

  if (code === "messaging/invalid-data-payload-key") {
    return new ApiError(400, "invalid_message_payload", "The message data contains a reserved key.");
  }

  if (
    code === "messaging/installation-id-not-registered" ||
    code === "messaging/registration-token-not-registered"
  ) {
    return new ApiError(
      410,
      "message_target_not_registered",
      "The message target is no longer registered.",
    );
  }
  if (code.startsWith("app-check/")) {
    return new ApiError(401, "unauthenticated", "Authentication is required.");
  }
  if (
    code.endsWith("/invalid-email") ||
    code.endsWith("/invalid-uid") ||
    code.endsWith("/invalid-argument") ||
    code.endsWith("/argument-error") ||
    code === "400"
  ) {
    return new ApiError(400, "invalid_argument", "The request contains an invalid value.");
  }
  if (
    code === "401" ||
    code.includes("unauthenticated") ||
    code.includes("id-token") ||
    code.includes("session-cookie") ||
    code.endsWith("/user-disabled")
  ) {
    return new ApiError(401, "unauthenticated", "Authentication is required.");
  }
  if (code === "403" || code.includes("permission-denied")) {
    return new ApiError(403, "permission_denied", "The operation is not permitted.");
  }
  if (code === "429" || code.includes("quota")) {
    return new ApiError(429, "resource_exhausted", "The service is temporarily rate limited.");
  }
  if (
    code.endsWith("/invalid-registration-token") ||
    code.endsWith("/invalid-recipient")
  ) {
    return new ApiError(400, "invalid_message_target", "The FCM token or installation ID is invalid.");
  }
  return new ApiError(500, "internal", "The server could not complete the request.");
}

export function sendData(res: Response, data: unknown, status = 200): void {
  const context = getRequestContext(res.req);
  res.status(status).json({ data, requestId: context.requestId });
}

export function errorMiddleware(
  error: unknown,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  void next;
  const mapped = mapExternalError(error);
  const context = getRequestContext(req);

  logger.error("admin_api_error", {
    requestId: context.requestId,
    actorUid: context.actor?.uid,
    method: req.method,
    path: req.path,
    status: mapped.status,
    apiCode: mapped.code,
    ...safeErrorDetails(error),
  });

  if (res.headersSent) {
    res.destroy();
    return;
  }
  res.status(mapped.status).json({
    error: { code: mapped.code, message: mapped.message },
    requestId: context.requestId,
  });
}
