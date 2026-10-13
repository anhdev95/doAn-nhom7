@echo off
REM =====================================================================
REM IE103 - Nhom 7 - Tao database IE103_HRM_Nhom7 tu dau bang sqlcmd (Windows)
REM Chay: 01 -> 02 -> 03 -> 04 -> Security\Authentication -> Security\Authorization
REM
REM Cach dung (mo Command Prompt tai thu muc nay):
REM     ChayTatCa.cmd                    Windows Authentication, server localhost
REM     ChayTatCa.cmd sa MatKhau         SQL Server Authentication
REM Doi SERVER ben duoi neu dung instance khac (vd. localhost\SQLEXPRESS).
REM Neu database da ton tai: mo 01_CreateDatabase.sql, dat @TaoLai = 1 roi chay lai.
REM =====================================================================
setlocal
set SERVER=localhost
if "%~1"=="" (set AUTH=-E) else (set AUTH=-U %1 -P %2)
cd /d "%~dp0"

for %%F in (01_CreateDatabase.sql 02_CreateTables.sql 03_Constraints.sql 04_SeedData.sql Security\Authentication.sql Security\Authorization.sql) do (
    echo.
    echo ===== %%F
    sqlcmd -S %SERVER% %AUTH% -C -f 65001 -b -i "%%F"
    if errorlevel 1 goto loi
)

echo.
echo Hoan tat. Kiem tra: cd ..\Website ^&^& npm run check-db
goto :eof

:loi
echo.
echo Dung lai vi co loi o file tren. Doc thong bao loi (Msg ...) de xu ly.
exit /b 1
