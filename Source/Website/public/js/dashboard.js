// Dashboard: mọi số liệu lấy từ GET /api/dashboard (truy vấn SQL Server mỗi lần tải trang).
const BOX_IDS = ['dash-server', 'dash-integration', 'dash-tables', 'dash-domains'];

function renderCards(cards) {
  const LABELS = { NHANVIEN: 'Nhân viên', PHONGBAN: 'Phòng ban', UNGVIEN: 'Ứng viên', DAOTAO: 'Khóa đào tạo' };
  return cards.map((c) => `
    <div class="col-6 col-lg-3"><div class="card h-100"><div class="card-body">
      <div class="text-muted small">${esc(LABELS[c.name])} <code>${esc(c.name)}</code></div>
      <div class="stat-value">${c.exists ? esc(c.total) : statusBadge('missing')}</div>
      <a class="small" href="/tables?t=${esc(c.name)}">Xem bảng →</a>
    </div></div></div>`).join('');
}

function renderServer(s) {
  return `<div class="mb-2"><span class="badge text-bg-success">Connected</span></div>
    <table class="table table-sm mb-0 small">
      <tr><th>Server</th><td>${esc(s.serverName)}</td></tr>
      <tr><th>SQL Server</th><td>${esc(s.productVersion)} – ${esc(s.edition)}</td></tr>
      <tr><th>Database</th><td>${esc(s.databaseName)}</td></tr>
      <tr><th>Login</th><td>${esc(s.loginName)}</td></tr>
      <tr><th>DB user</th><td>${esc(s.databaseUser)}</td></tr>
      <tr><th>Giờ server</th><td>${esc(s.serverTime)}</td></tr>
    </table>`;
}

function renderIntegration(i) {
  const row = (label, href, part, owner) => {
    const ready = part.byStatus.ready || 0;
    const groups = Object.entries(part.byStatus).filter(([k]) => k !== 'ready')
      .map(([k, n]) => `${statusBadge(k)} <span class="small">${n}</span>`).join(' ');
    return `<div class="mb-3">
      <div class="d-flex justify-content-between"><a href="${href}" class="fw-semibold">${label}</a><span class="small">${owner}</span></div>
      <div class="progress my-1" role="progressbar" style="height:8px"><div class="progress-bar bg-success" style="width:${(ready / part.total) * 100}%"></div></div>
      <div class="small">${readyCount(ready, part.total)} ${groups}</div>
      ${part.manifest.exists ? (part.manifest.error ? `<div class="small text-danger">Manifest lỗi: ${esc(part.manifest.error)}</div>` : '') : `<div class="small text-muted">Chưa có <code>${esc(part.manifest.path)}</code></div>`}
    </div>`;
  };
  return row('Processing (SP/Trigger/Function/Cursor)', '/processing', i.processing, 'Tuyến')
    + row('Reports', '/reports', i.reports, 'Tuyến')
    + '<a class="small" href="/security">Security (xác thực, phân quyền, backup…) →</a>';
}

function renderTables(tables, missing) {
  const note = missing.length
    ? `<div class="alert alert-warning small py-2">${statusBadge('missing')} Chưa có ${missing.length}/${tables.length} bảng: ${missing.map(esc).join(', ')}. Chạy script trong <code>Source/Database</code>.</div>`
    : `<div class="small text-success mb-2">Đủ ${tables.length} bảng.</div>`;
  return note + `<div class="row row-cols-2 row-cols-md-4 g-2">${tables.map((t) => `
    <div class="col"><a class="d-block border rounded p-2 bg-white text-decoration-none h-100" href="/tables?t=${esc(t.name)}">
      <div class="small text-muted text-truncate">${esc(t.label)}</div>
      <div class="d-flex justify-content-between align-items-center gap-1"><code class="text-truncate">${esc(t.name)}</code>
        <span class="fw-semibold text-body">${t.exists ? esc(t.total) : statusBadge('missing')}</span></div>
    </a></div>`).join('')}</div>`;
}

function renderDomains(domains) {
  return `<div class="row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3">${domains.map((d) => `
    <div class="col"><div class="small fw-semibold">${esc(d.label)}</div><div class="small text-muted mb-1"><code>${esc(d.table)}.${esc(d.column)}</code></div>
      ${d.available
    ? `<table class="table table-sm mb-0 small">${d.values.map((v) => `<tr><td>${esc(v.value)}</td><td class="text-end fw-semibold">${esc(v.count)}</td></tr>`).join('')}
         ${d.extra.map((v) => `<tr class="table-warning" title="Giá trị ngoài miền đã chốt"><td>${v.value === null ? '<i>NULL</i>' : esc(v.value)} ⚠</td><td class="text-end fw-semibold">${esc(v.count)}</td></tr>`).join('')}</table>`
    : `<div>${statusBadge('missing')} <span class="small">bảng/cột chưa tồn tại</span></div>`}
    </div>`).join('')}</div>`;
}

document.addEventListener('DOMContentLoaded', async () => {
  for (const id of BOX_IDS) document.getElementById(id).innerHTML = loadingHtml();
  const d = await api('/api/dashboard');
  if (!d.ok) {
    // Lỗi kết nối đã hiển thị ở banner chung phía trên; chỉ hiện lỗi khác ở đây.
    if (!d.error || d.error.kind !== 'connection') document.getElementById('dash-error').innerHTML = errorBox(d.error, 'Không tải được Dashboard');
    document.getElementById('dash-server').innerHTML = '<span class="badge text-bg-danger">Disconnected</span>';
    for (const id of BOX_IDS.slice(1)) document.getElementById(id).innerHTML = '<span class="text-muted small">Không có dữ liệu khi mất kết nối DB.</span>';
    return;
  }
  document.getElementById('dash-cards').innerHTML = renderCards(d.cards);
  document.getElementById('dash-server').innerHTML = renderServer(d.server);
  document.getElementById('dash-integration').innerHTML = renderIntegration(d.integration);
  document.getElementById('dash-tables').innerHTML = renderTables(d.tables, d.missingTables);
  document.getElementById('dash-domains').innerHTML = renderDomains(d.domains);
});
