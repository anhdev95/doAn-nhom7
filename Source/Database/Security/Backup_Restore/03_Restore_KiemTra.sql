/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 6. RESTORE (an toàn – ra database bản sao)
   Restore bản backup FULL mới nhất của IE103_HRM_Nhom7 thành database
   IE103_HRM_Nhom7_RestoreTest, rồi SELECT so sánh với database đang chạy.
   Không đụng tới database chính → chạy được cả khi Website đang mở.
   @FileBackup: NULL = lấy bản backup FULL mới nhất trong msdb; hoặc đường dẫn file .bak.
   ===================================================================== */

SET NOCOUNT ON;

USE master;
GO

DECLARE @FileBackup NVARCHAR(500) = NULL;
DECLARE @DbKiemTra SYSNAME = N'IE103_HRM_Nhom7_RestoreTest';

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
PRINT N'Restore từ file: ' + @FileBackup;

-- Đặt file dữ liệu/log của bản sao vào thư mục mặc định của instance, đổi tên để không trùng DB chính.
DECLARE @ThuMucData NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(400));
DECLARE @ThuMucLog  NVARCHAR(400) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(400));

-- Danh sách file logic trong bản backup
DECLARE @FileList TABLE (
    LogicalName NVARCHAR(128), PhysicalName NVARCHAR(260), [Type] CHAR(1), FileGroupName NVARCHAR(128),
    Size NUMERIC(20, 0), MaxSize NUMERIC(20, 0), FileId BIGINT, CreateLSN NUMERIC(25, 0), DropLSN NUMERIC(25, 0),
    UniqueId UNIQUEIDENTIFIER, ReadOnlyLSN NUMERIC(25, 0), ReadWriteLSN NUMERIC(25, 0), BackupSizeInBytes BIGINT,
    SourceBlockSize INT, FileGroupId INT, LogGroupGUID UNIQUEIDENTIFIER, DifferentialBaseLSN NUMERIC(25, 0),
    DifferentialBaseGUID UNIQUEIDENTIFIER, IsReadOnly BIT, IsPresent BIT, TDEThumbprint VARBINARY(32), SnapshotUrl NVARCHAR(360)
);
DECLARE @sqlFileList NVARCHAR(MAX) = N'RESTORE FILELISTONLY FROM DISK = N''' + REPLACE(@FileBackup, N'''', N'''''') + N'''';
INSERT INTO @FileList EXEC (@sqlFileList);

DECLARE @Move NVARCHAR(MAX) = N'';
SELECT @Move += N', MOVE N''' + REPLACE(LogicalName, N'''', N'''''') + N''' TO N'''
              + CASE WHEN [Type] = 'L' THEN @ThuMucLog ELSE @ThuMucData END
              + @DbKiemTra + N'_' + CAST(FileId AS NVARCHAR(10))
              + CASE WHEN [Type] = 'L' THEN N'.ldf' WHEN FileId = 1 THEN N'.mdf' ELSE N'.ndf' END + N''''
FROM @FileList;

-- Bản sao cũ (nếu có) được thay thế
IF DB_ID(@DbKiemTra) IS NOT NULL
    EXEC (N'ALTER DATABASE [' + @DbKiemTra + N'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;');

DECLARE @sql NVARCHAR(MAX) = N'RESTORE DATABASE ' + QUOTENAME(@DbKiemTra)
    + N' FROM DISK = N''' + REPLACE(@FileBackup, N'''', N'''''') + N''''
    + N' WITH REPLACE, RECOVERY, CHECKSUM, STATS = 25' + @Move + N';';
EXEC sys.sp_executesql @sql;

EXEC (N'ALTER DATABASE [' + @DbKiemTra + N'] SET MULTI_USER;');
PRINT N'Đã restore thành database ' + @DbKiemTra;
GO

/* SELECT kiểm tra 1: dòng PHONGBAN bị thay đổi ở 02_DemoThayDoiDuLieu.sql */
SELECT N'Database đang chạy (đã bị thay đổi)' AS Nguon, MaPB, TenPB, MoTa
FROM IE103_HRM_Nhom7.dbo.PHONGBAN WHERE MaPB = (SELECT MIN(MaPB) FROM IE103_HRM_Nhom7.dbo.PHONGBAN)
UNION ALL
SELECT N'Bản restore (dữ liệu lúc backup)', MaPB, TenPB, MoTa
FROM IE103_HRM_Nhom7_RestoreTest.dbo.PHONGBAN WHERE MaPB = (SELECT MIN(MaPB) FROM IE103_HRM_Nhom7_RestoreTest.dbo.PHONGBAN);

/* SELECT kiểm tra 2: số dòng từng bảng ở 2 database */
SELECT COALESCE(a.Bang, b.Bang) AS Bang, a.SoDong AS SoDong_DangChay, b.SoDong AS SoDong_BanRestore,
       CASE WHEN a.SoDong = b.SoDong THEN N'Khớp' ELSE N'Khác' END AS SoSanh
FROM (SELECT t.name AS Bang, SUM(p.rows) AS SoDong
        FROM IE103_HRM_Nhom7.sys.tables t
        JOIN IE103_HRM_Nhom7.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
       WHERE t.is_ms_shipped = 0 GROUP BY t.name) AS a
FULL JOIN (SELECT t.name AS Bang, SUM(p.rows) AS SoDong
             FROM IE103_HRM_Nhom7_RestoreTest.sys.tables t
             JOIN IE103_HRM_Nhom7_RestoreTest.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
            WHERE t.is_ms_shipped = 0 GROUP BY t.name) AS b ON b.Bang = a.Bang
ORDER BY Bang;

/* Lịch sử restore */
SELECT TOP (5) rh.restore_date AS ThoiGian, rh.destination_database_name AS DatabaseDich,
       rh.user_name AS NguoiThucHien, m.physical_device_name AS TuFile
FROM msdb.dbo.restorehistory AS rh
JOIN msdb.dbo.backupset AS b ON b.backup_set_id = rh.backup_set_id
JOIN msdb.dbo.backupmediafamily AS m ON m.media_set_id = b.media_set_id
WHERE rh.destination_database_name LIKE N'IE103_HRM_Nhom7%'
ORDER BY rh.restore_date DESC;
GO

/* Dọn dẹp sau demo (tuỳ chọn):
   ALTER DATABASE IE103_HRM_Nhom7_RestoreTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   DROP DATABASE IE103_HRM_Nhom7_RestoreTest;                                          */
