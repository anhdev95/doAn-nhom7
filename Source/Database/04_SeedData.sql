/* =====================================================================
   IE103 – Nhóm 7 – Hệ thống CSDL quản lý nhân sự
   04_SeedData.sql – Dữ liệu mẫu
   ---------------------------------------------------------------------
   Thời điểm dữ liệu: đến 10/2026. Dữ liệu nhất quán giữa các bảng:
     - 24 nhân viên (19 Đang làm, 2 Tạm nghỉ, 3 Nghỉ việc), có cây quản lý (MaQuanLy).
     - Mỗi nhân viên còn làm việc có đúng 1 hợp đồng 'Hiệu lực'; có lịch sử 'Hết hạn', 'Chấm dứt'.
     - Tuyển dụng: ứng viên Đạt/Không đạt/Chưa có kết quả; số 'Đã tuyển' ≤ SoLuong của vị trí;
       2 ứng viên trúng tuyển đã trở thành nhân viên (NV 21, 22).
     - Đào tạo/đánh giá chỉ cho nhân viên đang làm tại thời điểm đó; điểm 0–100, nhiều mức xếp loại.
     - Chấm công 01/09–09/10/2026 (thứ 2–6, trừ nghỉ lễ 01–02/09 và ngày nghỉ phép đã duyệt):
       có OT / không OT, đi muộn, về sớm, vắng.
     - Đơn nghỉ phép: Chờ duyệt / Đã duyệt / Từ chối; đơn đã duyệt không trùng thời gian.
     - Bảng lương 07, 08, 09/2026 tính từ hợp đồng hiệu lực + khen thưởng trong tháng:
         KhauTru = 10,5% LuongCoBan (BHXH 8% + BHYT 1,5% + BHTN 1%)
         LuongThucNhan = LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru
       Tháng 10/2026 để trống cho phần xử lý lương (Procedure/Trigger) demo.
   Giá trị trạng thái ngoài 6 miền đã chốt (CHAM_CONG, DOT_TUYENDUNG, PHUC_LOI, DAOTAO.HinhThuc,
   DANH_GIA.XepLoai, THAM_GIA_DAO_TAO.KetQua) là đề xuất – xem Source/Database/README.md.
   Toàn bộ chạy trong 1 transaction: lỗi ở bất kỳ bước nào → không ghi gì.
   Chạy sau 03_Constraints.sql, trên database chưa có dữ liệu.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
USE IE103_HRM_Nhom7;
GO

IF EXISTS (SELECT 1 FROM dbo.NHANVIEN)
BEGIN
    RAISERROR(N'Đã có dữ liệu – giữ nguyên. Muốn nạp lại: chạy 01 (@TaoLai = 1) → 02 → 03 → 04.', 16, 1);
    SET NOEXEC ON;
END
GO

BEGIN TRY
BEGIN TRANSACTION;

/* ---------------------------------------------------------------------
   1. PHONGBAN (6)
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.PHONGBAN ON;
INSERT INTO dbo.PHONGBAN (MaPB, TenPB, MoTa) VALUES
 (1, N'Ban Giám đốc',      N'Điều hành chung, hoạch định chiến lược và phê duyệt các quyết định quan trọng.'),
 (2, N'Phòng Nhân sự',     N'Tuyển dụng, quản lý hồ sơ, hợp đồng, đào tạo, đánh giá và chế độ cho nhân viên.'),
 (3, N'Phòng Kế toán',     N'Tính lương, quản lý thu chi, báo cáo tài chính, thuế và bảo hiểm.'),
 (4, N'Phòng Kinh doanh',  N'Tìm kiếm khách hàng, bán hàng và chăm sóc khách hàng.'),
 (5, N'Phòng Kỹ thuật',    N'Phát triển, vận hành và bảo trì hệ thống phần mềm của công ty.'),
 (6, N'Phòng Marketing',   N'Xây dựng thương hiệu, truyền thông và các chiến dịch quảng bá.');
SET IDENTITY_INSERT dbo.PHONGBAN OFF;

/* ---------------------------------------------------------------------
   2. CHUCVU (7)
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.CHUCVU ON;
INSERT INTO dbo.CHUCVU (MaCV, TenCV, MoTaCV, TrachNhiem, YeuCauKyNang) VALUES
 (1, N'Giám đốc',      N'Người đứng đầu công ty.',           N'Điều hành toàn bộ hoạt động, chịu trách nhiệm trước hội đồng thành viên.', N'Quản trị doanh nghiệp, lãnh đạo, ra quyết định.'),
 (2, N'Trưởng phòng',  N'Phụ trách một phòng ban.',          N'Lập kế hoạch, phân công và đánh giá công việc của phòng.',               N'Quản lý đội nhóm, chuyên môn sâu, trên 5 năm kinh nghiệm.'),
 (3, N'Phó phòng',     N'Hỗ trợ trưởng phòng.',              N'Điều phối công việc hằng ngày, thay trưởng phòng khi vắng.',             N'Chuyên môn tốt, kỹ năng điều phối, trên 3 năm kinh nghiệm.'),
 (4, N'Chuyên viên',   N'Nhân sự có chuyên môn chính.',      N'Thực hiện và chịu trách nhiệm các nghiệp vụ chuyên môn được giao.',       N'Tốt nghiệp đại học đúng chuyên ngành, trên 2 năm kinh nghiệm.'),
 (5, N'Nhân viên',     N'Nhân sự thực hiện nghiệp vụ.',      N'Thực hiện công việc theo phân công của quản lý.',                         N'Tốt nghiệp cao đẳng/đại học, kỹ năng tin học văn phòng.'),
 (6, N'Kế toán viên',  N'Nhân sự nghiệp vụ kế toán.',        N'Ghi sổ, lập chứng từ, tính lương, kê khai thuế và bảo hiểm.',             N'Chứng chỉ kế toán, thành thạo Excel và phần mềm kế toán.'),
 (7, N'Thực tập sinh', N'Sinh viên thực tập.',               N'Học việc và hỗ trợ công việc của phòng.',                                 N'Sinh viên năm 3–4, ham học hỏi.');
SET IDENTITY_INSERT dbo.CHUCVU OFF;

/* ---------------------------------------------------------------------
   3. NHANVIEN (24) – MaQuanLy: giám đốc (1) → trưởng phòng (2–6) → nhân viên
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.NHANVIEN ON;
INSERT INTO dbo.NHANVIEN (MaNV, HoTen, NgaySinh, GioiTinh, CCCD, Email, SoDienThoai, DiaChi, NgayVaoLam, TrangThai, MaPB, MaCV, MaQuanLy) VALUES
 ( 1, N'Nguyễn Văn An',    '1975-03-12', N'Nam',  '079075000101', 'an.nguyen@hrm-nhom7.vn',   '0903100101', N'12 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM', '2015-01-05', N'Đang làm',  1, 1, NULL),
 ( 2, N'Trần Thị Bích',    '1982-07-21', N'Nữ',   '079182000202', 'bich.tran@hrm-nhom7.vn',   '0903100202', N'45 Lê Lợi, Quận 1, TP.HCM',                      '2016-03-01', N'Đang làm',  2, 2, 1),
 ( 3, N'Lê Minh Châu',     '1980-11-02', N'Nữ',   '079180000303', 'chau.le@hrm-nhom7.vn',     '0903100303', N'78 Hai Bà Trưng, Quận 3, TP.HCM',                '2016-06-15', N'Đang làm',  3, 2, 1),
 ( 4, N'Phạm Quốc Dũng',   '1983-05-09', N'Nam',  '079083000404', 'dung.pham@hrm-nhom7.vn',   '0903100404', N'23 Cách Mạng Tháng 8, Quận 10, TP.HCM',          '2017-02-10', N'Đang làm',  4, 2, 1),
 ( 5, N'Hoàng Đức Huy',    '1985-09-30', N'Nam',  '079085000505', 'huy.hoang@hrm-nhom7.vn',   '0903100505', N'102 Võ Văn Tần, Quận 3, TP.HCM',                 '2017-08-01', N'Đang làm',  5, 2, 1),
 ( 6, N'Võ Thị Hạnh',      '1987-12-14', N'Nữ',   '079187000606', 'hanh.vo@hrm-nhom7.vn',     '0903100606', N'9 Phan Xích Long, Phú Nhuận, TP.HCM',            '2018-04-02', N'Đang làm',  6, 2, 1),
 ( 7, N'Đặng Thu Trang',   '1990-02-18', N'Nữ',   '079190000707', 'trang.dang@hrm-nhom7.vn',  '0903100707', N'56 Nguyễn Trãi, Quận 5, TP.HCM',                 '2019-05-06', N'Đang làm',  2, 4, 2),
 ( 8, N'Bùi Văn Khánh',    '1992-06-25', N'Nam',  '079092000808', 'khanh.bui@hrm-nhom7.vn',   '0903100808', N'31 Lý Thường Kiệt, Tân Bình, TP.HCM',            '2021-09-01', N'Đang làm',  2, 5, 2),
 ( 9, N'Ngô Thị Lan',      '1991-10-08', N'Nữ',   '079191000909', 'lan.ngo@hrm-nhom7.vn',     '0903100909', N'17 Trần Hưng Đạo, Quận 1, TP.HCM',               '2019-11-11', N'Đang làm',  3, 6, 3),
 (10, N'Đỗ Thanh Long',    '1993-04-17', N'Nam',  '079093001010', 'long.do@hrm-nhom7.vn',     '0903101010', N'88 Xô Viết Nghệ Tĩnh, Bình Thạnh, TP.HCM',       '2022-01-10', N'Tạm nghỉ',  3, 6, 3),
 (11, N'Phan Thị Mai',     '1994-08-29', N'Nữ',   '079194001111', 'mai.phan@hrm-nhom7.vn',    '0903101111', N'5 Hoàng Diệu, Quận 4, TP.HCM',                   '2018-10-01', N'Đang làm',  4, 3, 4),
 (12, N'Vũ Hoàng Nam',     '1995-01-05', N'Nam',  '079095001212', 'nam.vu@hrm-nhom7.vn',      '0903101212', N'140 Âu Cơ, Tân Phú, TP.HCM',                     '2020-07-01', N'Đang làm',  4, 5, 4),
 (13, N'Huỳnh Ngọc Oanh',  '1996-03-22', N'Nữ',   '079196001313', 'oanh.huynh@hrm-nhom7.vn',  '0903101313', N'27 Nguyễn Văn Linh, Quận 7, TP.HCM',             '2022-03-15', N'Nghỉ việc', 4, 5, 4),
 (14, N'Trịnh Công Phúc',  '1989-12-01', N'Nam',  '079089001414', 'phuc.trinh@hrm-nhom7.vn',  '0903101414', N'66 Điện Biên Phủ, Bình Thạnh, TP.HCM',           '2018-02-01', N'Đang làm',  5, 3, 5),
 (15, N'Lý Minh Quân',     '1994-05-19', N'Nam',  '079094001515', 'quan.ly@hrm-nhom7.vn',     '0903101515', N'12 Kha Vạn Cân, TP. Thủ Đức, TP.HCM',            '2019-08-12', N'Đang làm',  5, 4, 5),
 (16, N'Mai Thị Quỳnh',    '1997-09-09', N'Nữ',   '079197001616', 'quynh.mai@hrm-nhom7.vn',   '0903101616', N'3 Lê Văn Việt, TP. Thủ Đức, TP.HCM',             '2021-04-05', N'Đang làm',  5, 4, 5),
 (17, N'Tô Văn Sơn',       '1998-11-11', N'Nam',  '079098001717', 'son.to@hrm-nhom7.vn',      '0903101717', N'210 Quang Trung, Gò Vấp, TP.HCM',                '2023-06-01', N'Đang làm',  5, 5, 5),
 (18, N'Đinh Thị Thảo',    '1996-07-07', N'Nữ',   '079196001818', 'thao.dinh@hrm-nhom7.vn',   '0903101818', N'14 Nguyễn Thị Minh Khai, Quận 1, TP.HCM',        '2020-11-02', N'Đang làm',  6, 4, 6),
 (19, N'Lâm Gia Bảo',      '1999-02-14', N'Nam',  '079099001919', 'bao.lam@hrm-nhom7.vn',     '0903101919', N'48 Phạm Văn Đồng, TP. Thủ Đức, TP.HCM',          '2023-09-18', N'Nghỉ việc', 6, 5, 6),
 (20, N'Châu Ngọc Uyên',   '1997-04-30', N'Nữ',   '079197002020', 'uyen.chau@hrm-nhom7.vn',   '0903102020', N'19 Bạch Đằng, Bình Thạnh, TP.HCM',               '2024-02-19', N'Tạm nghỉ',  2, 5, 2),
 (21, N'Kiều Văn Việt',    '2004-06-06', N'Nam',  '079204002121', 'viet.kieu@hrm-nhom7.vn',   '0903102121', N'7 Lê Đức Thọ, Gò Vấp, TP.HCM',                   '2026-07-01', N'Đang làm',  5, 7, 14),
 (22, N'Dương Thị Xuân',   '1998-10-10', N'Nữ',   '079198002222', 'xuan.duong@hrm-nhom7.vn',  '0903102222', N'25 Nguyễn Oanh, Gò Vấp, TP.HCM',                 '2025-03-03', N'Đang làm',  4, 5, 11),
 (23, N'Quách Minh Anh',   '1999-12-25', N'Khác', '079199002323', 'anh.quach@hrm-nhom7.vn',   '0903102323', N'60 Trường Chinh, Tân Bình, TP.HCM',              '2025-09-15', N'Đang làm',  6, 5, 6),
 (24, N'Hà Văn Thịnh',     '1986-01-20', N'Nam',  '079086002424', 'thinh.ha@hrm-nhom7.vn',    '0903102424', N'11 Pasteur, Quận 3, TP.HCM',                     '2015-03-01', N'Nghỉ việc', 3, 6, 3);
SET IDENTITY_INSERT dbo.NHANVIEN OFF;

/* ---------------------------------------------------------------------
   4. HOPDONG (34) – mỗi nhân viên còn làm việc có đúng 1 hợp đồng 'Hiệu lực'
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.HOPDONG ON;
INSERT INTO dbo.HOPDONG (MaHD, MaNV, LoaiHD, NgayBatDau, NgayKetThuc, LuongCoBan, TrangThai, LuongHieuSuat, PhuCap) VALUES
 ( 1,  1, N'Không xác định thời hạn', '2015-01-05', NULL,         45000000, N'Hiệu lực', 8000000, 5000000),
 ( 2,  2, N'Xác định thời hạn',       '2016-03-01', '2019-02-28', 18000000, N'Hết hạn',  1500000, 2000000),
 ( 3,  2, N'Không xác định thời hạn', '2019-03-01', NULL,         30000000, N'Hiệu lực', 4000000, 3000000),
 ( 4,  3, N'Không xác định thời hạn', '2016-06-15', NULL,         30000000, N'Hiệu lực', 4000000, 3000000),
 ( 5,  4, N'Không xác định thời hạn', '2017-02-10', NULL,         32000000, N'Hiệu lực', 6000000, 3000000),
 ( 6,  5, N'Không xác định thời hạn', '2017-08-01', NULL,         32000000, N'Hiệu lực', 5000000, 3000000),
 ( 7,  6, N'Không xác định thời hạn', '2018-04-02', NULL,         28000000, N'Hiệu lực', 4000000, 3000000),
 ( 8,  7, N'Xác định thời hạn',       '2019-05-06', '2022-05-05', 14000000, N'Hết hạn',  1000000, 1000000),
 ( 9,  7, N'Không xác định thời hạn', '2022-05-06', NULL,         18000000, N'Hiệu lực', 2000000, 1500000),
 (10,  8, N'Xác định thời hạn',       '2021-09-01', '2024-08-31', 10000000, N'Hết hạn',   500000,  800000),
 (11,  8, N'Xác định thời hạn',       '2024-09-01', '2027-08-31', 12000000, N'Hiệu lực', 1000000,  800000),
 (12,  9, N'Không xác định thời hạn', '2019-11-11', NULL,         14000000, N'Hiệu lực', 1500000, 1000000),
 (13, 10, N'Xác định thời hạn',       '2022-01-10', '2027-01-09', 13000000, N'Hiệu lực', 1000000,  800000),
 (14, 11, N'Không xác định thời hạn', '2018-10-01', NULL,         22000000, N'Hiệu lực', 3000000, 2000000),
 (15, 12, N'Xác định thời hạn',       '2020-07-01', '2023-06-30', 10000000, N'Hết hạn',  1000000,  800000),
 (16, 12, N'Không xác định thời hạn', '2023-07-01', NULL,         12500000, N'Hiệu lực', 2000000,  800000),
 (17, 13, N'Xác định thời hạn',       '2022-03-15', '2025-03-14', 10000000, N'Hết hạn',  1000000,  800000),
 (18, 13, N'Xác định thời hạn',       '2025-03-15', '2025-06-30', 11000000, N'Chấm dứt', 1000000,  800000),
 (19, 14, N'Không xác định thời hạn', '2018-02-01', NULL,         24000000, N'Hiệu lực', 3500000, 2000000),
 (20, 15, N'Không xác định thời hạn', '2019-08-12', NULL,         20000000, N'Hiệu lực', 2500000, 1500000),
 (21, 16, N'Xác định thời hạn',       '2021-04-05', '2024-04-04', 15000000, N'Hết hạn',  1500000, 1000000),
 (22, 16, N'Không xác định thời hạn', '2024-04-05', NULL,         18000000, N'Hiệu lực', 2500000, 1000000),
 (23, 17, N'Xác định thời hạn',       '2023-06-01', '2026-05-31', 11000000, N'Hết hạn',  1000000,  800000),
 (24, 17, N'Xác định thời hạn',       '2026-06-01', '2029-05-31', 13000000, N'Hiệu lực', 1500000,  800000),
 (25, 18, N'Không xác định thời hạn', '2020-11-02', NULL,         17000000, N'Hiệu lực', 2000000, 1200000),
 (26, 19, N'Xác định thời hạn',       '2023-09-18', '2025-09-17', 10000000, N'Hết hạn',   800000,  800000),
 (27, 19, N'Xác định thời hạn',       '2025-09-18', '2025-12-31', 10500000, N'Chấm dứt',  800000,  800000),
 (28, 20, N'Xác định thời hạn',       '2024-02-19', '2027-02-18', 11000000, N'Hiệu lực',  800000,  800000),
 (29, 21, N'Thử việc',                '2026-07-01', '2026-12-31',  5000000, N'Hiệu lực',        0,  500000),
 (30, 22, N'Thử việc',                '2025-03-03', '2025-05-02',  8000000, N'Hết hạn',         0,  500000),
 (31, 22, N'Xác định thời hạn',       '2025-05-03', '2028-05-02', 11000000, N'Hiệu lực', 1000000,  800000),
 (32, 23, N'Xác định thời hạn',       '2025-09-15', '2026-09-14', 10000000, N'Hết hạn',   800000,  800000),
 (33, 23, N'Xác định thời hạn',       '2026-09-15', '2028-09-14', 11500000, N'Hiệu lực', 1000000,  800000),
 (34, 24, N'Không xác định thời hạn', '2015-03-01', '2024-12-31', 16000000, N'Chấm dứt', 1500000, 1000000);
SET IDENTITY_INSERT dbo.HOPDONG OFF;

/* ---------------------------------------------------------------------
   5. DOT_TUYENDUNG (3) – tổng số lượng tính từ VI_TRI_TUYENDUNG
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.DOT_TUYENDUNG ON;
INSERT INTO dbo.DOT_TUYENDUNG (MaDotTD, TenDotTD, NgayBatDau, NgayKetThuc, TrangThai, ChiPhi) VALUES
 (1, N'Tuyển dụng đợt 1 năm 2025',            '2025-02-01', '2025-03-31', N'Đã kết thúc', 25000000),
 (2, N'Tuyển thực tập sinh hè 2026',          '2026-05-15', '2026-06-30', N'Đã kết thúc',  8000000),
 (3, N'Tuyển dụng đợt 4 năm 2026',            '2026-10-01', '2026-11-30', N'Đang tuyển',  30000000);
SET IDENTITY_INSERT dbo.DOT_TUYENDUNG OFF;

/* ---------------------------------------------------------------------
   6. VI_TRI_TUYENDUNG (7)
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.VI_TRI_TUYENDUNG ON;
INSERT INTO dbo.VI_TRI_TUYENDUNG (MaViTri, MaDotTD, TenViTri, SoLuong, YeuCau, MaPB, SoVongPV) VALUES
 (1, 1, N'Nhân viên kinh doanh',              2, N'Tốt nghiệp cao đẳng trở lên, giao tiếp tốt, ưu tiên có kinh nghiệm bán hàng.',             4, 2),
 (2, 1, N'Kế toán viên',                      1, N'Tốt nghiệp đại học chuyên ngành kế toán, thành thạo Excel, có chứng chỉ kế toán.',         3, 2),
 (3, 2, N'Thực tập sinh phát triển phần mềm', 2, N'Sinh viên năm 3–4 ngành CNTT, biết C#/Java và SQL cơ bản.',                               5, 1),
 (4, 2, N'Thực tập sinh marketing',           1, N'Sinh viên năm 3–4 ngành marketing/truyền thông, biết thiết kế cơ bản.',                    6, 1),
 (5, 3, N'Lập trình viên Backend',            2, N'Trên 2 năm kinh nghiệm .NET hoặc Node.js, thành thạo SQL Server.',                          5, 3),
 (6, 3, N'Chuyên viên tuyển dụng',            1, N'Trên 2 năm kinh nghiệm tuyển dụng, kỹ năng phỏng vấn và đánh giá ứng viên.',               2, 2),
 (7, 3, N'Chuyên viên marketing số',          1, N'Kinh nghiệm chạy quảng cáo Facebook/Google, phân tích số liệu chiến dịch.',               6, 2);
SET IDENTITY_INSERT dbo.VI_TRI_TUYENDUNG OFF;

/* ---------------------------------------------------------------------
   7. UNGVIEN (16)
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.UNGVIEN ON;
INSERT INTO dbo.UNGVIEN (MaUV, HoTen, NgaySinh, Email, SoDienThoai, DiaChi, TrinhDo, KinhNghiem) VALUES
 ( 1, N'Dương Thị Xuân',    '1998-10-10', 'xuan.duong98@gmail.com',   '0912000001', N'25 Nguyễn Oanh, Gò Vấp, TP.HCM',          N'Cao đẳng Quản trị kinh doanh', N'2 năm nhân viên bán hàng bán lẻ.'),
 ( 2, N'Trương Quang Hải',  '1996-02-03', 'hai.truong96@gmail.com',   '0912000002', N'90 Lạc Long Quân, Tân Bình, TP.HCM',      N'Đại học Marketing',            N'1 năm telesales.'),
 ( 3, N'Nguyễn Thị Hồng',   '2000-05-15', 'hong.nguyen00@gmail.com',  '0912000003', N'33 Tô Hiến Thành, Quận 10, TP.HCM',       N'Cao đẳng Kinh tế',             N'Mới tốt nghiệp.'),
 ( 4, N'Lê Hoàng Phương',   '1995-08-21', 'phuong.le95@gmail.com',    '0912000004', N'15 Nguyễn Kiệm, Phú Nhuận, TP.HCM',       N'Đại học Kế toán',              N'3 năm kế toán tổng hợp.'),
 ( 5, N'Phạm Minh Trí',     '1997-12-30', 'tri.pham97@gmail.com',     '0912000005', N'72 Lê Văn Sỹ, Quận 3, TP.HCM',            N'Đại học Tài chính',            N'1 năm kiểm toán nội bộ.'),
 ( 6, N'Kiều Văn Việt',     '2004-06-06', 'viet.kieu04@gmail.com',    '0912000006', N'7 Lê Đức Thọ, Gò Vấp, TP.HCM',            N'Sinh viên năm 4 CNTT',         N'Dự án môn học web ASP.NET.'),
 ( 7, N'Hồ Thanh Tâm',      '2004-01-19', 'tam.ho04@gmail.com',       '0912000007', N'41 Hoàng Văn Thụ, Phú Nhuận, TP.HCM',     N'Sinh viên năm 3 CNTT',         NULL),
 ( 8, N'Đoàn Ngọc Bảo Trân','2003-09-09', 'tran.doan03@gmail.com',    '0912000008', N'8 Võ Thị Sáu, Quận 3, TP.HCM',            N'Sinh viên năm 4 CNTT',         N'Thực tập 3 tháng tại công ty phần mềm.'),
 ( 9, N'Vương Thị Yến',     '2003-11-11', 'yen.vuong03@gmail.com',    '0912000009', N'120 Nguyễn Thái Sơn, Gò Vấp, TP.HCM',     N'Sinh viên năm 4 Marketing',    N'Cộng tác viên nội dung mạng xã hội.'),
 (10, N'Tạ Đình Khoa',      '1994-04-04', 'khoa.ta94@gmail.com',      '0912000010', N'18 Cộng Hòa, Tân Bình, TP.HCM',           N'Đại học CNTT',                 N'4 năm lập trình .NET, SQL Server.'),
 (11, N'Lưu Bảo Ngọc',      '1996-06-16', 'ngoc.luu96@gmail.com',     '0912000011', N'52 Nguyễn Đình Chiểu, Quận 3, TP.HCM',    N'Đại học Khoa học máy tính',    N'2 năm Node.js, PostgreSQL.'),
 (12, N'Mạc Văn Tùng',      '1993-03-08', 'tung.mac93@gmail.com',     '0912000012', N'9 Đường 3/2, Quận 10, TP.HCM',            N'Thạc sĩ Hệ thống thông tin',   N'5 năm backend, từng làm trưởng nhóm.'),
 (13, N'Âu Thị Kim',        '1999-07-27', 'kim.au99@gmail.com',       '0912000013', N'66 Phan Đăng Lưu, Bình Thạnh, TP.HCM',    N'Cao đẳng CNTT',                N'1 năm kiểm thử phần mềm.'),
 (14, N'Thân Đức Minh',     '1992-10-01', 'minh.than92@gmail.com',    '0912000014', N'27 Bùi Thị Xuân, Quận 1, TP.HCM',         N'Đại học Quản trị nhân lực',    N'3 năm chuyên viên tuyển dụng.'),
 (15, N'Giang Thị Thu',     '1997-02-28', 'thu.giang97@gmail.com',    '0912000015', N'102 Lê Quang Định, Bình Thạnh, TP.HCM',   N'Đại học Marketing',            N'2 năm digital marketing.'),
 (16, N'Ông Gia Huy',       '1998-08-08', 'huy.ong98@gmail.com',      '0912000016', N'14 Trần Quang Khải, Quận 1, TP.HCM',      N'Đại học Truyền thông',         N'1 năm quảng cáo Google Ads.');
SET IDENTITY_INSERT dbo.UNGVIEN OFF;

/* ---------------------------------------------------------------------
   8. UNG_TUYEN (21) – 'Đã tuyển' ⇒ KetQua 'Đạt'; VongPhongVan ≤ SoVongPV;
      số 'Đã tuyển' mỗi vị trí ≤ SoLuong
   --------------------------------------------------------------------- */
