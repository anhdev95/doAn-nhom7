// Lớp truy cập SQL Server dùng chung: chạy query có tham số, đọc bảng trong whitelist,
// đọc metadata object và chuẩn hóa kết quả để trả về JSON.
const { sql, getPool } = require('../config/database');
const { TABLES, getTable, pkColumns } = require('../config/tables');

const SAFE_IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;
const SAFE_OBJECT_NAME = /^([A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*$/;

function quoteIdentifier(name) {
  if (!SAFE_IDENTIFIER.test(name)) throw new Error(`Identifier không hợp lệ: ${name}`);
  return `[${name}]`;
}

function quoteObjectName(name) {
  if (!SAFE_OBJECT_NAME.test(name)) throw new Error(`Tên object không hợp lệ: ${name}`);
  return name.split('.').map(quoteIdentifier).join('.');
}

// `runner` là pool hoặc transaction – cho phép đọc dữ liệu "sau" trong cùng transaction.
function newRequest(runner) {
  return new sql.Request(runner);
}

function bindParams(request, params = {}) {
  for (const [name, p] of Object.entries(params)) {
    if (p && typeof p === 'object' && 'type' in p) request.input(name, p.type, p.value);
    else request.input(name, p);
  }
  return request;
}

async function query(text, params, runner) {
  const target = runner || (await getPool());
  return bindParams(newRequest(target), params).query(text);
}

// ---------- Chuẩn hóa kết quả ----------
const pad = (n, len = 2) => String(n).padStart(len, '0');

function formatValue(value, type) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) {
    const ymd = `${value.getUTCFullYear()}-${pad(value.getUTCMonth() + 1)}-${pad(value.getUTCDate())}`;
    const hms = `${pad(value.getUTCHours())}:${pad(value.getUTCMinutes())}:${pad(value.getUTCSeconds())}`;
    if (type === sql.Date) return ymd;
    if (type === sql.Time) return hms;
    return `${ymd} ${hms}`;
  }
  if (Buffer.isBuffer(value)) return `0x${value.toString('hex')}`;
  if (typeof value === 'bigint') return value.toString();
  return value;
}

function serializeRecordset(recordset) {
  if (!recordset) return { columns: [], rows: [] };
  const meta = Object.values(recordset.columns || {}).sort((a, b) => a.index - b.index);
  const columns = meta.length
    ? meta.map((c) => ({ name: c.name, type: c.type && c.type.declaration ? c.type.declaration : null }))
    : Object.keys(recordset[0] || {}).map((name) => ({ name, type: null }));
  const typeOf = Object.fromEntries(meta.map((c) => [c.name, c.type]));
  // DECIMAL/NUMERIC: giữ đúng số chữ số thập phân của cột (vd 10000000.50 thay vì 10000000.5).
  const scaleOf = Object.fromEntries(meta.filter((c) => c.type === sql.Decimal || c.type === sql.Numeric).map((c) => [c.name, c.scale]));
  const rows = recordset.map((row) => {
    const out = {};
    for (const col of columns) {
      const v = row[col.name];
      out[col.name] = typeof v === 'number' && scaleOf[col.name] !== undefined ? v.toFixed(scaleOf[col.name]) : formatValue(v, typeOf[col.name]);
    }
    return out;
  });
  return { columns, rows };
}

function serializeResult(result) {
  return {
    recordsets: (result.recordsets || []).map(serializeRecordset),
    rowsAffected: result.rowsAffected || [],
    returnValue: result.returnValue === undefined ? null : result.returnValue,
    output: result.output || {},
  };
}

// ---------- Bảng trong whitelist ----------
async function readTable(tableName, { page = 1, pageSize = 50, order = 'asc' } = {}, runner) {
  const table = getTable(tableName);
  if (!table) {
    const err = new Error(`Bảng "${tableName}" không nằm trong whitelist.`);
    err.status = 400;
    throw err;
  }
  const size = Math.min(Math.max(parseInt(pageSize, 10) || 50, 1), 500);
  const current = Math.max(parseInt(page, 10) || 1, 1);
  const t = quoteIdentifier(table.name);
  const direction = String(order).toLowerCase() === 'desc' ? 'DESC' : 'ASC';
  const orderBy = pkColumns(table).map((c) => `${quoteIdentifier(c)} ${direction}`).join(', ');

  const result = await query(
    `SELECT COUNT_BIG(*) AS total FROM ${t};
     SELECT * FROM ${t} ORDER BY ${orderBy} OFFSET @offset ROWS FETCH NEXT @size ROWS ONLY;`,
    { offset: { type: sql.Int, value: (current - 1) * size }, size: { type: sql.Int, value: size } },
    runner,
  );
  const total = Number(result.recordsets[0][0].total);
  return {
    table: table.name,
    label: table.label,
    page: current,
    pageSize: size,
    order: direction.toLowerCase(),
    pk: table.pk,
    total,
    totalPages: Math.max(Math.ceil(total / size), 1),
    ...serializeRecordset(result.recordsets[1]),
  };
}

// Đếm số dòng của các bảng whitelist đang tồn tại trong DB (bảng chưa tạo -> exists:false).
async function countAllTables() {
  const existing = await query(
    `SELECT t.name FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) = 'dbo'`,
  );
  const names = new Set(existing.recordset.map((r) => r.name.toUpperCase()));
  const present = TABLES.filter((t) => names.has(t.name));
  let counts = {};
  if (present.length) {
    const unions = present
      .map((t) => `SELECT '${t.name}' AS tableName, COUNT_BIG(*) AS total FROM ${quoteIdentifier(t.name)}`)
      .join(' UNION ALL ');
    const r = await query(unions);
    counts = Object.fromEntries(r.recordset.map((row) => [row.tableName, Number(row.total)]));
  }
  return TABLES.map((t) => ({
    name: t.name,
    label: t.label,
    group: t.group,
    exists: names.has(t.name),
    total: names.has(t.name) ? counts[t.name] : null,
  }));
}

// ---------- Metadata object (procedure/function/trigger) ----------
async function getObjectInfo(objectName) {
  if (!objectName) return null;
  quoteObjectName(objectName);
  const r = await query(
    `SELECT o.name, o.type, o.type_desc, o.create_date, o.modify_date,
            OBJECT_DEFINITION(o.object_id) AS definition
       FROM sys.objects o
      WHERE o.object_id = OBJECT_ID(@name)`,
    { name: { type: sql.NVarChar(256), value: objectName } },
  );
  const row = r.recordset[0];
  if (!row) return { exists: false };
  return {
    exists: true,
    name: row.name,
    type: row.type.trim(),
    typeDesc: row.type_desc,
    createDate: formatValue(row.create_date),
    modifyDate: formatValue(row.modify_date),
    definition: row.definition,
  };
}

async function getServerInfo() {
  const r = await query(
    `SELECT @@SERVERNAME AS serverName,
            CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(50)) AS productVersion,
            CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100)) AS edition,
            DB_NAME() AS databaseName,
            SUSER_SNAME() AS loginName,
            USER_NAME() AS databaseUser,
            SYSDATETIME() AS serverTime`,
  );
  const row = r.recordset[0];
  return { ...row, serverTime: formatValue(row.serverTime) };
}

module.exports = {
  sql,
  query,
  newRequest,
  bindParams,
  quoteIdentifier,
  quoteObjectName,
  serializeRecordset,
  serializeResult,
  readTable,
  countAllTables,
  getObjectInfo,
  getServerInfo,
};
