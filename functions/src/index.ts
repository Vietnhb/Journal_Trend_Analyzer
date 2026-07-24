import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { app } from "./app.js";
import { processDueCampaigns } from "./campaign-service.js";
import { REGION } from "./constants.js";

export const adminApi = onRequest(
  {
    region: REGION,
    cors: false,
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: 1,
    invoker: "public",
  },
  app,
);

export const dispatchScheduledCampaigns = onSchedule(
  {
    region: REGION,
    schedule: "every 1 minutes",
    timeZone: "Asia/Bangkok",
    timeoutSeconds: 120,
    memory: "256MiB",
    maxInstances: 1,
  },
  processDueCampaigns,
);
