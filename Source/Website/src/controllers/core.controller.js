// Health check, Dashboard và generic table viewer.
const { publicConnectionInfo, diagnoseError } = require('../config/database');
const { TABLES } = require('../config/tables');
const sqlService = require('../services/sql.service');
const exportService = require('../services/export.service');
const processingService = require('../services/processing.service');
const { domainStats } = require('../integration/contract.check');
const { loadReportsManifest } = require('../integration/reports.manifest');
const { handle } = require('../utils/http');

// Tóm tắt trạng thái package tích hợp (Processing/Reports) cho Dashboard.
async function integrationSummary() {
  const count = (items, key) => items.reduce((acc, x) => ({ ...acc, [key(x)]: (acc[key(x)] || 0) + 1 }), {});
  const p = await processingService.listCases();
  const r = loadReportsManifest();
  return {
    processing: { manifest: p.manifest, total: p.cases.length, byStatus: count(p.cases, (c) => c.status.code) },
    reports: { manifest: r.manifest, total: r.reports.length, byStatus: count(r.reports, (x) => x.status) },
  };
}

// Luôn trả 200 để frontend hiển thị được trạng thái, kể cả khi DB mất kết nối.
async function health(req, res) {
  const connection = publicConnectionInfo();
  try {
    const server = await sqlService.getServerInfo();
    res.json({ ok: true, connected: true, connection, server });
  } catch (err) {
    res.json({ ok: false, connected: false, connection, error: await diagnoseError(err) });
  }
}

const dashboard = handle(async (req, res) => {
  const server = await sqlService.getServerInfo();
  const tables = await sqlService.countAllTables();
  const pick = (name) => tables.find((t) => t.name === name);

  res.json({
    ok: true,
    server,
    cards: ['NHANVIEN', 'PHONGBAN', 'UNGVIEN', 'DAOTAO'].map(pick),
    domains: await domainStats(),
    integration: await integrationSummary(),
    tables,
    missingTables: tables.filter((t) => !t.exists).map((t) => t.name),
  });
});

function listTables(req, res) {
  res.json({ ok: true, tables: TABLES });
}

const readTable = handle(async (req, res) => {
  const data = await sqlService.readTable(req.params.tableName, {
    page: req.query.page,
    pageSize: req.query.pageSize,
    order: req.query.order,
  });
  res.json({ ok: true, ...data });
});

const exportTable = handle(async (req, res) => {
  const file = await exportService.exportTableCsv(req.params.tableName, req.query.order);
  res.set('Content-Type', 'text/csv; charset=utf-8');
  res.set('Content-Disposition', `attachment; filename="${file.fileName}"`);
  res.set('X-Row-Count', String(file.rowCount));
  res.send(file.content);
});

module.exports = { health, dashboard, listTables, readTable, exportTable };
