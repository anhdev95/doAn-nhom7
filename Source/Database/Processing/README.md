# Processing – Xử lý thông tin (Tuyến)

Chạy theo thứ tự (sau `01`–`04` và 2 script Security): `Procedures.sql` → `Functions.sql` → `Triggers.sql` → `Cursors.sql`.
Website đọc `processing.manifest.json` để hiển thị và Execute từng case (mặc định ROLLBACK).

| Mã | Object | Nội dung |
|---|---|---|
| SP01 | `SP01_HopDongSapHetHan` | Danh sách hợp đồng sắp hết hạn |
| SP02 | `SP02_ChiPhiTuyenDung` | Chi phí và hiệu quả tuyển dụng theo tháng |
| SP03 | `SP03_LichSuUngTuyen` | Lịch sử ứng tuyển của một ứng viên |
| SP04 | `SP04_ThongKeNhanVienPhongBan` | Thống kê nhân viên theo phòng ban |
| SP05 | `SP05_NhanVienKhongNghiPhep` | Nhân viên không nghỉ phép trong năm |
| TRG01 | `TRG01_DonNghiPhep_KhongTrung` | Không cho nộp đơn nghỉ phép trùng thời gian |
| TRG02 | `TRG02_DonNghiPhep_SoNgay` | Kiểm tra số ngày nghỉ phép |
| TRG03 | `TRG03_ChamCong_NVNghiViec` | Không chấm công cho nhân viên đã nghỉ việc |
| TRG04 | `TRG04_HopDong_MotHieuLuc` | Mỗi nhân viên chỉ có một hợp đồng hiệu lực |
| TRG05 | `TRG05_XoaDaoTao` | Xóa khóa đào tạo kèm các lượt tham gia |
| FN01 | `FN01_TongNgayNghi` | Tổng số ngày nghỉ phép đã duyệt trong tháng |
| FN02 | `FN02_TongCongOT` | Số công và tổng giờ tăng ca trong tháng |
| FN03 | `FN03_TyLeDau` | Tỷ lệ đậu của đợt tuyển dụng |
| CUR01 | `SP06_TinhHieuSuatThang` | Tính hiệu suất KPI và xếp loại theo tháng (cursor) |
| CUR02 | `SP07_TinhLuongThang` | Tính lương tháng cho nhân viên đang làm (cursor) |

`Tests/`: testcase cho 5 trigger – các bước hợp lệ chạy trước, bước vi phạm đặt cuối (kỳ vọng bị chặn).
