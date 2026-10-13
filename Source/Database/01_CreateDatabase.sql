/* =====================================================================
   IE103 – Nhóm 7 – Hệ thống CSDL quản lý nhân sự
   01_CreateDatabase.sql – Tạo database IE103_HRM_Nhom7
   ---------------------------------------------------------------------
   - File dữ liệu/log đặt ở thư mục mặc định của instance (chạy được trên mọi máy).
   - Collation Vietnamese_CI_AS: sắp xếp/so sánh tiếng Việt đúng (Ă, Â, Đ…), không phân biệt hoa thường.
   - Recovery model SIMPLE: phù hợp demo (backup FULL – xem Security/Backup_Restore).
   - Database đã tồn tại → dừng lại, không xóa. Muốn tạo lại từ đầu: đặt @TaoLai = 1
     (XÓA TOÀN BỘ dữ liệu hiện có).
   Thứ tự: 01 → 02_CreateTables → 03_Constraints → 04_SeedData
   ===================================================================== */

SET NOCOUNT ON;
USE master;
GO

DECLARE @TaoLai BIT = 0;   -- ĐỔI THÀNH 1 để xóa và tạo lại database

IF DB_ID(N'IE103_HRM_Nhom7') IS NOT NULL
BEGIN
    IF @TaoLai = 0
    BEGIN
        RAISERROR(N'Database IE103_HRM_Nhom7 đã tồn tại – giữ nguyên. Đặt @TaoLai = 1 nếu muốn xóa và tạo lại.', 16, 1);
        SET NOEXEC ON;   -- bỏ qua các lệnh còn lại của script
    END
    ELSE
    BEGIN
        ALTER DATABASE [IE103_HRM_Nhom7] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [IE103_HRM_Nhom7];
        PRINT N'Đã xóa database IE103_HRM_Nhom7 cũ.';
    END
END
GO

CREATE DATABASE [IE103_HRM_Nhom7] COLLATE Vietnamese_CI_AS;
GO

ALTER DATABASE [IE103_HRM_Nhom7] SET RECOVERY SIMPLE;
ALTER DATABASE [IE103_HRM_Nhom7] SET MULTI_USER;
GO

-- Kiểm tra
SELECT d.name AS DatabaseName, d.collation_name AS Collation, d.recovery_model_desc AS RecoveryModel,
       d.compatibility_level AS CompatibilityLevel, d.create_date AS NgayTao
FROM sys.databases AS d
WHERE d.name = N'IE103_HRM_Nhom7';
GO

SET NOEXEC OFF;
GO
