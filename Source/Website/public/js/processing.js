// Processing Demo theo các bước B1–B5 (FinalProject_Note_2026):
// B1 bài toán · B2 câu SQL · B3 dữ liệu trước · B4 nút thực thi · B5 output + dữ liệu sau.
const TYPE_LABEL = { procedure: 'Stored Procedure', trigger: 'Trigger', function: 'Function', cursor: 'Cursor' };
const OWNER = 'chờ bàn giao package Xử lý thông tin (Source/Database/Processing)';

let current = null; // chi tiết case đang mở

function rowKey(row, pk) { return String(row[pk]); }

// Tô màu dòng thêm mới/thay đổi giữa dữ liệu trước và sau (so theo PK).
function diffKeys(before, after) {
  const changed = new Set();
  if (!before || !after || before.error || after.error) return { changed, removed: [] };
  const old = new Map(before.rows.map((r) => [rowKey(r, after.pk), JSON.stringify(r)]));
  for (const r of after.rows) {
    const k = rowKey(r, after.pk);
    if (old.get(k) !== JSON.stringify(r)) changed.add(k);
  }
  const now = new Set(after.rows.map((r) => rowKey(r, after.pk)));
  // Trang chỉ chứa N dòng có PK lớn nhất: dòng cũ bị đẩy khỏi trang không phải là bị xóa.
  const pageFull = after.rows.length >= after.pageSize;
  const minShown = Math.min(...after.rows.map((r) => Number(r[after.pk])));
  const removed = [...old.keys()].filter((k) => !now.has(k) && (!pageFull || Number(k) >= minShown));
  return { changed, removed };
}

function renderRelated(list, compareWith) {
  if (!list || !list.length) return pendingBox('Case chưa khai báo bảng liên quan (relatedTables).');
  return list.map((t, i) => {
    if (t.error) return errorBox(t.error, `Bảng ${t.table}`);
    const { changed, removed } = compareWith ? diffKeys(compareWith[i], t) : { changed: new Set(), removed: [] };
    const note = compareWith
      ? `<span class="small ms-2">${changed.size ? `<span class="badge text-bg-warning">${changed.size} dòng thêm/sửa</span>` : ''}
         ${removed.length ? `<span class="badge text-bg-danger">${removed.length} dòng bị xóa (${t.pk} = ${removed.map(esc).join(', ')})</span>` : ''}
         ${!changed.size && !removed.length ? '<span class="badge text-bg-light text-dark border">không thay đổi</span>' : ''}</span>`
      : '';
    return `<div class="mb-3"><div class="small mb-1"><code>${esc(t.table)}</code> – ${t.total} dòng (hiển thị ${t.rows.length} dòng mới nhất theo ${esc(t.pk)})${note}</div>
      ${renderTable(t, { pk: t.pk, changedKeys: changed })}</div>`;
  }).join('');
}

function renderSqlSection(c) {
  const parts = [];
  if (c.definition) {
    parts.push(`<div class="small text-muted mb-1">Definition đọc trực tiếp từ SQL Server: <code>${esc(c.objectName)}</code> (${esc(c.definition.typeDesc)}, sửa lần cuối ${esc(c.definition.modifyDate)})</div>
      <pre class="sql-code">${esc(c.definition.definition || '(không đọc được definition – object có thể bị mã hóa hoặc login thiếu quyền VIEW DEFINITION)')}</pre>`);
  } else if (c.objectName) {
    const hint = c.status.code === 'missing-object' ? 'chưa tồn tại trong database – chạy script của Tuyến trong SSMS.'
      : 'chưa hiển thị vì case chưa Ready – xem vấn đề ở đầu trang.';
    parts.push(`<div class="alert alert-warning small">${statusBadge(c.status.code, true)} Object <code>${esc(c.objectName)}</code> ${hint}</div>`);
  }
  if (c.scriptSql !== null && c.execute) parts.push(`<div class="small text-muted mb-1">Testcase: <code>Source/Database/${esc(c.execute.file)}</code></div><pre class="sql-code">${esc(c.scriptSql)}</pre>`);
  if (c.sourceSql !== null && c.sourceFile) parts.push(`<details><summary class="small">File nguồn <code>Source/Database/${esc(c.sourceFile)}</code></summary><pre class="sql-code">${esc(c.sourceSql)}</pre></details>`);
  return parts.join('') || pendingBox(OWNER);
}

