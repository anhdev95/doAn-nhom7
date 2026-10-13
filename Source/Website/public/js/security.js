// Security: trạng thái thật từ SQL Server + test đăng nhập/phân quyền.
// Không có nút tạo login/GRANT/backup/restore: các thao tác đó chạy bằng script thật của nhóm trong SSMS.
const $ = (id) => document.getElementById(id);

function queryBlock(q, emptyText) {
  if (!q.ok) return errorBox(q.error, 'Không đọc được (login website có thể thiếu quyền xem catalog/msdb)');
  return q.rows.length ? renderTable(q) : `<div class="small text-muted">${esc(emptyText)}</div>`;
}

const hasFiles = (files) => files.some((f) => f.exists);

function scriptsBlock(files) {
  return files.map((f) => (f.exists
    ? `<details class="mb-1"><summary class="small">${statusBadge('ready')} <code>Source/Database/${esc(f.path)}</code></summary>${f.content !== null ? `<pre class="sql-code">${esc(f.content)}</pre>` : '<div class="small text-muted">(file dữ liệu – không hiển thị nội dung)</div>'}</details>`
    : `<div class="small mb-1">${statusBadge('pending')} <code>Source/Database/${esc(f.path)}</code> – chờ nhóm cung cấp</div>`)).join('');
}

const card = (id, title, body) => `<div class="card mb-3" id="${id}"><div class="card-header fw-semibold">${title}</div><div class="card-body">${body}</div></div>`;
const steps = (items) => `<ol class="small mb-2">${items.map((s) => `<li>${s}</li>`).join('')}</ol>`;

function renderLoginResult(r) {
  if (!r.ok) return errorBox(r.error);
  if (!r.authenticated) return `<div class="alert alert-danger mb-2"><strong>✘ authenticated = false</strong> · login <code>${esc(r.username)}</code></div>${errorBox(r.error, 'Phản hồi của SQL Server')}`;
  const parts = [`<div class="alert alert-success mb-2"><strong>✔ authenticated = true</strong> · SQL login <code>${esc(r.identity.loginName)}</code> · DB user <code>${esc(r.identity.databaseUser)}</code> · DB <code>${esc(r.identity.databaseName)}</code></div>`];
  parts.push('<div class="small fw-semibold">Role membership (IS_ROLEMEMBER: 1 = thành viên, 0 = không, NULL = role chưa tồn tại)</div>', queryBlock(r.roleMembership, ''));
  parts.push('<div class="small fw-semibold mt-2">Permission matrix (HAS_PERMS_BY_NAME, 1 = có quyền)</div>', queryBlock(r.permissionMatrix, 'Database chưa có bảng nào trong 16 bảng contract.'));
  if (r.selectTry) {
    parts.push(`<div class="small fw-semibold mt-2">Thử SELECT trên <code>${esc(r.selectTry.table)}</code></div>`);
    parts.push(r.selectTry.allowed
      ? `<div class="small text-success mb-1">✔ SELECT allowed (${r.selectTry.data.total} dòng, hiển thị 5)</div>${renderTable(r.selectTry.data)}`
      : errorBox(r.selectTry.error, '✘ SELECT denied'));
  }
  return parts.join('');
}

// Import: chụp dữ liệu trước → chạy script import trong SSMS → so sánh dữ liệu sau (đều đọc từ SQL Server).
let snapshot = null;
async function takeSnapshot(compare) {
  const table = $('imp-table').value;
  const outBox = $('imp-result');
  outBox.innerHTML = loadingHtml();
  const d = await api(`/api/tables/${encodeURIComponent(table)}?pageSize=500&order=desc`);
  if (!d.ok) { outBox.innerHTML = errorBox(d.error, `Không đọc được ${table}`); return; }
  if (!compare || !snapshot || snapshot.table !== table) {
    snapshot = d;
    outBox.innerHTML = `<div class="small mb-1"><span class="badge text-bg-secondary">Trước</span> ${esc(table)}: ${d.total} dòng (lúc ${new Date().toLocaleTimeString()}). Chạy script import trong SSMS rồi bấm <strong>So sánh sau import</strong>.</div>${renderTable(d)}`;
    $('imp-compare').disabled = false;
    return;
  }
  const before = new Map(snapshot.rows.map((r) => [String(r[d.pk]), JSON.stringify(r)]));
  const changed = new Set(d.rows.filter((r) => before.get(String(r[d.pk])) !== JSON.stringify(r)).map((r) => String(r[d.pk])));
  outBox.innerHTML = `<div class="small mb-1"><span class="badge text-bg-secondary">Trước</span> ${snapshot.total} dòng → <span class="badge text-bg-primary">Sau</span> ${d.total} dòng
    · <span class="badge text-bg-warning">${changed.size} dòng thêm/sửa</span> (trong 500 dòng PK lớn nhất)</div>${renderTable(d, { pk: d.pk, changedKeys: changed })}`;
}

