-- TRG05 – Xóa khóa đào tạo thì xóa luôn các lượt tham gia (INSTEAD OF DELETE).
-- MaDT, MaTG là IDENTITY: không truyền mã, lấy mã vừa tạo bằng SCOPE_IDENTITY().
DECLARE @DT1 INT, @DT2 INT;

-- Chuẩn bị data: khóa 1 có 2 người tham gia, khóa 2 chưa có ai
INSERT INTO DAOTAO (TenKhoaHoc, HinhThuc, NgayBatDau, NgayKetThuc, NoiDung)
VALUES (N'Kỹ năng giao tiếp', N'Trực tiếp', '2026-11-01', '2026-11-05', N'Giao tiếp nơi công sở');
SET @DT1 = SCOPE_IDENTITY();
INSERT INTO DAOTAO (TenKhoaHoc, HinhThuc, NgayBatDau, NgayKetThuc, NoiDung)
VALUES (N'An toàn thông tin', N'Trực tuyến', '2026-12-01', '2026-12-03', N'Bảo mật dữ liệu');
SET @DT2 = SCOPE_IDENTITY();

INSERT INTO THAM_GIA_DAO_TAO (MaNV, MaDT, NgayThamGia, KetQua, DanhGia)
VALUES (1, @DT1, '2026-11-01', N'Đang học', N'Tích cực'),
       (2, @DT1, '2026-11-01', N'Đang học', N'Tốt');
PRINT N'Chuẩn bị: khóa ' + CAST(@DT1 AS NVARCHAR(10)) + N' có 2 người tham gia, khóa ' + CAST(@DT2 AS NVARCHAR(10)) + N' chưa có ai.';

-- 1. Xóa khóa có người tham gia → THÀNH CÔNG, 2 bản ghi tham gia cũng bị xóa
DELETE FROM DAOTAO WHERE MaDT = @DT1;
PRINT N'Bước 1 – THÀNH CÔNG: xóa khóa có người tham gia.';
SELECT * FROM THAM_GIA_DAO_TAO WHERE MaDT = @DT1;   -- kỳ vọng: 0 dòng

-- 2. Xóa khóa chưa có ai tham gia → THÀNH CÔNG
DELETE FROM DAOTAO WHERE MaDT = @DT2;
PRINT N'Bước 2 – THÀNH CÔNG: xóa khóa chưa có ai tham gia.';
SELECT * FROM DAOTAO WHERE MaDT IN (@DT1, @DT2);    -- kỳ vọng: 0 dòng
