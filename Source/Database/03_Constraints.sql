/* =====================================================================
   IE103 – Nhóm 7 – Hệ thống CSDL quản lý nhân sự
   03_Constraints.sql – Khóa ngoại, UNIQUE, CHECK, DEFAULT, index
   ---------------------------------------------------------------------
   Theo Master Handoff §3 (quan hệ), §4 (ràng buộc) và các miền giá trị nhóm đã chốt.
   - FK dùng NO ACTION: không cho xóa dữ liệu cha khi còn dữ liệu con (bảo toàn lịch sử nhân sự).
   - Các quy tắc nghiệp vụ nhiều dòng/nhiều bảng (trùng đơn nghỉ đã duyệt, chấm công nhân viên
     đã nghỉ việc, nhiều hợp đồng hiệu lực, tuyển vượt số lượng, tính lương thực nhận…) KHÔNG đặt ở đây:
     thuộc phần Trigger/Procedure (Tuyến).
   Chạy sau 02_CreateTables.sql.
   ===================================================================== */

SET NOCOUNT ON;
USE IE103_HRM_Nhom7;
GO

IF OBJECT_ID(N'dbo.FK_NHANVIEN_PHONGBAN', N'F') IS NOT NULL
BEGIN
    RAISERROR(N'Ràng buộc đã được tạo trước đó – giữ nguyên. Muốn tạo lại từ đầu: chạy 01 với @TaoLai = 1 rồi 02, 03.', 16, 1);
    SET NOEXEC ON;
END
GO

/* =====================================================================
   1. KHÓA NGOẠI (16) – Master Handoff §3
   ===================================================================== */
ALTER TABLE dbo.NHANVIEN         ADD CONSTRAINT FK_NHANVIEN_PHONGBAN          FOREIGN KEY (MaPB)     REFERENCES dbo.PHONGBAN (MaPB);
ALTER TABLE dbo.NHANVIEN         ADD CONSTRAINT FK_NHANVIEN_CHUCVU            FOREIGN KEY (MaCV)     REFERENCES dbo.CHUCVU (MaCV);
ALTER TABLE dbo.NHANVIEN         ADD CONSTRAINT FK_NHANVIEN_QUANLY            FOREIGN KEY (MaQuanLy) REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.HOPDONG          ADD CONSTRAINT FK_HOPDONG_NHANVIEN           FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.VI_TRI_TUYENDUNG ADD CONSTRAINT FK_VITRI_DOTTUYENDUNG         FOREIGN KEY (MaDotTD)  REFERENCES dbo.DOT_TUYENDUNG (MaDotTD);
ALTER TABLE dbo.VI_TRI_TUYENDUNG ADD CONSTRAINT FK_VITRI_PHONGBAN             FOREIGN KEY (MaPB)     REFERENCES dbo.PHONGBAN (MaPB);
ALTER TABLE dbo.UNG_TUYEN        ADD CONSTRAINT FK_UNGTUYEN_UNGVIEN           FOREIGN KEY (MaUV)     REFERENCES dbo.UNGVIEN (MaUV);
ALTER TABLE dbo.UNG_TUYEN        ADD CONSTRAINT FK_UNGTUYEN_VITRI             FOREIGN KEY (MaViTri)  REFERENCES dbo.VI_TRI_TUYENDUNG (MaViTri);
ALTER TABLE dbo.THAM_GIA_DAO_TAO ADD CONSTRAINT FK_THAMGIA_NHANVIEN           FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.THAM_GIA_DAO_TAO ADD CONSTRAINT FK_THAMGIA_DAOTAO             FOREIGN KEY (MaDT)     REFERENCES dbo.DAOTAO (MaDT);
ALTER TABLE dbo.DANH_GIA         ADD CONSTRAINT FK_DANHGIA_NHANVIEN           FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.KHEN_THUONG      ADD CONSTRAINT FK_KHENTHUONG_NHANVIEN        FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.CHAM_CONG        ADD CONSTRAINT FK_CHAMCONG_NHANVIEN          FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.DON_NGHI_PHEP    ADD CONSTRAINT FK_DONNGHIPHEP_NHANVIEN       FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.BANG_LUONG       ADD CONSTRAINT FK_BANGLUONG_NHANVIEN         FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
ALTER TABLE dbo.PHUC_LOI         ADD CONSTRAINT FK_PHUCLOI_NHANVIEN           FOREIGN KEY (MaNV)     REFERENCES dbo.NHANVIEN (MaNV);
GO

/* =====================================================================
   2. UNIQUE (9) – Master Handoff §4
   ===================================================================== */
