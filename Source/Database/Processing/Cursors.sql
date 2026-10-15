/* =====================================================================
   CURSOR 1: SP06_TinhHieuSuatThang
   Duyệt từng bản DANH_GIA trong tháng:
     1. Tính hiệu suất từng KPI = KPIThucTe / KPIMucTieu * 100
     2. Kiểm tra tổng trọng số = 100 (sai -> báo lỗi, bỏ qua)
     3. HieuSuatKPITong = Σ(HieuSuatKPI × TrongSo) / 100
     4. Gán XepLoai theo ngưỡng
   PHẢI CHẠY TRƯỚC SP07 (tính lương cần HieuSuatKPITong).
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.SP06_TinhHieuSuatThang
    @Thang INT,
    @Nam   INT
AS
BEGIN
    SET NOCOUNT ON;
 
    DECLARE @MaDG        INT,
            @TongTrongSo DECIMAL(6,2),
            @HieuSuat    DECIMAL(6,2),
            @XepLoai     NVARCHAR(30),
            @SoThanhCong INT = 0,
            @SoLoi       INT = 0;
 
    DECLARE cur_DanhGia CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaDG
        FROM   DANH_GIA
        WHERE  Thang = @Thang
          AND  Nam   = @Nam;
 
    OPEN cur_DanhGia;
    FETCH NEXT FROM cur_DanhGia INTO @MaDG;
 
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 1. Hiệu suất từng KPI thành phần (%)
        UPDATE DANH_GIA_CHI_TIET
        SET    HieuSuatKPI = KPIThucTe * 100.0 / KPIMucTieu
        WHERE  MaDG = @MaDG;
 
        -- 2. Tổng trọng số và hiệu suất tổng
        SELECT @TongTrongSo = SUM(TrongSo),
               @HieuSuat    = SUM(HieuSuatKPI * TrongSo) / 100
        FROM   DANH_GIA_CHI_TIET
        WHERE  MaDG = @MaDG;
 
        IF @TongTrongSo IS NULL OR @TongTrongSo <> 100
        BEGIN
            PRINT N'Bỏ qua đánh giá ' + CAST(@MaDG AS NVARCHAR(10))
                + N': tổng trọng số = ' + ISNULL(CAST(@TongTrongSo AS NVARCHAR(10)), N'0')
                + N' (phải bằng 100).';
            SET @SoLoi += 1;
        END
        ELSE
        BEGIN
            -- 3. Xếp loại theo ngưỡng (thống nhất với dữ liệu mẫu, Source/Database/README.md)
            SET @XepLoai = CASE
                               WHEN @HieuSuat >= 90 THEN N'Xuất sắc'
                               WHEN @HieuSuat >= 80 THEN N'Giỏi'
                               WHEN @HieuSuat >= 65 THEN N'Khá'
                               WHEN @HieuSuat >= 50 THEN N'Trung bình'
                               ELSE N'Yếu'
                           END;
 
            -- 4. Cập nhật kết quả
            UPDATE DANH_GIA
            SET    HieuSuatKPITong = @HieuSuat,
                   XepLoai         = @XepLoai
            WHERE  MaDG = @MaDG;
 
            SET @SoThanhCong += 1;
        END
 
        FETCH NEXT FROM cur_DanhGia INTO @MaDG;
    END
 
    CLOSE cur_DanhGia;
    DEALLOCATE cur_DanhGia;
 
    PRINT N'Hoàn tất: ' + CAST(@SoThanhCong AS NVARCHAR(10)) + N' bản đánh giá đã tính, '
        + CAST(@SoLoi AS NVARCHAR(10)) + N' bản bị bỏ qua.';

    -- Xem kết quả
    SELECT dg.MaDG, dg.MaNV, nv.HoTen, dg.Thang, dg.Nam, dg.HieuSuatKPITong, dg.XepLoai
    FROM   DANH_GIA dg
    JOIN   NHANVIEN nv ON nv.MaNV = dg.MaNV
    WHERE  dg.Thang = @Thang AND dg.Nam = @Nam
    ORDER BY dg.HieuSuatKPITong DESC;
END
GO
 
 
/* =====================================================================
   CURSOR 2: SP07_TinhLuongThang
   Duyệt từng nhân viên đang làm, tính lương tháng và ghi vào BANG_LUONG.
 
   Công thức (ghi rõ trong báo cáo):
     LuongCoBan (thực tế) = LuongCoBan(HĐ) × (SoCong + NgayNghiPhep) / CongTheoThang
     LuongHieuSuat        = LuongHieuSuat(HĐ) × HieuSuatKPITong / 100
     PhuCap               = PhuCap(HĐ) + TienOT
     TienOT             = SoGioOT × LuongCoBan(HĐ) / CongTheoThang / 8 × 1.5
     TienThuong           = Σ KHEN_THUONG.SoTien trong tháng (Giấy khen có SoTien = 0)
     KhauTru              = LuongCoBan(HĐ) × 10.5%  (BHXH)
     LuongThucNhan        = LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru
   ===================================================================== */
CREATE OR ALTER PROCEDURE dbo.SP07_TinhLuongThang
    @Thang INT,
    @CongTheoThang DECIMAL(5,2),
    @Nam   INT
