-- TRG03 – Không chấm công cho nhân viên đã nghỉ việc hoặc trước ngày vào làm.
-- Website dừng ở lỗi đầu tiên: các bước THÀNH CÔNG đặt trước, bước BỊ CHẶN đặt cuối.
-- MaCC là IDENTITY: không truyền mã. Dữ liệu mẫu: NV 13, 19, 24 'Nghỉ việc'; NV 21 vào làm 01/07/2026.

-- 1. Nhân viên đang làm → THÀNH CÔNG
INSERT INTO CHAM_CONG (MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
VALUES (1, '2026-11-02', '08:00', '17:00', 0, N'Đúng giờ');
PRINT N'Bước 1 – THÀNH CÔNG: chấm công NV1 ngày 02/11.';

-- 2. Nhân viên đã nghỉ việc (NV13) → BỊ CHẶN (lỗi 50003)
PRINT N'Bước 2 – thử chấm công NV13 đã nghỉ việc (kỳ vọng: BỊ CHẶN)...';
INSERT INTO CHAM_CONG (MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
VALUES (13, '2026-11-02', '08:00', '17:00', 0, N'Đúng giờ');

-- Trường hợp BỊ CHẶN khác – thay cho bước 2 khi demo:
-- Chấm công NV21 trước ngày vào làm 01/07/2026 → lỗi 50004
-- INSERT INTO CHAM_CONG (MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
-- VALUES (21, '2026-06-15', '08:00', '17:00', 0, N'Đúng giờ');
-- Đổi bản chấm công của NV1 ngày 02/11 sang NV13 (kiểm tra UPDATE) → lỗi 50003
-- UPDATE CHAM_CONG SET MaNV = 13 WHERE MaNV = 1 AND Ngay = '2026-11-02';