ALTER TABLE dbo.NHANVIEN         ADD CONSTRAINT UQ_NHANVIEN_CCCD           UNIQUE (CCCD);
ALTER TABLE dbo.NHANVIEN         ADD CONSTRAINT UQ_NHANVIEN_Email          UNIQUE (Email);
ALTER TABLE dbo.PHONGBAN         ADD CONSTRAINT UQ_PHONGBAN_TenPB          UNIQUE (TenPB);
ALTER TABLE dbo.CHUCVU           ADD CONSTRAINT UQ_CHUCVU_TenCV            UNIQUE (TenCV);
ALTER TABLE dbo.UNGVIEN          ADD CONSTRAINT UQ_UNGVIEN_Email           UNIQUE (Email);
ALTER TABLE dbo.CHAM_CONG        ADD CONSTRAINT UQ_CHAMCONG_MaNV_Ngay      UNIQUE (MaNV, Ngay);
ALTER TABLE dbo.BANG_LUONG       ADD CONSTRAINT UQ_BANGLUONG_MaNV_Thang_Nam UNIQUE (MaNV, Thang, Nam);
ALTER TABLE dbo.UNG_TUYEN        ADD CONSTRAINT UQ_UNGTUYEN_MaUV_MaViTri   UNIQUE (MaUV, MaViTri);
ALTER TABLE dbo.THAM_GIA_DAO_TAO ADD CONSTRAINT UQ_THAMGIA_MaNV_MaDT       UNIQUE (MaNV, MaDT);
GO

/* =====================================================================
   3. CHECK
   ===================================================================== */

-- 3.1 Miền giá trị đã chốt
ALTER TABLE dbo.NHANVIEN      ADD CONSTRAINT CK_NHANVIEN_GioiTinh   CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác'));
ALTER TABLE dbo.NHANVIEN      ADD CONSTRAINT CK_NHANVIEN_TrangThai  CHECK (TrangThai IN (N'Đang làm', N'Tạm nghỉ', N'Nghỉ việc'));
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT CK_HOPDONG_TrangThai   CHECK (TrangThai IN (N'Hiệu lực', N'Hết hạn', N'Chấm dứt'));
ALTER TABLE dbo.DON_NGHI_PHEP ADD CONSTRAINT CK_DONNGHIPHEP_TrangThai CHECK (TrangThai IN (N'Chờ duyệt', N'Đã duyệt', N'Từ chối'));
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT CK_UNGTUYEN_TrangThai  CHECK (TrangThai IN (N'Đang xử lý', N'Đã tuyển', N'Từ chối'));
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT CK_UNGTUYEN_KetQua     CHECK (KetQua IN (N'Chưa có kết quả', N'Đạt', N'Không đạt'));

-- 3.2 Số lượng, điểm, thời lượng (Master Handoff §4)
ALTER TABLE dbo.DANH_GIA         ADD CONSTRAINT CK_DANHGIA_Diem         CHECK (Diem BETWEEN 0 AND 100);
ALTER TABLE dbo.CHAM_CONG        ADD CONSTRAINT CK_CHAMCONG_SoGioOT     CHECK (SoGioOT >= 0);
ALTER TABLE dbo.VI_TRI_TUYENDUNG ADD CONSTRAINT CK_VITRI_SoLuong        CHECK (SoLuong > 0);
ALTER TABLE dbo.VI_TRI_TUYENDUNG ADD CONSTRAINT CK_VITRI_SoVongPV       CHECK (SoVongPV > 0);
ALTER TABLE dbo.UNG_TUYEN        ADD CONSTRAINT CK_UNGTUYEN_VongPhongVan CHECK (VongPhongVan >= 0);
ALTER TABLE dbo.DON_NGHI_PHEP    ADD CONSTRAINT CK_DONNGHIPHEP_SoNgay   CHECK (SoNgay > 0);
ALTER TABLE dbo.BANG_LUONG       ADD CONSTRAINT CK_BANGLUONG_Thang      CHECK (Thang BETWEEN 1 AND 12);
ALTER TABLE dbo.BANG_LUONG       ADD CONSTRAINT CK_BANGLUONG_Nam        CHECK (Nam BETWEEN 2000 AND 2100);

-- 3.3 Khoảng thời gian (Master Handoff §4)
ALTER TABLE dbo.DON_NGHI_PHEP ADD CONSTRAINT CK_DONNGHIPHEP_KhoangNgay CHECK (DenNgay >= TuNgay);
ALTER TABLE dbo.DOT_TUYENDUNG ADD CONSTRAINT CK_DOTTUYENDUNG_KhoangNgay CHECK (NgayKetThuc >= NgayBatDau);
ALTER TABLE dbo.DAOTAO        ADD CONSTRAINT CK_DAOTAO_KhoangNgay      CHECK (NgayKetThuc >= NgayBatDau);
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT CK_HOPDONG_KhoangNgay     CHECK (NgayKetThuc IS NULL OR NgayKetThuc > NgayBatDau);
ALTER TABLE dbo.PHUC_LOI      ADD CONSTRAINT CK_PHUCLOI_KhoangNgay     CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);

