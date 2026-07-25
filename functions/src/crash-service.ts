import { BigQuery } from "@google-cloud/bigquery";
import { logger } from "firebase-functions";

import { ApiError, safeErrorDetails } from "./errors.js";
import { crashlyticsAppId, crashlyticsTable } from "./params.js";
import { parseCrashlyticsTable } from "./validation.js";

let bigQueryClient: BigQuery | undefined;
const crashReportTimeZone = "Asia/Ho_Chi_Minh";

function client(): BigQuery {
  bigQueryClient ??= new BigQuery();
  return bigQueryClient;
}

function runtimeProjectId(): string | undefined {
  const direct = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;
  if (direct !== undefined && /^[A-Za-z0-9_-]+$/u.test(direct)) return direct;
  try {
    const firebaseConfig = JSON.parse(process.env.FIREBASE_CONFIG ?? "{}") as {
      projectId?: unknown;
    };
    return typeof firebaseConfig.projectId === "string" &&
      /^[A-Za-z0-9_-]+$/u.test(firebaseConfig.projectId)
      ? firebaseConfig.projectId
      : undefined;
  } catch {
    return undefined;
  }
}

function numeric(value: unknown): number {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  if (typeof value === "bigint") return Number(value);
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (typeof value === "object" && value !== null && "value" in value) {
    return numeric(value.value);
  }
  return 0;
}

function text(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (typeof value === "object" && value !== null && "value" in value) {
    return text(value.value);
  }
  return null;
}

function emptyResult(
  status: "ready" | "unconfigured" | "error",
  reason: string,
): Record<string, unknown> {
  return {
    status,
    reason,
    summary: { events: 0, fatal: 0, nonFatal: 0, affectedUsers: 0 },
    crashFree: {
      available: false,
      usersPercent: null,
      sessionsPercent: null,
      totalUsers: 0,
      totalSessions: 0,
    },
    releases: [],
    issues: [],
    daily: [],
  };
}

export function crashlyticsTablePrefix(appId: string): string {
  const normalized = appId.trim().replaceAll(".", "_");
  if (!/^\w+$/u.test(normalized)) return "";
  return `${normalized}_ANDROID`;
}

export function selectCrashlyticsTableNames(
  names: readonly string[],
  appId = "",
): string[] {
  const configuredPrefix = crashlyticsTablePrefix(appId);
  return names
    .filter((name) =>
      !name.startsWith("firebase_sessions_") &&
      /^\w+_(?:ANDROID|IOS)(?:_REALTIME)?$/u.test(name) &&
      (configuredPrefix.length === 0 ||
        name === configuredPrefix ||
        name === `${configuredPrefix}_REALTIME`),
    )
    .sort((left, right) => left.localeCompare(right));
}

function unionAllSource(tableNames: readonly string[]): string {
  if (tableNames.length === 1) return tableNames[0]!;
  const selections = tableNames
    .map((table) => `SELECT * FROM ${table}`)
    .join(" UNION ALL ");
  return `(${selections})`;
}

async function discoverCrashlyticsSource(): Promise<{
  source: string | null;
  datasetFound: boolean;
  tables: string[];
}> {
  const [datasets] = await client().getDatasets({ all: true });
  const crashDatasets = datasets.filter((dataset) =>
    dataset.id?.startsWith("firebase_crashlytics"),
  );
  if (crashDatasets.length === 0) {
    return { source: null, datasetFound: false, tables: [] };
  }

  const tableNames: string[] = [];
  const projectId = runtimeProjectId();
  for (const dataset of crashDatasets) {
    const [tables] = await dataset.getTables();
    for (const name of selectCrashlyticsTableNames(
      tables.map((table) => table.id ?? ""),
      crashlyticsAppId.value(),
    )) {
      const datasetId = dataset.id;
      if (
        projectId !== undefined &&
        datasetId !== undefined &&
        /^[A-Za-z0-9_-]+$/u.test(projectId) &&
        /^\w+$/u.test(datasetId)
      ) {
        tableNames.push(`\`${projectId}.${datasetId}.${name}\``);
      }
    }
  }
  if (tableNames.length === 0) {
    return { source: null, datasetFound: true, tables: [] };
  }
  return {
    source: unionAllSource(tableNames),
    datasetFound: true,
    tables: tableNames,
  };
}

