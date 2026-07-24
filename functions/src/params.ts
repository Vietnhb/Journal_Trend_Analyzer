import { defineBoolean, defineString } from "firebase-functions/params";

export const enforceAppCheck = defineBoolean("ENFORCE_APP_CHECK", {
  default: false,
  description: "Require a valid X-Firebase-AppCheck token on admin API requests.",
});

export const adminAllowedOrigins = defineString("ADMIN_ALLOWED_ORIGINS", {
  default: [
    "https://journal-trend-analyzer-admin.web.app",
    "https://journal-trend-analyzer-admin.firebaseapp.com",
  ].join(","),
  description: "Comma-separated exact origins permitted through Firebase Hosting rewrites.",
});

export const ga4PropertyId = defineString("GA4_PROPERTY_ID", {
  default: "",
  description: "Numeric GA4 property ID used by the admin Analytics dashboard.",
});

export const crashlyticsTable = defineString("CRASHLYTICS_TABLE", {
  default: "",
  description: "Crashlytics BigQuery table in project.dataset.table form.",
});
