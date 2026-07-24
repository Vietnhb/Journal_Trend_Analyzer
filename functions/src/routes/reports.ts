import { pipeline } from "node:stream/promises";

import { Router } from "express";

import { writeMutationAudit } from "../audit.js";
import { sendData } from "../errors.js";
import {
  deleteReport,
  getValidatedPdf,
  listReportPage,
} from "../report-service.js";
import {
  reportDeleteSchema,
  reportPathQuerySchema,
  reportsQuerySchema,
  singleQueryValue,
} from "../validation.js";

export const reportsRouter = Router();

reportsRouter.get("/", async (req, res) => {
  const query = reportsQuerySchema.parse({
    pageToken: singleQueryValue(req.query.pageToken),
    pageSize: singleQueryValue(req.query.pageSize),
  });
  sendData(res, await listReportPage({
    pageSize: query.pageSize,
    ...(query.pageToken === undefined ? {} : { pageToken: query.pageToken }),
  }));
});

function contentDisposition(name: string): string {
  const ascii = name.replace(/[^\x20-\x7e]/g, "_").replace(/["\\]/g, "_");
  const encoded = encodeURIComponent(name).replace(/['()]/g, (value) =>
    `%${value.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  return `inline; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

reportsRouter.get("/download", async (req, res, next) => {
  try {
    const { path } = reportPathQuerySchema.parse({
      path: singleQueryValue(req.query.path),
    });
    const report = await getValidatedPdf(path);
    res.status(200);
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Length", String(report.sizeBytes));
    res.setHeader("Content-Disposition", contentDisposition(report.name));
    res.setHeader("Cache-Control", "private, no-store");
    await pipeline(report.file.createReadStream({ decompress: false }), res);
  } catch (error) {
    if (res.headersSent) res.destroy();
    else next(error);
  }
});

reportsRouter.delete("/", async (req, res) => {
  const { path, generation } = reportDeleteSchema.parse(req.body as unknown);
  await deleteReport(path, generation);
  await writeMutationAudit(req, {
    action: "report.delete",
    targetType: "storage_report",
    targetId: path,
    summary: "Deleted a PDF report from Cloud Storage.",
    details: { generation },
  });
  sendData(res, { path, generation, deleted: true });
});
