// Helper trả lỗi JSON thống nhất cho API.
const { describeError } = require('../config/database');

function sendError(res, err) {
  if (err && err.status && err.status < 500) {
    return res.status(err.status).json({ ok: false, error: { kind: 'request', message: err.message } });
  }
  const info = describeError(err);
  // 208 = bảng/object chưa tồn tại → 404 (không phải lỗi máy chủ).
  const status = info.kind === 'connection' ? 503 : info.kind === 'permission' ? 403 : info.number === 208 ? 404 : 500;
  return res.status(status).json({ ok: false, error: info });
}

// Bọc controller async để mọi lỗi đều đi qua sendError.
const handle = (fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (err) {
    sendError(res, err);
  }
};

module.exports = { sendError, handle };
