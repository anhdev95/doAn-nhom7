# Security – An toàn thông tin (Đức)

Database: `IE103_HRM_Nhom7`. Chạy trong SSMS bằng tài khoản **sysadmin** (vd. `sa`), **sau** `01`–`04` của nhóm.
Mọi script chạy lại nhiều lần được. File `.sql` lưu UTF-8 có BOM (SSMS đọc đúng tiếng Việt).

```text
Security/
├── Authentication.sql                 1. Xác thực
├── Authorization.sql                  2. Phân quyền
├── Import_Export/
│   ├── 01_Import_ChamCong.sql         3. Import (CSV → CHAM_CONG)
│   ├── cham_cong_import.csv              file dữ liệu import mẫu
│   ├── 02_Export.sql                  4. Export (truy vấn xuất + đối chiếu số dòng)
│   └── Export_bcp.cmd                    xuất ra file bằng bcp (Windows)
└── Backup_Restore/
    ├── 01_Backup.sql                  5. Backup + kiểm tra file
    ├── 02_DemoThayDoiDuLieu.sql       6. Restore – bước thay đổi dữ liệu demo
    ├── 03_Restore_KiemTra.sql            Restore ra DB bản sao + SELECT so sánh (an toàn)
    └── 04_Restore_GhiDe.sql              Restore ghi đè DB chính (cần @XacNhanGhiDe = 1)
```

## Tài khoản demo (tạo bởi Authentication.sql)

| Login / DB user | Mật khẩu demo | Role | Vai trò |
|---|---|---|---|
| `hrm_hr` | `Hr@Nhom7_2026` | `HR_ROLE` | Nhân sự |
| `hrm_ketoan` | `KeToan@Nhom7_2026` | `ACCOUNTING_ROLE` | Kế toán |
| `hrm_quanly` | `QuanLy@Nhom7_2026` | `MANAGER_ROLE` | Quản lý |
| `hrm_web` | `Web@Nhom7_2026` | db_datareader, db_datawriter, EXECUTE, VIEW DEFINITION | Login của Website Demo |

Đổi mật khẩu trong `Authentication.sql` nếu cần (không dùng ký tự `#`). Website che mật khẩu của chính nó khi hiển thị script.

## Phân quyền (Authorization.sql)

| Bảng | HR_ROLE | ACCOUNTING_ROLE | MANAGER_ROLE |
|---|---|---|---|
| NHANVIEN, HOPDONG | SELECT, INSERT, UPDATE | SELECT · **DENY** INSERT/UPDATE/DELETE | SELECT · **DENY** INSERT/UPDATE/DELETE |
| PHONGBAN, CHUCVU, CHAM_CONG, KHEN_THUONG, DS_PHUC_LOI, PHUC_LOI | SELECT, INSERT, UPDATE | SELECT | SELECT |
| DON_NGHI_PHEP | SELECT, INSERT, UPDATE | SELECT | SELECT · UPDATE **chỉ cột TrangThai** (duyệt đơn) |
| DANH_GIA, DANH_GIA_CHI_TIET | SELECT, INSERT, UPDATE | – | SELECT, INSERT, UPDATE |
| DAOTAO, THAM_GIA_DAO_TAO | SELECT, INSERT, UPDATE | – | SELECT |
| DOT_TUYENDUNG, VI_TRI_TUYENDUNG, UNGVIEN, UNG_TUYEN | SELECT, INSERT, UPDATE | **DENY SELECT** | SELECT |
| BANG_LUONG | SELECT · **DENY** INSERT/UPDATE/DELETE | SELECT, INSERT, UPDATE | SELECT · **DENY** INSERT/UPDATE/DELETE |

Không role nào có DELETE (dữ liệu nhân sự chỉ cập nhật trạng thái). Demo REVOKE: script cấp tạm `DELETE CHAM_CONG` cho HR rồi thu hồi.
Quyền EXECUTE trên procedure/function của Tuyến: cấp theo từng object sau khi Tuyến bàn giao (Bước 6 trong script).

## Thứ tự chạy & kịch bản demo

| # | Bước | Chạy | Kết quả cần thấy |
|---|---|---|---|
| 1 | Xác thực | `Authentication.sql` | 4 login + user; bảng “Đăng nhập được” cho hrm_hr/ketoan/quanly, “Bị từ chối” cho login không tồn tại |
| 1b | Đăng nhập thật | SSMS Connect hoặc Website `/security` → Test đăng nhập | Đúng mật khẩu → vào được; sai mật khẩu → lỗi 18456 |
| 2 | Phân quyền | `Authorization.sql` | Bảng role/thành viên, bảng GRANT/DENY, ma trận ĐƯỢC PHÉP / BỊ TỪ CHỐI, demo REVOKE |
| 2b | User A được – User B bị từ chối | Website `/security`: thử SELECT `UNGVIEN` với `hrm_hr` (được) và `hrm_ketoan` (lỗi 229) | |
| 3 | Import | Copy `cham_cong_import.csv` lên máy SQL Server, sửa `@FileImport`, chạy `01_Import_ChamCong.sql` | Số dòng trước/sau, dòng bị loại kèm lý do, SELECT dòng mới |
| 4 | Export | `02_Export.sql` (Save Results As…) hoặc `Export_bcp.cmd` | File xuất có số dòng = `SoDongXuat` |
| 5 | Backup | `01_Backup.sql` | Đường dẫn file `.bak`, VERIFYONLY hợp lệ, bản ghi trong msdb |
| 6 | Restore | `02_DemoThayDoiDuLieu.sql` → `03_Restore_KiemTra.sql` | Dòng PHONGBAN khác nhau giữa DB đang chạy và bản restore; số dòng 18 bảng khớp |
| 6b | Restore ghi đè (tuỳ chọn) | `04_Restore_GhiDe.sql` với `@XacNhanGhiDe = 1` | Dữ liệu về lại lúc backup; Website tự kết nối lại |

## Lưu ý theo máy demo

- **Import**: `@FileImport` là đường dẫn trên máy chạy SQL Server; tài khoản service SQL Server phải đọc được file (vd. `C:\IE103\Import\`).
  File mẫu khớp `04_SeedData.sql`: 8 dòng hợp lệ (12–13/10/2026) và 8 dòng cố ý sai (nhân viên đã nghỉ việc, đã có chấm công,
  MaNV không tồn tại, ngày sai, giờ ra trước giờ vào, trùng trong file, thiếu trạng thái) để minh họa bước kiểm tra.
  SQL Server trên Linux/Docker không hỗ trợ `CODEPAGE` → tiếng Việt sai; dùng SSMS → Tasks → *Import Flat File…*.
- **Export_bcp.cmd** cần *SQL Server Command Line Utilities* (bcp). File `.tsv` mở bằng Excel: Data → From Text/CSV.
- **Backup**: mặc định ghi vào thư mục backup của instance; nếu đổi `@ThuMucBackup`, service SQL Server phải có quyền ghi.
- **SQL Server Express**: không hỗ trợ `COMPRESSION` (script không dùng).
- Website dùng login `hrm_web`: trong `Source/Website/.env` đặt `DB_USER=hrm_web`, `DB_PASSWORD="Web@Nhom7_2026"`.