INSERT INTO dbo.UNG_TUYEN (MaUV, MaViTri, NgayUngTuyen, VongPhongVan, KetQua, TrangThai) VALUES
 -- Đợt 1/2025
 ( 1, 1, '2025-02-10', 2, N'Đạt',             N'Đã tuyển'),
 ( 2, 1, '2025-02-12', 2, N'Không đạt',       N'Từ chối'),
 ( 3, 1, '2025-02-15', 1, N'Không đạt',       N'Từ chối'),
 ( 4, 2, '2025-02-11', 2, N'Không đạt',       N'Từ chối'),
 ( 5, 2, '2025-02-20', 1, N'Không đạt',       N'Từ chối'),
 -- Đợt thực tập hè 2026
 ( 6, 3, '2026-05-20', 1, N'Đạt',             N'Đã tuyển'),
 ( 7, 3, '2026-05-22', 1, N'Không đạt',       N'Từ chối'),
 ( 8, 3, '2026-05-25', 1, N'Đạt',             N'Từ chối'),        -- đạt nhưng ứng viên từ chối nhận việc
 ( 9, 4, '2026-05-21', 1, N'Không đạt',       N'Từ chối'),
 -- Đợt 4/2026 (đang tuyển)
 (10, 5, '2026-10-02', 2, N'Chưa có kết quả', N'Đang xử lý'),
 (11, 5, '2026-10-03', 1, N'Chưa có kết quả', N'Đang xử lý'),
 (12, 5, '2026-10-02', 3, N'Đạt',             N'Đang xử lý'),     -- đạt vòng cuối, chờ gửi thư mời
 (13, 5, '2026-10-04', 1, N'Không đạt',       N'Từ chối'),
 ( 5, 5, '2026-10-05', 2, N'Không đạt',       N'Từ chối'),
 (14, 6, '2026-10-03', 1, N'Chưa có kết quả', N'Đang xử lý'),
 ( 2, 6, '2026-10-06', 1, N'Chưa có kết quả', N'Đang xử lý'),
 (11, 6, '2026-10-08', 0, N'Chưa có kết quả', N'Đang xử lý'),     -- mới nộp hồ sơ
 (15, 7, '2026-10-02', 2, N'Chưa có kết quả', N'Đang xử lý'),
 (16, 7, '2026-10-07', 0, N'Chưa có kết quả', N'Đang xử lý'),
 ( 3, 7, '2026-10-07', 1, N'Không đạt',       N'Từ chối'),
 ( 9, 7, '2026-10-09', 1, N'Chưa có kết quả', N'Đang xử lý');

