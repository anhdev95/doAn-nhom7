/* =====================================================================
   IE103 – Nhóm 7 – Hệ thống CSDL quản lý nhân sự
   02_CreateTables.sql – Tạo 16 bảng theo Database contract (Master Handoff §2)
   ---------------------------------------------------------------------
   - Tên bảng, tên cột, kiểu dữ liệu đúng contract.
   - PK: INT IDENTITY(1,1) – INSERT không cần truyền mã (dữ liệu mẫu dùng IDENTITY_INSERT).
   - NULL/NOT NULL: cột bắt buộc theo nghiệp vụ là NOT NULL; cột contract ghi "nullable"
     (HOPDONG.NgayKetThuc, PHUC_LOI.NgayKetThuc, NHANVIEN.MaQuanLy) cho phép NULL.
   - Khóa ngoại, UNIQUE, CHECK, DEFAULT nằm ở 03_Constraints.sql.
   - Chạy trên database vừa tạo bởi 01 (chưa có bảng). Muốn tạo lại: chạy 01 với @TaoLai = 1.
   ===================================================================== */

SET NOCOUNT ON;
USE IE103_HRM_Nhom7;
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE name IN (
    N'PHONGBAN', N'CHUCVU', N'NHANVIEN', N'HOPDONG', N'DOT_TUYENDUNG', N'VI_TRI_TUYENDUNG', N'UNGVIEN', N'UNG_TUYEN',
    N'DAOTAO', N'THAM_GIA_DAO_TAO', N'DANH_GIA', N'KHEN_THUONG', N'CHAM_CONG', N'DON_NGHI_PHEP', N'BANG_LUONG', N'PHUC_LOI'))
