@echo off
title สร้างและตั้งค่าแชร์โฟลเดอร์ Scan (Final Shortcut Fix)

echo =================================================================
echo กำลังดำเนินการ: สร้างและตั้งค่าแชร์โฟลเดอร์ "Scan"
echo =================================================================
echo.

:: 1. กำหนดชื่อและเส้นทางของโฟลเดอร์
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
:: ใช้ตัวแปร USERPROFILE เพื่อสร้างโฟลเดอร์ใน Documents ของผู้ใช้ที่รัน

:: 2. สร้างโฟลเดอร์ (ขั้นตอนเดิม)
mkdir "%FullFolderPath%"
if exist "%FullFolderPath%" (
    echo [? สำเร็จ] สร้างโฟลเดอร์แล้ว
) else (
    echo [? ล้มเหลว] ไม่สามารถสร้างโฟลเดอร์ได้
    goto :eof
)
echo.

:: 3. แชร์โฟลเดอร์ (ขั้นตอนเดิม)
net share %FolderName%="%FullFolderPath%" /GRANT:Everyone,FULL
echo [? สำเร็จ] แชร์โฟลเดอร์ "%FolderName%" เรียบร้อย
echo ** เส้นทาง Network: \\%COMPUTERNAME%\%FolderName% **
echo.

:: 4. ตั้งค่าสิทธิ์ NTFS (ขั้นตอนเดิม)
echo กำลังตั้งค่าสิทธิ์ NTFS ให้ Everyone เป็น Full Control...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T
echo [? สำเร็จ] ตั้งค่าสิทธิ์ NTFS: Everyone Full Control เรียบร้อย
echo.

:: 5. **แก้ไข:** สร้าง Shortcut ไปที่ Desktop ของผู้ใช้ปัจจุบันด้วย PowerShell
echo กำลังสร้าง Shortcut "Scan" บน Desktop ของผู้ใช้ %USERNAME%...
powershell -Command "$Desktop = Join-Path $env:PUBLIC -ChildPath 'Desktop'; If (Test-Path $Desktop) { $s=(New-Object -COM WScript.Shell).CreateShortcut((Join-Path $Desktop 'Scan.lnk')); $s.TargetPath='%FullFolderPath%'; $s.Save(); Exit 0 } Else { Write-Error 'Public Desktop not found.'; Exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo [? สำเร็จ] สร้าง Shortcut บน Desktop แล้ว
) else (
    echo [? ล้มเหลว] สร้าง Shortcut ไม่สำเร็จ (อาจไม่มี Public Desktop)
)
echo.

:: 6. เปิด Advanced Sharing Settings (ขั้นตอนเดิม)
echo กำลังเปิดหน้าต่าง "Advanced Sharing Settings"...
control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced

echo =================================================================
echo === การดำเนินการเสร็จสิ้น ===
echo =================================================================
pause