function renderExecuteForm(c) {
  if (c.status.code !== 'ready') {
    return c.status.code === 'pending'
      ? pendingBox(`Chưa có case ${c.id} – ${OWNER}.`)
      : `<div class="alert alert-warning small mb-0">${statusBadge(c.status.code, true)} Chưa thể thực thi – xem vấn đề ở đầu trang.</div>`;
  }
  const params = c.execute.params.map((p) => `
    <div class="col-sm-6 col-lg-4"><label class="form-label small mb-1">${esc(p.label)} <code>@${esc(p.name)}</code> <span class="text-muted">${esc(p.type)}</span>${p.required ? ' <span class="text-danger">*</span>' : ''}</label>
      <input class="form-control form-control-sm" name="${esc(p.name)}" value="${esc(p.default ?? '')}" ${p.required ? 'required' : ''}
        ${p.type === 'Date' ? 'type="date"' : p.type === 'Time' ? 'type="time" step="1"' : ['Int', 'BigInt', 'Decimal'].includes(p.type) ? `type="number" step="${p.type === 'Decimal' ? '0.01' : '1'}"` : ''}></div>`).join('');
  return `<form id="exec-form" class="row g-2 align-items-end" novalidate>
      <div class="col-12 small text-muted">Cách thực thi: <code>${esc(c.execute.kind)}</code> ${c.execute.kind === 'script' ? `· file <code>${esc(c.execute.file)}</code>` : `· <code>${esc(c.execute.name)}</code>`}</div>
      ${params || '<div class="col-12 small text-muted">Không có tham số.</div>'}
      <div class="col-12 d-flex flex-wrap gap-3 align-items-center mt-2">
        ${c.execute.transaction
    ? `<div class="form-check form-switch mb-0"><input class="form-check-input" type="checkbox" id="exec-commit">
            <label class="form-check-label small" for="exec-commit">Lưu thay đổi (COMMIT). Tắt = chạy thử, ROLLBACK sau khi đọc dữ liệu sau.</label></div>`
    : '<span class="small text-warning-emphasis">Object tự quản lý transaction → luôn COMMIT.</span>'}
        <button class="btn btn-primary btn-sm ms-auto" type="submit">▶ Execute</button>
      </div>
    </form>`;
}

function renderResults(r) {
  const parts = [`<div class="small mb-2">Chế độ: <span class="badge text-bg-${r.mode === 'commit' ? 'danger' : 'secondary'}">${r.mode.toUpperCase()}</span> · ${r.durationMs} ms</div>`];
  if (r.executedSql) parts.push(`<details class="mb-2"><summary class="small">Câu lệnh đã gửi tới SQL Server</summary><pre class="sql-code">${esc(r.executedSql)}</pre></details>`);
  if (!r.ok) parts.push(errorBox(r.executionError, 'SQL Server trả về lỗi'));
  if (r.messages && r.messages.length) parts.push(`<div class="small fw-semibold">Messages (PRINT/RAISERROR mức thông tin)</div><pre class="sql-code">${esc(r.messages.join('\n'))}</pre>`);
  (r.results || []).forEach((res, i) => {
    const meta = [`rowsAffected: [${res.rowsAffected.join(', ')}]`];
    if (res.returnValue !== null) meta.push(`returnValue: ${esc(res.returnValue)}`);
    if (Object.keys(res.output).length) meta.push(`output: ${esc(JSON.stringify(res.output))}`);
    parts.push(`<div class="small text-muted">${r.results.length > 1 ? `Batch ${i + 1} · ` : ''}${meta.join(' · ')}</div>`);
    res.recordsets.forEach((rs) => { parts.push(`<div class="mb-2">${renderTable(rs)}</div>`); });
  });
  return parts.join('');
}