async function discoverSessionsSource(): Promise<string | null> {
  const [datasets] = await client().getDatasets({ all: true });
  const projectId = runtimeProjectId();
  if (projectId === undefined) return null;
  const tableNames: string[] = [];
  for (const dataset of datasets.filter((item) =>
    item.id?.startsWith("firebase_sessions"),
  )) {
    const datasetId = dataset.id;
    if (datasetId === undefined || !/^\w+$/u.test(datasetId)) continue;
    const [tables] = await dataset.getTables();
    for (const name of selectCrashlyticsTableNames(
      tables.map((table) => table.id ?? ""),
      crashlyticsAppId.value(),
    )) {
      if (/^\w+_ANDROID(?:_REALTIME)?$/u.test(name)) {
        tableNames.push(`\`${projectId}.${datasetId}.${name}\``);
      }
    }
  }
  if (tableNames.length === 0) return null;
  return unionAllSource(tableNames);
}

function jsonArray(value: unknown): Array<Record<string, unknown>> {
  if (typeof value !== "string") return [];
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed)
      ? parsed.filter(
        (item): item is Record<string, unknown> =>
          typeof item === "object" && item !== null,
      )
      : [];
  } catch {
    return [];
  }
}

function latestIssueDetails(row: Record<string, unknown>): Record<string, unknown> {
  const exceptions = jsonArray(row.exceptions_json);
  const primaryException = exceptions.find((item) => item.blamed === true) ??
    exceptions[0];
  const rawFrames = primaryException !== undefined &&
      Array.isArray(primaryException.frames)
    ? primaryException.frames
    : [];
  const frames = rawFrames
    .filter(
      (item): item is Record<string, unknown> =>
        typeof item === "object" && item !== null,
    )
    .slice(0, 30)
    .map((frame) => ({
      symbol: text(frame.symbol),
      file: text(frame.file),
      line: numeric(frame.line),
      library: text(frame.library),
      owner: text(frame.owner),
      blamed: frame.blamed === true,
    }));
  return {
    eventId: text(row.latest_event_id),
    occurredAt: text(row.last_seen),
    file: text(row.blame_file),
    line: numeric(row.blame_line),
    symbol: text(row.blame_symbol),
    device: {
      manufacturer: text(row.device_manufacturer),
      model: text(row.device_model),
      architecture: text(row.device_architecture),
    },
    operatingSystem: {
      name: text(row.os_name),
      version: text(row.os_version),
      deviceType: text(row.os_device_type),
    },
    memoryUsed: numeric(row.memory_used),
    memoryFree: numeric(row.memory_free),
    storageUsed: numeric(row.storage_used),
    storageFree: numeric(row.storage_free),
    exceptionType: text(primaryException?.type),
    exceptionMessage: text(primaryException?.exception_message),
    frames,
    customKeys: jsonArray(row.custom_keys_json).slice(0, 30).map((item) => ({
      key: text(item.key),
      value: text(item.value),
    })),
    logs: jsonArray(row.logs_json).slice(-50).map((item) => ({
      timestamp: text(item.timestamp),
      message: text(item.message),
    })),
  };
}

function externalCode(error: unknown): string {
  if (!(error instanceof Error) || !("code" in error)) return "";
  const code = error.code;
  return typeof code === "string" || typeof code === "number" ? String(code) : "";
}

type CrashSourceResolution =
  | { status: "ready"; source: string }
  | { status: "unavailable"; result: Record<string, unknown> };

async function resolveCrashSource(): Promise<CrashSourceResolution> {
  const configuredTable = crashlyticsTable.value().trim();
  if (configuredTable.length > 0) {
    try {
      return {
        status: "ready",
        source: `\`${parseCrashlyticsTable(configuredTable)}\``,
      };
    } catch (error) {
      if (!(error instanceof ApiError)) throw error;
      return {
        status: "unavailable",
        result: emptyResult(
          "unconfigured",
          "CRASHLYTICS_TABLE is not a valid project.dataset.table identifier.",
        ),
      };
    }
  }

  try {
    const discovered = await discoverCrashlyticsSource();
    if (discovered.source !== null) {
      return { status: "ready", source: discovered.source };
    }
    return {
      status: "unavailable",
      result: emptyResult(
        "unconfigured",
        discovered.datasetFound
          ? `Dataset firebase_crashlytics đã tồn tại nhưng chưa có bảng cho ứng dụng ${
              crashlyticsAppId.value().trim() || "Android đã cấu hình"
            }. Hãy bật Crashlytics BigQuery export cho app này và gửi ít nhất hai sự kiện mới.`
          : "Chưa tìm thấy dataset firebase_crashlytics. Hãy bật Crashlytics BigQuery export cho Firebase project này.",
      ),
    };
  } catch (error) {
    logger.error("crashlytics_discovery_failed", safeErrorDetails(error));
    return {
      status: "unavailable",
      result: emptyResult(
        "error",
        "Cannot inspect the Crashlytics BigQuery dataset. Check BigQuery IAM access.",
      ),
    };
  }
}

