// Reports: hiển thị report thật của Tuyến theo Source/Reports/reports.manifest.json.
const OWNER = 'chờ bàn giao package Report (Source/Reports)';

function reportBody(r) {
  if (r.status === 'pending') return pendingBox(`Chưa có report ${r.id} – ${OWNER}.`);
  if (r.status !== 'ready') return `<div class="alert alert-${r.status === 'missing-file' ? 'warning' : 'danger'} small mb-0">${statusBadge(r.status, true)}${issuesList(r.issues)}</div>`;
  if (r.type === 'image') {
    return `<a href="${esc(r.url)}" target="_blank" rel="noopener" title="Mở ảnh kích thước đầy đủ">
      <img class="report-img" src="${esc(r.url)}" alt="${esc(r.title)}" loading="lazy"></a>`;
  }
  if (r.type === 'link') {
    return `<a class="btn btn-outline-primary btn-sm" href="${esc(r.url)}" target="_blank" rel="noopener noreferrer">Mở report ↗</a>
      <div class="small text-muted mt-1 text-break">${esc(r.url)}</div>`;
  }
  return `<div class="ratio ratio-16x9"><iframe class="report-frame" src="${esc(r.url)}" title="${esc(r.title)}"
      sandbox="allow-scripts allow-same-origin allow-popups allow-forms" referrerpolicy="no-referrer" loading="lazy" allowfullscreen></iframe></div>
    <a class="small" href="${esc(r.url)}" target="_blank" rel="noopener noreferrer">Mở trong tab mới ↗</a>`;
}

document.addEventListener('DOMContentLoaded', async () => {
  const box = document.getElementById('rep-list');
  box.innerHTML = loadingHtml('Đang đọc manifest…');
  const d = await api('/api/reports');
  if (!d.ok) { box.innerHTML = errorBox(d.error); return; }
  const ready = d.reports.filter((r) => r.status === 'ready').length;
  box.innerHTML = manifestBanner(d.manifest, d.manifestIssues, OWNER)
    + `<div class="small mb-3">${readyCount(ready, d.reports.length)} report</div>`
    + d.reports.map((r) => `<div class="card mb-3"><div class="card-body">
      <div class="d-flex flex-wrap align-items-center gap-2 mb-1"><h5 class="mb-0">${esc(r.id)}${r.title ? ` · ${esc(r.title)}` : ''}</h5>
        ${statusBadge(r.status, true)}${r.type ? `<span class="badge text-bg-light border text-dark">${esc(r.type)}</span>` : ''}</div>
      ${r.description ? `<div class="small mb-1">${esc(r.description)}</div>` : ''}
      ${r.dataSource ? `<div class="small text-muted mb-2">Nguồn dữ liệu (SQL Server): ${esc(r.dataSource)}</div>` : ''}
      ${r.status === 'ready' ? issuesList(r.issues) : ''}
      ${reportBody(r)}
    </div></div>`).join('');
});
