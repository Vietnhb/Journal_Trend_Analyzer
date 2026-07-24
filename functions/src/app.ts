import express from "express";

import { apiRouter } from "./api-router.js";
import { API_PREFIX } from "./constants.js";
import { ApiError, errorMiddleware } from "./errors.js";
import {
  accessLogMiddleware,
  authenticateAdmin,
  corsMiddleware,
  requestContextMiddleware,
} from "./middleware.js";

export const app = express();

app.disable("x-powered-by");
app.use(requestContextMiddleware);
app.use(accessLogMiddleware);
app.use(corsMiddleware);
app.use(express.json({ limit: "64kb", type: ["application/json", "application/*+json"] }));
app.use(API_PREFIX, authenticateAdmin, apiRouter);
app.use((_req, _res, next) => {
  next(new ApiError(404, "not_found", "The requested API route does not exist."));
});
app.use(errorMiddleware);