/* ---------------------------------------------------------------------
   9. DAOTAO (6)
   --------------------------------------------------------------------- */
SET IDENTITY_INSERT dbo.DAOTAO ON;
INSERT INTO dbo.DAOTAO (MaDT, TenKhoaHoc, HinhThuc, NgayBatDau, NgayKetThuc, NoiDung) VALUES
 (1, N'Hội nhập nhân viên mới',                  N'Trực tiếp',  '2026-07-06', '2026-07-08', N'Văn hóa công ty, nội quy, quy trình làm việc, an toàn thông tin cơ bản.'),
 (2, N'Kỹ năng giao tiếp và làm việc nhóm',      N'Trực tiếp',  '2026-03-10', '2026-03-12', N'Giao tiếp hiệu quả, phản hồi, giải quyết xung đột trong nhóm.'),
 (3, N'Excel nâng cao cho kế toán',              N'Trực tuyến', '2026-04-01', '2026-04-30', N'Hàm tra cứu, PivotTable, Power Query, lập báo cáo lương.'),
 (4, N'Bảo mật thông tin trong doanh nghiệp',    N'Trực tuyến', '2026-06-01', '2026-06-15', N'Mật khẩu, lừa đảo qua email, phân quyền dữ liệu, sao lưu.'),
 (5, N'Kỹ năng lãnh đạo cho quản lý',            N'Trực tiếp',  '2026-08-17', '2026-08-21', N'Lãnh đạo tình huống, giao việc, đánh giá hiệu suất, huấn luyện nhân viên.'),
 (6, N'Lập trình .NET và SQL Server',            N'Kết hợp',    '2026-10-05', '2026-11-27', N'ASP.NET Core, Entity Framework, tối ưu truy vấn SQL Server.');
