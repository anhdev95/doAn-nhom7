/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 2. PHÂN QUYỀN (AUTHORIZATION)
   Database : IE103_HRM_Nhom7
   Mục tiêu :
     - 3 role: HR_ROLE, ACCOUNTING_ROLE, MANAGER_ROLE.
     - GRANT theo phạm vi công việc, DENY dữ liệu nhạy cảm/ngoài phạm vi, demo REVOKE.
     - Gán user (Authentication.sql) vào role.
     - Kiểm tra: cùng một thao tác, user A được phép – user B bị từ chối.
   Phạm vi (Master Handoff §6):
     - HR       : quản lý phần lớn dữ liệu nhân sự; chỉ XEM bảng lương.
     - Kế toán  : đọc dữ liệu cần cho tính lương; thao tác BANG_LUONG;
                  không xem dữ liệu tuyển dụng; không sửa hồ sơ/hợp đồng.
     - Quản lý  : chủ yếu đọc/xem báo cáo; được duyệt đơn nghỉ phép (chỉ cột TrangThai)
                  và nhập đánh giá; không sửa lương, hợp đồng, hồ sơ nhân viên.
   Điều kiện : chạy SAU Authentication.sql, bằng tài khoản sysadmin/db_owner.
   Chạy lại nhiều lần được: quyền cũ của 3 role bị thu hồi rồi cấp lại.
   ===================================================================== */

SET NOCOUNT ON;

USE IE103_HRM_Nhom7;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'hrm_hr')
BEGIN
    RAISERROR(N'Chưa có user hrm_hr – chạy Authentication.sql trước.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------------------------------------------------------------------
   Bước 1. Tạo role
   --------------------------------------------------------------------- */
IF DATABASE_PRINCIPAL_ID(N'HR_ROLE') IS NULL         CREATE ROLE HR_ROLE AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'ACCOUNTING_ROLE') IS NULL CREATE ROLE ACCOUNTING_ROLE AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'MANAGER_ROLE') IS NULL    CREATE ROLE MANAGER_ROLE AUTHORIZATION dbo;
GO

/* ---------------------------------------------------------------------
   Bước 2. Thu hồi quyền cũ của 3 role (để chạy lại script cho sạch)
   --------------------------------------------------------------------- */
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'REVOKE ' + pe.permission_name
             + CASE WHEN pe.class = 1 THEN N' ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(pe.major_id)) + N'.' + QUOTENAME(OBJECT_NAME(pe.major_id))
                    WHEN pe.class = 3 THEN N' ON SCHEMA::' + QUOTENAME(SCHEMA_NAME(pe.major_id))
                    ELSE N'' END
             + N' FROM ' + QUOTENAME(pr.name) + N' CASCADE;' + CHAR(10)
FROM sys.database_permissions AS pe
JOIN sys.database_principals AS pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN (N'HR_ROLE', N'ACCOUNTING_ROLE', N'MANAGER_ROLE')
  AND pe.class IN (0, 1, 3)
  AND pe.minor_id = 0;
-- Quyền cấp theo cột (minor_id <> 0): thu hồi kèm danh sách cột.
SELECT @sql += N'REVOKE ' + pe.permission_name + N' ON '
             + QUOTENAME(OBJECT_SCHEMA_NAME(pe.major_id)) + N'.' + QUOTENAME(OBJECT_NAME(pe.major_id))
             + N'(' + QUOTENAME(c.name) + N') FROM ' + QUOTENAME(pr.name) + N' CASCADE;' + CHAR(10)
FROM sys.database_permissions AS pe
JOIN sys.database_principals AS pr ON pr.principal_id = pe.grantee_principal_id
JOIN sys.columns AS c ON c.object_id = pe.major_id AND c.column_id = pe.minor_id
WHERE pr.name IN (N'HR_ROLE', N'ACCOUNTING_ROLE', N'MANAGER_ROLE')
  AND pe.class = 1 AND pe.minor_id <> 0;
EXEC sys.sp_executesql @sql;
GO

/* ---------------------------------------------------------------------
   Bước 3. HR_ROLE – Nhân sự
   --------------------------------------------------------------------- */
GRANT SELECT, INSERT, UPDATE ON dbo.PHONGBAN          TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.CHUCVU            TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.NHANVIEN          TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.HOPDONG           TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.DOT_TUYENDUNG     TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.VI_TRI_TUYENDUNG  TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.UNGVIEN           TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.UNG_TUYEN         TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.DAOTAO            TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.THAM_GIA_DAO_TAO  TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.DANH_GIA          TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.KHEN_THUONG       TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.CHAM_CONG         TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.DON_NGHI_PHEP     TO HR_ROLE;
GRANT SELECT, INSERT, UPDATE ON dbo.PHUC_LOI          TO HR_ROLE;
-- Bảng lương: HR chỉ được xem, không được sửa.
GRANT SELECT                 ON dbo.BANG_LUONG        TO HR_ROLE;
DENY  INSERT, UPDATE, DELETE ON dbo.BANG_LUONG        TO HR_ROLE;
GO

