@echo off
setlocal
title Scan Folder Setup

set "SHARE_NAME=Scan"
set "LOCAL_PATH=%USERPROFILE%\Documents\Scan"
set "NETWORK_PATH=\\127.0.0.1\%SHARE_NAME%"
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\Scan.lnk"

:: ตรวจสอบ Share
net share %SHARE_NAME% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Share %SHARE_NAME% exists.
) else (
    echo [INFO] Share %SHARE_NAME% not found.
)

:: ตรวจสอบ Network Folder
if exist "%NETWORK_PATH%" (
    echo [INFO] Network folder exists.
) else (
    echo [INFO] Network folder not found. Checking local folder...
    if not exist "%LOCAL_PATH%" (
        echo [INFO] Local folder not found. Creating...
        mkdir "%LOCAL_PATH%"
    ) else (
        echo [INFO] Local folder exists.
    )
    echo [INFO] Creating share...
    net share %SHARE_NAME%="%LOCAL_PATH%"
)

:: ตั้ง NTFS Permission
echo [INFO] Setting NTFS permissions...
icacls "%LOCAL_PATH%" /grant Everyone:(OI)(CI)F /T /C

:: ตั้ง Share Permission (ใช้ PowerShell)
echo [INFO] Setting share permissions...
powershell -Command "Try {Set-SmbShare -Name '%SHARE_NAME%' -FullAccess 'Everyone' -ErrorAction Stop} Catch {Write-Host '[WARN] Cannot set share permissions automatically. Admin rights required or unsupported edition.'}"

:: สร้าง Shortcut
echo [INFO] Creating shortcut on Desktop...
powershell -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT_PATH%'); $Shortcut.TargetPath='%NETWORK_PATH%'; $Shortcut.WorkingDirectory='%NETWORK_PATH%'; $Shortcut.Save()"

echo [DONE] Setup complete.
pause
