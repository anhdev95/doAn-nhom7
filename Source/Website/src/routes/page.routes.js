// Các trang HTML tĩnh; dữ liệu được nạp bằng fetch tới /api/* (lấy trực tiếp từ SQL Server).
const express = require('express');
const path = require('path');

const VIEWS = path.resolve(__dirname, '../../views');
const PAGES = {
  '/': 'dashboard.html',
  '/tables': 'tables.html',
  '/processing': 'processing.html',
  '/reports': 'reports.html',
  '/security': 'security.html',
};

const router = express.Router();
for (const [route, file] of Object.entries(PAGES)) {
  router.get(route, (req, res) => res.sendFile(path.join(VIEWS, file)));
}

module.exports = router;
