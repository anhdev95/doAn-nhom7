// Database contract (Master Handoff §2–§4 + các quyết định nhóm đã chốt) dưới dạng dữ liệu,
// dùng để ĐỐI CHIẾU database thật (npm run check-db) và hiển thị phân bố trạng thái trên Dashboard.
// Website không tạo/sửa schema từ file này.

// Kiểu ghi theo INFORMATION_SCHEMA: int | date | time | nvarchar(n) | varchar(n) | decimal(p,s)
const COLUMNS = {
  PHONGBAN: [['MaPB', 'int'], ['TenPB', 'nvarchar(100)'], ['MoTa', 'nvarchar(300)']],
  CHUCVU: [['MaCV', 'int'], ['TenCV', 'nvarchar(100)'], ['MoTaCV', 'nvarchar(300)'], ['TrachNhiem', 'nvarchar(300)'], ['YeuCauKyNang', 'nvarchar(300)']],
  NHANVIEN: [
    ['MaNV', 'int'], ['HoTen', 'nvarchar(100)'], ['NgaySinh', 'date'], ['GioiTinh', 'nvarchar(10)'], ['CCCD', 'varchar(12)'],
    ['Email', 'varchar(100)'], ['SoDienThoai', 'varchar(15)'], ['DiaChi', 'nvarchar(200)'], ['NgayVaoLam', 'date'],
    ['TrangThai', 'nvarchar(30)'], ['MaPB', 'int'], ['MaCV', 'int'], ['MaQuanLy', 'int'],
  ],
  HOPDONG: [
    ['MaHD', 'int'], ['MaNV', 'int'], ['LoaiHD', 'nvarchar(50)'], ['NgayBatDau', 'date'], ['NgayKetThuc', 'date'],
    ['LuongCoBan', 'decimal(18,2)'], ['TrangThai', 'nvarchar(30)'], ['LuongHieuSuat', 'decimal(18,2)'], ['PhuCap', 'decimal(18,2)'],
  ],
  DOT_TUYENDUNG: [['MaDotTD', 'int'], ['TenDotTD', 'nvarchar(200)'], ['NgayBatDau', 'date'], ['NgayKetThuc', 'date'], ['TrangThai', 'nvarchar(30)'], ['ChiPhi', 'decimal(18,2)']],
  VI_TRI_TUYENDUNG: [['MaViTri', 'int'], ['MaDotTD', 'int'], ['TenViTri', 'nvarchar(100)'], ['SoLuong', 'int'], ['YeuCau', 'nvarchar(500)'], ['MaPB', 'int'], ['SoVongPV', 'int']],
  UNGVIEN: [
    ['MaUV', 'int'], ['HoTen', 'nvarchar(100)'], ['NgaySinh', 'date'], ['Email', 'varchar(100)'], ['SoDienThoai', 'varchar(15)'],
    ['DiaChi', 'nvarchar(200)'], ['TrinhDo', 'nvarchar(100)'], ['KinhNghiem', 'nvarchar(500)'],
  ],
  UNG_TUYEN: [['MaUngTuyen', 'int'], ['MaUV', 'int'], ['MaViTri', 'int'], ['NgayUngTuyen', 'date'], ['VongPhongVan', 'int'], ['KetQua', 'nvarchar(30)'], ['TrangThai', 'nvarchar(30)']],
  DAOTAO: [['MaDT', 'int'], ['TenKhoaHoc', 'nvarchar(200)'], ['HinhThuc', 'nvarchar(30)'], ['NgayBatDau', 'date'], ['NgayKetThuc', 'date'], ['NoiDung', 'nvarchar(500)']],
  THAM_GIA_DAO_TAO: [['MaTG', 'int'], ['MaNV', 'int'], ['MaDT', 'int'], ['NgayThamGia', 'date'], ['KetQua', 'nvarchar(100)'], ['DanhGia', 'nvarchar(300)']],
  DANH_GIA: [['MaDG', 'int'], ['MaNV', 'int'], ['KyDanhGia', 'nvarchar(50)'], ['NgayDanhGia', 'date'], ['Diem', 'decimal(5,2)'], ['XepLoai', 'nvarchar(30)'], ['NhanXet', 'nvarchar(500)']],
  KHEN_THUONG: [['MaKT', 'int'], ['MaNV', 'int'], ['NgayKT', 'date'], ['LyDo', 'nvarchar(300)'], ['HinhThuc', 'nvarchar(100)'], ['SoTien', 'decimal(18,2)']],
  CHAM_CONG: [['MaCC', 'int'], ['MaNV', 'int'], ['Ngay', 'date'], ['GioVao', 'time'], ['GioRa', 'time'], ['SoGioOT', 'decimal(5,2)'], ['TrangThai', 'nvarchar(30)']],
  DON_NGHI_PHEP: [['MaDon', 'int'], ['MaNV', 'int'], ['TuNgay', 'date'], ['DenNgay', 'date'], ['SoNgay', 'decimal(5,2)'], ['LyDo', 'nvarchar(300)'], ['TrangThai', 'nvarchar(30)']],
  BANG_LUONG: [
    ['MaLuong', 'int'], ['MaNV', 'int'], ['Thang', 'int'], ['Nam', 'int'], ['LuongCoBan', 'decimal(18,2)'], ['LuongHieuSuat', 'decimal(18,2)'],
    ['PhuCap', 'decimal(18,2)'], ['TienThuong', 'decimal(18,2)'], ['KhauTru', 'decimal(18,2)'], ['LuongThucNhan', 'decimal(18,2)'],
  ],
  PHUC_LOI: [['MaPL', 'int'], ['MaNV', 'int'], ['TenPhucLoi', 'nvarchar(200)'], ['NgayBatDau', 'date'], ['NgayKetThuc', 'date'], ['GiaTri', 'decimal(18,2)'], ['TrangThai', 'nvarchar(30)']],
};