-- 3.4 Các khoản tiền không âm (Master Handoff §4)
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT CK_HOPDONG_Tien       CHECK (LuongCoBan >= 0 AND LuongHieuSuat >= 0 AND PhuCap >= 0);
ALTER TABLE dbo.DOT_TUYENDUNG ADD CONSTRAINT CK_DOTTUYENDUNG_ChiPhi CHECK (ChiPhi >= 0);
ALTER TABLE dbo.KHEN_THUONG   ADD CONSTRAINT CK_KHENTHUONG_SoTien  CHECK (SoTien >= 0);
ALTER TABLE dbo.PHUC_LOI      ADD CONSTRAINT CK_PHUCLOI_GiaTri     CHECK (GiaTri >= 0);
ALTER TABLE dbo.BANG_LUONG    ADD CONSTRAINT CK_BANGLUONG_Tien     CHECK (LuongCoBan >= 0 AND LuongHieuSuat >= 0 AND PhuCap >= 0
                                                                        AND TienThuong >= 0 AND KhauTru >= 0 AND LuongThucNhan >= 0);
-- Ghi chú: công thức LuongThucNhan = LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru
-- do phần SQL nghiệp vụ (Tuyến) bảo đảm; dữ liệu mẫu tuân thủ, kiểm tra bằng `npm run check-db`.

-- 3.5 Tính hợp lệ của hồ sơ nhân viên
ALTER TABLE dbo.NHANVIEN ADD CONSTRAINT CK_NHANVIEN_CCCD       CHECK (LEN(CCCD) = 12 AND CCCD NOT LIKE '%[^0-9]%');
ALTER TABLE dbo.NHANVIEN ADD CONSTRAINT CK_NHANVIEN_Email      CHECK (Email LIKE '_%@_%._%');
ALTER TABLE dbo.UNGVIEN  ADD CONSTRAINT CK_UNGVIEN_Email       CHECK (Email LIKE '_%@_%._%');
ALTER TABLE dbo.NHANVIEN ADD CONSTRAINT CK_NHANVIEN_NgayVaoLam CHECK (NgayVaoLam > NgaySinh);
ALTER TABLE dbo.NHANVIEN ADD CONSTRAINT CK_NHANVIEN_QuanLy     CHECK (MaQuanLy IS NULL OR MaQuanLy <> MaNV);
GO

/* =====================================================================
   4. DEFAULT – giá trị mặc định khi INSERT không truyền
   ===================================================================== */
