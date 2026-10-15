# IE103 – Nhóm 7 – Website Demo HRM

Website demo cho đồ án **Hệ thống cơ sở dữ liệu quản lý nhân sự** (Microsoft SQL Server, database `IE103_HRM_Nhom7`).

```text
Browser  →  Node.js + Express  →  mssql  →  Microsoft SQL Server
```

- Mọi dữ liệu hiển thị được truy vấn trực tiếp từ SQL Server ở mỗi lần tải trang; website **không** lưu sẵn, mock hay hard-code dữ liệu/kết quả.
- Procedure/Trigger/Function/Cursor và Report do **Tuyến** bàn giao dưới dạng package; website tự nhận, không cần sửa code.
- Script An toàn thông tin do **nhóm** cung cấp; website đọc trạng thái thật (role, quyền, lịch sử backup/restore) và cung cấp công cụ test.

## 1. Giới thiệu các trang

| URL | Trang | Nội dung |
|---|---|---|
| `/` | Dashboard | Trạng thái kết nối, server, SQL version; số nhân viên/phòng ban/ứng viên/khóa đào tạo; số dòng 18 bảng (bảng thiếu = **Missing**); phân bố trạng thái theo miền giá trị đã chốt; tiến độ tích hợp Processing/Reports |
| `/tables` | Database Tables | Xem 18 bảng contract (whitelist), phân trang, số dòng/trang, sắp xếp PK tăng/giảm, NULL hiển thị rõ, **Export CSV** |
| `/processing` | Processing | 15 case (5 SP, 5 Trigger, 3 Function, 2 Cursor) theo B1 Bài toán → B2 SQL (definition đọc từ SQL Server) → B3 dữ liệu trước → B4 Execute (ROLLBACK/COMMIT) → B5 output, PRINT, lỗi, dữ liệu sau (tô màu thay đổi) |
| `/reports` | Reports | 5 report (ảnh/link/embed) theo `Source/Reports/reports.manifest.json` |
| `/security` | Security | Authentication (test đăng nhập), Authorization (role, GRANT/DENY, permission matrix), Import (so sánh trước/sau), Export, Backup/Restore (lịch sử msdb) |

Trạng thái thống nhất trên toàn website: **Connected / Disconnected** (DB) và **Ready / Pending / Missing / Error** (case, report, script).

## 2. Requirements

| Thành phần | Phiên bản |
|---|---|
| Node.js | ≥ 18 (đã test Node 24) – kiểm tra `node -v` |
| npm | đi kèm Node.js |
| Microsoft SQL Server | 2017 trở lên (đã test 2022 Developer); Express/Developer đều được. Website dùng `STRING_SPLIT` (database compatibility level ≥ 130) và `STRING_AGG` (SQL Server 2017+) |
| SSMS | để chạy script SQL của nhóm |
| Trình duyệt | Chrome/Edge/Firefox bản mới |

SQL Server phải bật **SQL Server Authentication (Mixed Mode)** và **TCP/IP** (xem mục Troubleshooting).

Tạo database trước khi chạy website: `Source\Database\ChayTatCa.cmd` (Windows) hoặc chạy `01` → `04` rồi
`Security/Authentication.sql`, `Security/Authorization.sql` trong SSMS – chi tiết ở `Source/Database/README.md`.

## 3. Cài đặt

```bash
cd Source/Website
npm install
cp .env.example .env          # Windows: copy .env.example .env
```

## 4. Cấu hình `.env`

```env
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=IE103_HRM_Nhom7
DB_USER=hrm_web
DB_PASSWORD="Web@Nhom7_2026"
DB_ENCRYPT=false
DB_TRUST_SERVER_CERTIFICATE=true
PORT=3000
```

- **Password có ký tự `#` phải đặt trong dấu nháy kép** (`DB_PASSWORD="Abc#123"`), nếu không phần sau `#` bị hiểu là comment → *Login failed*.
- `DB_SERVER`: tên máy/IP. Named instance (`.\SQLEXPRESS`) → dùng `DB_SERVER=localhost` + `DB_PORT` cố định của instance.
- SQL Server local: `DB_ENCRYPT=false`, `DB_TRUST_SERVER_CERTIFICATE=true`. Azure SQL: `DB_ENCRYPT=true`.
- `.env` nằm trong `.gitignore` – **không commit, không gửi password qua chat**. Website không trả credential về trình duyệt và không ghi log password.
- Login `hrm_web` được tạo bởi `Source/Database/Security/Authentication.sql` và cấp quyền ở `Authorization.sql` (đọc/ghi 18 bảng, EXECUTE, VIEW DEFINITION, đọc lịch sử backup/restore trong msdb). Trước khi chạy 2 script đó có thể tạm dùng `sa`. Login bị DENY sẽ không “thấy” bảng/object → website báo **Missing**.

## 5. Các lệnh

