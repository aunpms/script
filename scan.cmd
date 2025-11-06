@echo off
title สร้างและตั้งค่าแชร์โฟลเดอร์ Scan (v2 - ตรวจสอบก่อน)
chcp 874 > nul

echo =================================================================
echo กำลังดำเนินการ: สร้างและตั้งค่าแชร์โฟลเดอร์ "Scan"
echo =================================================================
echo.

:: 1. กำหนดชื่อและเส้นทางของโฟลเดอร์
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
set "ExistingPath="

echo โฟลเดอร์เป้าหมาย: "%FullFolderPath%"
echo.

:: 2. ตรวจสอบว่ามี Share "Scan" อยู่แล้วหรือไม่
echo กำลังตรวจสอบว่ามี Share ชื่อ "%FolderName%" อยู่หรือไม่...
net share | findstr /I /C:"%FolderName% " > nul

if %ERRORLEVEL% equ 0 (
    :: 2.1 ถ้ามี Share "Scan" อยู่แล้ว
    echo [? ตรวจพบ] มี Share ชื่อ "%FolderName%" อยู่แล้ว
    
    :: 2.2 ตรวจสอบว่า Path ถูกต้องหรือไม่
    echo กำลังตรวจสอบเส้นทาง (Path) ของ Share ที่มีอยู่...
    
    :: ใช้ for /f เพื่อดึงค่า Path จากคำสั่ง net share
    for /f "tokens=1,*" %%a in ('net share %FolderName% ^| findstr /I /C:"Path "') do (
        set "ExistingPath=%%b"
    )
    
    :: ลบช่องว่างนำหน้าออกจาก Path ที่ดึงมาได้
    if defined ExistingPath (
        for /f "tokens=* delims= " %%i in ("%ExistingPath%") do set "ExistingPath=%%i"
    )

    echo   - เส้นทางที่ต้องการ: "%FullFolderPath%"
    echo   - เส้นทางปัจจุบัน:   "%ExistingPath%"
    echo.

    :: 2.3 เปรียบเทียบ Path (แบบไม่สนตัวพิมพ์เล็ก/ใหญ่)
    if /I "%ExistingPath%" == "%FullFolderPath%" (
        :: Path ถูกต้อง - ไปที่ขั้นตอนการตรวจสอบสิทธิ์
        echo [? สำเร็จ] Path ถูกต้อง, กำลังไปที่ขั้นตอนตรวจสอบสิทธิ์...
        goto :VERIFY_PERMISSIONS
    ) else (
        :: Path ไม่ถูกต้อง - ลบ Share เก่าทิ้ง แล้วไปสร้างใหม่
        echo [! แจ้งเตือน] Path ไม่ถูกต้อง!
        echo กำลังลบ Share เก่าที่ชี้ไปที่ "%ExistingPath%"...
        net share %FolderName% /delete /Y
        echo [? สำเร็จ] ลบ Share เก่าเรียบร้อยแล้ว
        echo.
        goto :CREATE_NEW_SHARE
    )

) else (
    :: 2.4 ถ้าไม่มี Share "Scan" - ไปที่ขั้นตอนการสร้างใหม่
    echo [? ตรวจไม่พบ] ไม่พบ Share ชื่อ "%FolderName%", กำลังเริ่มสร้างใหม่...
    echo.
    goto :CREATE_NEW_SHARE
)


:: =================================================================
:: ส่วนของการสร้างใหม่ (สำหรับ Share ที่ยังไม่มี หรือ Path ผิด)
:: =================================================================
:CREATE_NEW_SHARE
echo --- กำลังเริ่มกระบวนการสร้าง Share ใหม่ ---
:: 3. สร้างโฟลเดอร์
mkdir "%FullFolderPath%"
if exist "%FullFolderPath%" (
    echo [? สำเร็จ] สร้างโฟลเดอร์แล้ว
) else (
    echo [? ล้มเหลว] ไม่สามารถสร้างโฟลเดอร์ได้
    goto :END_SCRIPT
)
echo.

:: 4. แชร์โฟลเดอร์
echo กำลังแชร์โฟลเดอร์ (GRANT)...
net share %FolderName%="%FullFolderPath%" /GRANT:Everyone,FULL
echo [? สำเร็จ] แชร์โฟลเดอร์ "%FolderName%" เรียบร้อย
echo ** เส้นทาง Network: \\%COMPUTERNAME%\%FolderName% **
echo.

:: 5. ตั้งค่าสิทธิ์ NTFS
echo กำลังตั้งค่าสิทธิ์ NTFS...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T
echo [? สำเร็จ] ตั้งค่าสิทธิ์ NTFS: Everyone Full Control เรียบร้อย
echo.

:: 6. สร้าง Shortcut
echo กำลังสร้าง Shortcut...
goto :CREATE_SHORTCUT


:: =================================================================
:: ส่วนของการตรวจสอบสิทธิ์ (สำหรับ Share ที่มีอยู่และ Path ถูกต้อง)
:: =================================================================
:VERIFY_PERMISSIONS
echo --- กำลังตรวจสอบและบังคับใช้สิทธิ์ ---
:: 4. (ตรวจสอบ) บังคับใช้สิทธิ์การแชร์
echo กำลังบังคับใช้สิทธิ์การแชร์ (GRANT)...
net share %FolderName% /GRANT:Everyone,FULL
echo [? สำเร็จ] ตั้งค่าสิทธิ์แชร์: Everyone Full Control เรียบร้อย
echo.

:: 5. (ตรวจสอบ) บังคับใช้สิทธิ์ NTFS
echo กำลังบังคับใช้สิทธิ์ NTFS...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T
echo [? สำเร็จ] ตั้งค่าสิทธิ์ NTFS: Everyone Full Control เรียบร้อย
echo.

:: 6. (ตรวจสอบ) สร้าง Shortcut
echo กำลังตรวจสอบ/สร้าง Shortcut...
goto :CREATE_SHORTCUT


:: =================================================================
:: ส่วนที่ทำร่วมกัน
:: =================================================================
:CREATE_SHORTCUT
powershell -Command "$Desktop = Join-Path $env:PUBLIC -ChildPath 'Desktop'; If (Test-Path $Desktop) { $s=(New-Object -COM WScript.Shell).CreateShortcut((Join-Path $Desktop 'Scan.lnk')); $s.TargetPath='%FullFolderPath%'; $s.Save(); Exit 0 } Else { Write-Error 'Public Desktop not found.'; Exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo [? สำเร็จ] สร้าง/อัปเดต Shortcut บน Desktop แล้ว
) else (
    echo [? ล้มเหลว] สร้าง Shortcut ไม่สำเร็จ (อาจไม่มี Public Desktop)
)
echo.

:: 7. เปิด Advanced Sharing Settings (ทำทุกกรณี)
echo กำลังเปิดหน้าต่าง "Advanced Sharing Settings"...
control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced

echo =================================================================
echo === การดำเนินการเสร็จสิ้น ===
echo =================================================================

:END_SCRIPT
pause