BEGIN
    RAISERROR(N'Database đã có bảng – giữ nguyên. Muốn tạo lại từ đầu: chạy 01_CreateDatabase.sql với @TaoLai = 1.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------- Tổ chức ---------- */

CREATE TABLE dbo.PHONGBAN (
    MaPB    INT IDENTITY(1, 1) NOT NULL,
    TenPB   NVARCHAR(100)      NOT NULL,
    MoTa    NVARCHAR(300)      NULL,
    CONSTRAINT PK_PHONGBAN PRIMARY KEY (MaPB)
);

CREATE TABLE dbo.CHUCVU (
    MaCV         INT IDENTITY(1, 1) NOT NULL,
    TenCV        NVARCHAR(100)      NOT NULL,
    MoTaCV       NVARCHAR(300)      NULL,
    TrachNhiem   NVARCHAR(300)      NULL,
    YeuCauKyNang NVARCHAR(300)      NULL,
    CONSTRAINT PK_CHUCVU PRIMARY KEY (MaCV)
);

CREATE TABLE dbo.NHANVIEN (
    MaNV        INT IDENTITY(1, 1) NOT NULL,
    HoTen       NVARCHAR(100)      NOT NULL,
    NgaySinh    DATE               NOT NULL,
    GioiTinh    NVARCHAR(10)       NOT NULL,
    CCCD        VARCHAR(12)        NOT NULL,
    Email       VARCHAR(100)       NOT NULL,
    SoDienThoai VARCHAR(15)        NULL,
    DiaChi      NVARCHAR(200)      NULL,
    NgayVaoLam  DATE               NOT NULL,
    TrangThai   NVARCHAR(30)       NOT NULL,
    MaPB        INT                NOT NULL,
    MaCV        INT                NOT NULL,
    MaQuanLy    INT                NULL,
    CONSTRAINT PK_NHANVIEN PRIMARY KEY (MaNV)
);

CREATE TABLE dbo.HOPDONG (
    MaHD          INT IDENTITY(1, 1) NOT NULL,
    MaNV          INT                NOT NULL,
    LoaiHD        NVARCHAR(50)       NOT NULL,
    NgayBatDau    DATE               NOT NULL,
    NgayKetThuc   DATE               NULL,
    LuongCoBan    DECIMAL(18, 2)     NOT NULL,
    TrangThai     NVARCHAR(30)       NOT NULL,
    LuongHieuSuat DECIMAL(18, 2)     NOT NULL,
    PhuCap        DECIMAL(18, 2)     NOT NULL,
    CONSTRAINT PK_HOPDONG PRIMARY KEY (MaHD)
);

/* ---------- Tuyển dụng ---------- */

CREATE TABLE dbo.DOT_TUYENDUNG (
    MaDotTD     INT IDENTITY(1, 1) NOT NULL,
    TenDotTD    NVARCHAR(200)      NOT NULL,
    NgayBatDau  DATE               NOT NULL,
    NgayKetThuc DATE               NOT NULL,
    TrangThai   NVARCHAR(30)       NOT NULL,
    ChiPhi      DECIMAL(18, 2)     NOT NULL,
    CONSTRAINT PK_DOT_TUYENDUNG PRIMARY KEY (MaDotTD)
);

CREATE TABLE dbo.VI_TRI_TUYENDUNG (
    MaViTri  INT IDENTITY(1, 1) NOT NULL,
    MaDotTD  INT                NOT NULL,
    TenViTri NVARCHAR(100)      NOT NULL,
    SoLuong  INT                NOT NULL,
    YeuCau   NVARCHAR(500)      NULL,
    MaPB     INT                NOT NULL,
    SoVongPV INT                NOT NULL,
    CONSTRAINT PK_VI_TRI_TUYENDUNG PRIMARY KEY (MaViTri)
);

CREATE TABLE dbo.UNGVIEN (
    MaUV        INT IDENTITY(1, 1) NOT NULL,
    HoTen       NVARCHAR(100)      NOT NULL,
    NgaySinh    DATE               NULL,
    Email       VARCHAR(100)       NOT NULL,
    SoDienThoai VARCHAR(15)        NULL,
    DiaChi      NVARCHAR(200)      NULL,
    TrinhDo     NVARCHAR(100)      NULL,
    KinhNghiem  NVARCHAR(500)      NULL,
    CONSTRAINT PK_UNGVIEN PRIMARY KEY (MaUV)
);

CREATE TABLE dbo.UNG_TUYEN (
    MaUngTuyen   INT IDENTITY(1, 1) NOT NULL,
    MaUV         INT                NOT NULL,
    MaViTri      INT                NOT NULL,
    NgayUngTuyen DATE               NOT NULL,
    VongPhongVan INT                NOT NULL,
    KetQua       NVARCHAR(30)       NOT NULL,
    TrangThai    NVARCHAR(30)       NOT NULL,
    CONSTRAINT PK_UNG_TUYEN PRIMARY KEY (MaUngTuyen)
);

/* ---------- Đào tạo & đánh giá ---------- */

CREATE TABLE dbo.DAOTAO (
    MaDT        INT IDENTITY(1, 1) NOT NULL,
    TenKhoaHoc  NVARCHAR(200)      NOT NULL,
    HinhThuc    NVARCHAR(30)       NOT NULL,
    NgayBatDau  DATE               NOT NULL,
    NgayKetThuc DATE               NOT NULL,
    NoiDung     NVARCHAR(500)      NULL,
    CONSTRAINT PK_DAOTAO PRIMARY KEY (MaDT)
);

CREATE TABLE dbo.THAM_GIA_DAO_TAO (
    MaTG        INT IDENTITY(1, 1) NOT NULL,
    MaNV        INT                NOT NULL,
    MaDT        INT                NOT NULL,
    NgayThamGia DATE               NOT NULL,
    KetQua      NVARCHAR(100)      NULL,
    DanhGia     NVARCHAR(300)      NULL,
    CONSTRAINT PK_THAM_GIA_DAO_TAO PRIMARY KEY (MaTG)
);

CREATE TABLE dbo.DANH_GIA (
    MaDG        INT IDENTITY(1, 1) NOT NULL,
    MaNV        INT                NOT NULL,
    KyDanhGia   NVARCHAR(50)       NOT NULL,
    NgayDanhGia DATE               NOT NULL,
    Diem        DECIMAL(5, 2)      NOT NULL,
    XepLoai     NVARCHAR(30)       NOT NULL,
    NhanXet     NVARCHAR(500)      NULL,
    CONSTRAINT PK_DANH_GIA PRIMARY KEY (MaDG)
);

/* ---------- Lương & đãi ngộ ---------- */

CREATE TABLE dbo.KHEN_THUONG (
    MaKT     INT IDENTITY(1, 1) NOT NULL,
    MaNV     INT                NOT NULL,
    NgayKT   DATE               NOT NULL,
    LyDo     NVARCHAR(300)      NOT NULL,
    HinhThuc NVARCHAR(100)      NOT NULL,
    SoTien   DECIMAL(18, 2)     NOT NULL,
    CONSTRAINT PK_KHEN_THUONG PRIMARY KEY (MaKT)
);

/* ---------- Chấm công & nghỉ phép ---------- */

CREATE TABLE dbo.CHAM_CONG (
    MaCC      INT IDENTITY(1, 1) NOT NULL,
    MaNV      INT                NOT NULL,
    Ngay      DATE               NOT NULL,
    GioVao    TIME               NULL,
    GioRa     TIME               NULL,
    SoGioOT   DECIMAL(5, 2)      NOT NULL,
    TrangThai NVARCHAR(30)       NOT NULL,
    CONSTRAINT PK_CHAM_CONG PRIMARY KEY (MaCC)
);

CREATE TABLE dbo.DON_NGHI_PHEP (
    MaDon     INT IDENTITY(1, 1) NOT NULL,
    MaNV      INT                NOT NULL,
    TuNgay    DATE               NOT NULL,
    DenNgay   DATE               NOT NULL,
    SoNgay    DECIMAL(5, 2)      NOT NULL,
    LyDo      NVARCHAR(300)      NULL,
    TrangThai NVARCHAR(30)       NOT NULL,
    CONSTRAINT PK_DON_NGHI_PHEP PRIMARY KEY (MaDon)
);

CREATE TABLE dbo.BANG_LUONG (
    MaLuong       INT IDENTITY(1, 1) NOT NULL,
    MaNV          INT                NOT NULL,
    Thang         INT                NOT NULL,
    Nam           INT                NOT NULL,
    LuongCoBan    DECIMAL(18, 2)     NOT NULL,
    LuongHieuSuat DECIMAL(18, 2)     NOT NULL,
    PhuCap        DECIMAL(18, 2)     NOT NULL,
    TienThuong    DECIMAL(18, 2)     NOT NULL,
    KhauTru       DECIMAL(18, 2)     NOT NULL,
    LuongThucNhan DECIMAL(18, 2)     NOT NULL,
    CONSTRAINT PK_BANG_LUONG PRIMARY KEY (MaLuong)
);

CREATE TABLE dbo.PHUC_LOI (
    MaPL        INT IDENTITY(1, 1) NOT NULL,
    MaNV        INT                NOT NULL,
    TenPhucLoi  NVARCHAR(200)      NOT NULL,
    NgayBatDau  DATE               NOT NULL,
    NgayKetThuc DATE               NULL,
    GiaTri      DECIMAL(18, 2)     NOT NULL,
    TrangThai   NVARCHAR(30)       NOT NULL,
    CONSTRAINT PK_PHUC_LOI PRIMARY KEY (MaPL)
);
GO

/* ---------- Mô tả bảng (tân từ) – hiển thị trong SSMS: Properties → Extended Properties ---------- */
DECLARE @MoTa TABLE (Bang SYSNAME, TanTu NVARCHAR(400));
INSERT INTO @MoTa VALUES
 (N'PHONGBAN',         N'Mỗi phòng ban có mã duy nhất, tên duy nhất và mô tả chức năng.'),
 (N'CHUCVU',           N'Mỗi chức vụ có mã, tên duy nhất, mô tả, trách nhiệm và yêu cầu kỹ năng.'),
 (N'NHANVIEN',         N'Mỗi nhân viên có mã duy nhất, thông tin cá nhân (CCCD, email duy nhất), thuộc một phòng ban, giữ một chức vụ và có thể có một người quản lý trực tiếp.'),
 (N'HOPDONG',          N'Mỗi hợp đồng thuộc một nhân viên, có loại, thời hạn, lương cơ bản, lương hiệu suất, phụ cấp và trạng thái.'),
 (N'DOT_TUYENDUNG',    N'Mỗi đợt tuyển dụng có thời gian, trạng thái và chi phí; số lượng cần tuyển tính từ các vị trí.'),
 (N'VI_TRI_TUYENDUNG', N'Mỗi vị trí thuộc một đợt tuyển dụng và một phòng ban, có số lượng cần tuyển, yêu cầu và số vòng phỏng vấn.'),
 (N'UNGVIEN',          N'Mỗi ứng viên có mã, thông tin liên hệ (email duy nhất), trình độ và kinh nghiệm.'),
 (N'UNG_TUYEN',        N'Mỗi lượt ứng tuyển là một ứng viên ứng tuyển một vị trí (mỗi cặp chỉ một lần), ghi vòng phỏng vấn, kết quả và trạng thái.'),
 (N'DAOTAO',           N'Mỗi khóa đào tạo có tên, hình thức, thời gian và nội dung.'),
 (N'THAM_GIA_DAO_TAO', N'Mỗi lượt tham gia là một nhân viên tham gia một khóa đào tạo (mỗi cặp chỉ một lần), ghi kết quả và đánh giá.'),
 (N'DANH_GIA',         N'Mỗi lần đánh giá ghi điểm (0–100), xếp loại và nhận xét của một nhân viên trong một kỳ.'),
 (N'KHEN_THUONG',      N'Mỗi lần khen thưởng ghi ngày, lý do, hình thức và số tiền thưởng của một nhân viên.'),
 (N'CHAM_CONG',        N'Mỗi bản ghi chấm công là giờ vào/ra, số giờ tăng ca và trạng thái của một nhân viên trong một ngày (mỗi ngày một bản ghi).'),
 (N'DON_NGHI_PHEP',    N'Mỗi đơn nghỉ phép của một nhân viên có khoảng thời gian, số ngày nghỉ, lý do và trạng thái duyệt.'),
 (N'BANG_LUONG',       N'Mỗi bảng lương là lương tháng của một nhân viên (mỗi nhân viên một bảng/tháng): LuongThucNhan = LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru.'),
 (N'PHUC_LOI',         N'Mỗi phúc lợi của một nhân viên có tên, thời gian áp dụng, giá trị và trạng thái.');

DECLARE @bang SYSNAME, @tantu NVARCHAR(400);
WHILE EXISTS (SELECT 1 FROM @MoTa)
BEGIN
    SELECT TOP (1) @bang = Bang, @tantu = TanTu FROM @MoTa ORDER BY Bang;
    EXEC sys.sp_addextendedproperty @name = N'MS_Description', @value = @tantu,
         @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = @bang;
    DELETE FROM @MoTa WHERE Bang = @bang;
END
GO

-- Kiểm tra: 16 bảng, số cột, tân từ
SELECT t.name AS Bang,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS SoCot,
       CAST(ep.value AS NVARCHAR(400)) AS TanTu
FROM sys.tables AS t
LEFT JOIN sys.extended_properties AS ep
       ON ep.major_id = t.object_id AND ep.minor_id = 0 AND ep.name = N'MS_Description'
WHERE t.is_ms_shipped = 0
ORDER BY t.name;
GO

SET NOEXEC OFF;
GO