async function openCase(id) {
  document.querySelectorAll('.case-item').forEach((el) => el.classList.toggle('active', el.dataset.id === id));
  const box = document.getElementById('proc-detail');
  box.innerHTML = loadingHtml();
  history.replaceState(null, '', `/processing#${id}`);
  const c = await api(`/api/processing/${encodeURIComponent(id)}`);
  if (!c.ok) { box.innerHTML = errorBox(c.error, `Không tải được case ${id}`); return; }
  current = c;

  const objStatus = !c.objectName ? '<span class="text-muted">—</span>'
    : c.object && c.object.exists ? `<span class="badge text-bg-success">Có trong DB</span> <span class="small text-muted">${esc(c.object.typeDesc)}</span>`
      : c.object ? statusBadge('missing-object', true) : '<span class="text-muted small">chưa kiểm tra</span>';
  box.innerHTML = `
    <div class="d-flex flex-wrap align-items-center gap-2 mb-2"><h5 class="mb-0">${esc(c.id)} · ${esc(TYPE_LABEL[c.type])}</h5>${statusBadge(c.status.code, true)}</div>
    ${issuesList(c.status.issues)}
    <div class="card mb-3"><div class="card-body">
      <div class="step-title">B1 · Bài toán</div>
      ${c.title ? `<div class="fw-semibold">${esc(c.title)}</div><div class="small mb-2" style="white-space:pre-line">${esc(c.description || '')}</div>` : pendingBox(OWNER)}
      <table class="table table-sm small mb-0 w-auto">
        <tr><th>ID</th><td>${esc(c.id)}</td><th class="ps-4">Loại</th><td>${esc(TYPE_LABEL[c.type])}</td></tr>
        <tr><th>Object</th><td>${c.objectName ? `<code>${esc(c.objectName)}</code>` : '—'}</td><th class="ps-4">Trạng thái object</th><td>${objStatus}</td></tr>
        <tr><th>Bảng liên quan</th><td colspan="3">${c.relatedTables.length ? c.relatedTables.map((t) => `<a href="/tables?t=${esc(t)}"><code>${esc(t)}</code></a>`).join(', ') : '—'}</td></tr>
      </table>
    </div></div>
    <div class="card mb-3"><div class="card-body"><div class="step-title mb-2">B2 · Câu truy vấn SQL</div>${renderSqlSection(c)}</div></div>
    <div class="card mb-3"><div class="card-body">
      <div class="d-flex"><div class="step-title mb-2">B3 · Dữ liệu trước khi thực thi</div>
        <button class="btn btn-link btn-sm ms-auto py-0" id="reload-before">Tải lại</button></div>
      <div id="before-box">${c.status.code === 'ready' ? renderRelated(c.before) : pendingBox('Hiển thị khi case ở trạng thái Ready.')}</div>
    </div></div>
    <div class="card mb-3"><div class="card-body"><div class="step-title mb-2">B4 · Thực thi</div>${renderExecuteForm(c)}</div></div>
    <div class="card mb-3"><div class="card-body"><div class="step-title mb-2">B5 · Output & dữ liệu sau</div>
      <div id="result-box" class="text-muted small">Chưa thực thi.</div>
      <div id="after-box" class="mt-3"></div>
    </div></div>`;

  document.getElementById('reload-before').addEventListener('click', () => openCase(id));
  const form = document.getElementById('exec-form');
  if (form) form.addEventListener('submit', (e) => { e.preventDefault(); execute(form); });
}

async function execute(form) {
  const btn = form.querySelector('button[type=submit]');
  const params = Object.fromEntries(new FormData(form).entries());
  const commitBox = document.getElementById('exec-commit');
  const mode = commitBox && commitBox.checked ? 'commit' : 'rollback';
  btn.disabled = true;
  document.getElementById('result-box').innerHTML = loadingHtml('Đang thực thi trên SQL Server…');
  document.getElementById('after-box').innerHTML = '';
  const r = await api(`/api/processing/${encodeURIComponent(current.id)}/execute`, {
    method: 'POST',
    body: JSON.stringify({ params, mode }),
  });
  btn.disabled = false;
  if (r.error && !r.executionError) {
    document.getElementById('result-box').innerHTML = errorBox(r.error, 'Không thực thi được');
    return;
  }
  document.getElementById('result-box').innerHTML = renderResults(r);
  document.getElementById('after-box').innerHTML = `<div class="small fw-semibold mb-1">Dữ liệu sau khi thực thi${r.mode === 'rollback' && r.ok ? ' (đọc trong transaction, trước khi ROLLBACK)' : ''}</div>${renderRelated(r.after, current.before)}`;
}

document.addEventListener('DOMContentLoaded', async () => {
  const list = document.getElementById('proc-list');
  list.innerHTML = `<div class="list-group-item">${loadingHtml()}</div>`;
  const d = await api('/api/processing');
  if (!d.ok) { list.innerHTML = ''; document.getElementById('proc-error').innerHTML = errorBox(d.error); return; }
  const ready = d.cases.filter((c) => c.status.code === 'ready').length;
  document.getElementById('proc-error').innerHTML = manifestBanner(d.manifest, d.manifestIssues, OWNER)
    + (d.dbError ? errorBox(d.dbError, 'Không kiểm tra được object trong DB') : '')
    + `<div class="small mb-2">${readyCount(ready, d.cases.length)} case sẵn sàng</div>`;

  list.innerHTML = Object.keys(TYPE_LABEL).map((type) => {
    const items = d.cases.filter((c) => c.type === type);
    return `<div class="list-group-item list-group-item-light fw-semibold">${TYPE_LABEL[type]} (${items.length})</div>` + items.map((c) => `
      <a href="#${esc(c.id)}" class="list-group-item list-group-item-action case-item" data-id="${esc(c.id)}">
        <div class="d-flex justify-content-between align-items-center"><span class="fw-semibold">${esc(c.id)}</span>${statusBadge(c.status.code)}</div>
        <div class="text-muted text-truncate">${c.title ? esc(c.title) : '(chưa có bài toán)'}</div>
      </a>`).join('');
  }).join('');

  list.addEventListener('click', (e) => {
    const a = e.target.closest('.case-item');
    if (!a) return;
    e.preventDefault();
    openCase(a.dataset.id);
  });
  const openFromHash = () => {
    const hash = location.hash.slice(1);
    if (hash && d.cases.some((c) => c.id === hash) && (!current || current.id !== hash)) openCase(hash);
  };
  window.addEventListener('hashchange', openFromHash);
  openFromHash();
});