/* ---------------------------------------------------------------------
   Bước 4. ACCOUNTING_ROLE – Kế toán
   --------------------------------------------------------------------- */
-- Dữ liệu cần để tính lương: chỉ đọc.
GRANT SELECT ON dbo.PHONGBAN      TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.CHUCVU        TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.NHANVIEN      TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.HOPDONG       TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.CHAM_CONG     TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.DON_NGHI_PHEP TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.KHEN_THUONG   TO ACCOUNTING_ROLE;
GRANT SELECT ON dbo.PHUC_LOI      TO ACCOUNTING_ROLE;
-- Nghiệp vụ lương.
GRANT SELECT, INSERT, UPDATE ON dbo.BANG_LUONG TO ACCOUNTING_ROLE;
-- Không sửa hồ sơ nhân viên, hợp đồng.
DENY INSERT, UPDATE, DELETE ON dbo.NHANVIEN TO ACCOUNTING_ROLE;
DENY INSERT, UPDATE, DELETE ON dbo.HOPDONG  TO ACCOUNTING_ROLE;
-- Dữ liệu tuyển dụng (thông tin cá nhân ứng viên) ngoài phạm vi kế toán.
DENY SELECT ON dbo.UNGVIEN          TO ACCOUNTING_ROLE;
DENY SELECT ON dbo.UNG_TUYEN        TO ACCOUNTING_ROLE;
DENY SELECT ON dbo.DOT_TUYENDUNG    TO ACCOUNTING_ROLE;
DENY SELECT ON dbo.VI_TRI_TUYENDUNG TO ACCOUNTING_ROLE;
GO

/* ---------------------------------------------------------------------
   Bước 5. MANAGER_ROLE – Quản lý
   --------------------------------------------------------------------- */
GRANT SELECT ON dbo.PHONGBAN          TO MANAGER_ROLE;
GRANT SELECT ON dbo.CHUCVU            TO MANAGER_ROLE;
GRANT SELECT ON dbo.NHANVIEN          TO MANAGER_ROLE;
GRANT SELECT ON dbo.HOPDONG           TO MANAGER_ROLE;
GRANT SELECT ON dbo.DOT_TUYENDUNG     TO MANAGER_ROLE;
GRANT SELECT ON dbo.VI_TRI_TUYENDUNG  TO MANAGER_ROLE;
GRANT SELECT ON dbo.UNGVIEN           TO MANAGER_ROLE;
GRANT SELECT ON dbo.UNG_TUYEN         TO MANAGER_ROLE;
GRANT SELECT ON dbo.DAOTAO            TO MANAGER_ROLE;
GRANT SELECT ON dbo.THAM_GIA_DAO_TAO  TO MANAGER_ROLE;
GRANT SELECT ON dbo.DANH_GIA          TO MANAGER_ROLE;
GRANT SELECT ON dbo.KHEN_THUONG       TO MANAGER_ROLE;
GRANT SELECT ON dbo.CHAM_CONG         TO MANAGER_ROLE;
GRANT SELECT ON dbo.DON_NGHI_PHEP     TO MANAGER_ROLE;
GRANT SELECT ON dbo.BANG_LUONG        TO MANAGER_ROLE;
GRANT SELECT ON dbo.PHUC_LOI          TO MANAGER_ROLE;
-- Duyệt đơn nghỉ phép: chỉ được cập nhật cột TrangThai (quyền theo cột).
GRANT UPDATE ON dbo.DON_NGHI_PHEP (TrangThai) TO MANAGER_ROLE;
-- Đánh giá nhân viên.
GRANT INSERT, UPDATE ON dbo.DANH_GIA TO MANAGER_ROLE;
-- Hạn chế chỉnh dữ liệu nhạy cảm.
DENY INSERT, UPDATE, DELETE ON dbo.BANG_LUONG TO MANAGER_ROLE;
DENY INSERT, UPDATE, DELETE ON dbo.HOPDONG    TO MANAGER_ROLE;
DENY INSERT, UPDATE, DELETE ON dbo.NHANVIEN   TO MANAGER_ROLE;
GO

