// Kiểm tra kết nối SQL Server + đối chiếu database với Database contract: `npm run check-db`.
// Chỉ đọc (catalog + COUNT/GROUP BY), không sửa schema/dữ liệu. Exit code 1 nếu có [FAIL].
require('dotenv').config({ quiet: true, path: require('path').resolve(__dirname, '../.env') });
const { closePool, diagnoseError, publicConnectionInfo } = require('../src/config/database');
const { OPEN_DECISIONS } = require('../src/config/contract');
const { checkContract } = require('../src/integration/contract.check');
const sqlService = require('../src/services/sql.service');

const color = process.stdout.isTTY ? { pass: '\x1b[32m', warn: '\x1b[33m', fail: '\x1b[31m', info: '\x1b[36m', reset: '\x1b[0m' } : { pass: '', warn: '', fail: '', info: '', reset: '' };
const print = (level, message) => console.log(`${color[level]}[${level.toUpperCase()}]${color.reset} ${message}`);

(async () => {
  const info = publicConnectionInfo();
  console.log(`Kết nối tới ${info.server}:${info.port} / database ${info.database} ...`);
  try {
    const server = await sqlService.getServerInfo();
    print('pass', `${server.serverName} | SQL Server ${server.productVersion} (${server.edition})`);
    print('info', `Login: ${server.loginName} | Database user: ${server.databaseUser}`);

    const tables = await sqlService.countAllTables();
    console.log(`\n== Số dòng ${tables.length} bảng ==`);
    for (const t of tables) console.log(`  ${t.exists ? '✔' : '✘'} ${t.name.padEnd(18)} ${t.exists ? `${t.total} dòng` : 'chưa tồn tại'}`);

    console.log('\n== Đối chiếu Database contract ==');
    const results = await checkContract();
    for (const r of results) print(r.level, r.message);
    for (const d of OPEN_DECISIONS) print('info', `Thiết kế: ${d}`);

    const n = (lv) => results.filter((r) => r.level === lv).length;
    console.log(`\nKết quả: ${n('pass')} PASS · ${n('warn')} WARN · ${n('fail')} FAIL`);
    process.exitCode = n('fail') ? 1 : 0;
  } catch (err) {
    const e = await diagnoseError(err);
    print('fail', `[${e.code || e.number || 'unknown'}] ${e.message}`);
    if (e.hint) console.error(`Gợi ý: ${e.hint}`);
    process.exitCode = 1;
  } finally {
    await closePool().catch(() => {});
  }
})();