// [bảng, cột, bảng tham chiếu, cột tham chiếu] – Master Handoff §3.
const FOREIGN_KEYS = [
  ['NHANVIEN', 'MaPB', 'PHONGBAN', 'MaPB'],
  ['NHANVIEN', 'MaCV', 'CHUCVU', 'MaCV'],
  ['NHANVIEN', 'MaQuanLy', 'NHANVIEN', 'MaNV'],
  ['HOPDONG', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['VI_TRI_TUYENDUNG', 'MaDotTD', 'DOT_TUYENDUNG', 'MaDotTD'],
  ['VI_TRI_TUYENDUNG', 'MaPB', 'PHONGBAN', 'MaPB'],
  ['UNG_TUYEN', 'MaUV', 'UNGVIEN', 'MaUV'],
  ['UNG_TUYEN', 'MaViTri', 'VI_TRI_TUYENDUNG', 'MaViTri'],
  ['THAM_GIA_DAO_TAO', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['THAM_GIA_DAO_TAO', 'MaDT', 'DAOTAO', 'MaDT'],
  ['DANH_GIA', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['KHEN_THUONG', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['CHAM_CONG', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['DON_NGHI_PHEP', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['BANG_LUONG', 'MaNV', 'NHANVIEN', 'MaNV'],
  ['PHUC_LOI', 'MaNV', 'NHANVIEN', 'MaNV'],
];

// [bảng, [cột...]] – Master Handoff §4.
const UNIQUES = [
  ['NHANVIEN', ['CCCD']],
  ['NHANVIEN', ['Email']],
  ['PHONGBAN', ['TenPB']],
  ['CHUCVU', ['TenCV']],
  ['UNGVIEN', ['Email']],
  ['CHAM_CONG', ['MaNV', 'Ngay']],
  ['BANG_LUONG', ['MaNV', 'Thang', 'Nam']],
  ['UNG_TUYEN', ['MaUV', 'MaViTri']],
  ['THAM_GIA_DAO_TAO', ['MaNV', 'MaDT']],
];

// Miền giá trị đã chốt (Master Handoff §2.3 + quyết định nhóm).
const DOMAINS = [
  { table: 'NHANVIEN', column: 'GioiTinh', label: 'Giới tính nhân viên', values: ['Nam', 'Nữ', 'Khác'] },
  { table: 'NHANVIEN', column: 'TrangThai', label: 'Trạng thái nhân viên', values: ['Đang làm', 'Tạm nghỉ', 'Nghỉ việc'] },
  { table: 'HOPDONG', column: 'TrangThai', label: 'Trạng thái hợp đồng', values: ['Hiệu lực', 'Hết hạn', 'Chấm dứt'] },
  { table: 'DON_NGHI_PHEP', column: 'TrangThai', label: 'Trạng thái đơn nghỉ phép', values: ['Chờ duyệt', 'Đã duyệt', 'Từ chối'] },
  { table: 'UNG_TUYEN', column: 'TrangThai', label: 'Trạng thái ứng tuyển', values: ['Đang xử lý', 'Đã tuyển', 'Từ chối'] },
  { table: 'UNG_TUYEN', column: 'KetQua', label: 'Kết quả ứng tuyển', values: ['Chưa có kết quả', 'Đạt', 'Không đạt'] },
];

// Quy tắc dữ liệu lưu sẵn: phần SQL nghiệp vụ của nhóm/Tuyến chịu trách nhiệm bảo đảm.
// check-db chỉ ĐẾM số dòng lệch để cảnh báo, không sửa dữ liệu.
const SALARY_RULE = 'LuongThucNhan = LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru';

// Quyết định thiết kế bổ sung (không đổi contract): ghi lại để check-db in ra khi đối chiếu.
const OPEN_DECISIONS = [
  'PK dùng INT IDENTITY(1,1) (02_CreateTables.sql) – INSERT không truyền mã; dữ liệu mẫu dùng IDENTITY_INSERT.',
  'Miền giá trị chưa chốt (chỉ dùng thống nhất trong dữ liệu mẫu, chưa có CHECK): CHAM_CONG.TrangThai, DOT_TUYENDUNG.TrangThai, PHUC_LOI.TrangThai, DAOTAO.HinhThuc, DANH_GIA.XepLoai, THAM_GIA_DAO_TAO.KetQua.',
];

module.exports = { COLUMNS, FOREIGN_KEYS, UNIQUES, DOMAINS, SALARY_RULE, OPEN_DECISIONS };
