# Source/Database – IE103_HRM_Nhom7

```text
Database/
├── 01_CreateDatabase.sql     tạo database (collation Vietnamese_CI_AS, recovery SIMPLE)
├── 02_CreateTables.sql       18 bảng theo Database contract + tân từ (MS_Description)
├── 03_Constraints.sql        18 FK, 11 UNIQUE, 35 CHECK, 22 DEFAULT, index cột FK
├── 04_SeedData.sql           dữ liệu mẫu nhất quán + truy vấn kiểm tra
├── ChayTatCa.cmd             chạy 01 → 04 → Security (Authentication, Authorization) → Processing bằng sqlcmd
├── ERD/                      ERD.png (báo cáo), ERD.mmd (Mermaid), ERD.md (mô tả quan hệ)
├── Processing/               5 SP · 5 Trigger · 3 Function · 2 Cursor + Tests/ – Tuyến
└── Security/                 Xác thực, phân quyền, import/export, backup/restore – Đức
```

## Cách chạy

**SSMS:** mở và Execute lần lượt `01` → `02` → `03` → `04` (đăng nhập sysadmin, vd. `sa`), sau đó `Security/Authentication.sql` → `Security/Authorization.sql` → `Processing/Procedures.sql` → `Functions.sql` → `Triggers.sql` → `Cursors.sql`.

**Một lệnh (Windows):**

```bat
cd Source\Database
ChayTatCa.cmd                 :: Windows Authentication
ChayTatCa.cmd sa MatKhau      :: SQL Server Authentication
```

Kiểm tra: `cd ..\Website && npm run check-db` → phải `0 FAIL`.

Mỗi script tự dừng nếu đã chạy trước đó (không ghi đè dữ liệu). Tạo lại từ đầu: trong `01_CreateDatabase.sql` đặt `@TaoLai = 1` (**xóa toàn bộ dữ liệu**) rồi chạy lại `01` → `04`, 2 script Security và 4 script Processing.

## Quyết định thiết kế (bổ sung, không đổi contract)

| Mục | Quyết định | Lý do |
|---|---|---|
| Khóa chính | `INT IDENTITY(1,1)` cho 17 bảng; `DANH_GIA_CHI_TIET` dùng PK kép `(MaDG, STT)` | INSERT không cần tự sinh mã; dữ liệu mẫu dùng `IDENTITY_INSERT` để mã cố định |
| NULL | NOT NULL cho cột bắt buộc; NULL cho cột contract ghi “nullable” (`HOPDONG.NgayKetThuc`, `PHUC_LOI.NgayKetThuc`, `NHANVIEN.MaQuanLy`) và cột mô tả/liên hệ phụ | Toàn vẹn dữ liệu |
| Khóa ngoại | `NO ACTION` (không cascade) | Không thể xóa phòng ban/nhân viên còn dữ liệu liên quan – giữ lịch sử nhân sự |
| CHECK | Theo Master Handoff §4 + 6 miền giá trị đã chốt + CCCD 12 chữ số, email có `@`, `NgayVaoLam > NgaySinh`, `MaQuanLy <> MaNV`, `Thang` 1–12 | |
| Không đặt CHECK | Công thức `LuongThucNhan`; `HieuSuatKPI = KPIThucTe / KPIMucTieu × 100`, `HieuSuatKPITong = Σ(HieuSuatKPI × TrongSo) / 100`, tổng `TrongSo` = 100 | Để phần xử lý (Tuyến) tự thiết kế procedure/trigger; dữ liệu mẫu tuân thủ, `check-db` kiểm tra |
| Đơn vị KPI | `TrongSo`, `HieuSuatKPI`, `HieuSuatKPITong` tính theo **%** (vd. 96.00 = 96%) | Xếp loại theo ngưỡng % |
| Quy tắc nhiều dòng | Trùng đơn nghỉ đã duyệt, chấm công người đã nghỉ, nhiều hợp đồng hiệu lực, tuyển vượt số lượng, đào tạo người không đang làm | **Không** cài ở đây – thuộc Trigger/Procedure của Tuyến. `04_SeedData.sql` có truy vấn chứng minh dữ liệu mẫu không vi phạm |
| Collation | `Vietnamese_CI_AS` | Sắp xếp/so sánh tiếng Việt đúng |

## Miền giá trị

Đã chốt (có CHECK):

