/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 5. BACKUP
   Quy trình: database đang hoạt động → BACKUP FULL → RESTORE VERIFYONLY
              → xác nhận file trong msdb → ghi nhận số dòng tại thời điểm backup.
   @ThuMucBackup:
     - NULL  : dùng thư mục backup mặc định của instance (service SQL Server chắc chắn ghi được).
     - Hoặc đường dẫn trên MÁY CHẠY SQL SERVER, vd N'C:\IE103\Backup\'
       (tài khoản service SQL Server phải có quyền ghi vào thư mục).
   Ghi chú : SQL Server Express không hỗ trợ COMPRESSION nên script không dùng.
   ===================================================================== */

SET NOCOUNT ON;

USE master;
GO

DECLARE @ThuMucBackup NVARCHAR(400) = NULL;

IF @ThuMucBackup IS NULL
    SET @ThuMucBackup = COALESCE(CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(400)),
                                 CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400)));

-- Thêm dấu phân cách cuối thư mục (Windows: \ – Linux: /)
DECLARE @PhanCach NCHAR(1) = CASE WHEN CHARINDEX(N'/', @ThuMucBackup) > 0 THEN N'/' ELSE N'\' END;
IF RIGHT(@ThuMucBackup, 1) NOT IN (N'\', N'/') SET @ThuMucBackup += @PhanCach;

DECLARE @FileBackup NVARCHAR(500) = @ThuMucBackup + N'IE103_HRM_Nhom7_FULL_'
                                  + FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmmss') + N'.bak';
DECLARE @TenBackup NVARCHAR(128) = N'IE103_HRM_Nhom7 Full ' + FORMAT(SYSDATETIME(), 'yyyy-MM-dd HH:mm:ss');

PRINT N'Backup ra file: ' + @FileBackup;

BACKUP DATABASE [IE103_HRM_Nhom7]
    TO DISK = @FileBackup
    WITH INIT, FORMAT, CHECKSUM, NAME = @TenBackup, STATS = 25;

-- Kiểm tra file backup đọc được và toàn vẹn
RESTORE VERIFYONLY FROM DISK = @FileBackup WITH CHECKSUM;
PRINT N'RESTORE VERIFYONLY: file backup hợp lệ.';

-- Xác nhận file backup trong lịch sử msdb
SELECT TOP (5)
       b.backup_finish_date                          AS ThoiGian,
       CASE b.type WHEN 'D' THEN N'Full' WHEN 'I' THEN N'Differential' WHEN 'L' THEN N'Log' END AS Loai,
       CAST(b.backup_size / 1048576.0 AS DECIMAL(10, 2)) AS DungLuongMB,
       b.has_backup_checksums                        AS CoChecksum,
       m.physical_device_name                        AS FileBackup
FROM msdb.dbo.backupset AS b
JOIN msdb.dbo.backupmediafamily AS m ON m.media_set_id = b.media_set_id
WHERE b.database_name = N'IE103_HRM_Nhom7'
ORDER BY b.backup_finish_date DESC;
GO

-- Số dòng các bảng tại thời điểm backup (để đối chiếu sau khi restore)
USE IE103_HRM_Nhom7;
GO
SELECT t.name AS Bang, SUM(p.rows) AS SoDong
FROM sys.tables AS t
JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.is_ms_shipped = 0
GROUP BY t.name
ORDER BY t.name;
GO
