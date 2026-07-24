import { randomUUID } from "node:crypto";

import type { NextFunction, Request, Response } from "express";
import { logger } from "firebase-functions";

import { adminAppCheck, adminAuth } from "./firebase.js";
import { ApiError } from "./errors.js";
import { adminAllowedOrigins, enforceAppCheck } from "./params.js";
import {
  getRequestContext,
  initializeRequestContext,
  setRequestActor,
} from "./request-context.js";
import { hasAdminClaim } from "./security.js";

const requestIdPattern = /^[A-Za-z0-9_-]{8,128}$/;

function acceptedRequestId(req: Request): string {
  const candidate = req.get("x-request-id")?.trim();
  return candidate !== undefined && requestIdPattern.test(candidate)
    ? candidate
    : randomUUID();
}

export function requestContextMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const requestId = acceptedRequestId(req);
  initializeRequestContext(req, requestId);
  res.setHeader("X-Request-Id", requestId);
  res.setHeader("Cache-Control", "private, no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  next();
}

function isLocalDevelopmentOrigin(origin: URL): boolean {
  return (
    (origin.protocol === "http:" || origin.protocol === "https:") &&
    (origin.hostname === "localhost" || origin.hostname === "127.0.0.1")
  );
}

function firstForwardedValue(value: string | undefined): string | undefined {
  const first = value?.split(",", 1)[0]?.trim();
  return first === undefined || first.length === 0 ? undefined : first;
}

function requestProtocol(req: Request): "http" | "https" | undefined {
  const forwarded = firstForwardedValue(req.get("x-forwarded-proto"))?.toLowerCase();
  const protocol = forwarded ?? req.protocol.toLowerCase();
  return protocol === "http" || protocol === "https" ? protocol : undefined;
}

function normalizedAuthorityOrigin(
  protocol: "http" | "https",
  authority: string | undefined,
): string | undefined {
  if (
    authority === undefined ||
    authority.length === 0 ||
    /[\s/@\\?#]/u.test(authority)
  ) {
    return undefined;
  }
  try {
    const parsed = new URL(`${protocol}://${authority}`);
    return parsed.origin;
  } catch {
    return undefined;
  }
}

export function parseAllowedOrigins(value: string): ReadonlySet<string> {
  const origins = new Set<string>();
  for (const candidate of value.split(",")) {
    try {
      const parsed = new URL(candidate.trim());
      if (
        (parsed.protocol === "http:" || parsed.protocol === "https:") &&
        parsed.username.length === 0 &&
        parsed.password.length === 0 &&
        parsed.pathname === "/" &&
        parsed.search.length === 0 &&
        parsed.hash.length === 0
      ) {
        origins.add(parsed.origin);
      }
    } catch {
      // Invalid configured entries are ignored so they fail closed.
    }
  }
  return origins;
}

export function isSameOrigin(
  req: Request,
  origin: URL,
  allowedOrigins = parseAllowedOrigins(adminAllowedOrigins.value()),
): boolean {
  const protocol = requestProtocol(req);
  if (protocol === undefined || `${protocol}:` !== origin.protocol) return false;

  const directOrigin = normalizedAuthorityOrigin(protocol, req.get("host"));
  if (directOrigin === origin.origin) return true;

  if (!allowedOrigins.has(origin.origin)) return false;
  const forwardedHostingOrigins = [
    firstForwardedValue(req.get("x-fh-requested-host")),
    firstForwardedValue(req.get("x-forwarded-host")),
  ].map((host) => normalizedAuthorityOrigin(protocol, host));
  return forwardedHostingOrigins.includes(origin.origin);
}

export function corsMiddleware(req: Request, res: Response, next: NextFunction): void {
  const rawOrigin = req.get("origin");
  if (rawOrigin === undefined) {
    next();
    return;
  }

  let origin: URL;
  try {
    origin = new URL(rawOrigin);
  } catch {
    next(new ApiError(403, "origin_not_allowed", "The request origin is not allowed."));
    return;
  }

  if (
    origin.username.length > 0 ||
    origin.password.length > 0 ||
    origin.pathname !== "/" ||
    origin.search.length > 0 ||
    origin.hash.length > 0
  ) {
    next(new ApiError(403, "origin_not_allowed", "The request origin is not allowed."));
    return;
  }

  if (!isLocalDevelopmentOrigin(origin) && !isSameOrigin(req, origin)) {
    next(new ApiError(403, "origin_not_allowed", "The request origin is not allowed."));
    return;
  }

  res.setHeader("Access-Control-Allow-Origin", origin.origin);
  res.setHeader("Vary", "Origin");
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Authorization, Content-Type, X-Firebase-AppCheck, "
      + "X-Google-Analytics-Token, X-Request-Id",
  );
  res.setHeader("Access-Control-Allow-Methods", "GET, PATCH, PUT, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Max-Age", "3600");
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  next();
}

export async function authenticateAdmin(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const authorization = req.get("authorization");
    const match = /^Bearer\s+([^\s]+)$/i.exec(authorization ?? "");
    if (match?.[1] === undefined) {
      throw new ApiError(401, "unauthenticated", "A Firebase ID token is required.");
    }

    let decodedToken;
    try {
      decodedToken = await adminAuth.verifyIdToken(match[1], true);
    } catch {
      throw new ApiError(401, "invalid_token", "The Firebase ID token is invalid or expired.");
    }
    if (!hasAdminClaim(decodedToken)) {
      throw new ApiError(403, "admin_required", "Administrator access is required.");
    }

    if (enforceAppCheck.value()) {
      const appCheckToken = req.get("x-firebase-appcheck")?.trim();
      if (appCheckToken === undefined || appCheckToken.length === 0) {
        throw new ApiError(401, "app_check_required", "A Firebase App Check token is required.");
      }
      try {
        await adminAppCheck.verifyToken(appCheckToken);
      } catch {
        throw new ApiError(401, "invalid_app_check", "The Firebase App Check token is invalid.");
      }
    }

    setRequestActor(req, decodedToken);
    next();
  } catch (error) {
    next(error);
  }
}

export function accessLogMiddleware(req: Request, res: Response, next: NextFunction): void {
  const startedAt = Date.now();
  res.on("finish", () => {
    const context = getRequestContext(req);
    logger.info("admin_api_request", {
      requestId: context.requestId,
      actorUid: context.actor?.uid,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: Date.now() - startedAt,
    });
  });
  next();
}
