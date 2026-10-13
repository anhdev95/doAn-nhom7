// Kiểm tra nhanh toàn project: `npm run check`
//   1. Syntax check mọi file .js (src, scripts, public/js)
//   2. validate-integration --allow-pending (package Tuyến chưa có chỉ là WARN)
//   3. Smoke test chỉ đọc: khởi động app trên cổng ngẫu nhiên, gọi các trang + GET API (không POST, không ghi DB)
// Exit code 1 nếu có lỗi.
const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
let failed = 0;
const log = (ok, msg) => {
  if (!ok) failed += 1;
  console.log(`${ok ? '[PASS]' : '[FAIL]'} ${msg}`);
};

function jsFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) return jsFiles(full);
    return e.name.endsWith('.js') ? [full] : [];
  });
}

console.log('== 1. Syntax check ==');
for (const file of ['src', 'scripts', 'public/js'].flatMap((d) => jsFiles(path.join(ROOT, d)))) {
  const r = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (r.status !== 0) log(false, `${path.relative(ROOT, file)}\n${r.stderr}`);
}
log(failed === 0, 'Tất cả file .js hợp lệ cú pháp.');

console.log('\n== 2. validate-integration --allow-pending ==');
const v = spawnSync(process.execPath, [path.join(__dirname, 'validate-integration.js'), '--allow-pending'], { encoding: 'utf8' });
process.stdout.write(v.stdout);
log(v.status === 0, 'validate-integration không có FAIL.');

console.log('\n== 3. Smoke test (chỉ đọc) ==');
require('dotenv').config({ quiet: true, path: path.join(ROOT, '.env') });
const app = require('../src/app');
const { closePool } = require('../src/config/database');

const CASES = [
  // [path, status được chấp nhận, mô tả]
  ['/', [200], 'Trang Dashboard'],
  ['/tables', [200], 'Trang Database Tables'],
  ['/processing', [200], 'Trang Processing'],
  ['/reports', [200], 'Trang Reports'],
  ['/security', [200], 'Trang Security'],
  ['/khong-ton-tai', [404], 'Trang 404'],
  ['/api/health', [200], 'GET /api/health'],
  ['/api/dashboard', [200, 503], 'GET /api/dashboard (503 nếu mất kết nối DB)'],
  ['/api/tables', [200], 'GET /api/tables'],
  ['/api/tables/NHANVIEN?pageSize=5', [200, 403, 404, 503], 'GET /api/tables/NHANVIEN (404 nếu bảng chưa tạo, 403 nếu thiếu quyền, 503 nếu mất DB)'],
  ['/api/tables/INVALID_TABLE', [400], 'GET /api/tables/INVALID_TABLE'],
  ['/api/tables/INVALID_TABLE/export.csv', [400], 'Export CSV bảng ngoài whitelist'],
  ['/api/processing', [200], 'GET /api/processing'],
  ['/api/processing/SP01', [200, 503], 'GET /api/processing/SP01'],
  ['/api/processing/INVALID', [404], 'GET /api/processing/INVALID'],
  ['/api/reports', [200], 'GET /api/reports'],
  ['/report-assets/..%2F..%2F.env', [404], 'Report asset path traversal'],
  ['/api/security/status', [200, 503], 'GET /api/security/status'],
  ['/api/khong-ton-tai', [404], 'API không tồn tại'],
];

const server = app.listen(0, async () => {
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [p, allowed, label] of CASES) {
    try {
      const res = await fetch(base + p);
      const text = await res.text();
      const leak = /DB_PASSWORD|password\s*[:=]\s*["'][^"']+/i.test(text) || (process.env.DB_PASSWORD && text.includes(process.env.DB_PASSWORD));
      log(allowed.includes(res.status) && !leak, `${label} → ${res.status}${leak ? ' (LỘ CREDENTIAL!)' : ''}`);
    } catch (e) {
      log(false, `${label} → ${e.message}`);
    }
  }
  server.close();
  await closePool().catch(() => {});
  console.log(`\n${failed ? `${failed} lỗi` : 'Tất cả kiểm tra đạt.'}`);
  process.exit(failed ? 1 : 0);
});
