// Kiểm tra object khai báo trong manifest có thật trong SQL Server và đúng loại (chỉ đọc catalog).
const { sql } = require('../config/database');
const sqlService = require('../services/sql.service');

// Mã sys.objects.type hợp lệ theo loại case / execute.kind.
function expectedObjectTypes(caseType, kind) {
  if (caseType === 'procedure') return ['P', 'PC'];
  if (caseType === 'trigger') return ['TR'];
  if (caseType === 'function') {
    if (kind === 'scalar-function') return ['FN', 'FS'];
    if (kind === 'table-function') return ['IF', 'TF', 'FT'];
    return ['FN', 'FS', 'IF', 'TF', 'FT'];
  }
  return ['P', 'PC', 'FN', 'FS', 'IF', 'TF', 'FT', 'TR']; // cursor: có thể nằm trong procedure/function/trigger
}

const key = (name) => (name.includes('.') ? name : `dbo.${name}`).toLowerCase();

// names: danh sách tên object (đã qua kiểm tra định dạng). Trả về Map key -> thông tin.
async function getObjectsInfo(names, runner) {
  const unique = [...new Set(names.filter(Boolean))];
  const map = new Map();
  if (!unique.length) return map;
  const r = await sqlService.query(
    `SELECT n.value AS requested, o.name, RTRIM(o.type) AS type, o.type_desc AS typeDesc,
            OBJECT_SCHEMA_NAME(o.parent_object_id) + '.' + OBJECT_NAME(o.parent_object_id) AS parentObject
       FROM STRING_SPLIT(@names, ',') n
       LEFT JOIN sys.objects o ON o.object_id = OBJECT_ID(n.value)`,
    { names: { type: sql.NVarChar(sql.MAX), value: unique.join(',') } },
    runner,
  );
  for (const row of r.recordset) {
    map.set(key(row.requested), row.name
      ? { exists: true, type: row.type, typeDesc: row.typeDesc, parentObject: row.parentObject }
      : { exists: false });
  }
  return map;
}

// Lỗi cấp DB của một case: object chưa tạo hoặc sai loại.
function objectIssues(c, info) {
  const issues = [];
  const check = (name, label, types) => {
    const o = info.get(key(name));
    if (!o || !o.exists) {
      issues.push({ level: 'fail', code: 'missing-object', message: `${label} ${name} chưa tồn tại trong database.` });
    } else if (!types.includes(o.type)) {
      issues.push({ level: 'fail', code: 'wrong-object-type', message: `${label} ${name} là ${o.typeDesc}, không đúng loại (${types.join('/')}).` });
    }
  };
  const kind = c.execute && c.execute.kind;
  if (c.objectName) check(c.objectName, 'Object', expectedObjectTypes(c.type, kind));
  if (c.execute && c.execute.name && (!c.objectName || key(c.execute.name) !== key(c.objectName))) {
    const types = kind === 'procedure' ? ['P', 'PC'] : expectedObjectTypes('function', kind);
    check(c.execute.name, 'execute.name', types);
  }
  return issues;
}

function objectNamesOf(cases) {
  return cases.flatMap((c) => [c.objectName, c.execute && c.execute.name]).filter(Boolean);
}

module.exports = { expectedObjectTypes, getObjectsInfo, objectIssues, objectNamesOf, objectKey: key };
