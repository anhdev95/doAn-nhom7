// Thực thi các case Xử lý thông tin khai báo trong Source/Database/Processing/processing.manifest.json.
// Manifest được đọc lại mỗi request (có cache theo mtime) nên Tuyến bàn giao package là website tự nhận.
// Service chỉ GỌI object/script thật do nhóm bàn giao; không chứa SQL nghiệp vụ.
const { sql, getPool, describeError } = require('../config/database');
const { loadProcessingManifest } = require('../integration/processing.manifest');
const { getObjectsInfo, objectIssues, objectNamesOf, objectKey } = require('../integration/db.checks');
const { PARAM_TYPES, convertParam } = require('../integration/params');
const { resolveSql, isFile, readText } = require('../integration/paths');
const sqlService = require('./sql.service');
const { maskSecrets } = require('../utils/secrets');

const BLOCKING = (i) => i.level === 'fail';

// ---------- Trạng thái ----------
// pending | config-error | missing-file | missing-object | wrong-object-type | ready | unknown (DB lỗi)
function fileStatus(c) {
  if (!c.declared) return 'pending';
  const fails = c.issues.filter(BLOCKING);
  if (!fails.length) return 'ready';
  return fails.every((i) => i.code === 'missing-file') ? 'missing-file' : 'config-error';
}

function withDbStatus(c, info) {
  const code = fileStatus(c);
  if (code !== 'ready') return { code, issues: c.issues };
  const dbIssues = objectIssues(c, info);
  if (!dbIssues.length) return { code: 'ready', issues: c.issues };
  const wrong = dbIssues.find((i) => i.code === 'wrong-object-type');
  return { code: wrong ? 'wrong-object-type' : 'missing-object', issues: [...c.issues, ...dbIssues] };
}

function summary(c, status, info) {
  const obj = c.objectName && info ? info.get(objectKey(c.objectName)) : null;
  return {
    id: c.id,
    type: c.type,
    title: c.title,
    description: c.description,
    objectName: c.objectName,
    object: obj ? { exists: obj.exists, typeDesc: obj.typeDesc || null } : null,
    sourceFile: c.sourceFile,
    relatedTables: c.relatedTables.map((t) => t.table),
    execute: c.execute,
    status,
  };
}

async function loadWithStatus() {
  const { manifest, issues, cases } = loadProcessingManifest();
  let info = new Map();
  let dbError = null;
  const needDb = cases.some((c) => fileStatus(c) === 'ready');
  if (needDb) {
    try {
      info = await getObjectsInfo(objectNamesOf(cases.filter((c) => fileStatus(c) === 'ready')));
    } catch (err) {
      dbError = describeError(err);
    }
  }
  const items = cases.map((c) => {
    const status = dbError && fileStatus(c) === 'ready'
      ? { code: 'unknown', issues: c.issues }
      : withDbStatus(c, info);
    return { c, status, info };
  });
  return { manifest, manifestIssues: issues, items, dbError };
}

async function listCases() {
  const { manifest, manifestIssues, items, dbError } = await loadWithStatus();
  return {
    manifest,
    manifestIssues,
    dbError,
    cases: items.map(({ c, status, info }) => summary(c, status, info)),
  };
}

async function findCase(id) {
  const data = await loadWithStatus();
  const item = data.items.find((x) => x.c.id === id);
  if (!item) throw Object.assign(new Error(`Không có case "${id}".`), { status: 404 });
  if (data.dbError && item.status.code === 'unknown') {
    throw Object.assign(new Error(data.dbError.message), { number: data.dbError.number, code: data.dbError.code });
  }
  return item;
}

async function readRelated(c, runner) {
  const out = [];
  for (const t of c.relatedTables) {
    try {
      out.push(await sqlService.readTable(t.table, { page: 1, pageSize: t.pageSize, order: 'desc' }, runner));
    } catch (err) {
      out.push({ table: t.table, error: describeError(err) });
    }
  }
  return out;
}

const readSql = (rel) => {
  const full = resolveSql(rel);
  return isFile(full) ? readText(full) : null;
};

async function getCaseDetail(id) {
  const { c, status, info } = await findCase(id);
  let definition = null;
  if (c.objectName && status.code === 'ready') {
    const obj = await sqlService.getObjectInfo(c.objectName);
    definition = obj.exists ? obj : null;
  }
  return {
    ...summary(c, status, info),
    definition,
    sourceSql: c.sourceFile ? maskSecrets(readSql(c.sourceFile)) : null,
    scriptSql: c.execute && c.execute.kind === 'script' ? maskSecrets(readSql(c.execute.file)) : null,
    before: status.code === 'ready' ? await readRelated(c) : [],
  };
}