| Cột | Giá trị |
|---|---|
| `NHANVIEN.GioiTinh` | Nam · Nữ · Khác |
| `NHANVIEN.TrangThai` | Đang làm · Tạm nghỉ · Nghỉ việc |
| `HOPDONG.TrangThai` | Hiệu lực · Hết hạn · Chấm dứt |
| `DON_NGHI_PHEP.TrangThai` | Chờ duyệt · Đã duyệt · Từ chối |
| `UNG_TUYEN.TrangThai` | Đang xử lý · Đã tuyển · Từ chối |
| `UNG_TUYEN.KetQua` | Chưa có kết quả · Đạt · Không đạt |
| `DS_PHUC_LOI.TrangThai` | Đang áp dụng · Hết hiệu lực |

Đề xuất – dùng thống nhất trong dữ liệu mẫu, **chưa** có CHECK (nhóm chốt thì bổ sung vào `03_Constraints.sql`):

| Cột | Giá trị đang dùng |
|---|---|
| `CHAM_CONG.TrangThai` | Đúng giờ · Đi muộn · Về sớm · Vắng |
| `DOT_TUYENDUNG.TrangThai` | Đang tuyển · Đã kết thúc |
| `DAOTAO.HinhThuc` | Trực tiếp · Trực tuyến · Kết hợp |
| `DANH_GIA.XepLoai` | Theo `HieuSuatKPITong`: Xuất sắc (≥ 90) · Giỏi (≥ 80) · Khá (≥ 65) · Trung bình (≥ 50) · Yếu |
| `THAM_GIA_DAO_TAO.KetQua` | Hoàn thành · Không hoàn thành · Đang học |
| `HOPDONG.LoaiHD` | Thử việc · Xác định thời hạn · Không xác định thời hạn |

## Dữ liệu mẫu (04_SeedData.sql)

| Bảng | Dòng | Ghi chú |
|---|---|---|
| PHONGBAN | 6 | Ban Giám đốc, Nhân sự, Kế toán, Kinh doanh, Kỹ thuật, Marketing |
| CHUCVU | 7 | Giám đốc → Thực tập sinh |
| NHANVIEN | 24 | 19 Đang làm, 2 Tạm nghỉ (NV 10, 20), 3 Nghỉ việc (NV 13, 19, 24); cây quản lý giám đốc → trưởng phòng → nhân viên |
| HOPDONG | 34 | 21 Hiệu lực (mỗi người còn làm đúng 1), 10 Hết hạn, 3 Chấm dứt; có thử việc, gia hạn |
| DOT_TUYENDUNG / VI_TRI | 3 / 7 | 2 đợt đã kết thúc, 1 đợt đang tuyển (10–11/2026) |
| UNGVIEN / UNG_TUYEN | 16 / 21 | Đạt / Không đạt / Chưa có kết quả; NV 21, 22 là ứng viên trúng tuyển |
| DAOTAO / THAM_GIA | 6 / 23 | Có khóa đang học (10–11/2026) |
| DANH_GIA / DANH_GIA_CHI_TIET | 34 / 102 | Tháng 12/2025 và 09/2026; mỗi lần 3 KPI theo phòng ban (trọng số 50/30/20); đủ 5 mức xếp loại |
| KHEN_THUONG | 10 | Có khen thưởng trong 07–09/2026 (vào TienThuong của bảng lương) |
| CHAM_CONG | 504 | 01/09–09/10/2026, thứ 2–6, trừ lễ 01–02/09 và ngày nghỉ phép đã duyệt; có OT, đi muộn, về sớm, vắng |
| DON_NGHI_PHEP | 13 | Chờ duyệt 4 · Đã duyệt 7 · Từ chối 2; nửa ngày (0.5); nghỉ dài (thai sản, không lương) |
| BANG_LUONG | 58 | 07, 08, 09/2026; `KhauTru = 10,5% LuongCoBan`; đúng công thức `LuongThucNhan`. **Tháng 10/2026 để trống** cho demo tính lương |
| DS_PHUC_LOI / PHUC_LOI | 7 / 16 | 6 loại Đang áp dụng, 1 loại Hết hiệu lực; `NgayKetThuc` NULL = đang hưởng |

Cuối `04_SeedData.sql` có 10 truy vấn kiểm tra quy tắc – tất cả phải trả về `0`.
