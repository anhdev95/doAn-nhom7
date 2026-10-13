require('dotenv').config({ quiet: true });
const path = require('path');
const express = require('express');
const { closePool } = require('./config/database');
const apiRoutes = require('./routes/api.routes');
const pageRoutes = require('./routes/page.routes');
const reports = require('./controllers/reports.controller');

const app = express();
const ROOT = path.resolve(__dirname, '..');

app.disable('x-powered-by');
// Header bảo mật cơ bản: chỉ chạy script của chính website; iframe chỉ nhúng report https.
app.use((req, res, next) => {
  res.set({
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src https:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'self'",
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'same-origin',
  });
  next();
});
app.use(express.json({ limit: '100kb' }));
app.use(express.static(path.join(ROOT, 'public'), { redirect: false }));
app.use('/vendor/bootstrap', express.static(path.join(ROOT, 'node_modules/bootstrap/dist')));

app.get('/favicon.ico', (req, res) => res.status(204).end());
app.get('/report-assets/:file', reports.asset);
app.use('/api', apiRoutes);
app.use(pageRoutes);
app.use((req, res) => res.status(404).sendFile(path.join(ROOT, 'views/404.html')));

// Lỗi không lường trước: không lộ stack trace/credential ra client.
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error('[error]', err.message);
  res.status(err.status || 500).json({ ok: false, error: { kind: 'server', message: err.status ? err.message : 'Lỗi máy chủ.' } });
});

if (require.main === module) {
  const port = parseInt(process.env.PORT, 10) || 3000;
  const server = app.listen(port, () => {
    console.log(`IE103 HRM Demo: http://localhost:${port}`);
    console.log(`SQL Server: ${process.env.DB_SERVER || 'localhost'}:${process.env.DB_PORT || 1433} / ${process.env.DB_NAME || 'IE103_HRM_Nhom7'}`);
  });
  const shutdown = async () => {
    server.close();
    await closePool().catch(() => {});
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

module.exports = app;
