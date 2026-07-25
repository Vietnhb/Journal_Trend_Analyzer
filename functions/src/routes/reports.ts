import { pipeline } from "node:stream/promises";

import { Router } from "express";

import { writeMutationAudit } from "../audit.js";
import { sendData } from "../errors.js";
import {
  deleteAllReports,
  deleteReport,
  deleteReports,
  getValidatedPdf,
  listReportPage,
} from "../report-service.js";
import {
  reportDeleteSchema,
  reportsBulkDeleteSchema,
  reportsDeleteAllSchema,
  reportDownloadQuerySchema,
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
    `%${value.codePointAt(0)!.toString(16).toUpperCase()}`,
  );
  return `inline; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

reportsRouter.get("/download", async (req, res, next) => {
  try {
    const { path, generation } = reportDownloadQuerySchema.parse({
      path: singleQueryValue(req.query.path),
      generation: singleQueryValue(req.query.generation),
    });
    const report = await getValidatedPdf(path, generation);
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

reportsRouter.delete("/bulk", async (req, res) => {
  const { reports } = reportsBulkDeleteSchema.parse(req.body as unknown);
  const result = await deleteReports(reports);
  await writeMutationAudit(req, {
    action: "report.bulk_delete",
    targetType: "storage_report_batch",
    targetId: `selected:${reports.length}`,
    summary: `Deleted ${result.deleted.length} selected PDF reports from Cloud Storage.`,
    details: {
      requestedCount: reports.length,
      deletedCount: result.deleted.length,
      failedCount: result.failed.length,
    },
  });
  sendData(res, result);
});

reportsRouter.delete("/all", async (req, res) => {
  reportsDeleteAllSchema.parse(req.body as unknown);
  const result = await deleteAllReports();
  await writeMutationAudit(req, {
    action: "report.delete_all",
    targetType: "storage_report_collection",
    targetId: "report-prefix",
    summary: `Deleted ${result.deleted.length} PDF reports from Cloud Storage.`,
    details: {
      deletedCount: result.deleted.length,
      failedCount: result.failed.length,
    },
  });
  sendData(res, result);
});
