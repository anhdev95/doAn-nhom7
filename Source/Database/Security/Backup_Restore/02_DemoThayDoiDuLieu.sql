/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 6. RESTORE (bước chuẩn bị)
   Thay đổi dữ liệu demo SAU khi đã chạy 01_Backup.sql, để chứng minh restore
   đưa dữ liệu về đúng thời điểm backup.
   Thay đổi: ghi đè MoTa của phòng ban có MaPB nhỏ nhất (không xóa dòng nào,
   không ảnh hưởng khóa ngoại). Dữ liệu gốc được in ra để đối chiếu.
   ===================================================================== */

SET NOCOUNT ON;

USE IE103_HRM_Nhom7;
GO

DECLARE @MaPB INT = (SELECT MIN(MaPB) FROM dbo.PHONGBAN);

IF @MaPB IS NULL
BEGIN
    RAISERROR(N'PHONGBAN chưa có dữ liệu – chạy 04_SeedData.sql trước.', 16, 1);
    RETURN;
END

SELECT N'TRƯỚC khi thay đổi' AS ThoiDiem, MaPB, TenPB, MoTa FROM dbo.PHONGBAN WHERE MaPB = @MaPB;

UPDATE dbo.PHONGBAN
SET MoTa = N'[DEMO RESTORE] Dữ liệu bị thay đổi lúc ' + FORMAT(SYSDATETIME(), 'yyyy-MM-dd HH:mm:ss')
WHERE MaPB = @MaPB;

SELECT N'SAU khi thay đổi' AS ThoiDiem, MaPB, TenPB, MoTa FROM dbo.PHONGBAN WHERE MaPB = @MaPB;
GO
