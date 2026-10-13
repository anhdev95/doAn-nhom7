// Đọc trạng thái An toàn thông tin trực tiếp từ SQL Server + test đăng nhập bằng login khác.
const fs = require('fs');
const path = require('path');
const { sql, connectAs, describeError } = require('../config/database');
const { getTable } = require('../config/tables');
const securityConfig = require('../config/security.config');
const sqlService = require('./sql.service');
const { readText } = require('../integration/paths');
const { maskSecrets } = require('../utils/secrets');

const DATABASE_DIR = path.resolve(__dirname, '../../../Database');

// Chạy một truy vấn catalog; nếu login không đủ quyền xem thì trả lỗi thay vì làm hỏng cả trang.
async function safeQuery(text, params, runner) {
  try {
    const r = await sqlService.query(text, params, runner);
    return { ok: true, ...sqlService.serializeRecordset(r.recordset) };
  } catch (err) {
    return { ok: false, error: describeError(err) };
  }
}

function listScriptFiles(entries) {
  const files = [];
  for (const rel of entries) {
    const full = path.resolve(DATABASE_DIR, rel);
    if (!full.startsWith(DATABASE_DIR + path.sep) || !fs.existsSync(full)) {
      files.push({ path: rel, exists: false });
      continue;
    }
    const targets = fs.statSync(full).isDirectory()
      ? fs.readdirSync(full).filter((f) => !f.startsWith('.')).map((f) => `${rel}/${f}`)
      : [rel];
    if (!targets.length) files.push({ path: rel, exists: false });
    for (const t of targets) {
      const tf = path.resolve(DATABASE_DIR, t);
      const isSql = path.extname(tf).toLowerCase() === '.sql';
      files.push({ path: t, exists: true, content: isSql ? maskSecrets(readText(tf)) : null });
    }
  }
  return files;
}

function rolesParam() {
  return { roles: { type: sql.NVarChar(sql.MAX), value: securityConfig.expectedRoles.join(',') } };
}

async function getStatus() {
  const identity = await sqlService.getServerInfo();

  const roles = await safeQuery(
    `SELECT r.value AS roleName,
            CASE WHEN p.principal_id IS NULL THEN 0 ELSE 1 END AS existsInDb,
            (SELECT STRING_AGG(m.name, ', ') FROM sys.database_role_members rm
               JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
              WHERE rm.role_principal_id = p.principal_id) AS members
       FROM STRING_SPLIT(@roles, ',') r
       LEFT JOIN sys.database_principals p ON p.name = r.value AND p.type = 'R'`,
    rolesParam(),
  );

  const permissions = await safeQuery(
    `SELECT pr.name AS principalName, pe.state_desc AS state, pe.permission_name AS permission,
            pe.class_desc AS scope,
            COALESCE(OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id), SCHEMA_NAME(pe.major_id)) AS objectName
       FROM sys.database_permissions pe
       JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
      WHERE pr.name IN (SELECT value FROM STRING_SPLIT(@roles, ','))
         OR pr.principal_id IN (SELECT rm.member_principal_id FROM sys.database_role_members rm
                                  JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
                                 WHERE r.name IN (SELECT value FROM STRING_SPLIT(@roles, ',')))
      ORDER BY pr.name, objectName, pe.permission_name`,
    rolesParam(),
  );

  const users = await safeQuery(
    `SELECT dp.name AS databaseUser, dp.type_desc AS type, COALESCE(sp.name, SUSER_SNAME(dp.sid)) AS loginName, dp.create_date AS createDate
       FROM sys.database_principals dp
       LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
      WHERE dp.type IN ('S', 'U', 'G') AND dp.principal_id > 4 AND dp.is_fixed_role = 0
      ORDER BY dp.name`,
  );

  const backups = await safeQuery(
    `SELECT TOP 10 b.backup_start_date AS startDate, b.backup_finish_date AS finishDate,
            CASE b.type WHEN 'D' THEN N'Full' WHEN 'I' THEN N'Differential' WHEN 'L' THEN N'Log' ELSE b.type END AS backupType,
            CAST(b.backup_size / 1048576.0 AS DECIMAL(18, 2)) AS sizeMB,
            m.physical_device_name AS filePath
       FROM msdb.dbo.backupset b
       JOIN msdb.dbo.backupmediafamily m ON m.media_set_id = b.media_set_id
      WHERE b.database_name = DB_NAME()
      ORDER BY b.backup_finish_date DESC`,
  );

  const restores = await safeQuery(
    `SELECT TOP 10 rh.restore_date AS restoreDate, rh.destination_database_name AS databaseName,
            rh.restore_type AS restoreType, rh.user_name AS restoredBy, m.physical_device_name AS fromFile
       FROM msdb.dbo.restorehistory rh
       JOIN msdb.dbo.backupset b ON b.backup_set_id = rh.backup_set_id
       JOIN msdb.dbo.backupmediafamily m ON m.media_set_id = b.media_set_id
      -- Gồm cả database bản sao kiểm tra restore (vd. IE103_HRM_Nhom7_RestoreTest).
      WHERE rh.destination_database_name = DB_NAME() OR rh.destination_database_name LIKE DB_NAME() + N'[_]%'
      ORDER BY rh.restore_date DESC`,
  );

  const s = securityConfig.scripts;
  return {
    identity,
    expectedRoles: securityConfig.expectedRoles,
    roles,
    permissions,
    users,
    backups,
    restores,
    scripts: {
      authentication: listScriptFiles(s.authentication),
      authorization: listScriptFiles(s.authorization),
      importExport: listScriptFiles(s.importExport),
      backupRestore: listScriptFiles(s.backupRestore),
    },
  };
}

