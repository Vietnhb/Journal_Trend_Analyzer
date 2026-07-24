import { logger } from "firebase-functions";

import { safeErrorDetails } from "./errors.js";
import { ga4PropertyId } from "./params.js";

type AnalyticsStatus =
  | "ready"
  | "authorization_required"
  | "unconfigured"
  | "error";

interface AnalyticsDataApiValue {
  value?: string;
}

interface AnalyticsDataApiRow {
  dimensionValues?: AnalyticsDataApiValue[];
  metricValues?: AnalyticsDataApiValue[];
}

interface AnalyticsDataApiReport {
  rows?: AnalyticsDataApiRow[];
}

class AnalyticsDataApiError extends Error {
  constructor(readonly status: number) {
    super(`Google Analytics Data API returned HTTP ${status}.`);
  }
}

function numeric(value: unknown): number {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function emptyResult(
  status: AnalyticsStatus,
  reason: string,
): Record<string, unknown> {
  return {
    status,
    reason,
    summary: { activeUsers: 0, sessions: 0, eventCount: 0 },
    events: [],
    daily: [],
    eventDaily: [],
  };
}

export function formatAnalyticsDate(value: string | null | undefined): string {
  if (value === undefined || value === null || !/^\d{8}$/u.test(value)) {
    return value ?? "";
  }
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
}

function acceptedAccessToken(value: string | undefined): string | null {
  const token = value?.trim();
  if (
    token === undefined ||
    token.length < 20 ||
    token.length > 4096 ||
    /\s/u.test(token)
  ) {
    return null;
  }
  return token;
}

async function runReport(
  propertyId: string,
  accessToken: string,
  body: Record<string, unknown>,
): Promise<AnalyticsDataApiReport> {
  const response = await fetch(
    `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    },
  );
  if (!response.ok) throw new AnalyticsDataApiError(response.status);
  return await response.json() as AnalyticsDataApiReport;
}

export async function loadAnalytics(
  range: { start: string; end: string },
  rawAccessToken: string | undefined,
): Promise<Record<string, unknown>> {
  const propertyId = ga4PropertyId.value().trim().replace(/^properties\//, "");
  if (!/^\d+$/u.test(propertyId)) {
    return emptyResult(
      "unconfigured",
      "Chưa có GA4_PROPERTY_ID hợp lệ cho Firebase project.",
    );
  }

  const accessToken = acceptedAccessToken(rawAccessToken);
  if (accessToken === null) {
    return emptyResult(
      "authorization_required",
      "Kết nối tài khoản Google của bạn để cấp quyền chỉ đọc dữ liệu Analytics.",
    );
  }

  const dateRanges = [{
    startDate: range.start.slice(0, 10),
    endDate: range.end.slice(0, 10),
  }];
  try {
    const [summary, events, daily, eventDaily] = await Promise.all([
      runReport(propertyId, accessToken, {
        dateRanges,
        metrics: [
          { name: "activeUsers" },
          { name: "sessions" },
          { name: "eventCount" },
        ],
      }),
      runReport(propertyId, accessToken, {
        dateRanges,
        dimensions: [{ name: "eventName" }],
        metrics: [
          { name: "eventCount" },
          { name: "totalUsers" },
          { name: "eventCountPerUser" },
          { name: "totalRevenue" },
        ],
        orderBys: [{ metric: { metricName: "eventCount" }, desc: true }],
        limit: 250,
      }),
      runReport(propertyId, accessToken, {
        dateRanges,
        dimensions: [{ name: "date" }],
        metrics: [{ name: "eventCount" }],
        orderBys: [{ dimension: { dimensionName: "date" } }],
      }),
      runReport(propertyId, accessToken, {
        dateRanges,
        dimensions: [{ name: "date" }, { name: "eventName" }],
        metrics: [{ name: "eventCount" }],
        orderBys: [{ dimension: { dimensionName: "date" } }],
        limit: 100_000,
      }),
    ]);

    const summaryMetrics = summary.rows?.[0]?.metricValues ?? [];
    return {
      status: "ready",
      reason: "Dữ liệu được đọc bằng quyền Google Analytics của admin hiện tại.",
      summary: {
        activeUsers: numeric(summaryMetrics[0]?.value),
        sessions: numeric(summaryMetrics[1]?.value),
        eventCount: numeric(summaryMetrics[2]?.value),
      },
      events: (events.rows ?? []).map((row) => ({
        name: row.dimensionValues?.[0]?.value ?? "",
        count: numeric(row.metricValues?.[0]?.value),
        users: numeric(row.metricValues?.[1]?.value),
        countPerUser: numeric(row.metricValues?.[2]?.value),
        revenue: numeric(row.metricValues?.[3]?.value),
      })),
      daily: (daily.rows ?? []).map((row) => ({
        date: formatAnalyticsDate(row.dimensionValues?.[0]?.value),
        count: numeric(row.metricValues?.[0]?.value),
      })),
      eventDaily: (eventDaily.rows ?? []).map((row) => ({
        date: formatAnalyticsDate(row.dimensionValues?.[0]?.value),
        name: row.dimensionValues?.[1]?.value ?? "",
        count: numeric(row.metricValues?.[0]?.value),
      })),
    };
  } catch (error) {
    logger.warn("analytics_data_api_failed", safeErrorDetails(error));
    if (
      error instanceof AnalyticsDataApiError &&
      (error.status === 401 || error.status === 403)
    ) {
      return emptyResult(
        "authorization_required",
        "Quyền Google Analytics đã hết hạn hoặc tài khoản này không có quyền xem Property.",
      );
    }
    return emptyResult(
      "error",
      "Không thể đọc dữ liệu từ Google Analytics Data API. Hãy thử lại.",
    );
  }
}
