const securityService = require('../services/security.service');
const { handle } = require('../utils/http');

const status = handle(async (req, res) => {
  res.json({ ok: true, ...(await securityService.getStatus()) });
});

const loginTest = handle(async (req, res) => {
  const { username, password, tryTable } = req.body || {};
  res.json(await securityService.loginTest({ username, password, tryTable }));
});

module.exports = { status, loginTest };
