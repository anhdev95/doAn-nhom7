// Loader + validator cho Source/Database/Processing/processing.manifest.json (package của Tuyến).
// Website và scripts/validate-integration.js dùng chung module này.
// Không có SQL nghiệp vụ ở đây: chỉ kiểm tra cấu trúc package.
const { getTable } = require('../config/tables');
const { PARAM_TYPE_NAMES, convertParam } = require('./params');
const { PROCESSING_MANIFEST, resolveSql, isFile, readText } = require('./paths');
const { readJsonFile, fail, warn, nonEmptyString, unknownKeys } = require('./manifest.util');

// 15 case bắt buộc theo đề: 5 SP, 5 Trigger, 3 Function, 2 Cursor.
const EXPECTED = [
  ...[1, 2, 3, 4, 5].map((n) => ({ id: `SP0${n}`, type: 'procedure' })),
  ...[1, 2, 3, 4, 5].map((n) => ({ id: `TRG0${n}`, type: 'trigger' })),
  ...[1, 2, 3].map((n) => ({ id: `FN0${n}`, type: 'function' })),
  ...[1, 2].map((n) => ({ id: `CUR0${n}`, type: 'cursor' })),
];
const TYPES = ['procedure', 'trigger', 'function', 'cursor'];
const EXECUTE_KINDS = ['procedure', 'scalar-function', 'table-function', 'script'];
// execute.kind được phép theo loại case.
const KINDS_BY_TYPE = {
  procedure: ['procedure', 'script'],
  trigger: ['script'],
  function: ['scalar-function', 'table-function', 'script'],
  cursor: ['script', 'procedure'],
};
// Case bắt buộc có objectName (cursor có thể chỉ là script testcase).
const OBJECT_REQUIRED = ['procedure', 'trigger', 'function'];

