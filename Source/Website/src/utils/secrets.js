// Che credential của chính website khi trả nội dung file (SQL) về trình duyệt.
// Vd. Authentication.sql chứa mật khẩu login hrm_web = DB_PASSWORD trong .env.
function maskSecrets(text) {
  if (typeof text !== 'string') return text;
  const secret = process.env.DB_PASSWORD;
  if (!secret || secret.length < 4) return text;
  return text.split(secret).join('********');
}

module.exports = { maskSecrets };