ALTER TABLE dbo.NHANVIEN      ADD CONSTRAINT DF_NHANVIEN_TrangThai     DEFAULT (N'Đang làm')         FOR TrangThai;
ALTER TABLE dbo.NHANVIEN      ADD CONSTRAINT DF_NHANVIEN_NgayVaoLam    DEFAULT (CAST(GETDATE() AS DATE)) FOR NgayVaoLam;
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT DF_HOPDONG_TrangThai      DEFAULT (N'Hiệu lực')         FOR TrangThai;
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT DF_HOPDONG_LuongHieuSuat  DEFAULT (0)                   FOR LuongHieuSuat;
ALTER TABLE dbo.HOPDONG       ADD CONSTRAINT DF_HOPDONG_PhuCap         DEFAULT (0)                   FOR PhuCap;
ALTER TABLE dbo.DOT_TUYENDUNG ADD CONSTRAINT DF_DOTTUYENDUNG_ChiPhi    DEFAULT (0)                   FOR ChiPhi;
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT DF_UNGTUYEN_NgayUngTuyen  DEFAULT (CAST(GETDATE() AS DATE)) FOR NgayUngTuyen;
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT DF_UNGTUYEN_VongPhongVan  DEFAULT (0)                   FOR VongPhongVan;
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT DF_UNGTUYEN_KetQua        DEFAULT (N'Chưa có kết quả')  FOR KetQua;
ALTER TABLE dbo.UNG_TUYEN     ADD CONSTRAINT DF_UNGTUYEN_TrangThai     DEFAULT (N'Đang xử lý')       FOR TrangThai;
ALTER TABLE dbo.THAM_GIA_DAO_TAO ADD CONSTRAINT DF_THAMGIA_NgayThamGia DEFAULT (CAST(GETDATE() AS DATE)) FOR NgayThamGia;
ALTER TABLE dbo.DANH_GIA      ADD CONSTRAINT DF_DANHGIA_NgayDanhGia    DEFAULT (CAST(GETDATE() AS DATE)) FOR NgayDanhGia;
ALTER TABLE dbo.KHEN_THUONG   ADD CONSTRAINT DF_KHENTHUONG_NgayKT      DEFAULT (CAST(GETDATE() AS DATE)) FOR NgayKT;
ALTER TABLE dbo.KHEN_THUONG   ADD CONSTRAINT DF_KHENTHUONG_SoTien      DEFAULT (0)                   FOR SoTien;
ALTER TABLE dbo.CHAM_CONG     ADD CONSTRAINT DF_CHAMCONG_Ngay          DEFAULT (CAST(GETDATE() AS DATE)) FOR Ngay;
ALTER TABLE dbo.CHAM_CONG     ADD CONSTRAINT DF_CHAMCONG_SoGioOT       DEFAULT (0)                   FOR SoGioOT;
ALTER TABLE dbo.DON_NGHI_PHEP ADD CONSTRAINT DF_DONNGHIPHEP_TrangThai  DEFAULT (N'Chờ duyệt')        FOR TrangThai;
ALTER TABLE dbo.BANG_LUONG    ADD CONSTRAINT DF_BANGLUONG_LuongHieuSuat DEFAULT (0)                  FOR LuongHieuSuat;
ALTER TABLE dbo.BANG_LUONG    ADD CONSTRAINT DF_BANGLUONG_PhuCap       DEFAULT (0)                   FOR PhuCap;
ALTER TABLE dbo.BANG_LUONG    ADD CONSTRAINT DF_BANGLUONG_TienThuong   DEFAULT (0)                   FOR TienThuong;
ALTER TABLE dbo.BANG_LUONG    ADD CONSTRAINT DF_BANGLUONG_KhauTru      DEFAULT (0)                   FOR KhauTru;
GO

/* =====================================================================
   5. INDEX trên cột khóa ngoại (tăng tốc JOIN/tra cứu theo nhân viên, phòng ban…)
      Cột đã là cột đầu của một UNIQUE (vd. CHAM_CONG.MaNV) không cần thêm.
   ===================================================================== */
CREATE INDEX IX_NHANVIEN_MaPB          ON dbo.NHANVIEN (MaPB);
CREATE INDEX IX_NHANVIEN_MaCV          ON dbo.NHANVIEN (MaCV);
CREATE INDEX IX_NHANVIEN_MaQuanLy      ON dbo.NHANVIEN (MaQuanLy);
CREATE INDEX IX_HOPDONG_MaNV           ON dbo.HOPDONG (MaNV);
CREATE INDEX IX_VITRI_MaDotTD          ON dbo.VI_TRI_TUYENDUNG (MaDotTD);
CREATE INDEX IX_VITRI_MaPB             ON dbo.VI_TRI_TUYENDUNG (MaPB);
CREATE INDEX IX_UNGTUYEN_MaViTri       ON dbo.UNG_TUYEN (MaViTri);
CREATE INDEX IX_THAMGIA_MaDT           ON dbo.THAM_GIA_DAO_TAO (MaDT);
CREATE INDEX IX_DANHGIA_MaNV           ON dbo.DANH_GIA (MaNV);
CREATE INDEX IX_KHENTHUONG_MaNV        ON dbo.KHEN_THUONG (MaNV);
CREATE INDEX IX_DONNGHIPHEP_MaNV       ON dbo.DON_NGHI_PHEP (MaNV);
CREATE INDEX IX_PHUCLOI_MaNV           ON dbo.PHUC_LOI (MaNV);
GO

/* =====================================================================
   6. Kiểm tra
   ===================================================================== */
SELECT OBJECT_NAME(o.parent_object_id) AS Bang,
       o.type_desc AS LoaiRangBuoc,
       COUNT(*) AS SoLuong
FROM sys.objects AS o
WHERE o.type IN ('PK', 'F', 'UQ', 'C', 'D')
  AND OBJECT_SCHEMA_NAME(o.object_id) = 'dbo'
GROUP BY OBJECT_NAME(o.parent_object_id), o.type_desc
ORDER BY Bang, LoaiRangBuoc;

SELECT o.type_desc AS LoaiRangBuoc, COUNT(*) AS TongSo
FROM sys.objects AS o
WHERE o.type IN ('PK', 'F', 'UQ', 'C', 'D') AND OBJECT_SCHEMA_NAME(o.object_id) = 'dbo'
GROUP BY o.type_desc
ORDER BY o.type_desc;
GO

SET NOEXEC OFF;
GO
