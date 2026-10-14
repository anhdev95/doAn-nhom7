--1. Trigger "Không trùng đơn nghỉ phép"
CREATE OR ALTER TRIGGER dbo.TRG01_DonNghiPhep_KhongTrung
ON dbo.DON_NGHI_PHEP
FOR INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted A
        JOIN DON_NGHI_PHEP B
             ON  B.MaNV  = A.MaNV
             AND B.MaDon <> A.MaDon
        WHERE B.TrangThai NOT IN (N'Từ chối', N'Đã hủy')
          AND A.TuNgay  <= B.DenNgay
          AND A.DenNgay >= B.TuNgay
    )
    BEGIN
        THROW 50001, N'Nhân viên đã có đơn nghỉ phép (chờ duyệt hoặc đã duyệt) trùng khoảng thời gian này.', 1;
    END
END
GO


--2. Trigger "Chặn nhập sai số ngày nghỉ phép"
--   SoNgay phải bằng số ngày từ TuNgay đến DenNgay; riêng đơn trong 1 ngày được phép nghỉ nửa ngày (0.5).
--   (SoNgay là NOT NULL nên không thể để trống rồi tự tính.)

CREATE OR ALTER TRIGGER dbo.TRG02_DonNghiPhep_SoNgay
ON dbo.DON_NGHI_PHEP
AFTER INSERT,UPDATE
AS 
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted
               WHERE SoNgay <> DATEDIFF(DAY, TuNgay, DenNgay) + 1
                 AND NOT (TuNgay = DenNgay AND SoNgay = 0.5))
    BEGIN
        THROW 50002, N'Số ngày nghỉ không khớp khoảng TuNgay – DenNgay (chỉ đơn 1 ngày được nghỉ 0.5). Vui lòng nhập lại', 1;
    END
END
GO

--3. Trigger "Không Chấm công cho nhân viên đã nghỉ việc / trước ngày vào làm"

CREATE OR ALTER TRIGGER dbo.TRG03_ChamCong_NVNghiViec
ON dbo.CHAM_CONG AFTER INSERT,UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
                JOIN NHANVIEN nv ON i.MaNV = nv.MaNV
                WHERE nv.TrangThai = N'Nghỉ việc')
        BEGIN
            THROW 50003, N'Nhân viên đã nghỉ việc', 1;
        END

    IF EXISTS (SELECT 1 FROM inserted i
                JOIN NHANVIEN nv ON i.MaNV = nv.MaNV
                WHERE i.Ngay < nv.NgayVaoLam)
        BEGIN
            THROW 50004, N'Ngày chấm công trước ngày vào làm của nhân viên', 1;
        END
END
GO

--4. Trigger "Đảm bảo chỉ mỗi nhân viên chỉ có 1 hợp đồng có hiệu lực"

CREATE OR ALTER TRIGGER dbo.TRG04_HopDong_MotHieuLuc
ON dbo.HOPDONG
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT hd.MaNV
        FROM HOPDONG hd
        WHERE hd.TrangThai = N'Hiệu lực'
          AND hd.MaNV IN (SELECT MaNV FROM inserted)   -- chỉ xét các NV vừa bị tác động
        GROUP BY hd.MaNV
        HAVING COUNT(*) > 1                            -- đếm riêng từng NV
    )
    BEGIN
        THROW 50005, N'Mỗi nhân viên chỉ được có 1 hợp đồng ở trạng thái Hiệu lực.', 1;
    END
END
GO
--5. Trigger "Xoá Mã Đào tạo"

CREATE OR ALTER TRIGGER dbo.TRG05_XoaDaoTao
ON dbo.DAOTAO
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM THAM_GIA_DAO_TAO
    WHERE MaDT IN (SELECT MaDT FROM deleted);

    DELETE FROM DAOTAO
    WHERE MaDT IN (SELECT MaDT FROM deleted);
END
GO

