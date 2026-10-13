/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 1. XÁC THỰC (AUTHENTICATION)
   Database : IE103_HRM_Nhom7
   Mục tiêu :
     - Tạo SQL login đại diện cho 3 nhóm người dùng: HR, Kế toán, Quản lý
       (+ 1 login riêng cho Website Demo).
     - Ánh xạ mỗi login thành database user trong IE103_HRM_Nhom7.
     - Kiểm tra: xác định login/user đang dùng, giả lập đăng nhập từng user,
       login không hợp lệ bị từ chối.
   Điều kiện :
     - SQL Server bật SQL Server and Windows Authentication mode (Mixed Mode).
     - Chạy bằng tài khoản sysadmin (vd. sa) SAU 01–04 của nhóm.
     - Chạy lại nhiều lần được: login đã có thì đặt lại mật khẩu demo.
   Thứ tự   : Authentication.sql → Authorization.sql
   ===================================================================== */

SET NOCOUNT ON;

USE master;
GO

IF DB_ID(N'IE103_HRM_Nhom7') IS NULL
BEGIN
    RAISERROR(N'Chưa có database IE103_HRM_Nhom7 – chạy 01_CreateDatabase.sql trước.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------------------------------------------------------------------
   Bước 1. Tạo / cập nhật SQL login
   Mật khẩu demo thỏa CHECK_POLICY (chữ hoa, chữ thường, số, ký tự đặc biệt).
   Không dùng ký tự # (file .env của Website hiểu # là comment).
   Đổi mật khẩu tại đây nếu cần trước khi demo.
   --------------------------------------------------------------------- */
DECLARE @TaiKhoan TABLE (LoginName SYSNAME PRIMARY KEY, MatKhau NVARCHAR(128), VaiTro NVARCHAR(100));
INSERT INTO @TaiKhoan (LoginName, MatKhau, VaiTro) VALUES
    (N'hrm_hr',     N'Hr@Nhom7_2026',     N'Nhân sự (HR)'),
    (N'hrm_ketoan', N'KeToan@Nhom7_2026', N'Kế toán'),
    (N'hrm_quanly', N'QuanLy@Nhom7_2026', N'Quản lý'),
    (N'hrm_web',    N'Web@Nhom7_2026',    N'Website Demo (Node.js)');

DECLARE @login SYSNAME, @matKhau NVARCHAR(128), @sql NVARCHAR(MAX);

WHILE EXISTS (SELECT 1 FROM @TaiKhoan)
BEGIN
    SELECT TOP (1) @login = LoginName, @matKhau = MatKhau FROM @TaiKhoan ORDER BY LoginName;

    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @login)
    BEGIN
        SET @sql = N'CREATE LOGIN ' + QUOTENAME(@login)
                 + N' WITH PASSWORD = N''' + REPLACE(@matKhau, N'''', N'''''') + N''''
                 + N', DEFAULT_DATABASE = [IE103_HRM_Nhom7], CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
        EXEC sys.sp_executesql @sql;
        PRINT N'Đã tạo login ' + @login;
    END
    ELSE
    BEGIN
        SET @sql = N'ALTER LOGIN ' + QUOTENAME(@login)
                 + N' WITH PASSWORD = N''' + REPLACE(@matKhau, N'''', N'''''') + N''''
                 + N', DEFAULT_DATABASE = [IE103_HRM_Nhom7], CHECK_POLICY = ON, CHECK_EXPIRATION = OFF; '
                 + N'ALTER LOGIN ' + QUOTENAME(@login) + N' ENABLE;';
        EXEC sys.sp_executesql @sql;
        PRINT N'Login ' + @login + N' đã có – đặt lại mật khẩu demo và ENABLE';
    END

    DELETE FROM @TaiKhoan WHERE LoginName = @login;
END
GO

/* ---------------------------------------------------------------------
   Bước 2. Tạo database user tương ứng trong IE103_HRM_Nhom7
   --------------------------------------------------------------------- */
USE IE103_HRM_Nhom7;
GO

DECLARE @ds TABLE (Ten SYSNAME PRIMARY KEY);
INSERT INTO @ds VALUES (N'hrm_hr'), (N'hrm_ketoan'), (N'hrm_quanly'), (N'hrm_web');
DECLARE @ten SYSNAME, @sql NVARCHAR(MAX);

WHILE EXISTS (SELECT 1 FROM @ds)
BEGIN
    SELECT TOP (1) @ten = Ten FROM @ds ORDER BY Ten;

    IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @ten)
        SET @sql = N'CREATE USER ' + QUOTENAME(@ten) + N' FOR LOGIN ' + QUOTENAME(@ten) + N' WITH DEFAULT_SCHEMA = dbo;';
    ELSE
        -- User đã có (vd. sau khi restore): gắn lại với login để tránh "orphaned user".
        SET @sql = N'ALTER USER ' + QUOTENAME(@ten) + N' WITH LOGIN = ' + QUOTENAME(@ten) + N', DEFAULT_SCHEMA = dbo;';
    EXEC sys.sp_executesql @sql;
    PRINT N'Database user ' + @ten + N' sẵn sàng';

    DELETE FROM @ds WHERE Ten = @ten;
END
GO

/* ---------------------------------------------------------------------
   Bước 3. Kiểm tra
   --------------------------------------------------------------------- */

-- 3.1 Danh sách login và database user vừa tạo
SELECT sp.name              AS SqlLogin,
       sp.type_desc         AS LoaiLogin,
       sp.is_disabled       AS BiKhoa,
       sp.default_database_name AS DatabaseMacDinh,
       dp.name              AS DatabaseUser
FROM sys.server_principals AS sp
LEFT JOIN sys.database_principals AS dp ON dp.sid = sp.sid
WHERE sp.name IN (N'hrm_hr', N'hrm_ketoan', N'hrm_quanly', N'hrm_web')
ORDER BY sp.name;

-- 3.2 Xác định login / database user đang dùng
SELECT SUSER_SNAME()     AS LoginHienTai,
       USER_NAME()       AS DatabaseUserHienTai,
       ORIGINAL_LOGIN()  AS LoginGoc,
       DB_NAME()         AS DatabaseHienTai;

-- 3.3 Giả lập đăng nhập bằng từng user hợp lệ
DECLARE @kq TABLE (LoginThu SYSNAME, KetQua NVARCHAR(30), LoginSauKhiDangNhap SYSNAME NULL, DatabaseUser SYSNAME NULL, ThongBao NVARCHAR(400) NULL);
DECLARE @thu TABLE (Ten SYSNAME PRIMARY KEY);
INSERT INTO @thu VALUES (N'hrm_hr'), (N'hrm_ketoan'), (N'hrm_quanly'), (N'hrm_khong_ton_tai');
DECLARE @t SYSNAME;

WHILE EXISTS (SELECT 1 FROM @thu)
BEGIN
    SELECT TOP (1) @t = Ten FROM @thu ORDER BY Ten;
    BEGIN TRY
        EXECUTE AS LOGIN = @t;
        INSERT INTO @kq VALUES (@t, N'Đăng nhập được', SUSER_SNAME(), USER_NAME(), NULL);
        REVERT;
    END TRY
    BEGIN CATCH
        -- 3.4 Login không hợp lệ (không tồn tại) bị từ chối
        INSERT INTO @kq VALUES (@t, N'Bị từ chối', NULL, NULL, ERROR_MESSAGE());
    END CATCH
    DELETE FROM @thu WHERE Ten = @t;
END

SELECT * FROM @kq ORDER BY KetQua, LoginThu;
GO

/* Kiểm tra đăng nhập THẬT (sai mật khẩu bị từ chối):
     - SSMS: Connect → SQL Server Authentication → hrm_hr / mật khẩu sai → lỗi 18456.
     - Website: trang /security → Test đăng nhập.                                   */

SET NOEXEC OFF;
GO