function groupIssueTrends(
  rows: readonly Record<string, unknown>[],
): Map<string, Array<Record<string, unknown>>> {
  const trends = new Map<string, Array<Record<string, unknown>>>();
  for (const row of rows) {
    const issueId = text(row.issue_id);
    if (issueId === null) continue;
    const points = trends.get(issueId) ?? [];
    points.push({
      date: text(row.event_date) ?? "",
      events: numeric(row.events),
    });
    trends.set(issueId, points);
  }
  return trends;
}

function groupIssueUsers(
  rows: readonly Record<string, unknown>[],
): Map<string, Array<Record<string, unknown>>> {
  const users = new Map<string, Array<Record<string, unknown>>>();
  for (const row of rows) {
    const issueId = text(row.issue_id);
    const installationId = text(row.installation_uuid);
    if (issueId === null || installationId === null) continue;
    const affected = users.get(issueId) ?? [];
    affected.push({
      installationId,
      userId: text(row.user_id),
      name: text(row.user_name),
      email: text(row.user_email),
      events: numeric(row.events),
      firstSeen: text(row.first_seen),
      lastSeen: text(row.last_seen),
      device: {
        manufacturer: text(row.device_manufacturer),
        model: text(row.device_model),
      },
      operatingSystem: {
        name: text(row.os_name),
        version: text(row.os_version),
      },
    });
    users.set(issueId, affected);
  }
  return users;
}

