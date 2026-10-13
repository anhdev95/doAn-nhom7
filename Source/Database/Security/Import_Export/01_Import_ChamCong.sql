/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 3. IMPORT
   Dataset  : chấm công  (file CSV → bảng CHAM_CONG)
   Quy trình: file CSV → BULK INSERT vào bảng tạm (#) → kiểm tra từng dòng
              → INSERT dòng hợp lệ vào CHAM_CONG → SELECT kiểm tra.
   File mẫu : Import_Export/cham_cong_import.csv (UTF-8, có dòng tiêu đề)
              MaNV,Ngay,GioVao,GioRa,SoGioOT,TrangThai
   Lưu ý    :
     - Đường dẫn @FileImport là đường dẫn TRÊN MÁY CHẠY SQL SERVER và tài khoản
       service SQL Server phải đọc được file (vd. copy vào C:\IE103\Import\).
     - Không tạo bảng mới trong database: dữ liệu trung gian nằm ở bảng tạm #.
     - Dòng lỗi được liệt kê kèm lý do, không được nhập.
     - MaCC: tự sinh nếu cột có IDENTITY; nếu không, lấy MAX(MaCC) + số thứ tự.
     - Cần SQL Server 2017+ (BULK INSERT FORMAT = 'CSV').
     - Tiếng Việt: trên Windows script đọc file theo UTF-8 (CODEPAGE 65001).
       SQL Server chạy trên Linux/Docker không hỗ trợ CODEPAGE → chữ có dấu bị sai;
       khi đó dùng SSMS → Tasks → Import Flat File… (cuối file).
   ===================================================================== */

SET NOCOUNT ON;

USE IE103_HRM_Nhom7;
GO

DECLARE @FileImport NVARCHAR(400) = N'C:\IE103\Import\cham_cong_import.csv';   -- ĐỔI theo máy demo

/* Bước 1. Đọc file CSV vào bảng tạm (mọi cột dạng chuỗi để tự kiểm tra kiểu) */
IF OBJECT_ID(N'tempdb..#ChamCongCSV') IS NOT NULL DROP TABLE #ChamCongCSV;
CREATE TABLE #ChamCongCSV (
    MaNV      NVARCHAR(50),
    Ngay      NVARCHAR(50),
    GioVao    NVARCHAR(50),
    GioRa     NVARCHAR(50),
    SoGioOT   NVARCHAR(50),
    TrangThai NVARCHAR(100)
);

-- CODEPAGE 65001 (UTF-8) chỉ khai báo trên Windows; SQL Server Linux mặc định đọc UTF-8 và không hỗ trợ CODEPAGE.
DECLARE @CodePage NVARCHAR(50) = CASE WHEN (SELECT host_platform FROM sys.dm_os_host_info) = N'Windows'
                                      THEN N', CODEPAGE = ''65001''' ELSE N'' END;
DECLARE @sql NVARCHAR(MAX) = N'BULK INSERT #ChamCongCSV FROM ' + QUOTENAME(@FileImport, N'''')
    + N' WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a''' + @CodePage + N', TABLOCK);';
EXEC sys.sp_executesql @sql;

-- Đánh số dòng theo thứ tự đã nạp (= thứ tự trong file; dòng 1 là tiêu đề nên bắt đầu từ 2).
ALTER TABLE #ChamCongCSV ADD DongTrongFile INT IDENTITY(2, 1);

/* Bước 2. Chuẩn hóa + kiểm tra từng dòng */
IF OBJECT_ID(N'tempdb..#ChamCongKiemTra') IS NOT NULL DROP TABLE #ChamCongKiemTra;
SELECT DongTrongFile,
       TRY_CONVERT(INT, LTRIM(RTRIM(MaNV)))                       AS MaNV,
       TRY_CONVERT(DATE, LTRIM(RTRIM(Ngay)), 23)                   AS Ngay,      -- yyyy-mm-dd
       TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(GioVao)), N''))     AS GioVao,
       TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(GioRa)), N''))      AS GioRa,
       TRY_CONVERT(DECIMAL(5, 2), NULLIF(LTRIM(RTRIM(SoGioOT)), N'')) AS SoGioOT,
       NULLIF(LTRIM(RTRIM(REPLACE(TrangThai, NCHAR(13), N''))), N'') AS TrangThai,
       COUNT(*) OVER (PARTITION BY TRY_CONVERT(INT, LTRIM(RTRIM(MaNV))), TRY_CONVERT(DATE, LTRIM(RTRIM(Ngay)), 23)) AS SoLanTrongFile,
       MaNV AS MaNV_Goc, Ngay AS Ngay_Goc, GioVao AS GioVao_Goc, GioRa AS GioRa_Goc, SoGioOT AS SoGioOT_Goc,
       CAST(NULL AS NVARCHAR(200)) AS LyDoLoi
