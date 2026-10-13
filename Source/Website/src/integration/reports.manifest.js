// Loader + validator cho Source/Reports/reports.manifest.json (5 report của Tuyến).
const path = require('path');
const { REPORTS_DIR, REPORTS_MANIFEST, resolveInside, isFile } = require('./paths');
const { readJsonFile, fail, warn, nonEmptyString, unknownKeys } = require('./manifest.util');

const EXPECTED_IDS = ['R01', 'R02', 'R03', 'R04', 'R05'];
const REPORT_TYPES = ['image', 'link', 'embed'];
// Không cho SVG: file SVG mở trực tiếp có thể chạy script trên origin của website.
const IMAGE_EXTENSIONS = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
const REPORT_KEYS = ['id', 'title', 'description', 'type', 'src', 'dataSource'];

function isHttpsUrl(value) {
  try {
    return new URL(value).protocol === 'https:';
  } catch (e) {
    return false;
  }
}

// Ảnh phải là tên file nằm ngay trong Source/Reports (không có thư mục con, không ../).
function resolveImage(src) {
  if (!nonEmptyString(src) || src !== path.basename(src)) return null;
  return resolveInside(REPORTS_DIR, src, IMAGE_EXTENSIONS);
}

function validateReport(raw) {
  const issues = [...unknownKeys(raw, REPORT_KEYS, raw.id)];
  if (!nonEmptyString(raw.title)) issues.push(fail('title chưa có.'));
  if (!nonEmptyString(raw.description)) issues.push(warn('description chưa có.'));
  if (!nonEmptyString(raw.dataSource)) issues.push(fail('dataSource (bảng/view report sử dụng) chưa có.'));

  let status = 'ready';
  if (!REPORT_TYPES.includes(raw.type)) {
    issues.push(fail(`type "${raw.type}" không hợp lệ (cho phép: ${REPORT_TYPES.join(', ')}).`));
  } else if (raw.type === 'image') {
    const full = resolveImage(raw.src);
    if (!full) issues.push(fail(`src "${raw.src}" không hợp lệ: phải là tên file ${IMAGE_EXTENSIONS.join('/')} đặt trong Source/Reports.`));
    else if (!isFile(full)) {
      issues.push(fail(`Không tìm thấy file ảnh "${raw.src}" trong Source/Reports.`, 'missing-file'));
    }
  } else if (!isHttpsUrl(raw.src)) {
    issues.push(fail(`src phải là URL https:// hợp lệ cho type "${raw.type}".`));
  }

  const fails = issues.filter((i) => i.level === 'fail');
  if (fails.length) status = fails.every((i) => i.code === 'missing-file') ? 'missing-file' : 'config-error';

  return {
    id: raw.id,
    declared: true,
    title: nonEmptyString(raw.title) ? raw.title : null,
    description: nonEmptyString(raw.description) ? raw.description : null,
    type: REPORT_TYPES.includes(raw.type) ? raw.type : null,
    src: typeof raw.src === 'string' ? raw.src : null,
    dataSource: nonEmptyString(raw.dataSource) ? raw.dataSource : null,
    status,
    issues,
  };
}

const pendingReport = (id) => ({
  id, declared: false, title: null, description: null, type: null, src: null, dataSource: null, status: 'pending', issues: [],
});

function loadReportsManifest() {
  const file = readJsonFile(REPORTS_MANIFEST);
  const manifest = { path: file.path, exists: file.exists, error: file.error };
  const issues = [];
  const byId = new Map();

  if (file.exists && !file.error) {
    if (!Array.isArray(file.data)) {
      manifest.error = 'Manifest phải là một mảng JSON các report.';
    } else {
      file.data.forEach((raw, i) => {
        if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
          issues.push(fail(`Phần tử [${i}] phải là object.`));
          return;
        }
        if (!EXPECTED_IDS.includes(raw.id)) {
          issues.push(fail(`Phần tử [${i}]: id "${raw.id}" không hợp lệ (cho phép R01–R05).`));
          return;
        }
        if (byId.has(raw.id)) {
          issues.push(fail(`id "${raw.id}" bị trùng (phần tử [${i}]).`));
          const first = byId.get(raw.id);
          first.issues.push(fail('id bị khai báo nhiều lần trong manifest.'));
          first.status = 'config-error';
          return;
        }
        byId.set(raw.id, validateReport(raw));
      });
      const missing = EXPECTED_IDS.filter((id) => !byId.has(id));
      if (missing.length) issues.push(fail(`Thiếu ${missing.length}/5 report: ${missing.join(', ')}.`));
    }
  }

  const reports = EXPECTED_IDS.map((id) => byId.get(id) || pendingReport(id));
  return { manifest, issues, reports };
}

// Đường dẫn file ảnh hợp lệ cho route phục vụ asset: chỉ file được manifest khai báo, type=image, status ready.
function findReportImage(fileName) {
  const report = loadReportsManifest().reports.find((r) => r.type === 'image' && r.src === fileName && r.status === 'ready');
  return report ? resolveImage(report.src) : null;
}

module.exports = { EXPECTED_IDS, REPORT_TYPES, IMAGE_EXTENSIONS, loadReportsManifest, findReportImage };