// ---------- Thực thi ----------
function buildParams(defs = [], input = {}) {
  const params = {};
  const display = [];
  for (const def of defs) {
    const value = convertParam(def, input[def.name]);
    params[def.name] = { type: PARAM_TYPES[def.type](), value };
    display.push({ name: def.name, value: input[def.name] === undefined || input[def.name] === '' ? null : String(input[def.name]) });
  }
  return { params, display };
}

const literal = (v) => (v === null ? 'NULL' : /^-?\d+(\.\d+)?$/.test(v) ? v : `N'${v.replace(/'/g, "''")}'`);

function splitBatches(text) {
  return text
    .split(/^\s*GO\s*;?\s*$/gim)
    .map((b) => b.trim())
    .filter(Boolean);
}

function requestWithMessages(runner, params, messages) {
  const request = sqlService.bindParams(sqlService.newRequest(runner), params);
  request.on('info', (info) => messages.push(info.message));
  return request;
}

async function runExecute(ex, params, display, runner, messages) {
  const argList = ex.params.map((p) => `@${p.name}`).join(', ');
  switch (ex.kind) {
    case 'procedure': {
      const executedSql = `EXEC ${ex.name} ${display.map((d) => `@${d.name} = ${literal(d.value)}`).join(', ')}`.trim();
      const result = await requestWithMessages(runner, params, messages).execute(ex.name);
      return { executedSql, results: [sqlService.serializeResult(result)] };
    }
    case 'scalar-function':
    case 'table-function': {
      const fn = sqlService.quoteObjectName(ex.name);
      const text = ex.kind === 'scalar-function' ? `SELECT ${fn}(${argList}) AS [KetQua];` : `SELECT * FROM ${fn}(${argList});`;
      const result = await requestWithMessages(runner, params, messages).query(text);
      const shown = display.reduce((s, d) => s.replace(new RegExp(`@${d.name}\\b`, 'g'), literal(d.value)), text);
      return { executedSql: shown, results: [sqlService.serializeResult(result)] };
    }
    case 'script': {
      const text = readSql(ex.file);
      if (text === null) throw Object.assign(new Error(`Không đọc được file ${ex.file}.`), { status: 409 });
      const results = [];
      for (const batch of splitBatches(text)) {
        results.push(sqlService.serializeResult(await requestWithMessages(runner, params, messages).query(batch)));
      }
      return { executedSql: text, results };
    }
    default:
      throw new Error(`execute.kind không hợp lệ: ${ex.kind}`);
  }
}

// mode: 'rollback' (chạy thử, dữ liệu sau được đọc trong transaction rồi hoàn tác) | 'commit'.
async function executeCase(id, body = {}) {
  const { c, status } = await findCase(id);
  if (status.code !== 'ready') {
    throw Object.assign(new Error(`Case ${id} chưa sẵn sàng (trạng thái: ${status.code}).`), { status: 409 });
  }
  const ex = c.execute;
  const input = body.params && typeof body.params === 'object' && !Array.isArray(body.params) ? body.params : {};
  const { params, display } = buildParams(ex.params, input);
  const useTx = ex.transaction !== false;
  const mode = useTx && body.mode !== 'commit' ? 'rollback' : 'commit';
  const pool = await getPool();
  const messages = [];
  const started = Date.now();

  let tx = null;
  let runner = pool;
  if (useTx) {
    tx = new sql.Transaction(pool);
    await tx.begin();
    runner = tx;
  }

  try {
    const { executedSql, results } = await runExecute(ex, params, display, runner, messages);
    const after = await readRelated(c, runner);
    if (tx) await (mode === 'commit' ? tx.commit() : tx.rollback());
    return { ok: true, id, mode, durationMs: Date.now() - started, executedSql: maskSecrets(executedSql), results, messages, after };
  } catch (err) {
    if (tx) await tx.rollback().catch(() => {});
    if (err.status) throw err;
    const info = describeError(err);
    if (info.kind === 'connection') throw err;
    // Lỗi do SQL Server trả về (vd. trigger chặn thao tác) là một kết quả demo hợp lệ.
    return {
      ok: false,
      id,
      mode,
      durationMs: Date.now() - started,
      executionError: info,
      messages,
      after: await readRelated(c, pool),
    };
  }
}

module.exports = { listCases, getCaseDetail, executeCase };
