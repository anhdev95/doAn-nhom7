// Đối chiếu database thật với Database contract (chỉ đọc catalog + đếm dữ liệu lệch quy tắc).
// Dùng bởi `npm run check-db`. Không sửa schema/dữ liệu.
const { TABLES } = require('../config/tables');
const { COLUMNS, FOREIGN_KEYS, UNIQUES, DOMAINS, SALARY_RULE } = require('../config/contract');
const sqlService = require('../services/sql.service');

const pass = (message) => ({ level: 'pass', message });
const warn = (message) => ({ level: 'warn', message });
const fail = (message) => ({ level: 'fail', message });
const info = (message) => ({ level: 'info', message });

function typeOf(row) {
  const t = row.DATA_TYPE.toLowerCase();
  if (t === 'nvarchar' || t === 'varchar') return `${t}(${row.CHARACTER_MAXIMUM_LENGTH === -1 ? 'max' : row.CHARACTER_MAXIMUM_LENGTH})`;
  if (t === 'decimal' || t === 'numeric') return `decimal(${row.NUMERIC_PRECISION},${row.NUMERIC_SCALE})`;
  return t;
}

async function loadCatalog() {
  const r = await sqlService.query(`
    SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE
      FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' ORDER BY TABLE_NAME, ORDINAL_POSITION;
    SELECT t.name AS tableName, i.is_primary_key AS isPk, i.name AS indexName,
           STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS cols,
           MAX(CAST(c.is_identity AS INT)) AS hasIdentity
      FROM sys.indexes i
      JOIN sys.tables t ON t.object_id = i.object_id AND SCHEMA_NAME(t.schema_id) = 'dbo'
      JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
      JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
     WHERE i.is_primary_key = 1 OR i.is_unique = 1
     GROUP BY t.name, i.is_primary_key, i.name;
    SELECT OBJECT_NAME(fkc.parent_object_id) AS tableName, pc.name AS col,
           OBJECT_NAME(fkc.referenced_object_id) AS refTable, rc.name AS refCol
      FROM sys.foreign_key_columns fkc
      JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
      JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id;`);
  const [cols, indexes, fks] = r.recordsets;
  return { cols, indexes, fks };
}

