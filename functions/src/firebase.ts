import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import { readFileSync } from "node:fs";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { getStorage } from "firebase-admin/storage";

import { adminServiceAccountPath } from "./params.js";

const adminAppName = "journal-trend-admin";
const existingAdminApp = getApps().find((app) => app.name === adminAppName);
const inheritedOptions = getApps()[0]?.options ?? {};
function localEnvValue(name: string): string | undefined {
  if (process.env.FUNCTIONS_EMULATOR !== "true") return undefined;
  try {
    const source = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
    const line = source.split(/\r?\n/u).find((candidate) =>
      candidate.trimStart().startsWith(`${name}=`),
    );
    const value = line?.slice(line.indexOf("=") + 1).trim();
    return value === undefined || value.length === 0 ? undefined : value;
  } catch {
    return undefined;
  }
}

const configuredCredentialsPath = process.env.ADMIN_SERVICE_ACCOUNT_PATH?.trim()
  || localEnvValue("ADMIN_SERVICE_ACCOUNT_PATH")
  || "";
const credentialsPath = configuredCredentialsPath.length > 0
  ? configuredCredentialsPath
  : process.env.GOOGLE_APPLICATION_CREDENTIALS;
const serviceAccount = credentialsPath === undefined
  ? undefined
  : JSON.parse(readFileSync(credentialsPath, "utf8")) as {
    project_id?: string;
    client_email?: string;
    private_key?: string;
  };
const hasServiceAccount = typeof serviceAccount?.project_id === "string"
  && typeof serviceAccount.client_email === "string"
  && typeof serviceAccount.private_key === "string";
const projectId = (hasServiceAccount ? serviceAccount.project_id : undefined)
  ?? process.env.GCLOUD_PROJECT
  ?? process.env.GOOGLE_CLOUD_PROJECT
  ?? inheritedOptions.projectId;
const credential = credentialsPath !== undefined && hasServiceAccount
  ? cert(credentialsPath)
  : applicationDefault();
const firebaseApp = existingAdminApp ?? initializeApp(
  {
    ...inheritedOptions,
    ...(projectId === undefined ? {} : {
      projectId,
      storageBucket: !hasServiceAccount
        ? inheritedOptions.storageBucket ?? `${projectId}.firebasestorage.app`
        : `${projectId}.firebasestorage.app`,
    }),
    credential,
  },
  adminAppName,
);

export const adminAuth = getAuth(firebaseApp);
export const adminAppCheck = getAppCheck(firebaseApp);
export const adminFirestore = getFirestore(firebaseApp);
export const adminMessaging = getMessaging(firebaseApp);
export const adminStorage = getStorage(firebaseApp);

function remoteConfigRestClient(
  credentialsPath: string,
  projectId: string,
): ReturnType<typeof getRemoteConfig> {
  const credential = cert(credentialsPath);
  const baseUrl = `https://firebaseremoteconfig.googleapis.com/v1/projects/${projectId}`;

  async function request(
    method: "GET" | "PUT",
    path: string,
    body?: unknown,
    etag?: string,
  ): Promise<{ data: Record<string, unknown>; etag: string }> {
    const accessToken = await credential.getAccessToken();
    const response = await fetch(`${baseUrl}/${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${accessToken.access_token}`,
        Accept: "application/json",
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
        ...(etag === undefined ? {} : { "If-Match": etag }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const data = await response.json().catch(() => ({})) as Record<string, unknown>;
    if (!response.ok) {
      const error = new Error(`Remote Config REST request failed (${response.status}).`) as Error & {
        code: string;
      };
      error.code = response.status === 403
        ? "remote-config/permission-denied"
        : `remote-config/http-${response.status}`;
      throw error;
    }
    return { data, etag: response.headers.get("etag") ?? etag ?? "" };
  }

  function template(data: Record<string, unknown>, etag: string): Record<string, unknown> {
    return {
      conditions: [],
      parameters: {},
      parameterGroups: {},
      ...data,
      etag,
    };
  }

  return {
    async getTemplate() {
      const result = await request("GET", "remoteConfig");
      return template(result.data, result.etag);
    },
    async getTemplateAtVersion(versionNumber: number | string) {
      const result = await request(
        "GET",
        `remoteConfig?versionNumber=${encodeURIComponent(String(versionNumber))}`,
      );
      return template(result.data, result.etag);
    },
    async listVersions(options?: { pageSize?: number; pageToken?: string }) {
      const query = new URLSearchParams();
      if (options?.pageSize !== undefined) query.set("pageSize", String(options.pageSize));
      if (options?.pageToken !== undefined) query.set("pageToken", options.pageToken);
      const suffix = query.size === 0 ? "" : `?${query.toString()}`;
      const result = await request("GET", `remoteConfig:listVersions${suffix}`);
      return {
        versions: Array.isArray(result.data.versions) ? result.data.versions : [],
        nextPageToken: typeof result.data.nextPageToken === "string"
          ? result.data.nextPageToken
          : undefined,
      };
    },
    async validateTemplate(input: { etag: string }) {
      const { etag, ...body } = input;
      const result = await request("PUT", "remoteConfig?validate_only=true", body, etag);
      return template(result.data, etag);
    },
    async publishTemplate(input: { etag: string }) {
      const { etag, ...body } = input;
      const result = await request("PUT", "remoteConfig", body, etag);
      return template(result.data, result.etag);
    },
  } as unknown as ReturnType<typeof getRemoteConfig>;
}

export function getAdminRemoteConfig(): ReturnType<typeof getRemoteConfig> {
  const localCredentialsPath = adminServiceAccountPath.value().trim()
    || localEnvValue("ADMIN_SERVICE_ACCOUNT_PATH")
    || "";
  if (localCredentialsPath.length === 0) return getRemoteConfig(firebaseApp);

  const localKey = JSON.parse(readFileSync(localCredentialsPath, "utf8")) as {
    project_id: string;
  };
  return remoteConfigRestClient(localCredentialsPath, localKey.project_id);
}