SET IDENTITY_INSERT dbo.DAOTAO OFF;

/* ---------------------------------------------------------------------
   10. THAM_GIA_DAO_TAO (23) – chỉ nhân viên đang làm tại thời điểm khóa học
   --------------------------------------------------------------------- */
INSERT INTO dbo.THAM_GIA_DAO_TAO (MaNV, MaDT, NgayThamGia, KetQua, DanhGia) VALUES
 (21, 1, '2026-07-06', N'Hoàn thành',       N'Nắm tốt quy trình, tích cực đặt câu hỏi.'),
 ( 7, 2, '2026-03-10', N'Hoàn thành',       N'Chủ động, hỗ trợ đồng đội tốt.'),
 ( 8, 2, '2026-03-10', N'Hoàn thành',       NULL),
 (12, 2, '2026-03-10', N'Hoàn thành',       N'Cải thiện rõ kỹ năng thuyết trình.'),
 (16, 2, '2026-03-10', N'Hoàn thành',       NULL),
 (18, 2, '2026-03-10', N'Không hoàn thành', N'Vắng 1 buổi do công tác.'),
 (22, 2, '2026-03-10', N'Hoàn thành',       NULL),
 ( 3, 3, '2026-04-01', N'Hoàn thành',       N'Áp dụng ngay vào báo cáo lương.'),
 ( 9, 3, '2026-04-01', N'Hoàn thành',       N'Điểm bài cuối khóa cao nhất lớp.'),
 (10, 3, '2026-04-01', N'Hoàn thành',       NULL),
 ( 7, 4, '2026-06-01', N'Hoàn thành',       NULL),
 (14, 4, '2026-06-01', N'Hoàn thành',       N'Đề xuất được quy trình sao lưu cho phòng.'),
 (15, 4, '2026-06-01', N'Hoàn thành',       NULL),
 (16, 4, '2026-06-01', N'Hoàn thành',       NULL),
 (17, 4, '2026-06-01', N'Không hoàn thành', N'Chưa làm bài kiểm tra cuối khóa.'),
 ( 2, 5, '2026-08-17', N'Hoàn thành',       NULL),
 ( 4, 5, '2026-08-17', N'Hoàn thành',       N'Có kế hoạch phát triển đội ngũ cụ thể.'),
 ( 5, 5, '2026-08-17', N'Hoàn thành',       NULL),
 ( 6, 5, '2026-08-17', N'Hoàn thành',       NULL),
 (11, 5, '2026-08-17', N'Hoàn thành',       N'Phù hợp quy hoạch trưởng phòng.'),
 (15, 6, '2026-10-05', N'Đang học',         NULL),
 (17, 6, '2026-10-05', N'Đang học',         NULL),
 (21, 6, '2026-10-05', N'Đang học',         NULL);