const SAFE_IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;
const SAFE_OBJECT_NAME = /^([A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*$/;
const CASE_KEYS = ['id', 'type', 'title', 'description', 'objectName', 'sourceFile', 'relatedTables', 'execute'];
const EXECUTE_KEYS = ['kind', 'name', 'file', 'transaction', 'params'];
const PARAM_KEYS = ['name', 'type', 'label', 'required', 'default'];

const normalizeObjectName = (name) => (name.includes('.') ? name : `dbo.${name}`).toLowerCase();

function checkSqlFile(relPath, label, issues) {
  if (!nonEmptyString(relPath)) {
    issues.push(fail(`${label} chưa khai báo.`));
    return null;
  }
  const full = resolveSql(relPath);
  if (!full) {
    issues.push(fail(`${label} "${relPath}" không hợp lệ (phải là file .sql nằm trong Source/Database).`));
    return null;
  }
  if (!isFile(full)) {
    issues.push(fail(`${label} "${relPath}" không tồn tại.`, 'missing-file'));
    return null;
  }
  return full;
}

function validateParams(params, ex, scriptText, issues) {
  if (params === undefined) return [];
  if (!Array.isArray(params)) {
    issues.push(fail('execute.params phải là mảng.'));
    return [];
  }
  const seen = new Set();
  const out = [];
  params.forEach((p, i) => {
    const label = `execute.params[${i}]`;
    if (!p || typeof p !== 'object' || Array.isArray(p)) {
      issues.push(fail(`${label} phải là object.`));
      return;
    }
    issues.push(...unknownKeys(p, PARAM_KEYS, label));
    if (!SAFE_IDENTIFIER.test(p.name || '')) issues.push(fail(`${label}.name "${p.name}" không hợp lệ (không có @, chỉ chữ/số/_).`));
    else if (seen.has(p.name.toLowerCase())) issues.push(fail(`${label}.name "${p.name}" bị trùng.`));
    else seen.add(p.name.toLowerCase());
    if (!PARAM_TYPE_NAMES.includes(p.type)) issues.push(fail(`${label}.type "${p.type}" không hỗ trợ (cho phép: ${PARAM_TYPE_NAMES.join(', ')}).`));
    if (p.label !== undefined && typeof p.label !== 'string') issues.push(fail(`${label}.label phải là chuỗi.`));
    if (p.required !== undefined && typeof p.required !== 'boolean') issues.push(fail(`${label}.required phải là true/false.`));
    if (p.default !== undefined && p.default !== null && PARAM_TYPE_NAMES.includes(p.type)) {
      try { convertParam({ ...p, required: false }, p.default); } catch (e) { issues.push(fail(`${label}.default: ${e.message}`)); }
    }
    if (scriptText !== null && SAFE_IDENTIFIER.test(p.name || '') && !new RegExp(`@${p.name}\\b`, 'i').test(scriptText)) {
      issues.push(warn(`${label}: script testcase không dùng @${p.name}.`));
    }
    out.push({
      name: p.name,
      type: p.type,
      label: nonEmptyString(p.label) ? p.label : p.name,
      required: p.required === true,
      default: p.default === undefined ? null : p.default,
    });
  });
  return out;
}

function validateExecute(ex, type, objectName, issues) {
  if (!ex || typeof ex !== 'object' || Array.isArray(ex)) {
    issues.push(fail('execute chưa khai báo (cần để nút Execute hoạt động).'));
    return null;
  }
  issues.push(...unknownKeys(ex, EXECUTE_KEYS, 'execute'));
  if (!EXECUTE_KINDS.includes(ex.kind)) {
    issues.push(fail(`execute.kind "${ex.kind}" không hợp lệ (cho phép: ${EXECUTE_KINDS.join(', ')}).`));
    return null;
  }
  if (KINDS_BY_TYPE[type] && !KINDS_BY_TYPE[type].includes(ex.kind)) {
    issues.push(fail(`execute.kind "${ex.kind}" không dùng cho ${type} (cho phép: ${KINDS_BY_TYPE[type].join(', ')}).`));
  }
  if (ex.transaction !== undefined && typeof ex.transaction !== 'boolean') issues.push(fail('execute.transaction phải là true/false.'));

  let scriptText = null;
  if (ex.kind === 'script') {
    const full = checkSqlFile(ex.file, 'execute.file', issues);
    if (full) scriptText = readText(full);
  } else if (!nonEmptyString(ex.name) || !SAFE_OBJECT_NAME.test(ex.name)) {
    issues.push(fail(`execute.name "${ex.name}" không hợp lệ (dạng dbo.TenObject).`));
  } else if (objectName && SAFE_OBJECT_NAME.test(objectName) && normalizeObjectName(ex.name) !== normalizeObjectName(objectName)) {
    issues.push(warn(`execute.name "${ex.name}" khác objectName "${objectName}".`));
  }

  return {
    kind: ex.kind,
    name: ex.kind === 'script' ? null : ex.name || null,
    file: ex.kind === 'script' ? ex.file || null : null,
    transaction: ex.transaction !== false,
    params: validateParams(ex.params, ex, scriptText, issues),
  };
}

function validateRelatedTables(list, issues) {
  if (list === undefined || (Array.isArray(list) && !list.length)) {
    issues.push(warn('relatedTables trống: trang demo sẽ không có dữ liệu trước/sau.'));
    return [];
  }
  if (!Array.isArray(list)) {
    issues.push(fail('relatedTables phải là mảng.'));
    return [];
  }
  const out = [];
  list.forEach((t, i) => {
    const name = typeof t === 'string' ? t : t && t.table;
    const pageSize = t && typeof t === 'object' ? t.pageSize : undefined;
    const table = getTable(name);
    if (!table || table.name !== name) {
      issues.push(fail(`relatedTables[${i}] "${name}" không thuộc 16 bảng contract (viết HOA đúng tên bảng).`));
      return;
    }
    if (pageSize !== undefined && !(Number.isInteger(pageSize) && pageSize >= 1 && pageSize <= 500)) {
      issues.push(fail(`relatedTables[${i}].pageSize phải là số nguyên 1–500.`));
      return;
    }
    if (out.some((x) => x.table === name)) {
      issues.push(warn(`relatedTables: "${name}" bị lặp.`));
      return;
    }
    out.push({ table: name, pageSize: pageSize || 50 });
  });
  return out;
}

function validateCase(raw, expectedType) {
  const issues = [];
  issues.push(...unknownKeys(raw, CASE_KEYS, raw.id));
  if (raw.type !== expectedType) issues.push(fail(`type phải là "${expectedType}" (đang là "${raw.type}").`));
  if (!nonEmptyString(raw.title)) issues.push(fail('title (tên bài toán) chưa có.'));
  if (!nonEmptyString(raw.description)) issues.push(fail('description (mô tả bài toán) chưa có.'));

  let objectName = null;
  if (raw.objectName === undefined || raw.objectName === null || raw.objectName === '') {
    if (OBJECT_REQUIRED.includes(expectedType)) issues.push(fail(`objectName bắt buộc với ${expectedType}.`));
  } else if (typeof raw.objectName !== 'string' || !SAFE_OBJECT_NAME.test(raw.objectName)) {
    issues.push(fail(`objectName "${raw.objectName}" không hợp lệ (dạng dbo.TenObject).`));
  } else {
    objectName = raw.objectName;
  }

  checkSqlFile(raw.sourceFile, 'sourceFile', issues);
  const relatedTables = validateRelatedTables(raw.relatedTables, issues);
  const execute = validateExecute(raw.execute, expectedType, objectName, issues);

  return {
    id: raw.id,
    type: expectedType,
    declared: true,
    title: nonEmptyString(raw.title) ? raw.title : null,
    description: nonEmptyString(raw.description) ? raw.description : null,
    objectName,
    sourceFile: typeof raw.sourceFile === 'string' ? raw.sourceFile : null,
    relatedTables,
    execute,
    issues,
  };
}

const pendingCase = ({ id, type }) => ({
  id, type, declared: false, title: null, description: null, objectName: null, sourceFile: null, relatedTables: [], execute: null, issues: [],
});

// Trả về đủ 15 case (case chưa khai báo = pending) + lỗi cấp manifest.
function loadProcessingManifest() {
  const file = readJsonFile(PROCESSING_MANIFEST);
  const manifest = { path: file.path, exists: file.exists, error: file.error };
  const issues = [];
  const byId = new Map();

  if (file.exists && !file.error) {
    const data = file.data;
    if (!Array.isArray(data)) {
      manifest.error = 'Manifest phải là một mảng JSON các case.';
    } else {
      data.forEach((raw, i) => {
        if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
          issues.push(fail(`Phần tử [${i}] phải là object.`));
          return;
        }
        const slot = EXPECTED.find((e) => e.id === raw.id);
        if (!slot) {
          issues.push(fail(`Phần tử [${i}]: id "${raw.id}" không hợp lệ (cho phép SP01–SP05, TRG01–TRG05, FN01–FN03, CUR01–CUR02).`));
          return;
        }
        if (byId.has(raw.id)) {
          issues.push(fail(`id "${raw.id}" bị trùng (phần tử [${i}]).`));
          byId.get(raw.id).issues.push(fail(`id bị khai báo nhiều lần trong manifest.`));
          return;
        }
        byId.set(raw.id, validateCase(raw, slot.type));
      });
      const missing = EXPECTED.filter((e) => !byId.has(e.id)).map((e) => e.id);
      if (missing.length) issues.push(fail(`Thiếu ${missing.length}/15 case: ${missing.join(', ')}.`));
      for (const type of TYPES) {
        const want = EXPECTED.filter((e) => e.type === type).length;
        const got = [...byId.values()].filter((c) => c.type === type).length;
        if (got !== want) issues.push(fail(`Cần đúng ${want} ${type}, manifest có ${got}.`));
      }
    }
  }

  const cases = EXPECTED.map((slot) => byId.get(slot.id) || pendingCase(slot));
  return { manifest, issues, cases };
}

module.exports = { EXPECTED, KINDS_BY_TYPE, loadProcessingManifest, SAFE_OBJECT_NAME };
