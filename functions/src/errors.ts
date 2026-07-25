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

type ApiErrorSpec = readonly [status: number, code: string, message: string];

const exactErrorSpecs = new Map<string, ApiErrorSpec>([
  ["404", [404, "not_found", "The requested resource was not found."]],
  ["412", [409, "conflict", "The resource changed or already exists."]],
  ["400", [400, "invalid_argument", "The request contains an invalid value."]],
  ["401", [401, "unauthenticated", "Authentication is required."]],
  ["403", [403, "permission_denied", "The operation is not permitted."]],
  ["429", [429, "resource_exhausted", "The service is temporarily rate limited."]],
  [
    "remote-config/failed-precondition",
    [409, "conflict", "The resource changed or already exists."],
  ],
  [
    "messaging/payload-size-limit-exceeded",
    [413, "message_payload_too_large", "The message payload is too large."],
  ],
  [
    "messaging/invalid-data-payload-key",
    [400, "invalid_message_payload", "The message data contains a reserved key."],
  ],
  [
    "messaging/installation-id-not-registered",
    [410, "message_target_not_registered", "The message target is no longer registered."],
  ],
  [
    "messaging/registration-token-not-registered",
    [410, "message_target_not_registered", "The message target is no longer registered."],
  ],
]);

const invalidArgumentSuffixes = [
  "/invalid-email",
  "/invalid-uid",
  "/invalid-argument",
  "/argument-error",
] as const;
const authenticationFragments = [
  "unauthenticated",
  "id-token",
  "session-cookie",
] as const;
const invalidTargetSuffixes = [
  "/invalid-registration-token",
  "/invalid-recipient",
] as const;

function errorCode(error: unknown): string | undefined {
  if (!(error instanceof Error)) return undefined;
  const value = (error as CodedError).code;
  return value === undefined ? undefined : String(value);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message.toLowerCase() : "";
}

function isFirestoreNotConfigured(error: unknown): boolean {
  const message = errorMessage(error);
  return (
    message.includes("firestore.googleapis.com") &&
    (message.includes("has not been used") || message.includes("is disabled"))
  ) || (
    message.includes("database") &&
    message.includes("(default)") &&
    (message.includes("does not exist") || message.includes("not found"))
  );
}

export function safeErrorDetails(error: unknown): Record<string, unknown> {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorCode: errorCode(error),
  };
}

function apiErrorFromSpec(spec: ApiErrorSpec): ApiError {
  return new ApiError(spec[0], spec[1], spec[2]);
}

function mapZodError(error: ZodError): ApiError {
  const issue = error.issues[0];
  const field = issue?.path.join(".");
  const prefix = field === undefined || field.length === 0 ? "" : `${field}: `;
  return new ApiError(
    400,
    "invalid_argument",
    prefix + (issue?.message ?? "Invalid request."),
  );
}

function mapRequestBodyError(error: unknown): ApiError | undefined {
  if (!(error instanceof Error)) return undefined;
  const coded = error as CodedError;
  if (coded.status === 400 || coded.type === "entity.parse.failed") {
    return new ApiError(400, "invalid_json", "The request body is not valid JSON.");
  }
  if (coded.status === 413) {
    return new ApiError(413, "payload_too_large", "The request body is too large.");
  }
  return undefined;
}

function mapPatternedError(code: string): ApiError | undefined {
  if (code.endsWith("/user-not-found")) {
    return new ApiError(404, "not_found", "The requested resource was not found.");
  }
  if (code.endsWith("/email-already-exists") || code.includes("etag-mismatch")) {
    return new ApiError(409, "conflict", "The resource changed or already exists.");
  }
  if (code.startsWith("app-check/")) {
    return new ApiError(401, "unauthenticated", "Authentication is required.");
  }
  if (invalidArgumentSuffixes.some((suffix) => code.endsWith(suffix))) {
    return new ApiError(400, "invalid_argument", "The request contains an invalid value.");
  }
  if (
    authenticationFragments.some((fragment) => code.includes(fragment)) ||
    code.endsWith("/user-disabled")
  ) {
    return new ApiError(401, "unauthenticated", "Authentication is required.");
  }
  if (code.includes("permission-denied")) {
    return new ApiError(403, "permission_denied", "The operation is not permitted.");
  }
  if (code.includes("quota")) {
    return new ApiError(429, "resource_exhausted", "The service is temporarily rate limited.");
  }
  if (invalidTargetSuffixes.some((suffix) => code.endsWith(suffix))) {
    return new ApiError(400, "invalid_message_target", "The FCM token or installation ID is invalid.");
  }
  return undefined;
}

export function mapExternalError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  if (error instanceof ZodError) return mapZodError(error);

  const requestBodyError = mapRequestBodyError(error);
  if (requestBodyError !== undefined) return requestBodyError;

  const code = errorCode(error) ?? "";
  if (isFirestoreNotConfigured(error)) {
    return new ApiError(
      503,
      "firestore_not_configured",
      "Cloud Firestore is not ready. Enable the Cloud Firestore API and create the default Firestore database for this Firebase project.",
    );
  }
  const exactError = exactErrorSpecs.get(code);
  if (exactError !== undefined) return apiErrorFromSpec(exactError);
  return mapPatternedError(code) ??
    new ApiError(500, "internal", "The server could not complete the request.");
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
    next(error);
    return;
  }
  res.status(mapped.status).json({
    error: { code: mapped.code, message: mapped.message },
    requestId: context.requestId,
  });
}
