// Đọc file manifest JSON (có cache theo mtime để website nhận package mới mà không cần restart).
const fs = require('fs');
const { display, readText } = require('./paths');

const cache = new Map();

function readJsonFile(fullPath) {
  const shown = display(fullPath);
  let stat;
  try {
    stat = fs.statSync(fullPath);
  } catch (e) {
    return { path: shown, exists: false, data: null, error: null };
  }
  const key = `${stat.mtimeMs}:${stat.size}`;
  const hit = cache.get(fullPath);
  if (hit && hit.key === key) return hit.value;

  let value;
  try {
    const text = readText(fullPath);
    value = { path: shown, exists: true, data: JSON.parse(text), error: null };
  } catch (e) {
    value = { path: shown, exists: true, data: null, error: `JSON không hợp lệ: ${e.message}` };
  }
  cache.set(fullPath, { key, value });
  return value;
}

const fail = (message, code) => ({ level: 'fail', message, ...(code ? { code } : {}) });
const warn = (message) => ({ level: 'warn', message });
const nonEmptyString = (v) => typeof v === 'string' && v.trim().length > 0;

function unknownKeys(obj, allowed, label) {
  return Object.keys(obj)
    .filter((k) => !allowed.includes(k))
    .map((k) => warn(`${label}: thuộc tính "${k}" không được hỗ trợ, sẽ bị bỏ qua.`));
}

module.exports = { readJsonFile, fail, warn, nonEmptyString, unknownKeys };
