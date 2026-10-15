-- TRG01 – Không cho nhân viên có 2 đơn nghỉ (chờ duyệt / đã duyệt) trùng thời gian.
-- Website dừng ở lỗi đầu tiên: các bước THÀNH CÔNG đặt trước, bước BỊ CHẶN đặt cuối.
-- MaDon là IDENTITY: không truyền mã, lấy mã vừa tạo bằng SCOPE_IDENTITY().
DECLARE @Don1 INT;

-- 1. NV1 nộp đơn 10–12/11, chờ duyệt → THÀNH CÔNG
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-11-10', '2026-11-12', 3, N'Việc gia đình', N'Chờ duyệt');
SET @Don1 = SCOPE_IDENTITY();
PRINT N'Bước 1 – THÀNH CÔNG: NV1 nộp đơn 10–12/11 (MaDon = ' + CAST(@Don1 AS NVARCHAR(10)) + N').';

-- 2. NV2 nghỉ cùng ngày → THÀNH CÔNG (trigger chỉ xét cùng nhân viên)
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (2, '2026-11-10', '2026-11-12', 3, N'Khám sức khỏe', N'Chờ duyệt');
PRINT N'Bước 2 – THÀNH CÔNG: NV2 nghỉ cùng ngày với NV1.';

-- 3. Từ chối đơn ở bước 1, NV1 nộp lại đơn 12–14/11 (trùng ngày 12/11 với đơn đã từ chối) → THÀNH CÔNG
UPDATE DON_NGHI_PHEP SET TrangThai = N'Từ chối' WHERE MaDon = @Don1;
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-11-12', '2026-11-14', 3, N'Du lịch', N'Chờ duyệt');
PRINT N'Bước 3 – THÀNH CÔNG: đơn bị từ chối không tính trùng.';

-- 4. NV1 nộp thêm đơn 13/11, trùng đơn bước 3 đang chờ duyệt → BỊ CHẶN (lỗi 50001)
PRINT N'Bước 4 – thử nộp đơn 13/11 trùng đơn đang chờ duyệt (kỳ vọng: BỊ CHẶN)...';
INSERT INTO DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai)
VALUES (1, '2026-11-13', '2026-11-13', 1, N'Việc riêng', N'Chờ duyệt');

-- Trường hợp BỊ CHẶN khác (kiểm tra UPDATE) – thay cho bước 4 khi demo:
-- UPDATE DON_NGHI_PHEP SET TrangThai = N'Chờ duyệt' WHERE MaDon = @Don1;   -- mở lại đơn bước 1, trùng đơn bước 3
