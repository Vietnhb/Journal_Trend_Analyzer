import type { NextFunction, Request, Response } from "express";
import { afterAll, beforeEach, describe, expect, it } from "vitest";

import { ApiError } from "../src/errors.js";
import { corsMiddleware } from "../src/middleware.js";

const originalAllowedOrigins = process.env.ADMIN_ALLOWED_ORIGINS;

beforeEach(() => {
  process.env.ADMIN_ALLOWED_ORIGINS = [
    "https://journal-trend-analyzer-admin.web.app",
    "https://journal-trend-analyzer-admin.firebaseapp.com",
  ].join(",");
});

afterAll(() => {
  if (originalAllowedOrigins === undefined) {
    delete process.env.ADMIN_ALLOWED_ORIGINS;
  } else {
    process.env.ADMIN_ALLOWED_ORIGINS = originalAllowedOrigins;
  }
});

function request(method: string, headers: Record<string, string>): Request {
  const normalizedHeaders = new Map(
    Object.entries(headers).map(([name, value]) => [name.toLowerCase(), value]),
  );
  return {
    method,
    protocol: "https",
    get(name: string) {
      return normalizedHeaders.get(name.toLowerCase());
    },
  } as unknown as Request;
}

function response(): { response: Response; headers: Map<string, unknown> } {
  const headers = new Map<string, unknown>();
  const fakeResponse = {
    setHeader(name: string, value: unknown) {
      headers.set(name.toLowerCase(), value);
      return fakeResponse;
    },
    status() {
      return fakeResponse;
    },
    end() {
      return fakeResponse;
    },
  };
  return { response: fakeResponse as unknown as Response, headers };
}

function runCors(req: Request): { error: unknown; headers: Map<string, unknown> } {
  const res = response();
  let error: unknown = "middleware did not continue";
  const next = ((value?: unknown) => {
    error = value;
  }) as NextFunction;
  corsMiddleware(req, res.response, next);
  return { error, headers: res.headers };
}

describe("Firebase Hosting rewrite CORS", () => {
  it.each([
    ["POST", "x-forwarded-host"],
    ["PUT", "x-fh-requested-host"],
  ])("accepts %s from an exact allowlisted forwarded host", (method, forwardedHeader) => {
    const origin = "https://journal-trend-analyzer-admin.web.app";
    const result = runCors(request(method, {
      host: "adminapi-random-id.a.run.app",
      origin,
      "x-forwarded-proto": "https",
      [forwardedHeader]: "JOURNAL-TREND-ANALYZER-ADMIN.WEB.APP:443",
    }));

    expect(result.error).toBeUndefined();
    expect(result.headers.get("access-control-allow-origin")).toBe(origin);
  });

  it("rejects a different origin even when its forwarded host is spoofed", () => {
    const result = runCors(request("POST", {
      host: "adminapi-random-id.a.run.app",
      origin: "https://attacker.example",
      "x-forwarded-proto": "https",
      "x-forwarded-host": "attacker.example",
    }));

    expect(result.error).toBeInstanceOf(ApiError);
    expect(result.error).toMatchObject({ status: 403, code: "origin_not_allowed" });
  });

  it("uses only the first value in a forwarded host chain", () => {
    const result = runCors(request("PUT", {
      host: "adminapi-random-id.a.run.app",
      origin: "https://journal-trend-analyzer-admin.web.app",
      "x-forwarded-proto": "https",
      "x-forwarded-host": "internal.invalid, journal-trend-analyzer-admin.web.app",
    }));

    expect(result.error).toMatchObject({ status: 403, code: "origin_not_allowed" });
  });
});