/* ---------------------------------------------------------------------
   11. DANH_GIA (34) – XepLoai theo điểm:
       ≥ 90 Xuất sắc · ≥ 80 Giỏi · ≥ 65 Khá · ≥ 50 Trung bình · < 50 Yếu
   --------------------------------------------------------------------- */
INSERT INTO dbo.DANH_GIA (MaNV, KyDanhGia, NgayDanhGia, Diem, XepLoai, NhanXet)
SELECT d.MaNV, d.Ky, d.Ngay, d.Diem,
       CASE WHEN d.Diem >= 90 THEN N'Xuất sắc' WHEN d.Diem >= 80 THEN N'Giỏi' WHEN d.Diem >= 65 THEN N'Khá'
            WHEN d.Diem >= 50 THEN N'Trung bình' ELSE N'Yếu' END,
       d.NhanXet
FROM (VALUES
 ( 1, N'Năm 2025', CAST('2025-12-20' AS DATE), CAST(92.00 AS DECIMAL(5, 2)), N'Hoàn thành vượt kế hoạch doanh thu năm.'),
 ( 2, N'Năm 2025', '2025-12-20', 88.00, N'Tổ chức tuyển dụng đúng tiến độ.'),
 ( 3, N'Năm 2025', '2025-12-20', 90.50, N'Quyết toán năm chính xác, đúng hạn.'),
 ( 4, N'Năm 2025', '2025-12-20', 85.00, NULL),
 ( 5, N'Năm 2025', '2025-12-20', 93.00, N'Dẫn dắt dự án chuyển đổi hệ thống thành công.'),
 ( 6, N'Năm 2025', '2025-12-20', 81.00, NULL),
 ( 7, N'Năm 2025', '2025-12-20', 86.00, NULL),
 ( 8, N'Năm 2025', '2025-12-20', 72.00, N'Cần chủ động hơn trong công việc.'),
 ( 9, N'Năm 2025', '2025-12-20', 78.50, NULL),
 (10, N'Năm 2025', '2025-12-20', 64.00, N'Còn chậm tiến độ báo cáo tháng.'),
 (11, N'Năm 2025', '2025-12-20', 83.00, NULL),
 (12, N'Năm 2025', '2025-12-20', 76.00, NULL),
 (14, N'Năm 2025', '2025-12-20', 89.00, NULL),
 (15, N'Năm 2025', '2025-12-20', 91.00, N'Đóng góp lớn cho dự án nội bộ.'),
 (16, N'Năm 2025', '2025-12-20', 84.00, NULL),
 (17, N'Năm 2025', '2025-12-20', 68.00, NULL),
 (18, N'Năm 2025', '2025-12-20', 80.00, NULL),
 (19, N'Năm 2025', '2025-12-20', 45.00, N'Không đạt chỉ tiêu, đã xin nghỉ việc cuối năm.'),
 (20, N'Năm 2025', '2025-12-20', 70.00, NULL),
 (22, N'Năm 2025', '2025-12-20', 74.00, N'Thích nghi nhanh với công việc.'),
 (23, N'Năm 2025', '2025-12-20', 58.00, N'Mới vào làm, cần thêm thời gian.'),
 ( 7, N'Quý 3/2026', '2026-09-28', 88.00, NULL),
 ( 8, N'Quý 3/2026', '2026-09-28', 75.00, N'Có tiến bộ so với năm trước.'),
 ( 9, N'Quý 3/2026', '2026-09-28', 81.00, NULL),
 (11, N'Quý 3/2026', '2026-09-28', 86.00, NULL),
 (12, N'Quý 3/2026', '2026-09-28', 79.50, NULL),
 (14, N'Quý 3/2026', '2026-09-28', 90.00, NULL),
 (15, N'Quý 3/2026', '2026-09-28', 94.00, N'Hoàn thành sớm dự án nội bộ.'),
 (16, N'Quý 3/2026', '2026-09-28', 87.00, NULL),
 (17, N'Quý 3/2026', '2026-09-28', 71.00, NULL),
 (18, N'Quý 3/2026', '2026-09-28', 82.00, NULL),
 (21, N'Quý 3/2026', '2026-09-28', 62.00, N'Thực tập sinh, cần cải thiện kỹ năng SQL.'),
 (22, N'Quý 3/2026', '2026-09-28', 77.00, NULL),
 (23, N'Quý 3/2026', '2026-09-28', 66.00, NULL)
) AS d (MaNV, Ky, Ngay, Diem, NhanXet);

