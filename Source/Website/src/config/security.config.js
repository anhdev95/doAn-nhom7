// INTEGRATION POINT – An toàn thông tin (Đức phụ trách).
// Web chỉ ĐỌC trạng thái thật từ SQL Server (catalog view, msdb) và chạy test đăng nhập;
// không tự tạo login/user/role, không tự GRANT/DENY, không tự backup/restore.
// Hướng dẫn: Source/Database/Security/README.md

module.exports = {
  // Role đề xuất trong Master Handoff §6 – đổi lại nếu script Authorization.sql dùng tên khác.
  expectedRoles: ['HR_ROLE', 'ACCOUNTING_ROLE', 'MANAGER_ROLE'],

  // Quyền được kiểm tra bằng HAS_PERMS_BY_NAME khi test đăng nhập (trên các bảng whitelist).
  checkedPermissions: ['SELECT', 'INSERT', 'UPDATE', 'DELETE'],

  // Script thật của nhóm (đường dẫn tương đối từ Source/Database). Web chỉ hiển thị nội dung
  // và trạng thái "đã có file" – việc chạy script thực hiện trong SSMS theo docs.
  scripts: {
    authentication: ['Security/Authentication.sql'],
    authorization: ['Security/Authorization.sql', 'Security/Authorization_XuLy.sql'],
    importExport: ['Security/Import_Export'],
    backupRestore: ['Security/Backup_Restore'],
  },
};
