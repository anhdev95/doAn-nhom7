/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 6. RESTORE (ghi đè database chính)
   CẢNH BÁO: thay toàn bộ IE103_HRM_Nhom7 bằng bản backup – mọi thay đổi sau
   thời điểm backup sẽ mất. Chỉ dùng khi đã có bản backup an toàn.
   Trước khi chạy:
     1. DỪNG Website (Ctrl+C) và đóng các cửa sổ SSMS đang dùng IE103_HRM_Nhom7.
     2. Đổi @XacNhanGhiDe = 1.
   Sau khi chạy: khởi động lại Website, kiểm tra trang Database Tables.
   ===================================================================== */

SET NOCOUNT ON;

USE master;
GO

DECLARE @XacNhanGhiDe BIT = 0;                 -- ĐỔI THÀNH 1 để thực hiện
DECLARE @FileBackup NVARCHAR(500) = NULL;      -- NULL = bản backup FULL mới nhất trong msdb

IF @XacNhanGhiDe = 0
BEGIN
    RAISERROR(N'Chưa xác nhận: đặt @XacNhanGhiDe = 1 nếu chắc chắn muốn ghi đè IE103_HRM_Nhom7.', 16, 1);
    RETURN;
END

IF @FileBackup IS NULL
    SELECT TOP (1) @FileBackup = m.physical_device_name
    FROM msdb.dbo.backupset AS b
    JOIN msdb.dbo.backupmediafamily AS m ON m.media_set_id = b.media_set_id
    WHERE b.database_name = N'IE103_HRM_Nhom7' AND b.type = 'D'
    ORDER BY b.backup_finish_date DESC;

IF @FileBackup IS NULL
BEGIN
    RAISERROR(N'Chưa có bản backup FULL nào – chạy 01_Backup.sql trước.', 16, 1);
    RETURN;
END

-- Kiểm tra file trước khi ngắt kết nối người dùng
RESTORE VERIFYONLY FROM DISK = @FileBackup WITH CHECKSUM;
PRINT N'Restore ghi đè từ file: ' + @FileBackup;

ALTER DATABASE [IE103_HRM_Nhom7] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
BEGIN TRY
    RESTORE DATABASE [IE103_HRM_Nhom7] FROM DISK = @FileBackup WITH REPLACE, RECOVERY, CHECKSUM, STATS = 25;
END TRY
BEGIN CATCH
    ALTER DATABASE [IE103_HRM_Nhom7] SET MULTI_USER;
    THROW;
END CATCH
ALTER DATABASE [IE103_HRM_Nhom7] SET MULTI_USER;
PRINT N'Đã restore IE103_HRM_Nhom7.';
GO

/* SELECT kiểm tra: dòng PHONGBAN đã trở về giá trị lúc backup */
SELECT MaPB, TenPB, MoTa
FROM IE103_HRM_Nhom7.dbo.PHONGBAN
WHERE MaPB = (SELECT MIN(MaPB) FROM IE103_HRM_Nhom7.dbo.PHONGBAN);

SELECT TOP (3) rh.restore_date AS ThoiGian, rh.destination_database_name AS DatabaseDich,
       rh.user_name AS NguoiThucHien, m.physical_device_name AS TuFile
FROM msdb.dbo.restorehistory AS rh
JOIN msdb.dbo.backupset AS b ON b.backup_set_id = rh.backup_set_id
JOIN msdb.dbo.backupmediafamily AS m ON m.media_set_id = b.media_set_id
WHERE rh.destination_database_name = N'IE103_HRM_Nhom7'
ORDER BY rh.restore_date DESC;
GO
