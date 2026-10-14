// Generic table viewer: chỉ chọn được bảng trong whitelist do server trả về.
const state = { table: null, page: 1 };
const $ = (id) => document.getElementById(id);

async function loadTable() {
  const size = $('tbl-size').value;
  const order = $('tbl-order').value;
  $('tbl-content').innerHTML = loadingHtml();
  $('tbl-msg').innerHTML = '';
  history.replaceState(null, '', `/tables?t=${encodeURIComponent(state.table)}`);

  const d = await api(`/api/tables/${encodeURIComponent(state.table)}?page=${state.page}&pageSize=${size}&order=${order}`);
  if (!d.ok) {
    const missing = d.error && d.error.number === 208;
    $('tbl-content').innerHTML = (missing ? `<div class="mb-2">${statusBadge('missing')}</div>` : '') + errorBox(d.error, `Không đọc được bảng ${state.table}`);
    $('tbl-pages').innerHTML = '';
    $('tbl-info').textContent = '';
    $('tbl-export').disabled = true;
    return;
  }
  $('tbl-export').disabled = false;
  $('tbl-info').textContent = `${d.label} · ${d.total} dòng · trang ${d.page}/${d.totalPages} · sắp xếp theo ${pkLabel(d.pk)} ${d.order === 'desc' ? 'giảm dần' : 'tăng dần'}`;
  $('tbl-content').innerHTML = d.total ? renderTable(d) : `${renderTable(d)}<div class="small text-muted mt-1">Bảng chưa có dữ liệu.</div>`;

  const items = [];
  const add = (p, label, disabled, active) => items.push(
    `<li class="page-item${disabled ? ' disabled' : ''}${active ? ' active' : ''}"><a class="page-link" href="#" data-page="${p}">${label}</a></li>`);
  add(d.page - 1, '«', d.page <= 1);
  for (let p = Math.max(1, d.page - 3); p <= Math.min(d.totalPages, d.page + 3); p++) add(p, p, false, p === d.page);
  add(d.page + 1, '»', d.page >= d.totalPages);
  $('tbl-pages').innerHTML = items.join('');
}

// Export CSV: tải về qua fetch để hiển thị được lỗi (mất kết nối, bảng chưa tồn tại...).
async function exportCsv() {
  const btn = $('tbl-export');
  btn.disabled = true;
  $('tbl-msg').innerHTML = loadingHtml('Đang xuất CSV từ SQL Server…');
  try {
    const res = await fetch(`/api/tables/${encodeURIComponent(state.table)}/export.csv?order=${$('tbl-order').value}`);
    if (!res.ok) {
      const body = await res.json().catch(() => ({ error: { message: `HTTP ${res.status}` } }));
      $('tbl-msg').innerHTML = errorBox(body.error, 'Export thất bại');
      return;
    }
    const name = (/filename="([^"]+)"/.exec(res.headers.get('Content-Disposition') || '') || [])[1] || `${state.table}.csv`;
    const blob = await res.blob();
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: name });
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    $('tbl-msg').innerHTML = `<div class="alert alert-success small py-2">Đã xuất <code>${esc(name)}</code> – ${esc(res.headers.get('X-Row-Count'))} dòng.</div>`;
  } catch (e) {
    $('tbl-msg').innerHTML = errorBox({ message: 'Không gọi được web server.' }, 'Export thất bại');
  } finally {
    btn.disabled = false;
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  const select = $('tbl-select');
  const list = await api('/api/tables');
  if (!list.ok) {
    $('tbl-content').innerHTML = errorBox(list.error);
    return;
  }
  const groups = {};
  for (const t of list.tables) (groups[t.group] = groups[t.group] || []).push(t);
  select.innerHTML = Object.entries(groups).map(([g, ts]) =>
    `<optgroup label="${esc(g)}">${ts.map((t) => `<option value="${esc(t.name)}">${esc(t.name)} – ${esc(t.label)}</option>`).join('')}</optgroup>`).join('');

  const wanted = new URLSearchParams(location.search).get('t');
  if (wanted && list.tables.some((t) => t.name === wanted.toUpperCase())) select.value = wanted.toUpperCase();
  state.table = select.value;

  select.addEventListener('change', () => { state.table = select.value; state.page = 1; loadTable(); });
  $('tbl-size').addEventListener('change', () => { state.page = 1; loadTable(); });
  $('tbl-order').addEventListener('change', () => { state.page = 1; loadTable(); });
  $('tbl-reload').addEventListener('click', loadTable);
  $('tbl-export').addEventListener('click', exportCsv);
  $('tbl-pages').addEventListener('click', (e) => {
    const a = e.target.closest('[data-page]');
    if (!a) return;
    e.preventDefault();
    if (a.parentElement.classList.contains('disabled')) return;
    state.page = parseInt(a.dataset.page, 10);
    loadTable();
  });
  loadTable();
});
