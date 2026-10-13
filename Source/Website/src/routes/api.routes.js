const express = require('express');
const core = require('../controllers/core.controller');
const processing = require('../controllers/processing.controller');
const reports = require('../controllers/reports.controller');
const security = require('../controllers/security.controller');

const router = express.Router();

router.get('/health', core.health);
router.get('/dashboard', core.dashboard);
router.get('/tables', core.listTables);
router.get('/tables/:tableName/export.csv', core.exportTable);
router.get('/tables/:tableName', core.readTable);

router.get('/processing', processing.list);
router.get('/processing/:id', processing.detail);
router.post('/processing/:id/execute', processing.execute);

router.get('/reports', reports.list);

router.get('/security/status', security.status);
router.post('/security/login-test', security.loginTest);

router.use((req, res) => res.status(404).json({ ok: false, error: { kind: 'request', message: 'API không tồn tại.' } }));

module.exports = router;