INTO #ChamCongKiemTra
FROM #ChamCongCSV;

UPDATE k SET LyDoLoi =
    CASE
        WHEN k.MaNV IS NULL                                     THEN N'MaNV không phải số nguyên'
        WHEN k.Ngay IS NULL                                     THEN N'Ngay sai định dạng yyyy-mm-dd'
        WHEN k.GioVao IS NULL AND NULLIF(LTRIM(RTRIM(k.GioVao_Goc)), N'') IS NOT NULL THEN N'GioVao sai định dạng HH:mm'
        WHEN k.GioRa  IS NULL AND NULLIF(LTRIM(RTRIM(k.GioRa_Goc)),  N'') IS NOT NULL THEN N'GioRa sai định dạng HH:mm'
        WHEN k.SoGioOT IS NULL AND NULLIF(LTRIM(RTRIM(k.SoGioOT_Goc)), N'') IS NOT NULL THEN N'SoGioOT không phải số'
        WHEN k.SoGioOT < 0                                      THEN N'SoGioOT âm'
        WHEN k.GioVao IS NOT NULL AND k.GioRa IS NOT NULL AND k.GioRa < k.GioVao THEN N'GioRa trước GioVao'
        WHEN k.TrangThai IS NULL                                THEN N'Thiếu TrangThai'
        WHEN nv.MaNV IS NULL                                    THEN N'MaNV không tồn tại trong NHANVIEN'
        WHEN nv.TrangThai = N'Nghỉ việc'                        THEN N'Nhân viên đã nghỉ việc'
        WHEN EXISTS (SELECT 1 FROM dbo.CHAM_CONG c WHERE c.MaNV = k.MaNV AND c.Ngay = k.Ngay)
                                                                THEN N'Đã có chấm công (MaNV, Ngay) trong database'
        WHEN k.SoLanTrongFile > 1                               THEN N'Trùng (MaNV, Ngay) trong file'
    END
FROM #ChamCongKiemTra AS k
LEFT JOIN dbo.NHANVIEN AS nv ON nv.MaNV = k.MaNV;

/* Bước 3. Dữ liệu TRƯỚC khi import */
SELECT N'Trước import' AS ThoiDiem, COUNT(*) AS SoDongChamCong FROM dbo.CHAM_CONG;

/* Bước 4. Nhập các dòng hợp lệ (trong transaction) */
DECLARE @MaxMaCC INT, @SoDongNhap INT;
BEGIN TRY
    BEGIN TRANSACTION;

    IF COLUMNPROPERTY(OBJECT_ID(N'dbo.CHAM_CONG'), N'MaCC', 'IsIdentity') = 1
    BEGIN
        INSERT INTO dbo.CHAM_CONG (MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
        SELECT MaNV, Ngay, GioVao, GioRa, ISNULL(SoGioOT, 0), TrangThai
        FROM #ChamCongKiemTra WHERE LyDoLoi IS NULL;
    END
    ELSE
    BEGIN
        SELECT @MaxMaCC = ISNULL(MAX(MaCC), 0) FROM dbo.CHAM_CONG WITH (UPDLOCK, HOLDLOCK);
        INSERT INTO dbo.CHAM_CONG (MaCC, MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
        SELECT @MaxMaCC + ROW_NUMBER() OVER (ORDER BY DongTrongFile),
               MaNV, Ngay, GioVao, GioRa, ISNULL(SoGioOT, 0), TrangThai
        FROM #ChamCongKiemTra WHERE LyDoLoi IS NULL;
    END
    SET @SoDongNhap = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH

/* Bước 5. Kết quả */
SELECT (SELECT COUNT(*) FROM #ChamCongCSV) AS SoDongTrongFile,
       @SoDongNhap                          AS SoDongDaNhap,
       (SELECT COUNT(*) FROM #ChamCongKiemTra WHERE LyDoLoi IS NOT NULL) AS SoDongBiLoai;

SELECT DongTrongFile, MaNV_Goc AS MaNV, Ngay_Goc AS Ngay, LyDoLoi
FROM #ChamCongKiemTra WHERE LyDoLoi IS NOT NULL ORDER BY DongTrongFile;

/* Bước 6. SELECT kiểm tra dữ liệu SAU khi import */
SELECT N'Sau import' AS ThoiDiem, COUNT(*) AS SoDongChamCong FROM dbo.CHAM_CONG;

SELECT c.*
FROM dbo.CHAM_CONG AS c
JOIN #ChamCongKiemTra AS k ON k.MaNV = c.MaNV AND k.Ngay = c.Ngay AND k.LyDoLoi IS NULL
ORDER BY c.MaNV, c.Ngay;
GO

/* Cách khác (không cần script): SSMS → chuột phải database → Tasks → Import Flat File…
   chọn cham_cong_import.csv → bảng đích CHAM_CONG. Sau đó SELECT kiểm tra như Bước 6. */
