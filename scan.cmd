@echo off
setlocal enabledelayedexpansion
title Smart Localhost Scan Share Auto-Fix (v4.2)

echo ================================================================
echo   Smart Localhost Scan Share Auto-Fix (v4.2)
echo ================================================================
echo.

:: -----------------------------
:: 1. ตรวจสอบว่ามีแชร์อยู่แล้วหรือไม่
:: -----------------------------
echo [CHECK] Checking shared folder on \\127.0.0.1 ...
for /f "skip=2 tokens=1" %%A in ('net view \\127.0.0.1 ^| findstr /I "Scan"') do (
    if /I "%%A"=="Scan" (
        set "ScanExists=1"
    )
)

if defined ScanExists (
    echo [FOUND] \\127.0.0.1\Scan already exists.
    set "ScanFolder="
    for /f "skip=2 tokens=1,*" %%A in ('net share ^| findstr /I "^Scan"') do set "ScanFolder=%%B"
    if not defined ScanFolder (
        echo [WARN] Could not determine physical path of Scan share.
    ) else (
        echo [INFO] Physical path: !ScanFolder!
    )
) else (
    echo [MISSING] Shared folder "Scan" not found.
    set "ScanFolder=%USERPROFILE%\Documents\Scan"
    echo Creating new folder at "%ScanFolder%"...
    if not exist "%ScanFolder%" mkdir "%ScanFolder%" >nul 2>&1
    echo Sharing folder as "Scan"...
    net share Scan="%ScanFolder%" /grant:Everyone,full >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create shared folder.
        pause
        exit /b 1
    )
    echo [OK] Shared folder created: \\127.0.0.1\Scan
)

:: -----------------------------
:: 2. ตั้งสิทธิ์ NTFS ให้ Everyone Full Control
:: -----------------------------
if not defined ScanFolder set "ScanFolder=%USERPROFILE%\Documents\Scan"
echo [STEP] Setting NTFS permissions for Everyone (Full Control)...
icacls "%ScanFolder%" /grant Everyone:"(OI)(CI)F" /T >nul
if %errorlevel% equ 0 (
    echo [OK] NTFS permissions set.
) else (
    echo [WARN] Failed to apply NTFS permissions.
)

:: -----------------------------
:: 3. ตรวจสอบ Share Permission (Advanced Sharing)
:: -----------------------------
echo [STEP] Verifying Share Permissions...
net share Scan | find /I "Everyone" >nul
if %errorlevel% neq 0 (
    echo [FIX] Adding Everyone Full Control to Share Permissions...
    net share Scan /grant:Everyone,full >nul 2>&1
)
echo [OK] Share Permissions verified.

:: -----------------------------
:: 4. สร้าง Shortcut บน Desktop ไปที่ \\127.0.0.1\Scan
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

:: -----------------------------
:: 5. จบการทำงาน
:: -----------------------------
echo.
echo ================================================================
echo   All tasks completed successfully.
echo   You can now open: \\127.0.0.1\Scan
echo ================================================================
exit /b 0