/* ---------------------------------------------------------------------
   Bước 6. Quyền EXECUTE trên Procedure/Function của phần Xử lý thông tin
   Cấp SAU khi Tuyến bàn giao object, theo đúng tên object, ví dụ:
       GRANT EXECUTE ON dbo.<TenProcedure> TO HR_ROLE;
       GRANT EXECUTE ON dbo.<TenProcedureLuong> TO ACCOUNTING_ROLE;
       GRANT SELECT  ON dbo.<TenTableFunction> TO MANAGER_ROLE;
   Không cấp EXECUTE ON SCHEMA::dbo cho 3 role: procedure chạy theo ownership
   chaining sẽ bỏ qua các DENY ở trên.
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   Bước 7. Gán user vào role
   --------------------------------------------------------------------- */
IF IS_ROLEMEMBER(N'HR_ROLE', N'hrm_hr') = 0               ALTER ROLE HR_ROLE ADD MEMBER hrm_hr;
IF IS_ROLEMEMBER(N'ACCOUNTING_ROLE', N'hrm_ketoan') = 0   ALTER ROLE ACCOUNTING_ROLE ADD MEMBER hrm_ketoan;
IF IS_ROLEMEMBER(N'MANAGER_ROLE', N'hrm_quanly') = 0      ALTER ROLE MANAGER_ROLE ADD MEMBER hrm_quanly;
GO

/* ---------------------------------------------------------------------
   Bước 8. Quyền cho login của Website Demo (hrm_web)
   Website cần: đọc 16 bảng, chạy Execute (COMMIT) của phần Xử lý thông tin,
   đọc định nghĩa object, xem quyền của các role, xem lịch sử backup/restore.
   --------------------------------------------------------------------- */
IF IS_ROLEMEMBER(N'db_datareader', N'hrm_web') = 0 ALTER ROLE db_datareader ADD MEMBER hrm_web;
IF IS_ROLEMEMBER(N'db_datawriter', N'hrm_web') = 0 ALTER ROLE db_datawriter ADD MEMBER hrm_web;
GRANT EXECUTE ON SCHEMA::dbo TO hrm_web;
GRANT VIEW DEFINITION TO hrm_web;
GO

USE msdb;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'hrm_web')
    CREATE USER hrm_web FOR LOGIN hrm_web;
GRANT SELECT ON dbo.backupset         TO hrm_web;
GRANT SELECT ON dbo.backupmediafamily TO hrm_web;
GRANT SELECT ON dbo.restorehistory    TO hrm_web;
GO

USE IE103_HRM_Nhom7;
GO

/* ---------------------------------------------------------------------
   Bước 9. Kiểm tra
   --------------------------------------------------------------------- */

-- 9.1 Role và thành viên
SELECT r.name AS RoleName, m.name AS ThanhVien
FROM sys.database_principals AS r
LEFT JOIN sys.database_role_members AS rm ON rm.role_principal_id = r.principal_id
LEFT JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
WHERE r.name IN (N'HR_ROLE', N'ACCOUNTING_ROLE', N'MANAGER_ROLE')
ORDER BY r.name, m.name;

-- 9.2 Bảng quyền GRANT/DENY của 3 role
SELECT pr.name AS RoleName,
       pe.state_desc AS TrangThai,
       pe.permission_name AS Quyen,
       OBJECT_NAME(pe.major_id) AS Bang,
       COL_NAME(pe.major_id, pe.minor_id) AS Cot
FROM sys.database_permissions AS pe
JOIN sys.database_principals AS pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN (N'HR_ROLE', N'ACCOUNTING_ROLE', N'MANAGER_ROLE')
ORDER BY pr.name, Bang, pe.state_desc, pe.permission_name;

