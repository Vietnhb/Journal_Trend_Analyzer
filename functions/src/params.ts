import { defineBoolean, defineString } from "firebase-functions/params";

export const enforceAppCheck = defineBoolean("ENFORCE_APP_CHECK", {
  default: false,
  description: "Require a valid X-Firebase-AppCheck token on admin API requests.",
});

export const adminAllowedOrigins = defineString("ADMIN_ALLOWED_ORIGINS", {
  default: [
    "https://journal-trend-analyzer.web.app",
    "https://journal-trend-analyzer.firebaseapp.com",
  ].join(","),
  description: "Comma-separated exact origins permitted through Firebase Hosting rewrites.",
});

export const ga4PropertyId = defineString("GA4_PROPERTY_ID", {
  default: "",
  description: "Numeric GA4 property ID used by the admin Analytics dashboard.",
});

export const ga4StreamId = defineString("GA4_STREAM_ID", {
  default: "",
  description: "Numeric GA4 data stream ID scoped by the admin Analytics dashboard.",
});

export const crashlyticsTable = defineString("CRASHLYTICS_TABLE", {
  default: "",
  description: "Crashlytics BigQuery table in project.dataset.table form.",
});

export const crashlyticsAppId = defineString("CRASHLYTICS_APP_ID", {
  default: "",
  description:
    "Firebase Android package name whose Crashlytics batch and realtime tables are queried.",
});

export const adminServiceAccountPath = defineString("ADMIN_SERVICE_ACCOUNT_PATH", {
  default: "",
  description: "Local-only service account JSON path used by the Functions emulator.",
});