document.addEventListener('DOMContentLoaded', async () => {
  const box = $('sec-content');
  box.innerHTML = loadingHtml();
  const [d, tables] = await Promise.all([api('/api/security/status'), api('/api/tables')]);
  if (!d.ok) { box.innerHTML = ''; $('sec-error').innerHTML = errorBox(d.error, 'Không tải được trạng thái Security'); return; }
  const id = d.identity;
  const tableOptions = tables.ok ? tables.tables.map((t) => `<option value="${esc(t.name)}">${esc(t.name)}</option>`).join('') : '';
  const s = d.scripts;
  const overview = [
    ['sec-auth', 'Authentication', hasFiles(s.authentication)],
    ['sec-authz', 'Authorization', hasFiles(s.authorization)],
    ['sec-import', 'Import', hasFiles(s.importExport)],
    ['sec-export', 'Export', hasFiles(s.importExport)],
    ['sec-backup', 'Backup', hasFiles(s.backupRestore)],
    ['sec-restore', 'Restore', hasFiles(s.backupRestore)],
  ];

  box.innerHTML = `<div class="row row-cols-2 row-cols-md-3 row-cols-xl-6 g-2 mb-3">${overview.map(([anchor, label, ok]) => `
      <div class="col"><a href="#${anchor}" class="d-block border rounded p-2 bg-white text-decoration-none h-100">
        <div class="fw-semibold text-body small">${label}</div><div>${statusBadge(ok ? 'ready' : 'pending')}</div><div class="small text-muted">script nhóm</div></a></div>`).join('')}</div>`
  + card('sec-auth', '1. Authentication – Xác thực', `
      <div class="small mb-2">Website đang kết nối bằng SQL login <code>${esc(id.loginName)}</code> (DB user <code>${esc(id.databaseUser)}</code>) vào <code>${esc(id.databaseName)}</code>.</div>
      ${scriptsBlock(s.authentication)}
      <hr><div class="fw-semibold small mb-2">Test đăng nhập – kết quả thật từ SQL Server. Mật khẩu chỉ dùng để mở kết nối: không lưu, không log, không trả về.</div>
      <form id="login-form" class="row g-2 align-items-end" autocomplete="off">
        <div class="col-sm-6 col-lg-3"><label class="form-label small mb-1" for="lg-user">Username (SQL login)</label><input id="lg-user" name="username" class="form-control form-control-sm" required maxlength="128" autocomplete="off"></div>
        <div class="col-sm-6 col-lg-3"><label class="form-label small mb-1" for="lg-pass">Password</label><input id="lg-pass" name="password" type="password" class="form-control form-control-sm" maxlength="128" autocomplete="new-password"></div>
        <div class="col-sm-6 col-lg-3"><label class="form-label small mb-1" for="lg-table">Table cần thử SELECT</label><select id="lg-table" name="tryTable" class="form-select form-select-sm"><option value="">— không thử —</option>${tableOptions}</select></div>
        <div class="col-sm-6 col-lg-3"><button class="btn btn-primary btn-sm w-100">Đăng nhập thử</button></div>
      </form>
      <div id="login-result" class="mt-3"></div>`)
  + card('sec-authz', '2. Authorization – Phân quyền', `
      ${scriptsBlock(s.authorization)}
      <div class="small fw-semibold mt-2">Role mong đợi: ${d.expectedRoles.map((r) => `<code>${esc(r)}</code>`).join(', ')}</div>${queryBlock(d.roles, '')}
      <div class="small fw-semibold mt-2">GRANT/DENY hiện có cho các role trên và thành viên (sys.database_permissions)</div>${queryBlock(d.permissions, 'Chưa có quyền nào được cấp cho các role này.')}
      <div class="small fw-semibold mt-2">Database user hiện có</div>${queryBlock(d.users, 'Chưa có database user nào ngoài user hệ thống.')}
      <div class="small text-muted mt-2">Demo “User A được – User B bị từ chối”: dùng form Test đăng nhập ở mục 1 với 2 login khác nhau trên cùng một bảng.</div>`)
  + card('sec-import', '3. Import', `
      ${scriptsBlock(s.importExport)}
      ${steps(['Chọn bảng sẽ import và bấm <strong>Chụp dữ liệu trước</strong>.', 'Chạy script/wizard import của nhóm trong SSMS.', 'Bấm <strong>So sánh sau import</strong> – website SELECT lại bảng và tô màu dòng mới/thay đổi.'])}
      <div class="row g-2 align-items-end">
        <div class="col-sm-4 col-lg-3"><label class="form-label small mb-1" for="imp-table">Bảng</label><select id="imp-table" class="form-select form-select-sm">${tableOptions}</select></div>
        <div class="col-auto"><button id="imp-snap" class="btn btn-sm btn-outline-primary">Chụp dữ liệu trước</button></div>
        <div class="col-auto"><button id="imp-compare" class="btn btn-sm btn-primary" disabled>So sánh sau import</button></div>
      </div>
      <div id="imp-result" class="mt-2"></div>`)
  + card('sec-export', '4. Export', `
      ${scriptsBlock(s.importExport)}
      <div class="small">Tiện ích Website: trang <a href="/tables">Database Tables</a> có nút <strong>Export CSV</strong> xuất bảng đang chọn trực tiếp từ SQL Server
      (không thay thế script Export của nhóm).</div>`)
  + card('sec-backup', '5. Backup', `
      ${scriptsBlock(s.backupRestore)}
      ${steps(['Chạy script backup của nhóm trong SSMS.', 'Tải lại trang này: bản backup mới xuất hiện trong lịch sử kèm đường dẫn file.'])}
      <div class="small fw-semibold">Lịch sử backup của database (msdb.dbo.backupset)</div>${queryBlock(d.backups, 'Chưa có bản backup nào được ghi nhận.')}`)
  + card('sec-restore', '6. Restore', `
      ${scriptsBlock(s.backupRestore)}
      ${steps([
    'Đã có bản backup (mục 5) → chạy <code>02_DemoThayDoiDuLieu.sql</code> để thay đổi dữ liệu demo.',
    '<strong>Cách an toàn</strong>: chạy <code>03_Restore_KiemTra.sql</code> – restore thành database bản sao <code>…_RestoreTest</code> và SELECT so sánh với database đang chạy (website không bị ảnh hưởng).',
    '<strong>Ghi đè database chính</strong> (tuỳ chọn): <code>04_Restore_GhiDe.sql</code> với <code>@XacNhanGhiDe = 1</code>. Script ngắt mọi kết nối (kể cả website); website tự kết nối lại sau khi restore xong. Nên đóng các cửa sổ SSMS đang mở database.',
    'Kiểm tra: trang Database Tables thấy dữ liệu đã phục hồi; lịch sử restore bên dưới có bản ghi mới.',
  ])}
      <div class="small text-muted mb-2">Website cố ý không có nút Restore: thao tác này có thể làm mất dữ liệu nên chỉ chạy bằng script thật trong SSMS.</div>
      <div class="small fw-semibold">Lịch sử restore (msdb.dbo.restorehistory)</div>${queryBlock(d.restores, 'Chưa có lần restore nào được ghi nhận.')}`);

  $('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const form = e.target;
    const btn = form.querySelector('button');
    const out = $('login-result');
    out.innerHTML = loadingHtml('Đang kết nối SQL Server bằng login vừa nhập…');
    const body = Object.fromEntries(new FormData(form).entries());
    form.password.value = '';
    btn.disabled = true;
    const r = await api('/api/security/login-test', { method: 'POST', body: JSON.stringify(body) });
    btn.disabled = false;
    out.innerHTML = renderLoginResult(r);
  });
  if ($('imp-snap')) {
    $('imp-snap').addEventListener('click', () => takeSnapshot(false));
    $('imp-compare').addEventListener('click', () => takeSnapshot(true));
    $('imp-table').addEventListener('change', () => { snapshot = null; $('imp-compare').disabled = true; $('imp-result').innerHTML = ''; });
  }
});