-- 9.3 Cùng thao tác – user A được, user B bị từ chối.
--     Câu lệnh thử không trả dữ liệu, không thay đổi dữ liệu (WHERE 1 = 0) nhưng SQL Server vẫn kiểm tra quyền.
DECLARE @Thu TABLE (STT INT IDENTITY, NguoiDung SYSNAME, ThaoTac NVARCHAR(200), CauLenh NVARCHAR(400));
INSERT INTO @Thu (NguoiDung, ThaoTac, CauLenh) VALUES
    (N'hrm_hr',     N'Xem ứng viên (UNGVIEN)',          N'DECLARE @n INT; SELECT @n = COUNT(*) FROM dbo.UNGVIEN WHERE 1 = 0;'),
    (N'hrm_ketoan', N'Xem ứng viên (UNGVIEN)',          N'DECLARE @n INT; SELECT @n = COUNT(*) FROM dbo.UNGVIEN WHERE 1 = 0;'),
    (N'hrm_ketoan', N'Sửa bảng lương (BANG_LUONG)',     N'UPDATE dbo.BANG_LUONG SET KhauTru = KhauTru WHERE 1 = 0'),
    (N'hrm_hr',     N'Sửa bảng lương (BANG_LUONG)',     N'UPDATE dbo.BANG_LUONG SET KhauTru = KhauTru WHERE 1 = 0'),
    (N'hrm_quanly', N'Sửa bảng lương (BANG_LUONG)',     N'UPDATE dbo.BANG_LUONG SET KhauTru = KhauTru WHERE 1 = 0'),
    (N'hrm_hr',     N'Sửa hồ sơ nhân viên (NHANVIEN)',  N'UPDATE dbo.NHANVIEN SET DiaChi = DiaChi WHERE 1 = 0'),
    (N'hrm_ketoan', N'Sửa hồ sơ nhân viên (NHANVIEN)',  N'UPDATE dbo.NHANVIEN SET DiaChi = DiaChi WHERE 1 = 0'),
    (N'hrm_quanly', N'Duyệt đơn nghỉ (cột TrangThai)',  N'UPDATE dbo.DON_NGHI_PHEP SET TrangThai = TrangThai WHERE 1 = 0'),
    (N'hrm_quanly', N'Sửa lý do đơn nghỉ (cột LyDo)',   N'UPDATE dbo.DON_NGHI_PHEP SET LyDo = LyDo WHERE 1 = 0'),
    (N'hrm_quanly', N'Xem bảng lương (BANG_LUONG)',     N'DECLARE @n INT; SELECT @n = COUNT(*) FROM dbo.BANG_LUONG WHERE 1 = 0;');

DECLARE @KetQua TABLE (STT INT, NguoiDung SYSNAME, ThaoTac NVARCHAR(200), KetQua NVARCHAR(20), ThongBao NVARCHAR(400));
DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @Thu), @u SYSNAME, @tt NVARCHAR(200), @cl NVARCHAR(400);

WHILE @i <= @n
BEGIN
    SELECT @u = NguoiDung, @tt = ThaoTac, @cl = CauLenh FROM @Thu WHERE STT = @i;
    EXECUTE AS USER = @u;
    BEGIN TRY
        EXEC sys.sp_executesql @cl;
        REVERT;
        INSERT INTO @KetQua VALUES (@i, @u, @tt, N'ĐƯỢC PHÉP', NULL);
    END TRY
    BEGIN CATCH
        REVERT;
        INSERT INTO @KetQua VALUES (@i, @u, @tt, N'BỊ TỪ CHỐI', ERROR_MESSAGE());
    END CATCH
    SET @i += 1;
END

SELECT NguoiDung, ThaoTac, KetQua, ThongBao FROM @KetQua ORDER BY STT;
GO

/* ---------------------------------------------------------------------
   Bước 10. Demo REVOKE (GRANT → kiểm tra → REVOKE → kiểm tra)
   HR được cấp tạm quyền DELETE trên CHAM_CONG rồi bị thu hồi.
   --------------------------------------------------------------------- */
DECLARE @Revoke TABLE (Buoc NVARCHAR(60), KetQua NVARCHAR(20), ThongBao NVARCHAR(400));

GRANT DELETE ON dbo.CHAM_CONG TO HR_ROLE;
EXECUTE AS USER = N'hrm_hr';
BEGIN TRY
    DELETE FROM dbo.CHAM_CONG WHERE 1 = 0;
    REVERT;
    INSERT INTO @Revoke VALUES (N'Sau GRANT DELETE', N'ĐƯỢC PHÉP', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT INTO @Revoke VALUES (N'Sau GRANT DELETE', N'BỊ TỪ CHỐI', ERROR_MESSAGE());
END CATCH

REVOKE DELETE ON dbo.CHAM_CONG FROM HR_ROLE;
EXECUTE AS USER = N'hrm_hr';
BEGIN TRY
    DELETE FROM dbo.CHAM_CONG WHERE 1 = 0;
    REVERT;
    INSERT INTO @Revoke VALUES (N'Sau REVOKE DELETE', N'ĐƯỢC PHÉP', NULL);
END TRY
BEGIN CATCH
    REVERT;
    INSERT INTO @Revoke VALUES (N'Sau REVOKE DELETE', N'BỊ TỪ CHỐI', ERROR_MESSAGE());
END CATCH

SELECT N'hrm_hr' AS NguoiDung, N'DELETE CHAM_CONG' AS ThaoTac, Buoc, KetQua, ThongBao FROM @Revoke;
GO

SET NOEXEC OFF;
GO
