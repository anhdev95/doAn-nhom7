const processingService = require('../services/processing.service');
const { handle } = require('../utils/http');

const list = handle(async (req, res) => {
  res.json({ ok: true, ...(await processingService.listCases()) });
});

const detail = handle(async (req, res) => {
  res.json({ ok: true, ...(await processingService.getCaseDetail(req.params.id)) });
});

const execute = handle(async (req, res) => {
  res.json(await processingService.executeCase(req.params.id, req.body || {}));
});

module.exports = { list, detail, execute };
