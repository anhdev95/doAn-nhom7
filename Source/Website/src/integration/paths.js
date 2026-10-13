// Vị trí các package tích hợp, tính tương đối từ Source/Website.
//   Source/Database/Processing/processing.manifest.json   (Tuyến)
//   Source/Reports/reports.manifest.json                    (Tuyến)
//   Source/Database/Security/                               (nhóm)
const fs = require('fs');
const path = require('path');

const SOURCE_DIR = path.resolve(__dirname, '../../..');
const DATABASE_DIR = path.join(SOURCE_DIR, 'Database');
const PROCESSING_DIR = path.join(DATABASE_DIR, 'Processing');
const PROCESSING_MANIFEST = path.join(PROCESSING_DIR, 'processing.manifest.json');
const REPORTS_DIR = path.join(SOURCE_DIR, 'Reports');
const REPORTS_MANIFEST = path.join(REPORTS_DIR, 'reports.manifest.json');

// Đường dẫn hiển thị cho người dùng: tương đối từ Source/, không lộ đường dẫn tuyệt đối của máy.
function display(fullPath) {
  return path.relative(SOURCE_DIR, fullPath).split(path.sep).join('/');
}

// Resolve một đường dẫn tương đối nằm TRONG baseDir; trả null nếu thoát ra ngoài (../) hoặc sai đuôi.
function resolveInside(baseDir, relPath, extensions) {
  if (typeof relPath !== 'string' || !relPath.trim() || path.isAbsolute(relPath)) return null;
  const full = path.resolve(baseDir, relPath);
  if (!full.startsWith(baseDir + path.sep)) return null;
  if (extensions && !extensions.includes(path.extname(full).toLowerCase())) return null;
  return full;
}

const resolveSql = (relPath) => resolveInside(DATABASE_DIR, relPath, ['.sql']);

function isFile(full) {
  try {
    return Boolean(full) && fs.statSync(full).isFile();
  } catch (e) {
    return false;
  }
}

// Đọc file text (SQL/JSON) theo BOM: SSMS hay lưu .sql dạng UTF-16 LE; mặc định UTF-8.
function readText(full) {
  const buf = fs.readFileSync(full);
  if (buf[0] === 0xff && buf[1] === 0xfe) return buf.subarray(2).toString('utf16le');
  if (buf[0] === 0xfe && buf[1] === 0xff) {
    const swapped = Buffer.from(buf.subarray(2));
    swapped.swap16();
    return swapped.toString('utf16le');
  }
  return buf.toString('utf8').replace(/^\uFEFF/, '');
}

module.exports = {
  SOURCE_DIR,
  DATABASE_DIR,
  PROCESSING_DIR,
  PROCESSING_MANIFEST,
  REPORTS_DIR,
  REPORTS_MANIFEST,
  display,
  resolveInside,
  resolveSql,
  isFile,
  readText,
};
