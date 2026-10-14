--1. Stored procedure SP01_HopDongSapHetHan
CREATE OR ALTER PROCEDURE dbo.SP01_HopDongSapHetHan
    @SoNgay  INT = 30,          -- số ngày tới, mặc định 30
    @SoLuong INT = NULL OUTPUT  -- trả về: số hợp đồng sắp hết hạn (= NULL: website gọi không cần truyền)
AS
BEGIN
    SET NOCOUNT ON;

    IF @SoNgay IS NULL OR @SoNgay <= 0
    BEGIN
        THROW 50101, N'Số ngày phải lớn hơn 0.', 1;
    END

    DECLARE @HomNay DATE = CAST(GETDATE() AS DATE);

    -- Danh sách hợp đồng hiệu lực sẽ hết hạn trong @SoNgay ngày tới
    SELECT  hd.MaHD,
            nv.MaNV,
            nv.HoTen,
            pb.TenPB,
            hd.LoaiHD,
            hd.NgayKetThuc,
            DATEDIFF(DAY, @HomNay, hd.NgayKetThuc) AS SoNgayConLai
    FROM    HOPDONG hd
    JOIN    NHANVIEN nv ON hd.MaNV = nv.MaNV
    JOIN    PHONGBAN pb ON nv.MaPB = pb.MaPB
    WHERE   hd.TrangThai = N'Hiệu lực'
      AND   hd.NgayKetThuc BETWEEN @HomNay AND DATEADD(DAY, @SoNgay, @HomNay)
    ORDER BY SoNgayConLai;      -- sắp hết hạn trước lên đầu

    -- Gán số lượng vào tham số OUTPUT
    SELECT  @SoLuong = COUNT(*)
    FROM    HOPDONG
    WHERE   TrangThai = N'Hiệu lực'
      AND   NgayKetThuc BETWEEN @HomNay AND DATEADD(DAY, @SoNgay, @HomNay);

    SELECT @SoLuong AS SoLuong;  -- website không đọc tham số OUTPUT nên trả thêm dạng bảng
END
GO

--2. Stored procedure SP02_ChiPhiTuyenDung

CREATE OR ALTER PROCEDURE dbo.SP02_ChiPhiTuyenDung
    @Thang INT,
    @Nam   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TongChiPhi DECIMAL(18,2),
            @SoHoSo     INT,
            @SoDaTuyen  INT;

    -- 1. Tổng chi phí các đợt tuyển dụng bắt đầu trong tháng
    SELECT @TongChiPhi = ISNULL(SUM(ChiPhi), 0)
    FROM   DOT_TUYENDUNG
    WHERE  MONTH(NgayBatDau) = @Thang
      AND  YEAR(NgayBatDau)  = @Nam;

    -- 2. Số hồ sơ và số người được tuyển của các đợt đó
    SELECT @SoHoSo    = COUNT(*),
           @SoDaTuyen = ISNULL(SUM(CASE WHEN ut.TrangThai = N'Đã tuyển' THEN 1 ELSE 0 END), 0)
    FROM   UNG_TUYEN ut
    JOIN   VI_TRI_TUYENDUNG vt ON ut.MaViTri = vt.MaViTri
    JOIN   DOT_TUYENDUNG d     ON vt.MaDotTD = d.MaDotTD
    WHERE  MONTH(d.NgayBatDau) = @Thang
      AND  YEAR(d.NgayBatDau)  = @Nam;

    -- 3. Trả kết quả
    SELECT @Thang      AS Thang,
           @Nam        AS Nam,
           @TongChiPhi AS TongChiPhi,
           @SoHoSo     AS SoHoSo,
           @SoDaTuyen  AS SoNguoiDuocTuyen,
           CASE WHEN @SoHoSo = 0 THEN 0
                ELSE CAST(@SoDaTuyen * 100.0 / @SoHoSo AS DECIMAL(5,2))
           END         AS TyLeDau_PhanTram;
END
GO

