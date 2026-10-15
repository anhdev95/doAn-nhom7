# IE103 – Nhóm 7 – Source

Hệ thống cơ sở dữ liệu quản lý nhân sự – Microsoft SQL Server – database `IE103_HRM_Nhom7`.

| Thư mục | Nội dung | Phụ trách | Trạng thái |
|---|---|---|---|
| `Database/` (01–04, ERD) | Tạo DB, 18 bảng, ràng buộc, dữ liệu mẫu, ERD – `ChayTatCa.cmd` chạy tất cả | Đức | Hoàn thành |
| `Database/Processing/` | 5 Procedure, 5 Trigger, 3 Function, 2 Cursor + `processing.manifest.json` + `Tests/` | Tuyến | Hoàn thành |
| `Database/Security/` | Authentication, Authorization, Import/Export, Backup/Restore | Đức | Hoàn thành |
| `Reports/` | 5 report Tableau (R01–R05) + `reports.manifest.json` | Tuyến | Hoàn thành |
| `Website/` | Website Demo (Node.js + Express + mssql) | Đức | Hoàn thành |

Hướng dẫn chạy: [Website/README.md](Website/README.md) · Database: [Database/README.md](Database/README.md) · ERD: [Database/ERD/ERD.md](Database/ERD/ERD.md)

```bash
# 1. Database (Windows, SQL Server): Source\Database\ChayTatCa.cmd  – hoặc chạy 01→04 trong SSMS
# 2. Website
cd Website
npm install
cp .env.example .env     # điền thông tin SQL Server
npm run check-db
npm run validate-integration
npm start                # http://localhost:3000
```