| Lệnh | Mục đích |
|---|---|
| `npm run check-db` | Kết nối SQL Server; in server/version/login; số dòng 18 bảng; **đối chiếu schema với Database contract** (cột, kiểu, PK, FK, UNIQUE), miền giá trị trạng thái, quy tắc `LuongThucNhan` và KPI (`HieuSuatKPI`, `HieuSuatKPITong`, tổng `TrongSo` = 100). Exit ≠ 0 nếu có FAIL |
| `npm run validate-integration` | Kiểm tra package Processing/Reports của Tuyến + script Security; nếu kết nối được DB thì kiểm tra object tồn tại, đúng loại, tham số khớp, bảng liên quan tồn tại. In `[PASS]/[WARN]/[FAIL]`, exit ≠ 0 nếu có FAIL. Tuỳ chọn `-- --no-db`, `-- --allow-pending` |
| `npm start` | Chạy website (mặc định `http://localhost:3000`) |
| `npm run dev` | Chạy và tự restart khi sửa code |
| `npm run check` | Syntax check + `validate-integration --allow-pending` + smoke test chỉ đọc (các trang và GET API) |

Quy trình chạy chuẩn:

```bash
cd Source/Website
npm install
npm run check-db
npm run validate-integration
npm start
```

## 6. Cấu trúc thư mục

```text
Source/
├── Database/
│   ├── 01_CreateDatabase.sql … 04_SeedData.sql   ← tạo DB, 18 bảng, ràng buộc, dữ liệu mẫu
│   ├── ChayTatCa.cmd                             ← chạy 01→04 + Security bằng sqlcmd (Windows)
│   ├── ERD/                                      ← ERD.png, ERD.mmd, ERD.md
│   ├── Processing/                               ← Xử lý thông tin (SP/Trigger/Function/Cursor)
│   │   ├── Procedures.sql  Triggers.sql  Functions.sql  Cursors.sql
│   │   ├── processing.manifest.json
│   │   └── Tests/
│   └── Security/                                 ← nhóm cung cấp
│       ├── Authentication.sql  Authorization.sql
│       ├── Import_Export/
│       └── Backup_Restore/
├── Reports/                                      ← 5 report (ảnh/link/embed)
│   ├── reports.manifest.json
│   └── R01.png … R05.png
└── Website/
    ├── README.md  package.json  .env.example  .gitignore
    ├── scripts/        check-db.js · validate-integration.js · check.js
    ├── src/
    │   ├── app.js
    │   ├── config/        database.js (pool, lỗi) · tables.js (whitelist) · contract.js · security.config.js
    │   ├── integration/   đọc + validate manifest, kiểm tra object/contract trong DB
    │   ├── routes/  controllers/  services/  utils/
    ├── public/         css · js
    └── views/          trang HTML
```

## 7. Xử lý thông tin (Processing) và Report

Website đọc 2 file manifest mỗi lần tải trang (không cần sửa code, không cần restart):

- `Source/Database/Processing/processing.manifest.json` – 15 case (5 SP, 5 Trigger, 3 Function, 2 Cursor): bài toán, object,
  bảng liên quan, cách thực thi và tham số. Object được tạo bằng `Procedures.sql`, `Functions.sql`, `Triggers.sql`, `Cursors.sql`
  (chạy trong SSMS trên `IE103_HRM_Nhom7`); testcase trigger/cursor nằm trong `Processing/Tests/`.
- `Source/Reports/reports.manifest.json` – 5 report (`image` đặt cạnh manifest, `link`/`embed` là URL https).

Kiểm tra: `npm run validate-integration` (manifest, file, object trong DB đúng loại, tham số khớp). Case/report chưa hợp lệ hiển thị
**Pending / Missing / Error** kèm lý do thay vì làm lỗi trang.

## 8. An toàn thông tin

Script trong `Source/Database/Security/` – thứ tự chạy, tài khoản demo, bảng phân quyền và kịch bản demo:
`Source/Database/Security/README.md`. Trang `/security` hiển thị trạng thái thật: login đang dùng, test đăng nhập,
role và GRANT/DENY, ma trận quyền, lịch sử backup/restore (msdb).
Website **không** có nút tạo login/GRANT/backup/restore: các thao tác đó chạy bằng script trong SSMS.

## 9. Report

Ảnh report (`.png/.jpg/.webp`) đặt trong `Source/Reports/` và khai báo trong `reports.manifest.json`. Website chỉ phục vụ file
được manifest khai báo; iframe nhúng report dùng `sandbox`.

