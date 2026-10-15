// Export CSV một bảng trong whitelist – dữ liệu truy vấn trực tiếp từ SQL Server tại thời điểm bấm nút.
// Tiện ích của Website, không thay thế phần Export (SQL) của nhóm.
const { sql } = require('../config/database');
const { getTable, pkColumns } = require('../config/tables');
const sqlService = require('./sql.service');

const MAX_ROWS = 50000;

// Ô bắt đầu bằng = + - @ có thể bị Excel hiểu là công thức (CSV injection) → thêm ' phía trước.
function csvCell(value) {
  if (value === null || value === undefined) return '';
  let s = String(value);
  if (typeof value === 'string' && /^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

const pad = (n) => String(n).padStart(2, '0');

async function exportTableCsv(tableName, order = 'asc') {
  const table = getTable(tableName);
  if (!table) throw Object.assign(new Error(`Bảng "${tableName}" không nằm trong whitelist.`), { status: 400 });
  const direction = String(order).toLowerCase() === 'desc' ? 'DESC' : 'ASC';
  const orderBy = pkColumns(table).map((c) => `${sqlService.quoteIdentifier(c)} ${direction}`).join(', ');
  const result = await sqlService.query(
    `SELECT TOP (@limit) * FROM ${sqlService.quoteIdentifier(table.name)} ORDER BY ${orderBy}`,
    { limit: { type: sql.Int, value: MAX_ROWS + 1 } },
  );
  if (result.recordset.length > MAX_ROWS) {
    throw Object.assign(new Error(`Bảng ${table.name} có hơn ${MAX_ROWS} dòng – hãy dùng script Export của nhóm.`), { status: 413 });
  }
  const { columns, rows } = sqlService.serializeRecordset(result.recordset);
  const lines = [columns.map((c) => csvCell(c.name)).join(',')];
  for (const row of rows) lines.push(columns.map((c) => csvCell(row[c.name])).join(','));

  const now = new Date();
  const stamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  return {
    fileName: `IE103_HRM_${table.name}_${stamp}.csv`,
    rowCount: rows.length,
    // BOM để Excel đọc đúng tiếng Việt UTF-8.
    content: `﻿${lines.join('\r\n')}\r\n`,
  };
}

module.exports = { exportTableCsv, csvCell, MAX_ROWS };
