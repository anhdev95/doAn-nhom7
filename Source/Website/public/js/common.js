// Tiện ích dùng chung cho mọi trang: gọi API, navbar, trạng thái DB, render bảng.
const NAV = [
  ['/', 'Dashboard'],
  ['/tables', 'Database Tables'],
  ['/processing', 'Processing'],
  ['/reports', 'Reports'],
  ['/security', 'Security'],
];

function esc(value) {
  if (value === null || value === undefined) return '';
  return String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

async function api(url, options = {}) {
  const opts = { ...options, headers: { 'Content-Type': 'application/json', ...(options.headers || {}) } };
  let res;
  try {
    res = await fetch(url, opts);
  } catch (e) {
    return { ok: false, error: { kind: 'network', message: 'Không gọi được web server. Server Node.js có đang chạy?' } };
  }
  try {
    return await res.json();
  } catch (e) {
    return { ok: false, error: { kind: 'server', message: `HTTP ${res.status}` } };
  }
}

function errorBox(error, title = 'Lỗi') {
  if (!error) return '';
  const code = [error.code, error.number].filter(Boolean).join(' / ');
  return `<div class="alert alert-danger mb-2">
    <div class="fw-semibold">${esc(title)}${code ? ` <span class="badge text-bg-danger">${esc(code)}</span>` : ''}</div>
    <div class="small">${esc(error.message)}</div>
    ${error.hint ? `<div class="small mt-1"><strong>Gợi ý:</strong> ${esc(error.hint)}</div>` : ''}
  </div>`;
}

function pendingBox(text) {
  return `<div class="alert alert-secondary mb-2 small"><span class="badge text-bg-secondary me-1">Pending</span>${esc(text)}</div>`;
}

const loadingHtml = (text = 'Đang tải từ SQL Server…') =>
  `<div class="text-muted small d-flex align-items-center gap-2"><span class="spinner-border spinner-border-sm"></span>${esc(text)}</div>`;

// Nhóm trạng thái thống nhất trên toàn website: Ready · Pending · Missing · Error.
const STATUS_GROUPS = {
  ready: ['success', 'Ready'],
  pending: ['secondary', 'Pending'],
  'missing-file': ['warning', 'Missing'],
  'missing-object': ['warning', 'Missing'],
  missing: ['warning', 'Missing'],
  'config-error': ['danger', 'Error'],
  'wrong-object-type': ['danger', 'Error'],
  unknown: ['danger', 'Error'],
  error: ['danger', 'Error'],
};
const STATUS_DETAIL = {
  'missing-file': 'thiếu file',
  'missing-object': 'chưa có object trong DB',
  'config-error': 'lỗi manifest',
  'wrong-object-type': 'sai loại object',
  unknown: 'không kiểm tra được DB',
};
function statusBadge(code, withDetail = false) {
  const [color, label] = STATUS_GROUPS[code] || ['danger', 'Error'];
  const detail = withDetail && STATUS_DETAIL[code] ? ` · ${STATUS_DETAIL[code]}` : '';
  return `<span class="badge text-bg-${color}">${label}${esc(detail)}</span>`;
}

function issuesList(issues) {
  if (!issues || !issues.length) return '';
  return `<ul class="small mb-2 ps-3">${issues.map((i) => `<li class="${i.level === 'fail' ? 'text-danger' : 'text-warning-emphasis'}">
    <span class="badge ${i.level === 'fail' ? 'text-bg-danger' : 'text-bg-warning'}">${i.level === 'fail' ? 'FAIL' : 'WARN'}</span> ${esc(i.message)}</li>`).join('')}</ul>`;
}

// Banner trạng thái file manifest (chưa có / JSON lỗi / có lỗi cấp manifest).
function manifestBanner(manifest, issues, ownerText) {
  if (!manifest) return '';
  if (!manifest.exists) return pendingBox(`Chưa có ${manifest.path} – ${ownerText}.`);
  if (manifest.error) return `<div class="alert alert-danger small mb-2"><span class="badge text-bg-danger me-1">Error</span><code>${esc(manifest.path)}</code>: ${esc(manifest.error)}</div>`;
  if (issues && issues.length) return `<div class="alert alert-warning small mb-2"><div class="fw-semibold mb-1"><code>${esc(manifest.path)}</code> có vấn đề:</div>${issuesList(issues)}</div>`;
  return `<div class="small text-muted mb-2">Nguồn: <code>${esc(manifest.path)}</code></div>`;
}

// pk: tên cột PK, hoặc mảng tên cột nếu là PK kép (vd. ['MaDG', 'STT']).
function rowKey(row, pk) { return Array.isArray(pk) ? pk.map((c) => String(row[c])).join('|') : String(row[pk]); }
function pkLabel(pk) { return Array.isArray(pk) ? pk.join(', ') : pk; }

// data: { columns: [{name,type}], rows: [{...}] }
// opts.changedKeys: Set khóa (rowKey) được tô màu; opts.pk: cột PK.
function renderTable(data, opts = {}) {
  if (!data || !data.columns || !data.columns.length) return '<div class="text-muted small">(không có cột)</div>';
  const head = data.columns.map((c) => `<th title="${esc(c.type || '')}">${esc(c.name)}</th>`).join('');
  const body = data.rows.length
    ? data.rows.map((row) => {
      const key = opts.pk ? rowKey(row, opts.pk) : null;
      const cls = key && opts.changedKeys && opts.changedKeys.has(key) ? ' class="table-warning"' : '';
      return `<tr${cls}>${data.columns.map((c) => {
        const v = row[c.name];
        return v === null ? '<td class="text-muted fst-italic">NULL</td>' : `<td>${esc(v)}</td>`;
      }).join('')}</tr>`;
    }).join('')
    : `<tr><td colspan="${data.columns.length}" class="text-muted text-center">(0 dòng)</td></tr>`;
  return `<div class="table-responsive data-table"><table class="table table-sm table-bordered table-hover mb-0">
    <thead class="table-light"><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function renderNav() {
  const el = document.getElementById('app-nav');
  if (!el) return;
  const path = location.pathname;
  el.innerHTML = `<nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
    <div class="container-fluid">
      <a class="navbar-brand fw-semibold" href="/">IE103 · Nhóm 7 · HRM</a>
      <span class="db-status badge text-bg-secondary d-lg-none ms-auto me-2 text-truncate" style="max-width:55vw" title="Trạng thái kết nối SQL Server">DB: đang kiểm tra…</span>
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navMain" aria-label="Menu"><span class="navbar-toggler-icon"></span></button>
      <div class="collapse navbar-collapse" id="navMain">
        <ul class="navbar-nav me-auto">
          ${NAV.map(([href, label]) => `<li class="nav-item"><a class="nav-link${href === path ? ' active' : ''}" href="${href}">${label}</a></li>`).join('')}
        </ul>
        <span class="db-status badge text-bg-secondary d-none d-lg-inline-block text-truncate" style="max-width:40vw" title="Trạng thái kết nối SQL Server">DB: đang kiểm tra…</span>
      </div>
    </div>
  </nav>
  <div id="db-alert" class="container-fluid"></div>`;
}

// Kiểm tra kết nối DB, hiển thị badge + cảnh báo khi mất kết nối.
async function checkDb() {
  const badges = document.querySelectorAll('.db-status');
  const alertBox = document.getElementById('db-alert');
  const set = (color, text) => badges.forEach((b) => {
    b.className = b.className.replace(/text-bg-\w+/, `text-bg-${color}`);
    b.textContent = text;
  });
  const h = await api('/api/health');
  if (h.connected) {
    set('success', `Connected · ${h.server.databaseName} · ${h.server.loginName}`);
    alertBox.innerHTML = '';
  } else {
    set('danger', 'Disconnected');
    const c = h.connection || {};
    alertBox.innerHTML = errorBox(h.error, `Không kết nối được SQL Server (${c.server || '?'}:${c.port || '?'} / ${c.database || '?'})`);
  }
  return h;
}

// "x/y Ready": xanh khi đủ, xám khi chưa đủ.
function readyCount(ready, total) {
  return `<span class="badge text-bg-${ready === total ? 'success' : 'light border text-dark'}">${ready}/${total} Ready</span>`;
}

document.addEventListener('DOMContentLoaded', () => {
  renderNav();
  window.dbHealth = checkDb();
});
