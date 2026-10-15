-- TRG04 – Mỗi nhân viên chỉ có 1 hợp đồng 'Hiệu lực'.
-- Website dừng ở lỗi đầu tiên: các bước THÀNH CÔNG đặt trước, bước BỊ CHẶN đặt cuối.
-- MaHD là IDENTITY: không truyền mã, lấy mã vừa tạo bằng SCOPE_IDENTITY().
DECLARE @HD1 INT;

-- 0. Chuẩn bị: dữ liệu mẫu NV1, NV2 đã có HĐ 'Hiệu lực' → cho hết hạn để bắt đầu từ trạng thái chưa có HĐ hiệu lực
UPDATE HOPDONG SET TrangThai = N'Hết hạn' WHERE MaNV IN (1, 2) AND TrangThai = N'Hiệu lực';
PRINT N'Bước 0 – chuẩn bị: HĐ hiệu lực hiện tại của NV1, NV2 chuyển sang Hết hạn.';

-- 1. NV1 có HĐ hiệu lực đầu tiên → THÀNH CÔNG
INSERT INTO HOPDONG (MaNV, LoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, LuongHieuSuat, PhuCap, TrangThai)
VALUES (1, N'Xác định thời hạn', '2025-01-01', '2026-12-31', 10000000, 2000000, 500000, N'Hiệu lực');
SET @HD1 = SCOPE_IDENTITY();
PRINT N'Bước 1 – THÀNH CÔNG: NV1 có HĐ hiệu lực (MaHD = ' + CAST(@HD1 AS NVARCHAR(10)) + N').';

-- 2. NV2 có HĐ hiệu lực → THÀNH CÔNG (trigger đếm riêng từng nhân viên)
INSERT INTO HOPDONG (MaNV, LoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, LuongHieuSuat, PhuCap, TrangThai)
VALUES (2, N'Không xác định thời hạn', '2025-03-01', NULL, 12000000, 3000000, 500000, N'Hiệu lực');
PRINT N'Bước 2 – THÀNH CÔNG: NV2 có HĐ hiệu lực.';

-- 3. Tái ký đúng quy trình: cho HĐ bước 1 hết hạn, rồi mới thêm HĐ mới → THÀNH CÔNG
UPDATE HOPDONG SET TrangThai = N'Hết hạn' WHERE MaHD = @HD1;
INSERT INTO HOPDONG (MaNV, LoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, LuongHieuSuat, PhuCap, TrangThai)
VALUES (1, N'Xác định thời hạn', '2027-01-01', '2028-12-31', 11000000, 2000000, 500000, N'Hiệu lực');
PRINT N'Bước 3 – THÀNH CÔNG: NV1 tái ký sau khi HĐ cũ hết hạn.';

-- 4. NV1 thêm HĐ hiệu lực thứ hai → BỊ CHẶN (lỗi 50005)
PRINT N'Bước 4 – thử thêm HĐ hiệu lực thứ hai cho NV1 (kỳ vọng: BỊ CHẶN)...';
INSERT INTO HOPDONG (MaNV, LoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, LuongHieuSuat, PhuCap, TrangThai)
VALUES (1, N'Thử việc', '2027-01-01', '2027-02-28', 9000000, 0, 0, N'Hiệu lực');

-- Trường hợp BỊ CHẶN khác (kiểm tra UPDATE) – thay cho bước 4 khi demo:
-- UPDATE HOPDONG SET TrangThai = N'Hiệu lực' WHERE MaHD = @HD1;   -- mở lại HĐ bước 1