## 10. Troubleshooting

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| Badge **Disconnected**, lỗi `ESOCKET … Could not connect` | Sai `DB_SERVER`/`DB_PORT`; service SQL Server chưa chạy; TCP/IP tắt; firewall | Kiểm tra service *SQL Server (MSSQLSERVER/SQLEXPRESS)* đang chạy, đúng port, mở firewall |
| **TCP/IP chưa bật** | SQL Express mặc định tắt TCP/IP | SQL Server Configuration Manager → SQL Server Network Configuration → Protocols for … → **TCP/IP = Enabled** → restart service |
| **Sai port** | SQL Express mặc định dùng *dynamic port*, không phải 1433 | Configuration Manager → TCP/IP → IP Addresses → IPAll: xóa *TCP Dynamic Ports*, đặt *TCP Port* = 1433 → restart service |
| `Login failed for user` (ELOGIN) | Sai user/password; server chỉ bật Windows Authentication; login bị disable; password có `#` chưa đặt trong nháy | SSMS → Server Properties → Security → **SQL Server and Windows Authentication mode** (Mixed Mode) → restart service; login → Status → Enabled; `DB_PASSWORD="..."` |
| Gợi ý “Login đúng nhưng database chưa tồn tại” | Chưa tạo DB / sai `DB_NAME` | Chạy `Source/Database/01_CreateDatabase.sql` → `02` → `03` → `04` |
| Gợi ý “Login đúng nhưng chưa có user trong database” | Login chưa được map vào DB | Tạo user trong DB cho login (script Authentication của nhóm) |
| `self signed certificate` / lỗi SSL/TLS | Driver mã hóa nhưng server dùng certificate tự ký | `DB_TRUST_SERVER_CERTIFICATE=true` (local) hoặc `DB_ENCRYPT=false` |
| Dashboard/Tables báo **Missing** bảng, lỗi `Invalid object name` (208) | Chưa chạy script tạo bảng, hoặc login website bị DENY trên bảng đó | Chạy `02_CreateTables.sql`, `03_Constraints.sql`; dùng login đọc được đủ 18 bảng |
| `The SELECT permission was denied` (229) – HTTP 403 | Login website thiếu quyền | Cấp quyền đọc cho login website; login hạn chế chỉ dùng để demo ở trang Security |
| `npm run check-db` báo FAIL contract | Schema thật lệch Database contract | Đối chiếu từng mục FAIL với `Source/Database/02_CreateTables.sql`, `03_Constraints.sql` và ERD (`Source/Database/ERD/`) |
| Processing **Pending** | Chưa có `processing.manifest.json` / case chưa khai báo | Chưa có package Xử lý thông tin (mục 7) |
| Processing **Missing** | Thiếu file testcase, hoặc object chưa tạo trong DB, hoặc login website không có quyền thấy object | Chạy `Procedures.sql`…`Cursors.sql`; `npm run validate-integration` để xem chi tiết |
| Processing **Error** | Manifest sai (JSON, id, bảng, kiểu tham số, sai loại object…) | Xem danh sách FAIL ở đầu trang case hoặc `npm run validate-integration` |
| Reports **Pending** / **Missing** / **Error** | Chưa có manifest / thiếu file ảnh / `src` hoặc URL sai | `npm run validate-integration` (mục REPORTS) |
| Port 3000 đang dùng | Ứng dụng khác chiếm cổng | Đổi `PORT` trong `.env` |
| Restore báo database đang được dùng | Còn cửa sổ SSMS/kết nối khác đang dùng DB | `04_Restore_GhiDe.sql` tự ngắt kết nối (SINGLE_USER … ROLLBACK IMMEDIATE); website tự kết nối lại sau restore. Hoặc dùng `03_Restore_KiemTra.sql` (restore ra DB bản sao) |

## 11. API

| Method | Path | Mô tả |
|---|---|---|
| GET | `/api/health` | Trạng thái kết nối (luôn 200, kèm lỗi + gợi ý nếu mất kết nối) |
| GET | `/api/dashboard` | Số liệu dashboard, phân bố trạng thái, tiến độ tích hợp |
| GET | `/api/tables` | Danh sách 18 bảng whitelist |
| GET | `/api/tables/:table?page=&pageSize=&order=asc\|desc` | Dữ liệu một bảng (400 nếu ngoài whitelist, 404 nếu chưa tạo, 403 nếu thiếu quyền) |
| GET | `/api/tables/:table/export.csv?order=` | Export CSV toàn bảng (tối đa 50.000 dòng) |
| GET | `/api/processing` | 15 case + trạng thái manifest/DB |
| GET | `/api/processing/:id` | Chi tiết case: definition từ DB, file SQL, dữ liệu trước |
| POST | `/api/processing/:id/execute` | Body `{ "params": {...}, "mode": "rollback" \| "commit" }` (409 nếu case chưa Ready) |
| GET | `/api/reports` | 5 report + trạng thái |
| GET | `/report-assets/:file` | Ảnh report (chỉ file được manifest khai báo) |
| GET | `/api/security/status` | Login hiện tại, role, quyền, user, lịch sử backup/restore, script nhóm |
| POST | `/api/security/login-test` | Body `{ "username", "password", "tryTable"? }` |

## 12. Nguyên tắc bảo mật trong code

- Connection pool dùng chung, tự kết nối lại (`src/config/database.js`).
- Input từ client luôn qua parameterized query; tên bảng chỉ từ whitelist 18 bảng; tên object/tham số chỉ từ manifest phía server và được kiểm tra định dạng. **Không có endpoint nhận SQL tùy ý.**
- File SQL/ảnh chỉ được đọc bên trong `Source/Database` và `Source/Reports` (chặn `../`); ảnh SVG bị từ chối.
- Processing chạy trong transaction; mặc định **ROLLBACK** sau khi đọc dữ liệu “sau”.
- Header CSP/nosniff; iframe report dùng `sandbox`; CSV chống công thức Excel (`=`, `+`, `-`, `@`).
- Không trả stack trace, credential hay đường dẫn tuyệt đối ra client.

