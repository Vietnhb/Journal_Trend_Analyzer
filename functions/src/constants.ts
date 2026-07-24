export const API_PREFIX = "/api/v1";
export const REGION = "asia-southeast1";
export const REPORT_PREFIX = "report/";
export const MAX_REPORT_BYTES = 10 * 1024 * 1024;
export const AUDIT_COLLECTION = "admin_audit_logs";
export const BROADCAST_TOPIC = "all_users";
export const CAMPAIGN_COLLECTION = "fcm_campaigns";

export const LAB_ANALYTICS_EVENTS = [
  "login",
  "search_topic",
  "view_publication",
  "view_journal",
  "view_keyword",
  "export_pdf",
  "logout",
] as const;

export type LabAnalyticsEvent = (typeof LAB_ANALYTICS_EVENTS)[number];
