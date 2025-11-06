@echo off
setlocal enabledelayedexpansion
title Smart Localhost Scan Share Auto-Fix (v4.0)

echo ================================================================
echo   Smart Localhost Scan Share Auto-Fix (v4.0)
echo ================================================================
echo.

set "ScanName=Scan"
set "ScanFolder=%USERPROFILE%\Documents\%ScanName%"
set "ShortcutFile=%USERPROFILE%\Desktop\%ScanName%.lnk"
set "VBSFile=%TEMP%\mkshortcut.vbs"

:: -----------------------------------------------------------
:: 1. ตรวจสอบว่ามีการแชร์อยู่แล้วไหม
:: -----------------------------------------------------------
echo [CHECK] Checking shared folder on \\127.0.0.1 ...
net view \\127.0.0.1 | find /I "\\127.0.0.1\%ScanName%" >nul 2>&1
if %errorlevel%==0 (
    echo [FOUND] \\127.0.0.1\%ScanName% already shared.

    :: ---------------------------------------------------
    :: 2. ตั้งสิทธิ์ Share และ NTFS ใหม่ให้ Everyone Full
    :: ---------------------------------------------------
    echo [FIX] Resetting Share permissions for Everyone Full...
    net share %ScanName% /grant:everyone,full >nul 2>&1

    echo [FIX] Resetting NTFS permissions for Everyone Full...
    for /f "tokens=3*" %%A in ('net share ^| find /I "%ScanName%"') do (
        set "ExistingPath=%%A %%B"
    )
    icacls "!ExistingPath!" /grant Everyone:(OI)(CI)F /T >nul

    goto :make_shortcut
)

:: -----------------------------------------------------------
:: 3. ถ้าไม่พบการแชร์ → สร้างโฟลเดอร์ใหม่
:: -----------------------------------------------------------
echo [MISSING] Shared folder not found.
echo [CREATE] Creating new folder at "%ScanFolder%"...
if not exist "%ScanFolder%" mkdir "%ScanFolder%" >nul 2>&1

echo [SHARE] Sharing folder as "%ScanName%"...
net share %ScanName%="%ScanFolder%" /grant:everyone,full >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create shared folder "%ScanName%".
    pause
    exit /b
)
echo [OK] Shared folder created: \\127.0.0.1\%ScanName%

echo [NTFS] Setting NTFS permissions for Everyone (Full Control)...
icacls "%ScanFolder%" /grant Everyone:(OI)(CI)F /T >nul

:make_shortcut
:: -----------------------------------------------------------
:: 4. สร้าง Shortcut ไปยัง \\127.0.0.1\Scan
:: -----------------------------------------------------------
echo [STEP] Creating shortcut on Desktop...
(
    echo Set oWS = CreateObject("WScript.Shell")
    echo sLinkFile = "%ShortcutFile%"
    echo Set oLink = oWS.CreateShortcut(sLinkFile)
    echo oLink.TargetPath = "\\127.0.0.1\%ScanName%"
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
echo   All tasks completed successfully!
echo   Folder available at: \\127.0.0.1\%ScanName%
echo ================================================================
pause
exit /b
