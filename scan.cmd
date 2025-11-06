@echo off
:: -------------------------------
:: Scan Folder Setup (Auto-Elevate)
:: -------------------------------

:: ตรวจสอบ Admin
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Admin rights required. Relaunching as Admin...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: --------------------------------------------------
:: กำหนดตัวแปร
:: --------------------------------------------------
set "SHARE_NAME=Scan"
set "LOCAL_PATH=%USERPROFILE%\Documents\Scan"
set "NETWORK_PATH=\\127.0.0.1\%SHARE_NAME%"
set "SHORTCUT_PATH=%USERPROFILE%\Desktop\Scan.lnk"

:: --------------------------------------------------
:: ตรวจสอบ Share
:: --------------------------------------------------
net share %SHARE_NAME% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [INFO] Share %SHARE_NAME% exists.
) else (
    echo [INFO] Share %SHARE_NAME% not found.
)

:: --------------------------------------------------
:: ตรวจสอบ Network Folder
:: --------------------------------------------------
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

:: --------------------------------------------------
:: ตั้ง NTFS Permission
:: --------------------------------------------------
echo [INFO] Setting NTFS permissions...
icacls "%LOCAL_PATH%" /grant Everyone:(OI)(CI)F /T /C

:: --------------------------------------------------
:: ตั้ง Share Permission แบบครอบคลุมทุกเครื่อง
:: --------------------------------------------------
echo [INFO] Setting share permissions...
powershell -NoProfile -Command ^
"Try { ^
    if (Get-Command Set-SmbShare -ErrorAction SilentlyContinue) { ^
        Set-SmbShare -Name '%SHARE_NAME%' -FullAccess 'Everyone' -ErrorAction Stop ^
    } else { ^
        Write-Host '[WARN] Set-SmbShare not available. Windows Home edition?' ^
    } ^
} Catch { ^
    Write-Host '[WARN] Cannot set share permissions automatically. Admin rights required or unsupported edition.' ^
}"

:: --------------------------------------------------
:: สร้าง Shortcut บน Desktop
:: --------------------------------------------------
echo [INFO] Creating shortcut on Desktop...
powershell -NoProfile -Command ^
"$WshShell = New-Object -ComObject WScript.Shell; ^
$Shortcut = $WshShell.CreateShortcut('%SHORTCUT_PATH%'); ^
$Shortcut.TargetPath='%NETWORK_PATH%'; ^
$Shortcut.WorkingDirectory='%NETWORK_PATH%'; ^
$Shortcut.Save()"

echo [DONE] Setup complete.
exit /b
