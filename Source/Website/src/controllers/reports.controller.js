// Reports: đọc Source/Reports/reports.manifest.json mỗi request (website tự nhận package mới).
const { loadReportsManifest, findReportImage } = require('../integration/reports.manifest');

function list(req, res) {
  const { manifest, issues, reports } = loadReportsManifest();
  res.json({
    ok: true,
    manifest,
    manifestIssues: issues,
    reports: reports.map((r) => ({
      ...r,
      url: r.status !== 'ready' ? null : r.type === 'image' ? `/report-assets/${encodeURIComponent(r.src)}` : r.src,
    })),
  });
}

// Chỉ phục vụ file ảnh được manifest khai báo (type=image, file tồn tại trong Source/Reports).
function asset(req, res) {
  const full = findReportImage(req.params.file);
  if (!full) return res.status(404).type('text/plain').send('Report asset not found');
  res.set('X-Content-Type-Options', 'nosniff');
  return res.sendFile(full);
}

module.exports = { list, asset };
