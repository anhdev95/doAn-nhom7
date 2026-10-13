// Kiểm tra package tích hợp trước khi demo: `npm run validate-integration`
//   Processing (Tuyến): Source/Database/Processing/processing.manifest.json + file .sql
//   Reports (Tuyến):    Source/Reports/reports.manifest.json + ảnh
//   Security (nhóm):    Source/Database/Security/*
//   Database (nếu kết nối được): object tồn tại, đúng loại, tham số khớp, bảng liên quan tồn tại.
// Tuỳ chọn:
//   --no-db          bỏ qua kiểm tra database
//   --allow-pending  thiếu manifest chỉ là WARN (dùng khi package chưa được bàn giao)
// Exit code 1 nếu có ít nhất một [FAIL].
const path = require('path');
require('dotenv').config({ quiet: true, path: path.resolve(__dirname, '../.env') });
const fs = require('fs');
const { closePool, diagnoseError, publicConnectionInfo, sql } = require('../src/config/database');
const { loadProcessingManifest } = require('../src/integration/processing.manifest');
const { loadReportsManifest } = require('../src/integration/reports.manifest');
const { getObjectsInfo, objectIssues, objectNamesOf, objectKey } = require('../src/integration/db.checks');
const { PROCESSING_DIR, DATABASE_DIR, isFile, display } = require('../src/integration/paths');
const securityConfig = require('../src/config/security.config');
const sqlService = require('../src/services/sql.service');

const args = new Set(process.argv.slice(2));
const NO_DB = args.has('--no-db');
const ALLOW_PENDING = args.has('--allow-pending');

const color = process.stdout.isTTY ? { pass: '\x1b[32m', warn: '\x1b[33m', fail: '\x1b[31m', info: '\x1b[36m', reset: '\x1b[0m' } : { pass: '', warn: '', fail: '', info: '', reset: '' };
const counts = { pass: 0, warn: 0, fail: 0 };
function out(level, message) {
  if (counts[level] !== undefined) counts[level] += 1;
  console.log(`${color[level]}[${level.toUpperCase()}]${color.reset} ${message}`);
}
const section = (title) => console.log(`\n== ${title} ==`);

function printIssues(prefix, issues) {
  for (const i of issues) out(i.level, `${prefix} ${i.message}`);
}

function checkProcessing() {
  section('PROCESSING – Source/Database/Processing');
  const { manifest, issues, cases } = loadProcessingManifest();
  if (!manifest.exists) {
    out(ALLOW_PENDING ? 'warn' : 'fail', `${manifest.path} chưa tồn tại (chờ Tuyến bàn giao).`);
    return [];
  }
  if (manifest.error) {
    out('fail', `${manifest.path}: ${manifest.error}`);
    return [];
  }
  out('pass', `${manifest.path} đọc được (JSON hợp lệ).`);
  for (const f of ['Procedures.sql', 'Triggers.sql', 'Functions.sql', 'Cursors.sql']) {
    const full = path.join(PROCESSING_DIR, f);
    if (isFile(full)) out('pass', `${display(full)} có file.`);
    else out('warn', `${display(full)} chưa có (cấu trúc chuẩn của package).`);
  }
  printIssues('manifest:', issues);
  const valid = [];
  for (const c of cases) {
    if (!c.declared) continue;
    const fails = c.issues.filter((i) => i.level === 'fail');
    printIssues(`${c.id}`, c.issues);
    if (!fails.length) {
      out('pass', `${c.id} manifest valid (${c.type}, execute.kind=${c.execute.kind}).`);
      valid.push(c);
    }
  }
  return valid;
}

function checkReports() {
  section('REPORTS – Source/Reports');
  const { manifest, issues, reports } = loadReportsManifest();
  if (!manifest.exists) {
    out(ALLOW_PENDING ? 'warn' : 'fail', `${manifest.path} chưa tồn tại (chờ Tuyến bàn giao).`);
    return;
  }
  if (manifest.error) {
    out('fail', `${manifest.path}: ${manifest.error}`);
    return;
  }
  out('pass', `${manifest.path} đọc được (JSON hợp lệ).`);
  printIssues('manifest:', issues);
  for (const r of reports) {
    if (!r.declared) continue;
    printIssues(r.id, r.issues);
    if (r.status === 'ready') out('pass', `${r.id} ${r.type} hợp lệ${r.type === 'image' ? ` (${r.src})` : ''}.`);
  }
}

function checkSecurity() {
  section('SECURITY – Source/Database/Security (nhóm cung cấp)');
  for (const [group, entries] of Object.entries(securityConfig.scripts)) {
    for (const rel of entries) {
      const full = path.resolve(DATABASE_DIR, rel);
      const exists = full.startsWith(DATABASE_DIR + path.sep) && fs.existsSync(full);
      const isDir = exists && fs.statSync(full).isDirectory();
      const files = isDir ? fs.readdirSync(full).filter((f) => !f.startsWith('.')) : [];
      if (!exists || (isDir && !files.length)) out('warn', `${group}: Database/${rel} chưa có.`);
      else out('pass', `${group}: Database/${rel}${isDir ? ` (${files.length} file)` : ''}.`);
    }
  }
}

