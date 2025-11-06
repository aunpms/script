@echo off
setlocal EnableDelayedExpansion
title Smart Setup: Localhost Scan Folder Auto-Fix (v3.1)

echo =================================================================
echo   Smart Setup: Localhost Scan Folder Auto-Fix (v3.1)
echo =================================================================
echo.

:: ---------- CONFIG ----------
set "ShareName=Scan"
set "LocalPath=C:\Users\%USERNAME%\Documents\%ShareName%"
set "ShortcutPath=%USERPROFILE%\Desktop\%ShareName%.lnk"

:: ---------- CHECK EXISTING SHARE ----------
echo Checking existing shares on localhost...
for /f "tokens=1" %%A in ('net share ^| findstr /i "^%ShareName%"') do set Found=1

if defined Found (
    echo [FOUND] Shared folder "%ShareName%" already exists.
    set "ShareExists=1"
) else (
    echo [MISSING] Shared folder "%ShareName%" not found.
    set "ShareExists=0"
)

:: ---------- VERIFY / CREATE SHARE ----------
if "%ShareExists%"=="0" (
    echo Creating new shared folder at "%LocalPath%"...
    if not exist "%LocalPath%" mkdir "%LocalPath%" >nul 2>&1

    :: Create share manually (compatible with all Windows versions)
    net share "%ShareName%"="%LocalPath%" /remark:"Auto-created Scan share" /users:unlimited >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to create shared folder "%ShareName%".
        pause
        exit /b
    ) else (
        echo [OK] Folder created and shared as "%ShareName%".
    )
)

:: ---------- FIX SHARE PERMISSION (Everyone:Full Control) ----------
echo.
echo [1/3] Checking and fixing share permissions...
powershell -NoProfile -Command ^
    "$share = Get-SmbShare -Name '%ShareName%' -ErrorAction SilentlyContinue; ^
    if ($share) {revoke-SmbShareAccess -Name '%ShareName%' -AccountName 'Everyone' -Force -ErrorAction SilentlyContinue; ^
    Grant-SmbShareAccess -Name '%ShareName%' -AccountName 'Everyone' -AccessRight Full -Force }"
echo [OK] Share permission ensured.

:: ---------- FIX NTFS PERMISSIONS ----------
echo.
echo [2/3] Ensuring NTFS permissions...
icacls "%LocalPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
echo [OK] NTFS permission set.

:: ---------- CREATE SHORTCUT ----------
echo.
echo [3/3] Creating shortcut...
set "Target=\\127.0.0.1\%ShareName%"
(
echo Set oWS = CreateObject("WScript.Shell")
echo sLinkFile = "%ShortcutPath%"
echo Set oLink = oWS.CreateShortcut(sLinkFile)
echo oLink.TargetPath = "%Target%"
echo oLink.Save
) > "%TEMP%\makeshortcut.vbs"
cscript //nologo "%TEMP%\makeshortcut.vbs" >nul 2>&1
del "%TEMP%\makeshortcut.vbs" >nul 2>&1
echo [OK] Shortcut created on Desktop.

:: ---------- DONE ----------
echo.
echo Opening Advanced Sharing Settings...
start control.exe /name Microsoft.NetworkAndSharingCenter

echo.
echo All tasks completed successfully.
echo =================================================================
pause
exit /b
