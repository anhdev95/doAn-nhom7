// Cấu hình kết nối SQL Server + connection pool dùng chung cho toàn app.
// Credential chỉ đọc từ .env, không bao giờ trả về frontend hoặc ghi log.
const sql = require('mssql');

function toBool(value, fallback) {
  if (value === undefined || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
}

function buildConfig(overrides = {}) {
  const port = parseInt(process.env.DB_PORT, 10);
  return {
    server: process.env.DB_SERVER || 'localhost',
    port: Number.isInteger(port) ? port : 1433,
    database: process.env.DB_NAME || 'IE103_HRM_Nhom7',
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    options: {
      encrypt: toBool(process.env.DB_ENCRYPT, false),
      trustServerCertificate: toBool(process.env.DB_TRUST_SERVER_CERTIFICATE, true),
      enableArithAbort: true,
    },
    pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
    connectionTimeout: 8000,
    requestTimeout: 30000,
    ...overrides,
  };
}

// Thông tin kết nối an toàn để hiển thị (không có user/password).
function publicConnectionInfo() {
  const cfg = buildConfig();
  return { server: cfg.server, port: cfg.port, database: cfg.database };
}

let poolPromise = null;

// Trả về pool đang mở; nếu chưa có hoặc đã rớt thì tạo lại.
async function getPool() {
  if (poolPromise) {
    const pool = await poolPromise.catch(() => null);
    if (pool && pool.connected) return pool;
    poolPromise = null;
  }
  const pool = new sql.ConnectionPool(buildConfig());
  pool.on('error', () => { poolPromise = null; });
  poolPromise = pool.connect().catch((err) => {
    poolPromise = null;
    throw err;
  });
  return poolPromise;
}

async function closePool() {
  if (!poolPromise) return;
  const pool = await poolPromise.catch(() => null);
  poolPromise = null;
  if (pool) await pool.close();
}

// Mở một kết nối riêng với login khác (dùng cho demo xác thực/phân quyền).
async function connectAs(user, password) {
  const pool = new sql.ConnectionPool(buildConfig({ user, password, pool: { max: 1, min: 0 } }));
  return pool.connect();
}

// Chuyển lỗi driver/SQL Server thành thông điệp tiếng Việt + gợi ý xử lý (xem README).
function describeError(err) {
  const number = err && (err.number || (err.originalError && err.originalError.info && err.originalError.info.number));
  const code = err && err.code;
  const message = (err && err.message) || String(err);
  const result = { code: code || null, number: number || null, message, hint: null, kind: 'sql' };
  // SQL Server có thể trả nhiều lỗi liên tiếp (vd. trigger RAISERROR rồi ROLLBACK → lỗi 3609).
  // Lỗi nghiệp vụ nằm ở precedingErrors: đưa lên trước để người xem thấy đúng thông báo của trigger/procedure.
  const preceding = (err && Array.isArray(err.precedingErrors) ? err.precedingErrors : []).map((e) => e && e.message).filter(Boolean);
  if (preceding.length) {
    result.message = [...new Set([...preceding, message])].join(' | ');
    result.number = (err.precedingErrors[0] && err.precedingErrors[0].number) || result.number;
  }

  if (number === 18456 || code === 'ELOGIN') {
    result.kind = 'connection';
    result.hint = 'Login failed: kiểm tra DB_USER/DB_PASSWORD, SQL Server Authentication mode (Mixed Mode) và login đã được tạo/enable.';
  } else if (number === 4060) {
    result.kind = 'connection';
    result.hint = 'Không mở được database: kiểm tra DB_NAME, database đã được tạo (01_CreateDatabase.sql) và login có user trong database.';
  } else if (code === 'ESOCKET' || code === 'ETIMEOUT' || code === 'ECONNCLOSED' || code === 'ENOTOPEN') {
    result.kind = 'connection';
    if (/certificate|self[- ]signed|SSL|TLS/i.test(message)) {
      result.hint = 'Lỗi certificate: đặt DB_TRUST_SERVER_CERTIFICATE=true khi dùng SQL Server local, hoặc cài certificate hợp lệ.';
    } else {
      result.hint = 'Không kết nối được tới server: kiểm tra DB_SERVER/DB_PORT, SQL Server service đang chạy, TCP/IP đã bật trong SQL Server Configuration Manager, firewall.';
    }
  } else if (code === 'EINSTLOOKUP') {
    result.kind = 'connection';
    result.hint = 'Không tìm thấy named instance: bật SQL Server Browser hoặc dùng DB_PORT cố định.';
  } else if (number === 208) {
    result.hint = 'Bảng/object chưa tồn tại trong database: chạy các script trong Source/Database theo đúng thứ tự.';
  } else if (number === 229 || number === 230 || number === 262 || number === 300) {
    result.kind = 'permission';
    result.hint = 'Login hiện tại không có quyền thực hiện thao tác này (GRANT/DENY).';
  } else if (number === 2812 || number === 4121) {
    result.hint = 'Stored procedure/function chưa được tạo trong database.';
  }
  return result;
}

// SQL Server trả cùng thông báo "Login failed" khi sai password và khi database chưa tồn tại.
// Thử đăng nhập vào master bằng cùng credential để phân biệt hai trường hợp.
async function diagnoseError(err) {
  const info = describeError(err);
  if (info.code !== 'ELOGIN' && info.number !== 18456) return info;
  const probe = new sql.ConnectionPool(buildConfig({ database: 'master', pool: { max: 1, min: 0 } }));
  try {
    await probe.connect();
    const dbName = buildConfig().database;
    const r = await probe.request().input('db', sql.NVarChar(128), dbName).query('SELECT DB_ID(@db) AS id');
    info.number = 4060;
    info.hint = r.recordset[0].id === null
      ? `Login đúng nhưng database "${dbName}" chưa tồn tại: chạy Source/Database/01_CreateDatabase.sql rồi 02 → 04.`
      : `Login đúng nhưng chưa có user trong database "${dbName}" (hoặc user bị chặn CONNECT): tạo user cho login trong database.`;
  } catch (e) {
    // Vẫn lỗi với master -> đúng là sai user/password, giữ nguyên gợi ý.
  } finally {
    await probe.close().catch(() => {});
  }
  return info;
}

module.exports = { sql, getPool, closePool, connectAs, describeError, diagnoseError, publicConnectionInfo };