async function checkDatabase(validCases) {
  section('DATABASE');
  if (NO_DB) {
    out('warn', 'Bỏ qua kiểm tra database (--no-db).');
    return;
  }
  const conn = publicConnectionInfo();
  try {
    const s = await sqlService.getServerInfo();
    out('pass', `Kết nối ${conn.server}:${conn.port} / ${s.databaseName} (login ${s.loginName}).`);
  } catch (err) {
    const e = await diagnoseError(err);
    out('warn', `Không kết nối được database – bỏ qua kiểm tra object. ${e.message}${e.hint ? ` | ${e.hint}` : ''}`);
    return;
  }

  const tables = await sqlService.countAllTables();
  const existing = new Set(tables.filter((t) => t.exists).map((t) => t.name));
  const missingTables = tables.filter((t) => !t.exists).map((t) => t.name);
  if (missingTables.length) out('warn', `Chưa có ${missingTables.length}/16 bảng contract: ${missingTables.join(', ')}.`);
  else out('pass', 'Đủ 16 bảng contract.');

  await checkSecurityDb();

  if (!validCases.length) return;
  const info = await getObjectsInfo(objectNamesOf(validCases));

  for (const c of validCases) {
    const issues = objectIssues(c, info);
    printIssues(c.id, issues);
    if (!issues.length) {
      const names = [c.objectName, c.execute.name].filter(Boolean);
      for (const name of names.filter((n, i) => names.findIndex((x) => objectKey(x) === objectKey(n)) === i)) {
        const o = info.get(objectKey(name));
        out('pass', `${c.id} ${name} exists (${o.typeDesc}).`);
      }
    }
    for (const t of c.relatedTables) {
      if (!existing.has(t.table)) out('fail', `${c.id} relatedTables: bảng ${t.table} chưa tồn tại trong database.`);
    }
    if (c.type === 'trigger' && c.objectName) {
      const o = info.get(objectKey(c.objectName));
      const parent = o && o.parentObject ? o.parentObject.split('.').pop().toUpperCase() : null;
      if (parent && !c.relatedTables.some((t) => t.table === parent)) {
        out('warn', `${c.id} trigger gắn trên bảng ${parent} nhưng relatedTables không có ${parent}.`);
      }
    }
    if (!issues.length && c.execute.kind !== 'script' && c.execute.name) {
      const r = await sqlService.query(
        `SELECT SUBSTRING(name, 2, 128) AS name, is_output AS isOutput
           FROM sys.parameters WHERE object_id = OBJECT_ID(@obj) AND parameter_id > 0`,
        { obj: { type: sql.NVarChar(256), value: c.execute.name } },
      );
      const dbParams = r.recordset;
      for (const p of c.execute.params) {
        if (!dbParams.some((d) => d.name.toLowerCase() === p.name.toLowerCase())) {
          out('fail', `${c.id} tham số @${p.name} không có trong ${c.execute.name}.`);
        }
      }
      for (const d of dbParams) {
        if (!d.isOutput && !c.execute.params.some((p) => p.name.toLowerCase() === d.name.toLowerCase())) {
          out('warn', `${c.id} ${c.execute.name} có tham số @${d.name} nhưng manifest không khai báo (chỉ ổn nếu tham số có giá trị mặc định).`);
        }
      }
    }
  }
}

// Trạng thái An toàn thông tin trong database (kết quả sau khi chạy script Security của nhóm).
async function checkSecurityDb() {
  const roles = securityConfig.expectedRoles;
  const r = await sqlService.query(
    `SELECT r.value AS roleName, p.principal_id AS id,
            (SELECT COUNT(*) FROM sys.database_role_members rm WHERE rm.role_principal_id = p.principal_id) AS members,
            (SELECT COUNT(*) FROM sys.database_permissions pe WHERE pe.grantee_principal_id = p.principal_id AND pe.state = 'G') AS grants,
            (SELECT COUNT(*) FROM sys.database_permissions pe WHERE pe.grantee_principal_id = p.principal_id AND pe.state = 'D') AS denies
       FROM STRING_SPLIT(@roles, ',') r
       LEFT JOIN sys.database_principals p ON p.name = r.value AND p.type = 'R'`,
    { roles: { type: sql.NVarChar(sql.MAX), value: roles.join(',') } },
  );
  for (const row of r.recordset) {
    if (!row.id) out('warn', `Security: role ${row.roleName} chưa tồn tại (chạy Authorization.sql).`);
    else if (!row.members) out('warn', `Security: role ${row.roleName} chưa có thành viên.`);
    else out('pass', `Security: role ${row.roleName} – ${row.members} thành viên, ${row.grants} GRANT, ${row.denies} DENY.`);
  }
  if (r.recordset.some((x) => x.id) && !r.recordset.some((x) => x.denies)) out('warn', 'Security: chưa có quyền DENY nào cho các role (yêu cầu demo DENY/REVOKE).');
  const b = await sqlService.query(
    `SELECT COUNT(*) AS n, MAX(backup_finish_date) AS lastAt FROM msdb.dbo.backupset WHERE database_name = DB_NAME() AND type = 'D'`,
  ).catch(() => null);
  if (!b) out('warn', 'Security: login hiện tại không đọc được msdb – không kiểm tra lịch sử backup.');
  else if (!b.recordset[0].n) out('warn', 'Security: chưa có bản backup FULL nào của database (chạy Backup_Restore/01_Backup.sql).');
  else out('pass', `Security: có ${b.recordset[0].n} bản backup FULL trong msdb.`);
}

(async () => {
  console.log('IE103 Nhóm 7 – validate integration');
  const validCases = checkProcessing();
  checkReports();
  checkSecurity();
  try {
    await checkDatabase(validCases);
  } catch (err) {
    out('fail', `Lỗi khi kiểm tra database: ${err.message}`);
  } finally {
    await closePool().catch(() => {});
  }
  console.log(`\nKết quả: ${counts.pass} PASS · ${counts.warn} WARN · ${counts.fail} FAIL`);
  process.exitCode = counts.fail ? 1 : 0;
})();