AS
BEGIN
    SET NOCOUNT ON;
 
    -- Hằng số chính sách
    DECLARE   @HeSoOT    DECIMAL(5,2) = 1.5,
            @TyLeBH    DECIMAL(5,3) = 0.105; --BHYT:1.5% + BHXH: 8% + BHTN: 1%
 
    -- Biến cho từng nhân viên
    DECLARE @MaNV          INT,
            @LuongCB_HD    DECIMAL(18,2),
            @LuongHS_HD    DECIMAL(18,2),
            @PhuCap_HD     DECIMAL(18,2),
            @SoCong        DECIMAL(5,2),
            @GioOT         DECIMAL(6,2),
            @NgayNghi      DECIMAL(5,2),
            @HieuSuat      DECIMAL(6,2),
            @TienThuong    DECIMAL(18,2),
            @LuongCoBan    DECIMAL(18,2),
            @LuongHieuSuat DECIMAL(18,2),
            @PhuCap        DECIMAL(18,2),
            @KhauTru       DECIMAL(18,2),
            @ThucNhan      DECIMAL(18,2),
            @SoThanhCong   INT = 0,
            @SoLoi         INT = 0;
 
    DECLARE cur_NhanVien CURSOR LOCAL FAST_FORWARD FOR
        SELECT  nv.MaNV, hd.LuongCoBan, hd.LuongHieuSuat, hd.PhuCap
        FROM    NHANVIEN nv
        LEFT JOIN HOPDONG hd ON hd.MaNV = nv.MaNV
                            AND hd.TrangThai = N'Hiệu lực'
        WHERE   nv.TrangThai = N'Đang làm';
 
    OPEN cur_NhanVien;
    FETCH NEXT FROM cur_NhanVien INTO @MaNV, @LuongCB_HD, @LuongHS_HD, @PhuCap_HD;
 
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @LuongCB_HD IS NULL
        BEGIN
            PRINT N'Bỏ qua NV ' + CAST(@MaNV AS NVARCHAR(10)) + N': không có hợp đồng hiệu lực.';
            SET @SoLoi += 1;
        END
        ELSE
        BEGIN
            BEGIN TRY
                -- 1. Gọi lại 2 function
                SELECT @SoCong = SoCong, @GioOT = TongGioOT
                FROM   dbo.FN02_TongCongOT(@MaNV, @Thang, @Nam);
 
                SET @NgayNghi = dbo.FN01_TongNgayNghi(@MaNV, @Thang, @Nam);
 
                -- 2. Hiệu suất KPI tháng (chưa đánh giá -> 0)
                SET @HieuSuat = NULL;
                SELECT @HieuSuat = HieuSuatKPITong
                FROM   DANH_GIA
                WHERE  MaNV = @MaNV AND Thang = @Thang AND Nam = @Nam;
                SET @HieuSuat = ISNULL(@HieuSuat, 0);
 
                -- 3. Khen thưởng cộng vào lương trong tháng (mọi hình thức có tiền thưởng)
                SELECT @TienThuong = ISNULL(SUM(SoTien), 0)
                FROM   KHEN_THUONG
                WHERE  MaNV = @MaNV
                  AND  MONTH(NgayKT) = @Thang
                  AND  YEAR(NgayKT)  = @Nam;
 
                -- 4. Tính các khoản
                SET @LuongCoBan    = @LuongCB_HD * (@SoCong + @NgayNghi) / @CongTheoThang;
                SET @LuongHieuSuat = ISNULL(@LuongHS_HD, 0) * @HieuSuat / 100;
                SET @PhuCap        = ISNULL(@PhuCap_HD, 0)
                                   + @GioOT * @LuongCB_HD / @CongTheoThang / 8 * @HeSoOT;
                SET @KhauTru       = @LuongCB_HD * @TyLeBH;
                SET @ThucNhan      = @LuongCoBan + @LuongHieuSuat + @PhuCap + @TienThuong - @KhauTru;
                IF @ThucNhan < 0 SET @ThucNhan = 0;
 
                -- 5. Ghi vào BANG_LUONG: đã có thì cập nhật, chưa có thì thêm mới
                IF EXISTS (SELECT 1 FROM BANG_LUONG WHERE MaNV = @MaNV AND Thang = @Thang AND Nam = @Nam)
                    UPDATE BANG_LUONG
                    SET    LuongCoBan = @LuongCoBan, LuongHieuSuat = @LuongHieuSuat,
                           PhuCap = @PhuCap, TienThuong = @TienThuong,
                           KhauTru = @KhauTru, LuongThucNhan = @ThucNhan
                    WHERE  MaNV = @MaNV AND Thang = @Thang AND Nam = @Nam;
                ELSE
                    -- MaLuong là IDENTITY: không truyền mã
                    INSERT INTO BANG_LUONG (MaNV, Thang, Nam, LuongCoBan, LuongHieuSuat,
                                            PhuCap, TienThuong, KhauTru, LuongThucNhan)
                    VALUES (@MaNV, @Thang, @Nam, @LuongCoBan, @LuongHieuSuat,
                            @PhuCap, @TienThuong, @KhauTru, @ThucNhan);
 
                SET @SoThanhCong += 1;
            END TRY
            BEGIN CATCH
                PRINT N'Lỗi khi tính lương NV ' + CAST(@MaNV AS NVARCHAR(10)) + N': ' + ERROR_MESSAGE();
                SET @SoLoi += 1;
            END CATCH
        END
 
        FETCH NEXT FROM cur_NhanVien INTO @MaNV, @LuongCB_HD, @LuongHS_HD, @PhuCap_HD;
    END
 
    CLOSE cur_NhanVien;
    DEALLOCATE cur_NhanVien;
 
    PRINT N'Hoàn tất: ' + CAST(@SoThanhCong AS NVARCHAR(10)) + N' nhân viên đã tính lương, '
        + CAST(@SoLoi AS NVARCHAR(10)) + N' nhân viên bị bỏ qua.';
 
    -- Xem kết quả
    SELECT bl.*, nv.HoTen
    FROM   BANG_LUONG bl
    JOIN   NHANVIEN nv ON nv.MaNV = bl.MaNV
    WHERE  bl.Thang = @Thang AND bl.Nam = @Nam
    ORDER BY bl.MaNV;
END
GO