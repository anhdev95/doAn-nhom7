/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 2b. PHÂN QUYỀN TRÊN PHẦN XỬ LÝ
   Database : IE103_HRM_Nhom7
   Chạy SAU: Authorization.sql và 4 script Processing (Procedures, Functions,
             Triggers, Cursors). Chạy lại nhiều lần được.
   ---------------------------------------------------------------------
   Cấp theo từng object, không cấp EXECUTE ON SCHEMA::dbo: procedure chạy
   theo ownership chaining nên bỏ qua DENY trên bảng. Vì vậy chỉ role được
   phép sửa BANG_LUONG mới được chạy SP07 (tính lương ghi vào BANG_LUONG).
   ===================================================================== */
USE IE103_HRM_Nhom7;
GO

-- HR_ROLE: hợp đồng, tuyển dụng, nhân sự, nghỉ phép, đánh giá KPI.
GRANT EXECUTE ON dbo.SP01_HopDongSapHetHan         TO HR_ROLE;
GRANT EXECUTE ON dbo.SP02_ChiPhiTuyenDung          TO HR_ROLE;
GRANT EXECUTE ON dbo.SP03_LichSuUngTuyen           TO HR_ROLE;
GRANT EXECUTE ON dbo.SP04_ThongKeNhanVienPhongBan  TO HR_ROLE;
GRANT EXECUTE ON dbo.SP05_NhanVienKhongNghiPhep    TO HR_ROLE;
GRANT EXECUTE ON dbo.SP06_TinhHieuSuatThang        TO HR_ROLE;
GRANT EXECUTE ON dbo.FN01_TongNgayNghi             TO HR_ROLE;
GRANT SELECT  ON dbo.FN02_TongCongOT               TO HR_ROLE;
GRANT EXECUTE ON dbo.FN03_TyLeDau                  TO HR_ROLE;

-- ACCOUNTING_ROLE: tính lương và các hàm đầu vào của lương.
GRANT EXECUTE ON dbo.SP07_TinhLuongThang           TO ACCOUNTING_ROLE;
GRANT EXECUTE ON dbo.FN01_TongNgayNghi             TO ACCOUNTING_ROLE;
GRANT SELECT  ON dbo.FN02_TongCongOT               TO ACCOUNTING_ROLE;

-- MANAGER_ROLE: xem thống kê, hợp đồng sắp hết hạn, chấm KPI.
GRANT EXECUTE ON dbo.SP01_HopDongSapHetHan         TO MANAGER_ROLE;
GRANT EXECUTE ON dbo.SP04_ThongKeNhanVienPhongBan  TO MANAGER_ROLE;
GRANT EXECUTE ON dbo.SP05_NhanVienKhongNghiPhep    TO MANAGER_ROLE;
GRANT EXECUTE ON dbo.SP06_TinhHieuSuatThang        TO MANAGER_ROLE;
GRANT EXECUTE ON dbo.FN01_TongNgayNghi             TO MANAGER_ROLE;
GRANT SELECT  ON dbo.FN02_TongCongOT               TO MANAGER_ROLE;
GO

-- Kiểm tra: role nào chạy được object nào (1 = được, 0 = bị từ chối).
DECLARE @KQ TABLE (Role SYSNAME, Object SYSNAME, DuocChay INT);
DECLARE @Obj TABLE (Ten SYSNAME, Quyen SYSNAME);
INSERT INTO @Obj VALUES
 (N'dbo.SP01_HopDongSapHetHan', N'EXECUTE'), (N'dbo.SP02_ChiPhiTuyenDung', N'EXECUTE'),
 (N'dbo.SP03_LichSuUngTuyen', N'EXECUTE'), (N'dbo.SP04_ThongKeNhanVienPhongBan', N'EXECUTE'),
 (N'dbo.SP05_NhanVienKhongNghiPhep', N'EXECUTE'), (N'dbo.SP06_TinhHieuSuatThang', N'EXECUTE'),
 (N'dbo.SP07_TinhLuongThang', N'EXECUTE'), (N'dbo.FN01_TongNgayNghi', N'EXECUTE'),
 (N'dbo.FN02_TongCongOT', N'SELECT'), (N'dbo.FN03_TyLeDau', N'EXECUTE');

EXECUTE AS USER = N'hrm_hr';
INSERT INTO @KQ SELECT N'HR_ROLE', Ten, HAS_PERMS_BY_NAME(Ten, N'OBJECT', Quyen) FROM @Obj;
REVERT;
EXECUTE AS USER = N'hrm_ketoan';
INSERT INTO @KQ SELECT N'ACCOUNTING_ROLE', Ten, HAS_PERMS_BY_NAME(Ten, N'OBJECT', Quyen) FROM @Obj;
REVERT;
EXECUTE AS USER = N'hrm_quanly';
INSERT INTO @KQ SELECT N'MANAGER_ROLE', Ten, HAS_PERMS_BY_NAME(Ten, N'OBJECT', Quyen) FROM @Obj;
REVERT;

SELECT Object,
       MAX(CASE WHEN Role = N'HR_ROLE'         THEN DuocChay END) AS HR_ROLE,
       MAX(CASE WHEN Role = N'ACCOUNTING_ROLE' THEN DuocChay END) AS ACCOUNTING_ROLE,
       MAX(CASE WHEN Role = N'MANAGER_ROLE'    THEN DuocChay END) AS MANAGER_ROLE
FROM @KQ GROUP BY Object ORDER BY Object;
GO
