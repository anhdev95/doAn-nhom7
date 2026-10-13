// Kiểu tham số được phép trong manifest + chuyển giá trị nhập từ form sang kiểu SQL.
const { sql } = require('../config/database');

const PARAM_TYPES = {
  Int: () => sql.Int,
  BigInt: () => sql.BigInt,
  Decimal: () => sql.Decimal(18, 2),
  NVarChar: () => sql.NVarChar(sql.MAX),
  VarChar: () => sql.VarChar(sql.MAX),
  Date: () => sql.Date,
  Time: () => sql.Time(0),
  Bit: () => sql.Bit,
};

const badRequest = (message) => Object.assign(new Error(message), { status: 400 });

function convertParam(def, raw) {
  const empty = raw === undefined || raw === null || raw === '';
  if (empty) {
    if (def.required) throw badRequest(`Thiếu tham số ${def.label || def.name}.`);
    return null;
  }
  const v = String(raw).trim();
  const bad = () => badRequest(`Giá trị không hợp lệ cho ${def.label || def.name} (${def.type}).`);
  switch (def.type) {
    case 'Int':
    case 'BigInt':
      if (!/^-?\d+$/.test(v)) throw bad();
      if (def.type === 'Int') {
        const n = parseInt(v, 10);
        if (n > 2147483647 || n < -2147483648) throw bad();
        return n;
      }
      return v;
    case 'Decimal':
      if (!/^-?\d{1,16}(\.\d{1,2})?$/.test(v)) throw bad();
      return Number(v);
    case 'Date': {
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v);
      if (!m) throw bad();
      const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
      if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) throw bad();
      return d;
    }
    case 'Time': {
      const m = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(v);
      if (!m || +m[1] > 23 || +m[2] > 59 || +(m[3] || 0) > 59) throw bad();
      return new Date(Date.UTC(1970, 0, 1, +m[1], +m[2], +(m[3] || 0)));
    }
    case 'Bit':
      if (!['0', '1', 'true', 'false'].includes(v.toLowerCase())) throw bad();
      return v === '1' || v.toLowerCase() === 'true';
    default:
      if (String(raw).length > 4000) throw bad();
      return String(raw);
  }
}

module.exports = { PARAM_TYPES, PARAM_TYPE_NAMES: Object.keys(PARAM_TYPES), convertParam };
