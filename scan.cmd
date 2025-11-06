@echo off
setlocal
title Smart Setup: Localhost Scan Folder Auto-Fix (v3.5.1)

echo =================================================================
echo   Smart Setup: Localhost Scan Folder Auto-Fix (v3.5.1)
echo =================================================================
echo.

set "ShareName=Scan"
set "DefaultPath=%USERPROFILE%\Documents\%ShareName%"
set "ShortcutPath=%USERPROFILE%\Desktop\%ShareName%.lnk"

:: -----------------------------------------------------------------
:: 1. ตรวจสอบว่ามีแชร์อยู่แล้วหรือไม่
:: -----------------------------------------------------------------
echo Checking existing shares on localhost...
for /f "tokens=1" %%A in ('net share ^| findstr /I "^%ShareName% "') do set FOUND=1

if defined FOUND (
    echo [FOUND] Shared folder "%ShareName%" already exists on \\127.0.0.1\%ShareName%.
    set "FoundPath="
    for /f "tokens=1,*" %%a in ('net share %ShareName% ^| findstr /I "Path"') do set "FoundPath=%%b"
    if defined FoundPath (
        echo Share path detected: "%FoundPath%"
        set "TargetPath=%FoundPath%"
    ) else (
        echo [WARN] Could not detect share path, will reapply permissions.
        set "TargetPath=%DefaultPath%"
    )
    goto :CHECK_PERMS
)

:: -----------------------------------------------------------------
:: 2. ไม่เจอแชร์ -> สร้างโฟลเดอร์ใหม่
:: -----------------------------------------------------------------
echo [MISSING] Shared folder "%ShareName%" not found.
echo Creating new shared folder at "%DefaultPath%"...
if not exist "%DefaultPath%" (
    mkdir "%DefaultPath%" 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create folder "%DefaultPath%".
        pause
        exit /b
    )
)
set "TargetPath=%DefaultPath%"

:: ลบ share เดิมถ้ามีค้างในระบบ
net share %ShareName% /delete >nul 2>&1

:: แชร์ใหม่
net share %ShareName%="%TargetPath%" /grant:everyone,full >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create shared folder "%ShareName%".
    pause
    exit /b
) else (
    echo [OK] Shared folder created and available as \\127.0.0.1\%ShareName%
)

:: -----------------------------------------------------------------
:: 3. ตั้ง NTFS Permission (Full Control for Everyone)
:: -----------------------------------------------------------------
echo [STEP] Setting NTFS permissions for Everyone (Full Control)...
icacls "%TargetPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] Could not apply NTFS permission properly.
) else (
    echo [OK] NTFS permissions set.
)

:: -----------------------------------------------------------------
:: 4. สร้าง Shortcut ชี้ไปที่ \\127.0.0.1\Scan
:: -----------------------------------------------------------------
echo [STEP] Creating shortcut on Desktop...
set "TargetLink=\\127.0.0.1\%ShareName%"
set "TempVBS=%TEMP%\mkshortcut_%RANDOM%.vbs"
(
    echo Set oWS = CreateObject("WScript.Shell")
    echo sLinkFile = "%ShortcutPath%"
    echo Set oLink = oWS.CreateShortcut(sLinkFile)
    echo oLink.TargetPath = "%TargetLink%"
    echo oLink.Save
) > "%TempVBS%"
cscript //nologo "%TempVBS%" >nul
timeout /t 1 >nul
if exist "%TempVBS%" del "%TempVBS%" >nul 2>&1
echo [OK] Shortcut created: "%ShortcutPath%"
goto :DONE


:: -----------------------------------------------------------------
:: 5. ตรวจสอบสิทธิ์ถ้ามีแชร์อยู่แล้ว
:: -----------------------------------------------------------------
:CHECK_PERMS
echo [STEP] Checking permissions on existing share...
net share %ShareName% /grant:everyone,full >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] Could not reapply share permission. May already be OK.
) else (
    echo [OK] Share permissions confirmed.
)

icacls "%TargetPath%" | find /i "Everyone" | find "F" >nul
if %errorlevel% neq 0 (
    echo [FIX] Reapplying NTFS Full Control for Everyone...
    icacls "%TargetPath%" /grant Everyone:(OI)(CI)F /T >nul
) else (
    echo [OK] NTFS permission already correct.
)

if not exist "%ShortcutPath%" (
    echo [STEP] Creating missing shortcut...
    set "TempVBS=%TEMP%\mkshortcut_%RANDOM%.vbs"
    (
        echo Set oWS = CreateObject("WScript.Shell")
        echo sLinkFile = "%ShortcutPath%"
        echo Set oLink = oWS.CreateShortcut(sLinkFile)
        echo oLink.TargetPath = "\\127.0.0.1\%ShareName%"
        echo oLink.Save
    ) > "%TempVBS%"
    cscript //nologo "%TempVBS%" >nul
    timeout /t 1 >nul
    if exist "%TempVBS%" del "%TempVBS%" >nul 2>&1
    echo [OK] Shortcut created.
) else (
    echo [OK] Shortcut already exists.
)

:DONE
echo.
echo =================================================================
echo   All tasks completed successfully.
echo   You can now open: \\127.0.0.1\%ShareName%
echo =================================================================
pause
exit /b