async function checkContract() {
  const results = [];
  const { cols, indexes, fks } = await loadCatalog();
  const colsByTable = new Map();
  for (const c of cols) {
    if (!colsByTable.has(c.TABLE_NAME.toUpperCase())) colsByTable.set(c.TABLE_NAME.toUpperCase(), []);
    colsByTable.get(c.TABLE_NAME.toUpperCase()).push(c);
  }

  const present = new Set();
  for (const table of TABLES) {
    const actual = colsByTable.get(table.name);
    if (!actual) {
      results.push(fail(`${table.name}: bảng chưa tồn tại.`));
      continue;
    }
    present.add(table.name);
    const problems = [];
    for (const [name, type] of COLUMNS[table.name]) {
      const a = actual.find((c) => c.COLUMN_NAME.toLowerCase() === name.toLowerCase());
      if (!a) problems.push(`thiếu cột ${name}`);
      else if (typeOf(a) !== type) problems.push(`${name} là ${typeOf(a)}, contract là ${type}`);
    }
    const extra = actual.filter((a) => !COLUMNS[table.name].some(([n]) => n.toLowerCase() === a.COLUMN_NAME.toLowerCase()));
    if (problems.length) results.push(fail(`${table.name}: ${problems.join('; ')}.`));
    else results.push(pass(`${table.name}: ${COLUMNS[table.name].length} cột đúng contract.`));
    if (extra.length) results.push(warn(`${table.name}: có cột ngoài contract: ${extra.map((c) => c.COLUMN_NAME).join(', ')}.`));

    const pk = indexes.find((i) => i.tableName.toUpperCase() === table.name && i.isPk);
    if (!pk) results.push(fail(`${table.name}: chưa có PRIMARY KEY.`));
    else if (pk.cols.toLowerCase() !== table.pk.toLowerCase()) results.push(fail(`${table.name}: PK là (${pk.cols}), contract là (${table.pk}).`));
    else results.push(info(`${table.name}: PK ${table.pk} ${pk.hasIdentity ? 'có IDENTITY' : 'không IDENTITY'}.`));
  }

  for (const [t, c, rt, rc] of FOREIGN_KEYS) {
    if (!present.has(t) || !present.has(rt)) continue;
    const ok = fks.some((f) => f.tableName.toUpperCase() === t && f.col.toLowerCase() === c.toLowerCase()
      && f.refTable.toUpperCase() === rt && f.refCol.toLowerCase() === rc.toLowerCase());
    results.push(ok ? pass(`FK ${t}.${c} → ${rt}.${rc}`) : fail(`Thiếu FK ${t}.${c} → ${rt}.${rc}.`));
  }

  for (const [t, ucols] of UNIQUES) {
    if (!present.has(t)) continue;
    const want = [...ucols].map((x) => x.toLowerCase()).sort().join(',');
    const ok = indexes.some((i) => i.tableName.toUpperCase() === t && !i.isPk
      && i.cols.toLowerCase().split(',').sort().join(',') === want);
    results.push(ok ? pass(`UNIQUE ${t}(${ucols.join(', ')})`) : fail(`Thiếu UNIQUE ${t}(${ucols.join(', ')}).`));
  }

  for (const d of await domainStats()) {
    if (!d.available) continue;
    const outside = d.extra.filter((x) => x.value !== null);
    if (outside.length) {
      results.push(warn(`${d.table}.${d.column}: có giá trị ngoài miền đã chốt: ${outside.map((x) => `"${x.value}" (${x.count})`).join(', ')}.`));
    } else {
      results.push(pass(`${d.table}.${d.column}: dữ liệu đúng miền giá trị [${d.values.map((v) => v.value).join(' | ')}].`));
    }
  }

  if (present.has('BANG_LUONG')) {
    const r = await sqlService.query(`
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN ISNULL(LuongThucNhan, 0) <> ISNULL(LuongCoBan, 0) + ISNULL(LuongHieuSuat, 0) + ISNULL(PhuCap, 0)
                                                 + ISNULL(TienThuong, 0) - ISNULL(KhauTru, 0) THEN 1 ELSE 0 END) AS mismatched
        FROM [BANG_LUONG]`);
    const { total, mismatched } = r.recordset[0];
    results.push(mismatched
      ? warn(`BANG_LUONG: ${mismatched}/${total} dòng lệch quy tắc ${SALARY_RULE}.`)
      : pass(`BANG_LUONG: ${total} dòng khớp quy tắc ${SALARY_RULE}.`));
  }
  return results;
}

// Phân bố giá trị các cột có miền giá trị đã chốt (Dashboard + check-db).
async function domainStats() {
  const r = await sqlService.query(
    `SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo'`,
  );
  const has = new Set(r.recordset.map((x) => `${x.t.toUpperCase()}.${x.c.toLowerCase()}`));
  const out = [];
  for (const d of DOMAINS) {
    const base = { table: d.table, column: d.column, label: d.label };
    if (!has.has(`${d.table}.${d.column.toLowerCase()}`)) {
      out.push({ ...base, available: false, values: d.values.map((value) => ({ value, count: null })), extra: [] });
      continue;
    }
    const q = await sqlService.query(
      `SELECT ${sqlService.quoteIdentifier(d.column)} AS value, COUNT(*) AS count
         FROM ${sqlService.quoteIdentifier(d.table)} GROUP BY ${sqlService.quoteIdentifier(d.column)}`,
    );
    // So sánh sau khi chuẩn hóa NFC: dữ liệu tiếng Việt nhập dạng tổ hợp (NFD) vẫn khớp.
    const nfc = (v) => (typeof v === 'string' ? v.normalize('NFC') : v);
    const counts = new Map();
    for (const x of q.recordset) counts.set(nfc(x.value), (counts.get(nfc(x.value)) || 0) + x.count);
    out.push({
      ...base,
      available: true,
      values: d.values.map((value) => ({ value, count: counts.get(value) || 0 })),
      extra: [...counts].filter(([v]) => !d.values.includes(v)).map(([value, count]) => ({ value, count })),
    });
  }
  return out;
}

module.exports = { checkContract, domainStats };
