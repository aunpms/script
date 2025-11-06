@echo off
setlocal enabledelayedexpansion
title Smart Setup: Localhost Scan Folder Auto-Fix (v3.7)

echo ================================================================
echo   Smart Setup: Localhost Scan Folder Auto-Fix (v3.7)
echo ================================================================
echo.

:: -----------------------------
:: 1. ตรวจสอบการแชร์อยู่แล้วหรือไม่
:: -----------------------------
echo Checking existing shares on localhost...
for /f "skip=2 tokens=1" %%A in ('net share ^| findstr /I "Scan"') do (
    if /I "%%A"=="Scan" (
        echo [OK] Shared folder "Scan" already exists.
        goto :shortcut
    )
)
echo [MISSING] Shared folder "Scan" not found.

:: -----------------------------
:: 2. สร้างโฟลเดอร์หากยังไม่มี
:: -----------------------------
set "ScanFolder=%USERPROFILE%\Documents\Scan"
if not exist "%ScanFolder%" (
    echo Creating new folder at "%ScanFolder%"...
    mkdir "%ScanFolder%" >nul 2>&1
)

:: -----------------------------
:: 3. แชร์โฟลเดอร์
:: -----------------------------
echo Sharing folder as "Scan"...
net share Scan="%ScanFolder%" /grant:everyone,full >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create shared folder "Scan".
    pause
    exit /b
)
echo [OK] Shared folder created and available as \\127.0.0.1\Scan

:: -----------------------------
:: 4. ตั้งสิทธิ์ NTFS ให้ Everyone Full Control
:: -----------------------------
echo [STEP] Setting NTFS permissions for Everyone (Full Control)...
icacls "%ScanFolder%" /grant Everyone:(OI)(CI)F /T >nul
echo [OK] NTFS permissions set.

:shortcut
:: -----------------------------
:: 5. สร้างช็อตคัทจริงบน Desktop
:: -----------------------------
echo [STEP] Creating shortcut on Desktop...
set "ShortcutFile=%USERPROFILE%\Desktop\Scan.lnk"
set "VBSFile=%TEMP%\mkshortcut.vbs"

(
    echo Set oWS = CreateObject("WScript.Shell")
    echo sLinkFile = "%ShortcutFile%"
    echo Set oLink = oWS.CreateShortcut(sLinkFile)
    echo oLink.TargetPath = "\\127.0.0.1\Scan"
    echo oLink.IconLocation = "imageres.dll,3"
    echo oLink.Save
) > "%VBSFile%"

cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1

if exist "%ShortcutFile%" (
    echo [OK] Shortcut created: "%ShortcutFile%"
) else (
    echo [ERROR] Failed to create shortcut.
)

echo.
echo ================================================================
echo   All tasks completed successfully.
echo   You can now open: \\127.0.0.1\Scan
echo ================================================================
pause
exit /b
