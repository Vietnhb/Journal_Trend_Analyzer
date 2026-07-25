import type {
  RemoteConfigParameter,
  RemoteConfigParameterValue,
  RemoteConfigTemplate,
} from "firebase-admin/remote-config";

import { getAdminRemoteConfig } from "./firebase.js";
import { ApiError } from "./errors.js";
import { serializeRemoteConfigVersion } from "./serializers.js";

function valueOf(value: RemoteConfigParameterValue | undefined): string | null {
  return value !== undefined && "value" in value ? value.value : null;
}

function parameterEntries(template: RemoteConfigTemplate): Array<{
  key: string;
  group: string | null;
  parameter: RemoteConfigParameter;
}> {
  const entries: Array<{
    key: string;
    group: string | null;
    parameter: RemoteConfigParameter;
  }> = Object.entries(template.parameters).map(([key, parameter]) => ({
    key,
    group: null,
    parameter,
  }));
  for (const [group, parameterGroup] of Object.entries(template.parameterGroups)) {
    for (const [key, parameter] of Object.entries(parameterGroup.parameters)) {
      entries.push({ key, group, parameter });
    }
  }
  return entries;
}

function findParameter(
  template: RemoteConfigTemplate,
  key: string,
): RemoteConfigParameter | undefined {
  return parameterEntries(template).find((entry) => entry.key === key)?.parameter;
}

function setNumberParameter(
  template: RemoteConfigTemplate,
  key: string,
  value: number,
  fallbackDescription: string,
): void {
  const existing = findParameter(template, key);
  const next: RemoteConfigParameter = {
    ...existing,
    defaultValue: { value: String(value) },
    valueType: "NUMBER",
    description: existing?.description?.trim() || fallbackDescription,
  };

  if (template.parameters[key] !== undefined) {
    template.parameters[key] = next;
    return;
  }
  for (const group of Object.values(template.parameterGroups)) {
    if (group.parameters[key] !== undefined) {
      group.parameters[key] = next;
      return;
    }
  }
  template.parameters[key] = next;
}

function numericParameter(template: RemoteConfigTemplate, key: string): number | null {
  const raw = valueOf(findParameter(template, key)?.defaultValue);
  if (raw === null) return null;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

export function serializeRemoteConfig(template: RemoteConfigTemplate): Record<string, unknown> {
  return {
    etag: template.etag,
    version: serializeRemoteConfigVersion(template.version),
    parameters: {
      maxJournals: numericParameter(template, "max_journals"),
      maxKeywords: numericParameter(template, "max_keywords"),
    },
    allParameters: parameterEntries(template)
      .map(({ key, group, parameter }) => ({
        key,
        value: valueOf(parameter.defaultValue),
        description: parameter.description ?? null,
        valueType: parameter.valueType ?? "STRING",
        group,
      }))
      .sort((left, right) => left.key.localeCompare(right.key)),
  };
}

export async function getRemoteConfigData(): Promise<Record<string, unknown>> {
  return serializeRemoteConfig(await getAdminRemoteConfig().getTemplate());
}

export async function getRemoteConfigVersionData(
  versionNumber: number | string,
): Promise<Record<string, unknown>> {
  return serializeRemoteConfig(
    await getAdminRemoteConfig().getTemplateAtVersion(versionNumber),
  );
}

export function assertRemoteConfigEtag(actual: string, expected: string): void {
  if (actual !== expected) {
    throw new ApiError(
      409,
      "remote_config_conflict",
      "Remote Config changed since it was loaded. Refresh and try again.",
    );
  }
}

export async function updateRemoteConfig(input: {
  maxJournals: number;
  maxKeywords: number;
  expectedEtag: string;
  description: string;
}): Promise<Record<string, unknown>> {
  const remoteConfig = getAdminRemoteConfig();
  const template = await remoteConfig.getTemplate();
  assertRemoteConfigEtag(template.etag, input.expectedEtag);

  setNumberParameter(
    template,
    "max_journals",
    input.maxJournals,
    "Maximum number of journals displayed in journal rankings",
  );
  setNumberParameter(
    template,
    "max_keywords",
    input.maxKeywords,
    "Maximum number of keywords displayed in keyword rankings",
  );
  template.version = { description: input.description };
  const validated = await remoteConfig.validateTemplate(template);
  const published = await remoteConfig.publishTemplate(validated);
  return serializeRemoteConfig(published);
}

export async function rollbackRemoteConfig(input: {
  versionNumber: number | string;
  expectedEtag: string;
}): Promise<Record<string, unknown>> {
  const remoteConfig = getAdminRemoteConfig();
  const target = await remoteConfig.getTemplateAtVersion(input.versionNumber);
  const current = await remoteConfig.getTemplate();
  assertRemoteConfigEtag(current.etag, input.expectedEtag);

  // Publishing the retained template with the current ETag preserves optimistic
  // concurrency. The Admin SDK rollback helper force-publishes and bypasses it.
  const rollbackTemplate: RemoteConfigTemplate = {
    ...target,
    etag: current.etag,
    version: {
      description: `Rollback to Remote Config version ${input.versionNumber}.`,
    },
  };
  const validated = await remoteConfig.validateTemplate(rollbackTemplate);
  const published = await remoteConfig.publishTemplate(validated);
  return serializeRemoteConfig(published);
}