// Đăng nhập bằng login được nhập trên form → trả về kết quả thật từ SQL Server.
// Password chỉ dùng để mở kết nối, không lưu, không log, không trả về.
async function loginTest({ username, password, tryTable } = {}) {
  if (!username || typeof username !== 'string' || username.length > 128) {
    throw Object.assign(new Error('Thiếu hoặc sai định dạng username.'), { status: 400 });
  }
  if (password !== undefined && password !== null && (typeof password !== 'string' || password.length > 128)) {
    throw Object.assign(new Error('Password không hợp lệ.'), { status: 400 });
  }
  if (tryTable && !getTable(tryTable)) {
    throw Object.assign(new Error(`Bảng "${tryTable}" không nằm trong whitelist.`), { status: 400 });
  }

  let pool;
  try {
    pool = await connectAs(username, String(password || ''));
  } catch (err) {
    return { ok: true, authenticated: false, username, error: describeError(err) };
  }

  try {
    const identity = (await sqlService.query(
      `SELECT SUSER_SNAME() AS loginName, USER_NAME() AS databaseUser, DB_NAME() AS databaseName`,
      {},
      pool,
    )).recordset[0];

    const roleMembership = await safeQuery(
      `SELECT value AS roleName, IS_ROLEMEMBER(value) AS isMember FROM STRING_SPLIT(@roles, ',')`,
      rolesParam(),
      pool,
    );

    // Danh sách bảng lấy bằng kết nối chính: login bị DENY không thấy metadata của bảng đó.
    const existing = (await sqlService.countAllTables()).filter((t) => t.exists).map((t) => t.name);
    const perms = securityConfig.checkedPermissions;
    const permissionMatrix = existing.length
      ? await safeQuery(
        `SELECT t.value AS tableName, ${perms
          .map((p, i) => `ISNULL(HAS_PERMS_BY_NAME('dbo.' + t.value, 'OBJECT', @perm${i}), 0) AS [${p}]`)
          .join(', ')}
           FROM STRING_SPLIT(@tables, ',') t
          ORDER BY t.value`,
        {
          tables: { type: sql.NVarChar(sql.MAX), value: existing.join(',') },
          ...Object.fromEntries(perms.map((p, i) => [`perm${i}`, { type: sql.NVarChar(128), value: p }])),
        },
        pool,
      )
      : { ok: true, columns: [], rows: [] };

    // Thử SELECT thật trên một bảng để thấy GRANT/DENY có hiệu lực (lỗi 229 nếu bị từ chối).
    let selectTry = null;
    if (tryTable) {
      try {
        const data = await sqlService.readTable(tryTable, { page: 1, pageSize: 5 }, pool);
        selectTry = { table: tryTable, allowed: true, data };
      } catch (err) {
        selectTry = { table: tryTable, allowed: false, error: describeError(err) };
      }
    }

    return { ok: true, authenticated: true, username, identity, roleMembership, permissionMatrix, selectTry };
  } finally {
    await pool.close().catch(() => {});
  }
}

module.exports = { getStatus, loginTest };
