@echo off
setlocal enabledelayedexpansion
title Scan Folder Setup

:: 1. ตรวจสอบชื่อเครื่อง
set "COMPNAME=%COMPUTERNAME%"
echo Computer Name: %COMPNAME%

:: 2. ตรวจสอบ Documents\Scan
set "SCANFOLDER=%USERPROFILE%\Documents\Scan"
if exist "%SCANFOLDER%" (
    echo [INFO] Folder Scan exists in Documents.
) else (
    echo [INFO] Creating folder Scan in Documents...
    mkdir "%SCANFOLDER%"
)

:: 3. ตั้ง NTFS permission (Everyone Full Control)
echo [INFO] Setting NTFS permissions...
icacls "%SCANFOLDER%" /grant Everyone:F /T /C

:: 4. ตรวจสอบแชร์
set "SHARENAME=Scan"
net share | findstr /i "\\%COMPNAME%\%SHARENAME%" >nul
if %errorlevel%==0 (
    echo [INFO] Share %SHARENAME% already exists.
) else (
    echo [INFO] Creating share %SHARENAME%...
    net share %SHARENAME%="%SCANFOLDER%" /GRANT:Everyone,FULL
)

:: 5. ตั้ง Shortcut ไปยัง \\ComputerName\Scan
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\Scan.lnk"
if exist "%SHORTCUT%" (
    echo [INFO] Shortcut already exists.
) else (
    echo [INFO] Creating shortcut on Desktop...
    powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%SHORTCUT%');$s.TargetPath='\\\\%COMPNAME%\\%SHARENAME%';$s.Save()"
)

echo [DONE] Scan folder setup completed.
pause
