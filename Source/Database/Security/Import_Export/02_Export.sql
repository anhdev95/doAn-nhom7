/* =====================================================================
   IE103 – Nhóm 7 – AN TOÀN THÔNG TIN – 4. EXPORT
   Dataset  : (A) danh sách nhân viên   (B) bảng lương theo tháng
   Cách xuất:
     1. Chạy script này trong SSMS → chuột phải lưới kết quả → Save Results As… → .csv
     2. Hoặc chạy Export_bcp.cmd (bcp xuất thẳng ra file .tsv, dữ liệu lấy từ SQL Server)
     3. Hoặc SSMS → chuột phải database → Tasks → Export Data… (nguồn: câu truy vấn bên dưới)
   Kiểm tra : số dòng trong file = số dòng SoDongXuat ở cuối script.
   ===================================================================== */

SET NOCOUNT ON;

USE IE103_HRM_Nhom7;
GO

/* (A) Danh sách nhân viên – kèm phòng ban, chức vụ, người quản lý */
SELECT nv.MaNV,
       nv.HoTen,
       CONVERT(CHAR(10), nv.NgaySinh, 23)   AS NgaySinh,
       nv.GioiTinh,
       nv.Email,
       nv.SoDienThoai,
       CONVERT(CHAR(10), nv.NgayVaoLam, 23) AS NgayVaoLam,
       nv.TrangThai,
       pb.TenPB                              AS PhongBan,
       cv.TenCV                              AS ChucVu,
       ql.HoTen                              AS NguoiQuanLy
FROM dbo.NHANVIEN AS nv
LEFT JOIN dbo.PHONGBAN AS pb ON pb.MaPB = nv.MaPB
LEFT JOIN dbo.CHUCVU   AS cv ON cv.MaCV = nv.MaCV
LEFT JOIN dbo.NHANVIEN AS ql ON ql.MaNV = nv.MaQuanLy
ORDER BY nv.MaNV;
GO

/* (B) Bảng lương theo tháng – đổi @Thang/@Nam; để NULL để xuất tất cả */
DECLARE @Thang INT = NULL, @Nam INT = NULL;

SELECT bl.Nam, bl.Thang, bl.MaNV, nv.HoTen, pb.TenPB AS PhongBan,
       bl.LuongCoBan, bl.LuongHieuSuat, bl.PhuCap, bl.TienThuong, bl.KhauTru, bl.LuongThucNhan
FROM dbo.BANG_LUONG AS bl
JOIN dbo.NHANVIEN AS nv ON nv.MaNV = bl.MaNV
LEFT JOIN dbo.PHONGBAN AS pb ON pb.MaPB = nv.MaPB
WHERE (@Thang IS NULL OR bl.Thang = @Thang)
  AND (@Nam IS NULL OR bl.Nam = @Nam)
ORDER BY bl.Nam, bl.Thang, bl.MaNV;

/* Đối chiếu: số dòng phải bằng số dòng trong file đã xuất */
SELECT N'NHANVIEN'   AS DuLieu, (SELECT COUNT(*) FROM dbo.NHANVIEN) AS SoDongXuat
UNION ALL
SELECT N'BANG_LUONG', (SELECT COUNT(*) FROM dbo.BANG_LUONG
                       WHERE (@Thang IS NULL OR Thang = @Thang) AND (@Nam IS NULL OR Nam = @Nam));
GO
