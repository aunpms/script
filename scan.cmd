@echo off
setlocal enabledelayedexpansion
title Smart Setup: Localhost Scan Folder Auto-Fix (v3.8)

echo ================================================================
echo   Smart Setup: Localhost Scan Folder Auto-Fix (v3.8)
echo ================================================================
echo.

:: ------------------------------------------------------------
:: 1. ตรวจสอบว่ามีแชร์ "Scan" อยู่แล้วหรือไม่
:: ------------------------------------------------------------
echo 🔍 Checking existing shares...
for /f "skip=2 tokens=1" %%A in ('net share ^| findstr /I "^Scan " 2^>nul') do (
    if /I "%%A"=="Scan" (
        echo [OK] Shared folder "Scan" already exists.
        goto :shortcut
    )
)
echo [MISSING] No shared folder "Scan" found.
echo.

:: ------------------------------------------------------------
:: 2. ตรวจสอบว่า \\127.0.0.1\Scan มีอยู่ไหม
:: ------------------------------------------------------------
echo Checking if \\127.0.0.1\Scan exists...
net view \\127.0.0.1 | findstr /I "^Scan " >nul 2>&1
if %errorlevel%==0 (
    echo [FOUND] \\127.0.0.1\Scan detected.
    echo Re-sharing as local "Scan"...
    net share Scan="\\127.0.0.1\Scan" /grant:everyone,full >nul 2>&1
    goto :perms
)
echo [NOT FOUND] \\127.0.0.1\Scan not available.
echo.

:: ------------------------------------------------------------
:: 3. ถ้าไม่พบเลย ให้สร้างใหม่ใน Documents\Scan
:: ------------------------------------------------------------
set "ScanFolder=%USERPROFILE%\Documents\Scan"
echo Creating new shared folder at "%ScanFolder%"...
if not exist "%ScanFolder%" mkdir "%ScanFolder%" >nul 2>&1
net share Scan="%ScanFolder%" /grant:everyone,full >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create shared folder "Scan".
    pause
    exit /b
)
echo [OK] Shared folder created and available as \\127.0.0.1\Scan

:perms
:: ------------------------------------------------------------
:: 4. ตั้งสิทธิ์ NTFS ให้ Everyone (Full Control)
:: ------------------------------------------------------------
echo [STEP] Setting NTFS permissions for Everyone (Full Control)...
set "ScanFolderPath="
for /f "tokens=1,* delims= " %%a in ('net share Scan ^| findstr /R /C:"Path"') do set "ScanFolderPath=%%b"
if defined ScanFolderPath (
    icacls "!ScanFolderPath!" /grant Everyone:(OI)(CI)F /T /C >nul
    echo [OK] NTFS permissions set for Everyone.
) else (
    echo [WARNING] Could not determine share path for NTFS permission.
)

:: ------------------------------------------------------------
:: 5. สร้าง Shortcut ไปยัง \\127.0.0.1\Scan
:: ------------------------------------------------------------
:shortcut
echo [STEP] Creating shortcut on Desktop...
set "ShortcutFile=%USERPROFILE%\Desktop\Scan.lnk"
set "VBSFile=%TEMP%\mkshortcut_%RANDOM%.vbs"

(
    echo Set oWS = CreateObject("WScript.Shell")
    echo sLnk = "%ShortcutFile%"
    echo Set oLink = oWS.CreateShortcut(sLnk)
    echo oLink.TargetPath = "\\127.0.0.1\Scan"
    echo oLink.IconLocation = "imageres.dll,3"
    echo oLink.Description = "Open local Scan share"
    echo oLink.Save
) > "%VBSFile%"

cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1

if exist "%ShortcutFile%" (
    echo [OK] Shortcut created successfully: "%ShortcutFile%"
) else (
    echo [ERROR] Failed to create shortcut.
)

echo.
echo ================================================================
echo   ✅ All tasks completed successfully.
echo   You can now open: \\127.0.0.1\Scan
echo ================================================================
pause
exit /b
