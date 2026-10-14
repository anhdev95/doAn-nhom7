// Whitelist bảng cho generic table viewer – đúng 18 bảng trong Database contract (Master Handoff §2).
// Chỉ tên bảng có trong danh sách này mới được đưa vào câu SELECT; client không gửi được tên tùy ý.
// `pk` dùng để sắp xếp ổn định khi phân trang: tên cột, hoặc mảng tên cột nếu là PK kép.
const TABLES = [
  { name: 'NHANVIEN', pk: 'MaNV', label: 'Nhân viên', group: 'Nhân sự' },
  { name: 'PHONGBAN', pk: 'MaPB', label: 'Phòng ban', group: 'Nhân sự' },
  { name: 'CHUCVU', pk: 'MaCV', label: 'Chức vụ', group: 'Nhân sự' },
  { name: 'HOPDONG', pk: 'MaHD', label: 'Hợp đồng', group: 'Nhân sự' },
  { name: 'DOT_TUYENDUNG', pk: 'MaDotTD', label: 'Đợt tuyển dụng', group: 'Tuyển dụng' },
  { name: 'VI_TRI_TUYENDUNG', pk: 'MaViTri', label: 'Vị trí tuyển dụng', group: 'Tuyển dụng' },
  { name: 'UNGVIEN', pk: 'MaUV', label: 'Ứng viên', group: 'Tuyển dụng' },
  { name: 'UNG_TUYEN', pk: 'MaUngTuyen', label: 'Ứng tuyển', group: 'Tuyển dụng' },
  { name: 'DAOTAO', pk: 'MaDT', label: 'Khóa đào tạo', group: 'Đào tạo & Đánh giá' },
  { name: 'THAM_GIA_DAO_TAO', pk: 'MaTG', label: 'Tham gia đào tạo', group: 'Đào tạo & Đánh giá' },
  { name: 'DANH_GIA', pk: 'MaDG', label: 'Đánh giá', group: 'Đào tạo & Đánh giá' },
  { name: 'DANH_GIA_CHI_TIET', pk: ['MaDG', 'STT'], label: 'Đánh giá chi tiết (KPI)', group: 'Đào tạo & Đánh giá' },
  { name: 'CHAM_CONG', pk: 'MaCC', label: 'Chấm công', group: 'Chấm công & Nghỉ phép' },
  { name: 'DON_NGHI_PHEP', pk: 'MaDon', label: 'Đơn nghỉ phép', group: 'Chấm công & Nghỉ phép' },
  { name: 'BANG_LUONG', pk: 'MaLuong', label: 'Bảng lương', group: 'Lương & Đãi ngộ' },
  { name: 'KHEN_THUONG', pk: 'MaKT', label: 'Khen thưởng', group: 'Lương & Đãi ngộ' },
  { name: 'DS_PHUC_LOI', pk: 'MaLoaiPL', label: 'Danh sách phúc lợi', group: 'Lương & Đãi ngộ' },
  { name: 'PHUC_LOI', pk: 'MaPL', label: 'Phúc lợi', group: 'Lương & Đãi ngộ' },
];

const BY_NAME = new Map(TABLES.map((t) => [t.name, t]));

function getTable(name) {
  return BY_NAME.get(String(name || '').toUpperCase()) || null;
}

// Danh sách cột PK của bảng (luôn là mảng).
function pkColumns(table) {
  return Array.isArray(table.pk) ? table.pk : [table.pk];
}

module.exports = { TABLES, getTable, pkColumns };