/* ---------------------------------------------------------------------
   12. KHEN_THUONG (10)
   --------------------------------------------------------------------- */
INSERT INTO dbo.KHEN_THUONG (MaNV, NgayKT, LyDo, HinhThuc, SoTien) VALUES
 ( 5, '2025-12-30', N'Nhân viên xuất sắc năm 2025',              N'Giấy khen và tiền thưởng', 10000000),
 (14, '2025-12-30', N'Nhân viên xuất sắc năm 2025',              N'Giấy khen và tiền thưởng',  8000000),
 (22, '2026-04-15', N'Nhân viên mới tiêu biểu',                  N'Tiền thưởng',               1000000),
 (12, '2026-07-15', N'Vượt chỉ tiêu doanh số quý 2/2026',        N'Tiền thưởng',               3000000),
 (11, '2026-07-15', N'Vượt chỉ tiêu doanh số quý 2/2026',        N'Tiền thưởng',               5000000),
 (15, '2026-08-20', N'Hoàn thành sớm dự án nội bộ',              N'Tiền thưởng',               4000000),
 (16, '2026-08-20', N'Hoàn thành sớm dự án nội bộ',              N'Tiền thưởng',               4000000),
 ( 9, '2026-09-05', N'Hoàn thành quyết toán thuế đúng hạn',      N'Giấy khen',                       0),
 ( 7, '2026-09-10', N'Tổ chức đợt tuyển thực tập sinh hiệu quả', N'Giấy khen và tiền thưởng',  2000000),
 (18, '2026-09-25', N'Chiến dịch marketing quý 3 hiệu quả',      N'Tiền thưởng',               3500000);

/* ---------------------------------------------------------------------
   13. DON_NGHI_PHEP (13) – SoNgay = số ngày theo lịch (nửa ngày = 0.5);
       các đơn 'Đã duyệt' của cùng nhân viên không trùng thời gian
   --------------------------------------------------------------------- */
INSERT INTO dbo.DON_NGHI_PHEP (MaNV, TuNgay, DenNgay, SoNgay, LyDo, TrangThai) VALUES
 (20, '2026-05-01', '2026-10-31', 184,  N'Nghỉ thai sản',                           N'Đã duyệt'),
 (14, '2026-07-20', '2026-07-24',   5,  N'Nghỉ phép năm',                           N'Đã duyệt'),
 (10, '2026-08-01', '2026-11-30', 122,  N'Nghỉ không lương vì việc gia đình',       N'Đã duyệt'),
 ( 9, '2026-09-07', '2026-09-08',   2,  N'Việc cá nhân',                            N'Từ chối'),
 ( 7, '2026-09-14', '2026-09-15',   2,  N'Việc gia đình',                           N'Đã duyệt'),
 (17, '2026-09-14', '2026-09-14',   1,  N'Ốm (chưa có giấy xác nhận)',              N'Từ chối'),
 (12, '2026-09-21', '2026-09-21', 0.5,  N'Khám sức khỏe (nửa ngày)',                N'Đã duyệt'),
 (22, '2026-09-21', '2026-09-23',   3,  N'Việc gia đình',                           N'Đã duyệt'),
 (16, '2026-09-28', '2026-09-30',   3,  N'Ốm',                                      N'Đã duyệt'),
 ( 8, '2026-10-05', '2026-10-06',   2,  N'Ốm',                                      N'Chờ duyệt'),
 (15, '2026-10-12', '2026-10-14',   3,  N'Du lịch cùng gia đình',                   N'Chờ duyệt'),
 (18, '2026-10-19', '2026-10-23',   5,  N'Nghỉ phép năm',                           N'Chờ duyệt'),
 (11, '2026-10-26', '2026-10-27',   2,  N'Việc gia đình',                           N'Chờ duyệt');