--3. Stored procedure SP03_LichSuUngTuyen
CREATE OR ALTER PROCEDURE dbo.SP03_LichSuUngTuyen
    @MaUV    INT,
    @SoLuong INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Kiểm tra ứng viên có tồn tại
    IF NOT EXISTS (SELECT 1 FROM UNGVIEN WHERE MaUV = @MaUV)
    BEGIN
        THROW 50103, N'Không tìm thấy ứng viên với mã đã nhập.', 1;
    END

    -- Danh sách các lần ứng tuyển
    SELECT  uv.MaUV,
            uv.HoTen,
            d.TenDotTD,
            vt.TenViTri,
            pb.TenPB,
            ut.NgayUngTuyen,
            ut.VongPhongVan,
            ut.KetQua,
            ut.TrangThai
    FROM    UNG_TUYEN ut
    JOIN    UNGVIEN uv          ON uv.MaUV    = ut.MaUV
    JOIN    VI_TRI_TUYENDUNG vt ON vt.MaViTri = ut.MaViTri
    JOIN    DOT_TUYENDUNG d     ON d.MaDotTD  = vt.MaDotTD
    JOIN    PHONGBAN pb         ON pb.MaPB    = vt.MaPB
    WHERE   ut.MaUV = @MaUV
    ORDER BY ut.NgayUngTuyen DESC;

    -- Số lần ứng tuyển
    SELECT @SoLuong = COUNT(*)
    FROM   UNG_TUYEN
    WHERE  MaUV = @MaUV;

    SELECT @SoLuong AS SoLuong;  -- website không đọc tham số OUTPUT nên trả thêm dạng bảng
END
GO

--4.Stored procedure SP04_ThongKeNhanVienPhongBan
CREATE OR ALTER PROCEDURE dbo.SP04_ThongKeNhanVienPhongBan
    @MaPB INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
 
    IF @MaPB IS NOT NULL AND NOT EXISTS (SELECT 1 FROM PHONGBAN WHERE MaPB = @MaPB)
    BEGIN
        THROW 50104, N'Không tìm thấy phòng ban với mã đã nhập.', 1;
    END
 
    SELECT  pb.MaPB,
            pb.TenPB,
            SUM(CASE WHEN nv.TrangThai = N'Đang làm'  THEN 1 ELSE 0 END) AS DangLam,
            SUM(CASE WHEN nv.TrangThai = N'Tạm nghỉ'  THEN 1 ELSE 0 END) AS TamNghi,
            SUM(CASE WHEN nv.TrangThai = N'Nghỉ việc' THEN 1 ELSE 0 END) AS NghiViec,
            COUNT(nv.MaNV)                                               AS TongHoSo
    FROM    PHONGBAN pb
    LEFT JOIN NHANVIEN nv ON nv.MaPB = pb.MaPB       -- phòng ban chưa có ai vẫn hiện số 0
    WHERE   @MaPB IS NULL OR pb.MaPB = @MaPB
    GROUP BY pb.MaPB, pb.TenPB
    ORDER BY DangLam DESC;
END
GO
--5.Stored procedure SP05_NhanVienKhongNghiPhep

CREATE OR ALTER PROCEDURE dbo.SP05_NhanVienKhongNghiPhep
    @Nam     INT,
    @SoLuong INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @DauNam  DATE = DATEFROMPARTS(@Nam, 1, 1);
    DECLARE @CuoiNam DATE = DATEFROMPARTS(@Nam, 12, 31);
 
    SELECT  nv.MaNV,
            nv.HoTen,
            pb.TenPB,
            nv.NgayVaoLam
    INTO    #KetQua
    FROM    NHANVIEN nv
    JOIN    PHONGBAN pb ON pb.MaPB = nv.MaPB
    WHERE   nv.TrangThai = N'Đang làm'
      AND   nv.NgayVaoLam <= @CuoiNam
      AND   NOT EXISTS (                              -- không có đơn đã duyệt nào giao với năm
                SELECT 1
                FROM   DON_NGHI_PHEP d
                WHERE  d.MaNV = nv.MaNV
                  AND  d.TrangThai = N'Đã duyệt'
                  AND  d.TuNgay  <= @CuoiNam
                  AND  d.DenNgay >= @DauNam
            );
 
    SELECT * FROM #KetQua ORDER BY TenPB, HoTen;
    SELECT @SoLuong = COUNT(*) FROM #KetQua;
    SELECT @SoLuong AS SoLuong;  -- website không đọc tham số OUTPUT nên trả thêm dạng bảng
 
    DROP TABLE #KetQua;
END
GO
