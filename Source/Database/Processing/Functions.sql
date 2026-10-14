--1. Function FN01_TongNgayNghi
CREATE OR ALTER FUNCTION dbo.FN01_TongNgayNghi (@MaNV INT, @Thang INT, @Nam INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @DauThang  DATE = DATEFROMPARTS(@Nam, @Thang, 1);
    DECLARE @CuoiThang DATE = EOMONTH(@DauThang);
    DECLARE @Tong      DECIMAL(5,2);
 
    SELECT @Tong = SUM(
               CASE
                   WHEN TuNgay >= @DauThang AND DenNgay <= @CuoiThang
                       THEN ISNULL(SoNgay, DATEDIFF(DAY, TuNgay, DenNgay) + 1)
                   ELSE DATEDIFF(DAY,
                                 CASE WHEN TuNgay  > @DauThang  THEN TuNgay  ELSE @DauThang  END,
                                 CASE WHEN DenNgay < @CuoiThang THEN DenNgay ELSE @CuoiThang END) + 1
               END)
    FROM   DON_NGHI_PHEP
    WHERE  MaNV = @MaNV
      AND  TrangThai = N'Đã duyệt'
      AND  TuNgay  <= @CuoiThang          -- đơn có giao với tháng
      AND  DenNgay >= @DauThang;
 
    RETURN ISNULL(@Tong, 0);
END
GO
 
 
--2. Function FN02_TongCongOT

CREATE OR ALTER FUNCTION dbo.FN02_TongCongOT (@MaNV INT, @Thang INT, @Nam INT)
RETURNS TABLE
AS
RETURN (
    -- Có đi làm = mọi trạng thái trừ 'Vắng' (dữ liệu: Đúng giờ · Đi muộn · Về sớm · Vắng)
    SELECT  ISNULL(SUM(CASE WHEN TrangThai IN (N'Đúng giờ', N'Đi muộn', N'Về sớm') THEN 1 ELSE 0 END), 0) AS SoCong,
            ISNULL(SUM(SoGioOT), 0)                                                                    AS TongGioOT
    FROM    CHAM_CONG
    WHERE   MaNV = @MaNV
      AND   MONTH(Ngay) = @Thang
      AND   YEAR(Ngay)  = @Nam
);
GO
 
 
--3. Function FN03_TyLeDau

CREATE OR ALTER FUNCTION dbo.FN03_TyLeDau (@MaDotTD INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @TongHoSo INT, @SoDau INT;
 
    SELECT @TongHoSo = COUNT(*),
           @SoDau    = SUM(CASE WHEN ut.TrangThai = N'Đã tuyển' THEN 1 ELSE 0 END)
    FROM   UNG_TUYEN ut
    JOIN   VI_TRI_TUYENDUNG vt ON ut.MaViTri = vt.MaViTri
    WHERE  vt.MaDotTD = @MaDotTD;
 
    IF @TongHoSo = 0
        RETURN NULL;
 
    RETURN CAST(@SoDau * 100.0 / @TongHoSo AS DECIMAL(5,2));
END
GO