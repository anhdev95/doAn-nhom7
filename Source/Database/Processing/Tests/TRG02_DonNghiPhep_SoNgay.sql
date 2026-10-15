-- TRG02 – SoNgay phải khớp khoảng TuNgay–DenNgay (đơn 1 ngày được nghỉ 0.5).
-- Website dừng ở lỗi đầu tiên: các bước THÀNH CÔNG đặt trước, bước BỊ CHẶN đặt cuối.
-- MaDon là IDENTITY: không truyền mã, lấy mã vừa tạo bằng SCOPE_IDENTITY().
DECLARE @Don1 INT;

-- 1. Nghỉ 01–03/12, SoNgay = 3 → THÀNH CÔNG
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-12-01', '2026-12-03', 3, N'Việc riêng', N'Chờ duyệt');
SET @Don1 = SCOPE_IDENTITY();
PRINT N'Bước 1 – THÀNH CÔNG: 01–03/12, SoNgay = 3.';

-- 2. Nghỉ nửa ngày 10/12, SoNgay = 0.5 → THÀNH CÔNG
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-12-10', '2026-12-10', 0.5, N'Khám bệnh buổi sáng', N'Chờ duyệt');
PRINT N'Bước 2 – THÀNH CÔNG: nghỉ nửa ngày, SoNgay = 0.5.';

-- 3. Thêm nhiều dòng cùng lúc, đều đúng số ngày → THÀNH CÔNG
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (2, '2026-12-01', '2026-12-02', 2, N'Việc riêng', N'Chờ duyệt'),
       (3, '2026-12-05', '2026-12-09', 5, N'Về quê',    N'Chờ duyệt');
PRINT N'Bước 3 – THÀNH CÔNG: thêm 2 đơn cùng lúc (2 ngày, 5 ngày).';

-- 4. Nhập 5 ngày cho khoảng 15–17/12 (3 ngày) → BỊ CHẶN (lỗi 50002)
PRINT N'Bước 4 – thử nhập SoNgay = 5 cho khoảng 3 ngày (kỳ vọng: BỊ CHẶN)...';
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-12-15', '2026-12-17', 5, N'Du lịch', N'Chờ duyệt');

-- Trường hợp BỊ CHẶN khác (kiểm tra UPDATE) – thay cho bước 4 khi demo:
-- UPDATE DON_NGHI_PHEP SET DenNgay = '2026-12-01' WHERE MaDon = @Don1;   -- rút còn 1 ngày nhưng SoNgay vẫn là 3