/* ---------------------------------------------------------------------
   14. CHAM_CONG – 01/09/2026 → 09/10/2026, thứ 2–6, trừ nghỉ lễ 01–02/09
       Nhân viên 'Đang làm', đã vào làm, không có đơn nghỉ 'Đã duyệt' trong ngày.
       Kiểu ngày được phân bố cố định theo (MaNV, ngày) để dữ liệu lặp lại được:
         Đúng giờ · Đi muộn · Về sớm · tăng ca (SoGioOT > 0) · Vắng (không giờ vào/ra)
   --------------------------------------------------------------------- */
;WITH So AS (
    SELECT a.n * 10 + b.n AS i
    FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS a (n)
    CROSS JOIN (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS b (n)
),
Ngay AS (
    SELECT DATEADD(DAY, i, CAST('2026-09-01' AS DATE)) AS Ngay
    FROM So
    WHERE DATEADD(DAY, i, CAST('2026-09-01' AS DATE)) <= '2026-10-09'
),
NgayLam AS (
    SELECT Ngay FROM Ngay
    WHERE DATEDIFF(DAY, '1900-01-01', Ngay) % 7 < 5            -- 0 = thứ Hai … 4 = thứ Sáu (không phụ thuộc SET DATEFIRST)
      AND Ngay NOT IN ('2026-09-01', '2026-09-02')              -- nghỉ lễ Quốc khánh
),
LichLam AS (
    SELECT nv.MaNV, nl.Ngay,
           (nv.MaNV * 31 + DATEDIFF(DAY, '2026-01-01', nl.Ngay) * 17) % 20 AS Kieu
    FROM dbo.NHANVIEN AS nv
    CROSS JOIN NgayLam AS nl
    WHERE nv.TrangThai = N'Đang làm'
      AND nv.NgayVaoLam <= nl.Ngay
      AND NOT EXISTS (SELECT 1 FROM dbo.DON_NGHI_PHEP AS d
                      WHERE d.MaNV = nv.MaNV AND d.TrangThai = N'Đã duyệt'
                        AND nl.Ngay BETWEEN d.TuNgay AND d.DenNgay)
)
INSERT INTO dbo.CHAM_CONG (MaNV, Ngay, GioVao, GioRa, SoGioOT, TrangThai)
SELECT MaNV, Ngay,
       CASE Kieu WHEN 19 THEN NULL
                 WHEN 0  THEN CAST('08:25' AS TIME)
                 WHEN 7  THEN CAST('08:40' AS TIME)
                 ELSE DATEADD(MINUTE, (Kieu % 4) * 3, CAST('07:50' AS TIME)) END,
       CASE Kieu WHEN 19 THEN NULL
                 WHEN 1  THEN CAST('16:15' AS TIME)
                 WHEN 2  THEN CAST('19:30' AS TIME)
                 WHEN 3  THEN CAST('20:30' AS TIME)
                 WHEN 11 THEN CAST('19:00' AS TIME)
                 ELSE CAST('17:05' AS TIME) END,
       CASE Kieu WHEN 2 THEN 2.50 WHEN 3 THEN 3.50 WHEN 11 THEN 2.00 ELSE 0 END,
       CASE Kieu WHEN 19 THEN N'Vắng'
                 WHEN 0  THEN N'Đi muộn'
                 WHEN 7  THEN N'Đi muộn'
                 WHEN 1  THEN N'Về sớm'
                 ELSE N'Đúng giờ' END
FROM LichLam;

/* ---------------------------------------------------------------------
   15. BANG_LUONG – 07, 08, 09/2026
       Nhân viên có lương tháng: đã vào làm trước cuối tháng, chưa nghỉ việc,
       không nghỉ (đơn đã duyệt) trọn cả tháng. Lấy hợp đồng mới nhất còn hiệu lực trong tháng.
   --------------------------------------------------------------------- */
;WITH Thang AS (
    SELECT Thang, Nam, DATEFROMPARTS(Nam, Thang, 1) AS DauThang, EOMONTH(DATEFROMPARTS(Nam, Thang, 1)) AS CuoiThang
    FROM (VALUES (7, 2026), (8, 2026), (9, 2026)) AS t (Thang, Nam)
),
HopDongThang AS (
    SELECT t.Thang, t.Nam, t.DauThang, t.CuoiThang, hd.MaNV, hd.LuongCoBan, hd.LuongHieuSuat, hd.PhuCap,
           ROW_NUMBER() OVER (PARTITION BY t.Thang, t.Nam, hd.MaNV ORDER BY hd.NgayBatDau DESC) AS ThuTu
    FROM Thang AS t
    JOIN dbo.HOPDONG AS hd
      ON hd.NgayBatDau <= t.CuoiThang
     AND (hd.NgayKetThuc IS NULL OR hd.NgayKetThuc >= t.DauThang)
     AND hd.TrangThai <> N'Chấm dứt'
),
Luong AS (
    SELECT h.MaNV, h.Thang, h.Nam, h.LuongCoBan, h.LuongHieuSuat, h.PhuCap,
           ISNULL((SELECT SUM(kt.SoTien) FROM dbo.KHEN_THUONG AS kt
                   WHERE kt.MaNV = h.MaNV AND kt.NgayKT BETWEEN h.DauThang AND h.CuoiThang), 0) AS TienThuong,
           ROUND(h.LuongCoBan * 0.105, 0) AS KhauTru
    FROM HopDongThang AS h
    JOIN dbo.NHANVIEN AS nv ON nv.MaNV = h.MaNV
    WHERE h.ThuTu = 1
      AND nv.NgayVaoLam <= h.CuoiThang
      AND nv.TrangThai <> N'Nghỉ việc'
      AND NOT EXISTS (SELECT 1 FROM dbo.DON_NGHI_PHEP AS d
                      WHERE d.MaNV = h.MaNV AND d.TrangThai = N'Đã duyệt'
                        AND d.TuNgay <= h.DauThang AND d.DenNgay >= h.CuoiThang)
)
INSERT INTO dbo.BANG_LUONG (MaNV, Thang, Nam, LuongCoBan, LuongHieuSuat, PhuCap, TienThuong, KhauTru, LuongThucNhan)
SELECT MaNV, Thang, Nam, LuongCoBan, LuongHieuSuat, PhuCap, TienThuong, KhauTru,
       LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru
FROM Luong;

/* ---------------------------------------------------------------------
   16. PHUC_LOI (14)
   --------------------------------------------------------------------- */
INSERT INTO dbo.PHUC_LOI (MaNV, TenPhucLoi, NgayBatDau, NgayKetThuc, GiaTri, TrangThai) VALUES
 ( 1, N'Bảo hiểm sức khỏe cao cấp',   '2026-01-01', '2026-12-31', 15000000, N'Đang áp dụng'),
 ( 2, N'Bảo hiểm sức khỏe cao cấp',   '2026-01-01', '2026-12-31', 10000000, N'Đang áp dụng'),
 ( 5, N'Bảo hiểm sức khỏe cao cấp',   '2026-01-01', '2026-12-31', 10000000, N'Đang áp dụng'),
 ( 7, N'Hỗ trợ ăn trưa',              '2026-01-01', NULL,           730000, N'Đang áp dụng'),
 ( 8, N'Hỗ trợ ăn trưa',              '2026-01-01', NULL,           730000, N'Đang áp dụng'),
 (12, N'Hỗ trợ gửi xe',               '2025-06-01', NULL,           200000, N'Đang áp dụng'),
 (15, N'Hỗ trợ học phí thạc sĩ',      '2025-09-01', '2027-08-31', 30000000, N'Đang áp dụng'),
 (16, N'Khám sức khỏe định kỳ',       '2026-06-10', '2026-06-10',  1500000, N'Đã kết thúc'),
 (17, N'Khám sức khỏe định kỳ',       '2026-06-10', '2026-06-10',  1500000, N'Đã kết thúc'),
 (10, N'Hỗ trợ ăn trưa',              '2025-01-01', NULL,           730000, N'Tạm dừng'),
 (20, N'Hỗ trợ thai sản',             '2026-05-01', '2026-10-31',  5000000, N'Đang áp dụng'),
 (13, N'Hỗ trợ ăn trưa',              '2024-01-01', '2025-06-30',   730000, N'Đã kết thúc'),
 (19, N'Hỗ trợ gửi xe',               '2024-01-01', '2025-12-31',   200000, N'Đã kết thúc'),
 (21, N'Hỗ trợ ăn trưa',              '2026-07-01', NULL,           730000, N'Đang áp dụng');

COMMIT TRANSACTION;
PRINT N'Đã nạp dữ liệu mẫu.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
GO

/* =====================================================================
   Kiểm tra
   ===================================================================== */

-- Số dòng 16 bảng
SELECT N'PHONGBAN' AS Bang, COUNT(*) AS SoDong FROM dbo.PHONGBAN
UNION ALL SELECT N'CHUCVU', COUNT(*) FROM dbo.CHUCVU
UNION ALL SELECT N'NHANVIEN', COUNT(*) FROM dbo.NHANVIEN
UNION ALL SELECT N'HOPDONG', COUNT(*) FROM dbo.HOPDONG
UNION ALL SELECT N'DOT_TUYENDUNG', COUNT(*) FROM dbo.DOT_TUYENDUNG
UNION ALL SELECT N'VI_TRI_TUYENDUNG', COUNT(*) FROM dbo.VI_TRI_TUYENDUNG
UNION ALL SELECT N'UNGVIEN', COUNT(*) FROM dbo.UNGVIEN
UNION ALL SELECT N'UNG_TUYEN', COUNT(*) FROM dbo.UNG_TUYEN
UNION ALL SELECT N'DAOTAO', COUNT(*) FROM dbo.DAOTAO
UNION ALL SELECT N'THAM_GIA_DAO_TAO', COUNT(*) FROM dbo.THAM_GIA_DAO_TAO
UNION ALL SELECT N'DANH_GIA', COUNT(*) FROM dbo.DANH_GIA
UNION ALL SELECT N'KHEN_THUONG', COUNT(*) FROM dbo.KHEN_THUONG
UNION ALL SELECT N'CHAM_CONG', COUNT(*) FROM dbo.CHAM_CONG
UNION ALL SELECT N'DON_NGHI_PHEP', COUNT(*) FROM dbo.DON_NGHI_PHEP
UNION ALL SELECT N'BANG_LUONG', COUNT(*) FROM dbo.BANG_LUONG
UNION ALL SELECT N'PHUC_LOI', COUNT(*) FROM dbo.PHUC_LOI;

-- Các case cần có (Master Handoff §7)
SELECT N'NHANVIEN.TrangThai' AS NoiDung, TrangThai AS GiaTri, COUNT(*) AS SoDong FROM dbo.NHANVIEN GROUP BY TrangThai
UNION ALL SELECT N'HOPDONG.TrangThai', TrangThai, COUNT(*) FROM dbo.HOPDONG GROUP BY TrangThai
UNION ALL SELECT N'UNG_TUYEN.KetQua', KetQua, COUNT(*) FROM dbo.UNG_TUYEN GROUP BY KetQua
UNION ALL SELECT N'DON_NGHI_PHEP.TrangThai', TrangThai, COUNT(*) FROM dbo.DON_NGHI_PHEP GROUP BY TrangThai
UNION ALL SELECT N'CHAM_CONG có OT', CASE WHEN SoGioOT > 0 THEN N'Có OT' ELSE N'Không OT' END, COUNT(*) FROM dbo.CHAM_CONG GROUP BY CASE WHEN SoGioOT > 0 THEN N'Có OT' ELSE N'Không OT' END
UNION ALL SELECT N'DANH_GIA.XepLoai', XepLoai, COUNT(*) FROM dbo.DANH_GIA GROUP BY XepLoai
UNION ALL SELECT N'BANG_LUONG tháng', CONCAT(Thang, N'/', Nam), COUNT(*) FROM dbo.BANG_LUONG GROUP BY Thang, Nam
ORDER BY NoiDung, GiaTri;

-- Quy tắc dữ liệu: các dòng sau phải trả về 0
SELECT N'Lương lệch công thức' AS KiemTra, COUNT(*) AS SoDongViPham
FROM dbo.BANG_LUONG WHERE LuongThucNhan <> LuongCoBan + LuongHieuSuat + PhuCap + TienThuong - KhauTru
UNION ALL
SELECT N'NV còn làm không có đúng 1 HĐ hiệu lực', COUNT(*)
FROM dbo.NHANVIEN nv
WHERE nv.TrangThai <> N'Nghỉ việc'
  AND (SELECT COUNT(*) FROM dbo.HOPDONG hd WHERE hd.MaNV = nv.MaNV AND hd.TrangThai = N'Hiệu lực') <> 1
UNION ALL
SELECT N'Tuyển vượt số lượng vị trí', COUNT(*)
FROM dbo.VI_TRI_TUYENDUNG vt
WHERE (SELECT COUNT(*) FROM dbo.UNG_TUYEN ut WHERE ut.MaViTri = vt.MaViTri AND ut.TrangThai = N'Đã tuyển') > vt.SoLuong
UNION ALL
SELECT N'Vòng phỏng vấn vượt số vòng', COUNT(*)
FROM dbo.UNG_TUYEN ut JOIN dbo.VI_TRI_TUYENDUNG vt ON vt.MaViTri = ut.MaViTri WHERE ut.VongPhongVan > vt.SoVongPV
UNION ALL
SELECT N'Chấm công NV nghỉ việc/tạm nghỉ', COUNT(*)
FROM dbo.CHAM_CONG cc JOIN dbo.NHANVIEN nv ON nv.MaNV = cc.MaNV WHERE nv.TrangThai <> N'Đang làm'
UNION ALL
SELECT N'Đơn nghỉ đã duyệt trùng thời gian', COUNT(*)
FROM dbo.DON_NGHI_PHEP a JOIN dbo.DON_NGHI_PHEP b
  ON a.MaNV = b.MaNV AND a.MaDon < b.MaDon AND a.TrangThai = N'Đã duyệt' AND b.TrangThai = N'Đã duyệt'
 AND a.TuNgay <= b.DenNgay AND b.TuNgay <= a.DenNgay
UNION ALL
SELECT N'Đào tạo NV không đang làm lúc học', COUNT(*)
FROM dbo.THAM_GIA_DAO_TAO tg JOIN dbo.NHANVIEN nv ON nv.MaNV = tg.MaNV WHERE nv.NgayVaoLam > tg.NgayThamGia;
GO

SET NOEXEC OFF;
GO