export async function loadCrashes(
  range: { start: string; end: string },
): Promise<Record<string, unknown>> {
  const sourceResolution = await resolveCrashSource();
  if (sourceResolution.status === "unavailable") {
    return sourceResolution.result;
  }
  const { source } = sourceResolution;

  const timeFilter =
    "event_timestamp BETWEEN TIMESTAMP(@rangeStart) AND TIMESTAMP(@rangeEnd)";
  const rangeParams = { rangeStart: range.start, rangeEnd: range.end };
  const crashesCte = `
    crashes AS (
      SELECT * EXCEPT(_event_rank)
      FROM (
        SELECT *,
          ROW_NUMBER() OVER (
            PARTITION BY event_id ORDER BY received_timestamp DESC
          ) AS _event_rank
        FROM ${source}
        WHERE ${timeFilter}
      )
      WHERE _event_rank = 1
    )`;
  const summaryQuery = `
    WITH ${crashesCte}
    SELECT
      COUNT(DISTINCT event_id) AS events,
      COUNT(DISTINCT IF(error_type = 'FATAL', event_id, NULL)) AS fatal,
      COUNT(DISTINCT IF(error_type = 'NON_FATAL', event_id, NULL)) AS non_fatal,
      COUNT(DISTINCT installation_uuid) AS affected_users,
      ARRAY_AGG(
        DISTINCT IF(
          application.display_version IS NULL,
          NULL,
          CONCAT(
            application.display_version,
            IF(application.build_version IS NULL, '', CONCAT(' (', application.build_version, ')'))
          )
        )
        IGNORE NULLS
        LIMIT 20
      ) AS releases
    FROM crashes`;
  const issuesQuery = `
    WITH ${crashesCte},
    ranked AS (
      SELECT *,
        ROW_NUMBER() OVER (
          PARTITION BY issue_id ORDER BY event_timestamp DESC, received_timestamp DESC
        ) AS issue_rank
      FROM crashes
      WHERE issue_id IS NOT NULL
    ),
    totals AS (
      SELECT
        issue_id,
        ANY_VALUE(error_type) AS error_type,
        COUNT(DISTINCT event_id) AS events,
        COUNT(DISTINCT installation_uuid) AS affected_users,
        COUNT(DISTINCT variant_id) AS variants,
        MIN(event_timestamp) AS first_seen,
        MAX(event_timestamp) AS last_seen,
        ARRAY_AGG(
          DISTINCT IF(
            application.display_version IS NULL,
            NULL,
            CONCAT(
              application.display_version,
              IF(application.build_version IS NULL, '', CONCAT(' (', application.build_version, ')'))
            )
          )
          IGNORE NULLS
          LIMIT 10
        ) AS versions
      FROM crashes
      WHERE issue_id IS NOT NULL
      GROUP BY issue_id
    )
    SELECT
      totals.*,
      COALESCE(ranked.issue_title, ranked.blame_frame.symbol, totals.issue_id) AS title,
      ranked.issue_subtitle AS subtitle,
      ranked.event_id AS latest_event_id,
      ranked.blame_frame.file AS blame_file,
      ranked.blame_frame.line AS blame_line,
      ranked.blame_frame.symbol AS blame_symbol,
      ranked.device.manufacturer AS device_manufacturer,
      ranked.device.model AS device_model,
      ranked.device.architecture AS device_architecture,
      ranked.operating_system.name AS os_name,
      ranked.operating_system.display_version AS os_version,
      ranked.operating_system.device_type AS os_device_type,
      ranked.memory.used AS memory_used,
      ranked.memory.free AS memory_free,
      ranked.storage.used AS storage_used,
      ranked.storage.free AS storage_free,
      TO_JSON_STRING(ranked.exceptions) AS exceptions_json,
      TO_JSON_STRING(ranked.custom_keys) AS custom_keys_json,
      TO_JSON_STRING(ranked.logs) AS logs_json
    FROM totals
    JOIN ranked USING (issue_id)
    WHERE ranked.issue_rank = 1
    ORDER BY totals.events DESC, totals.last_seen DESC
    LIMIT 50`;
  const dailyQuery = `
    WITH ${crashesCte}
    SELECT
      DATE(event_timestamp, "${crashReportTimeZone}") AS event_date,
      COUNT(DISTINCT IF(error_type = 'FATAL', event_id, NULL)) AS fatal,
      COUNT(DISTINCT IF(error_type = 'NON_FATAL', event_id, NULL)) AS non_fatal
    FROM crashes
    GROUP BY event_date
    ORDER BY event_date`;
  const issueDailyQuery = `
    WITH ${crashesCte}
    SELECT
      issue_id,
      DATE(event_timestamp, "${crashReportTimeZone}") AS event_date,
      COUNT(DISTINCT event_id) AS events
    FROM crashes
    WHERE issue_id IS NOT NULL
    GROUP BY issue_id, event_date
    ORDER BY event_date`;
  const issueUsersQuery = `
    WITH ${crashesCte}
    SELECT
      issue_id,
      installation_uuid,
      ARRAY_AGG(user.id IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS user_id,
      ARRAY_AGG(user.name IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS user_name,
      ARRAY_AGG(user.email IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS user_email,
      COUNT(DISTINCT event_id) AS events,
      MIN(event_timestamp) AS first_seen,
      MAX(event_timestamp) AS last_seen,
      ARRAY_AGG(device.manufacturer IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS device_manufacturer,
      ARRAY_AGG(device.model IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS device_model,
      ARRAY_AGG(operating_system.name IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS os_name,
      ARRAY_AGG(operating_system.display_version IGNORE NULLS ORDER BY event_timestamp DESC LIMIT 1)[SAFE_OFFSET(0)]
        AS os_version
    FROM crashes
    WHERE issue_id IS NOT NULL
      AND installation_uuid IS NOT NULL
    GROUP BY issue_id, installation_uuid
    ORDER BY issue_id, last_seen DESC`;

  try {
    const sessionsSource = await discoverSessionsSource();
    const crashFreeQuery = sessionsSource === null
      ? null
      : `
        WITH ${crashesCte},
        sessions AS (
          SELECT * EXCEPT(_session_rank)
          FROM (
            SELECT *,
              ROW_NUMBER() OVER (
                PARTITION BY session_id ORDER BY received_timestamp DESC
              ) AS _session_rank
            FROM ${sessionsSource}
            WHERE event_timestamp BETWEEN TIMESTAMP(@rangeStart) AND TIMESTAMP(@rangeEnd)
              AND event_type = 'SESSION_START'
          )
          WHERE _session_rank = 1
        ),
        fatal_sessions AS (
          SELECT DISTINCT firebase_session_id AS session_id
          FROM crashes
          WHERE error_type = 'FATAL' AND firebase_session_id IS NOT NULL
        ),
        users AS (
          SELECT
            s.instance_id,
            MAX(IF(f.session_id IS NULL, 0, 1)) AS had_fatal
          FROM sessions s
          LEFT JOIN fatal_sessions f USING (session_id)
          GROUP BY s.instance_id
        )
        SELECT
          COUNT(DISTINCT s.session_id) AS total_sessions,
          COUNT(DISTINCT s.instance_id) AS total_users,
          COUNT(DISTINCT IF(f.session_id IS NULL, s.session_id, NULL)) AS crash_free_sessions,
          (SELECT COUNTIF(had_fatal = 0) FROM users) AS crash_free_users
        FROM sessions s
        LEFT JOIN fatal_sessions f USING (session_id)`;
    const [
      summaryResponse,
      issuesResponse,
      dailyResponse,
      issueDailyResponse,
      issueUsersResponse,
    ] = await Promise.all([
      client().query({ query: summaryQuery, params: rangeParams }),
      client().query({ query: issuesQuery, params: rangeParams }),
      client().query({ query: dailyQuery, params: rangeParams }),
      client().query({ query: issueDailyQuery, params: rangeParams }),
      client().query({ query: issueUsersQuery, params: rangeParams }),
    ]);
    const crashFreeRows = crashFreeQuery === null
      ? []
      : (await client().query({
        query: crashFreeQuery,
        params: rangeParams,
      }))[0] as Array<
        Record<string, unknown>
      >;
    const summary = summaryResponse[0][0] as Record<string, unknown> | undefined;
    const issues = issuesResponse[0] as Array<Record<string, unknown>>;
    const daily = dailyResponse[0] as Array<Record<string, unknown>>;
    const issueDaily = issueDailyResponse[0] as Array<Record<string, unknown>>;
    const issueUsers = issueUsersResponse[0] as Array<Record<string, unknown>>;
    const crashFree = crashFreeRows[0];
    const trends = groupIssueTrends(issueDaily);
    const users = groupIssueUsers(issueUsers);
    const eventCount = numeric(summary?.events);
    const totalSessions = numeric(crashFree?.total_sessions);
    const totalUsers = numeric(crashFree?.total_users);
    return {
      status: "ready",
      ...(eventCount === 0
        ? {
            reason:
              "Đã kết nối bảng Crashlytics realtime nhưng chưa có dòng dữ liệu. "
              + "Báo cáo vừa gửi có thể cần vài phút; lần khởi tạo streaming "
              + "đầu tiên có thể mất tới 1 giờ.",
          }
        : {}),
      summary: {
        events: eventCount,
        fatal: numeric(summary?.fatal),
        nonFatal: numeric(summary?.non_fatal),
        affectedUsers: numeric(summary?.affected_users),
      },
      crashFree: {
        available: totalSessions > 0,
        usersPercent: totalUsers > 0
          ? numeric(crashFree?.crash_free_users) / totalUsers * 100
          : null,
        sessionsPercent: totalSessions > 0
          ? numeric(crashFree?.crash_free_sessions) / totalSessions * 100
          : null,
        totalUsers,
        totalSessions,
      },
      releases: Array.isArray(summary?.releases)
        ? summary.releases.filter((item): item is string => typeof item === "string")
        : [],
      issues: issues.map((row) => ({
        issueId: text(row.issue_id) ?? "unknown",
        errorType: text(row.error_type) ?? "UNKNOWN",
        events: numeric(row.events),
        affectedUsers: numeric(row.affected_users),
        variants: numeric(row.variants),
        firstSeen: text(row.first_seen),
        lastSeen: text(row.last_seen),
        title: text(row.title) ?? "Unknown issue",
        subtitle: text(row.subtitle),
        versions: Array.isArray(row.versions)
          ? row.versions.filter((item): item is string => typeof item === "string")
          : [],
        trend: trends.get(text(row.issue_id) ?? "") ?? [],
        users: users.get(text(row.issue_id) ?? "") ?? [],
        latest: latestIssueDetails(row),
      })),
      daily: daily.map((row) => ({
        date: text(row.event_date) ?? "",
        fatal: numeric(row.fatal),
        nonFatal: numeric(row.non_fatal),
      })),
    };
  } catch (error) {
    const code = externalCode(error);
    logger.error("crashlytics_adapter_failed", safeErrorDetails(error));
    if (code === "404" || code.toLowerCase().includes("notfound")) {
      return emptyResult(
        "unconfigured",
        "The Crashlytics export table was not found. Enable BigQuery export and verify CRASHLYTICS_TABLE.",
      );
    }
    return emptyResult(
      "error",
      "Crashlytics reporting is temporarily unavailable. Check BigQuery export and IAM access.",
    );
  }
}
