@echo off
REM =====================================================================
REM IE103 - Nhom 7 - AN TOAN THONG TIN - 4. EXPORT bang bcp (Windows)
REM Xuat du lieu THAT tu SQL Server ra file .tsv (phan cach bang TAB, UTF-8).
REM Mo file bang Excel: Data > From Text/CSV > Delimiter: Tab.
REM
REM Cach chay: mo Command Prompt tai thu muc nay, sua SERVER/OUT neu can, roi:
REM     Export_bcp.cmd                     (Windows Authentication)
REM     Export_bcp.cmd sa MatKhau          (SQL Server Authentication)
REM =====================================================================
setlocal
set SERVER=localhost
set DB=IE103_HRM_Nhom7
set OUT=%~dp0export
if not exist "%OUT%" mkdir "%OUT%"

if "%~1"=="" (set AUTH=-T) else (set AUTH=-U %1 -P %2)

echo MaNV	HoTen	NgaySinh	GioiTinh	Email	SoDienThoai	NgayVaoLam	TrangThai	PhongBan	ChucVu> "%OUT%\NhanVien.tsv"
bcp "SELECT nv.MaNV, nv.HoTen, CONVERT(CHAR(10), nv.NgaySinh, 23), nv.GioiTinh, nv.Email, nv.SoDienThoai, CONVERT(CHAR(10), nv.NgayVaoLam, 23), nv.TrangThai, pb.TenPB, cv.TenCV FROM %DB%.dbo.NHANVIEN nv LEFT JOIN %DB%.dbo.PHONGBAN pb ON pb.MaPB = nv.MaPB LEFT JOIN %DB%.dbo.CHUCVU cv ON cv.MaCV = nv.MaCV ORDER BY nv.MaNV" queryout "%OUT%\NhanVien.tmp" -c -C 65001 -t "\t" -S %SERVER% %AUTH%
if errorlevel 1 goto loi
type "%OUT%\NhanVien.tmp" >> "%OUT%\NhanVien.tsv"
del "%OUT%\NhanVien.tmp"

echo Nam	Thang	MaNV	HoTen	LuongCoBan	LuongHieuSuat	PhuCap	TienThuong	KhauTru	LuongThucNhan> "%OUT%\BangLuong.tsv"
bcp "SELECT bl.Nam, bl.Thang, bl.MaNV, nv.HoTen, bl.LuongCoBan, bl.LuongHieuSuat, bl.PhuCap, bl.TienThuong, bl.KhauTru, bl.LuongThucNhan FROM %DB%.dbo.BANG_LUONG bl JOIN %DB%.dbo.NHANVIEN nv ON nv.MaNV = bl.MaNV ORDER BY bl.Nam, bl.Thang, bl.MaNV" queryout "%OUT%\BangLuong.tmp" -c -C 65001 -t "\t" -S %SERVER% %AUTH%
if errorlevel 1 goto loi
type "%OUT%\BangLuong.tmp" >> "%OUT%\BangLuong.tsv"
del "%OUT%\BangLuong.tmp"

echo.
echo Da xuat: %OUT%\NhanVien.tsv va %OUT%\BangLuong.tsv
echo Doi chieu so dong voi ket qua cuoi cua 02_Export.sql
goto :eof

:loi
echo Loi khi chay bcp. Kiem tra SERVER, quyen dang nhap va bcp da duoc cai (SQL Server Command Line Utilities).
exit /b 1
