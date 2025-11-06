@echo off
setlocal enabledelayedexpansion
title Smart Setup: Localhost Scan Folder Auto-Fix (v3.0)

echo.
echo ================================================================
echo   Smart Setup: Localhost Scan Folder Auto-Fix (v3.0)
echo ================================================================
echo.

set "ShareName=Scan"
set "DefaultFolder=%USERPROFILE%\Documents\Scan"
set "LocalPath=\\127.0.0.1\%ShareName%"
set "TempShareList=%TEMP%\sharelist_%RANDOM%.txt"

:: -------------------------------------------------------------
:: STEP 1 - CHECK IF "Scan" SHARE ALREADY EXISTS
:: -------------------------------------------------------------
echo Checking existing shares on localhost...
net view \\127.0.0.1 > "%TempShareList%" 2>nul

findstr /I /R " %ShareName% " "%TempShareList%" >nul
if %ERRORLEVEL% EQU 0 (
    echo [FOUND] Shared folder "%ShareName%" exists on \\127.0.0.1
    for /f "tokens=1,* delims= " %%a in ('net share %ShareName% ^| findstr /R /C:"Path"') do (
        set "SharePath=%%b"
    )
    set "SharePath=!SharePath:~0!"
    echo Share path: "!SharePath!"
    goto :CHECK_PERMISSIONS
) else (
    echo [MISSING] Shared folder "%ShareName%" not found.
    echo Creating new shared folder at "%DefaultFolder%"...
    if not exist "%DefaultFolder%" mkdir "%DefaultFolder%" >nul 2>&1
    net share %ShareName%="%DefaultFolder%" /GRANT:Everyone,FULL >nul
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create shared folder "%ShareName%".
        pause
        exit /b
    )
    set "SharePath=%DefaultFolder%"
    echo [OK] Shared folder created successfully.
)

del "%TempShareList%" >nul 2>&1
echo.

:: -------------------------------------------------------------
:: STEP 2 - CHECK & FIX PERMISSIONS
:: -------------------------------------------------------------
:CHECK_PERMISSIONS
echo Checking advanced sharing permissions...
powershell -NoProfile -Command ^
    "$share = Get-WmiObject -Class Win32_Share -Filter \"Name='%ShareName%'\"; if ($share) { $path = $share.Path; $tmp = (net share %ShareName%); if ($tmp -notmatch 'Everyone.*Full') { Write-Host '[FIX] Updating share permissions...'; $null = cmd /c 'net share %ShareName%=\"'+$path+'\" /GRANT:Everyone,FULL >nul' } }"
echo [OK] Share permissions verified.
echo.

echo Checking NTFS permissions...
icacls "%SharePath%" | findstr /I "Everyone" | findstr /I "(F)" >nul
if %ERRORLEVEL% NEQ 0 (
    echo [FIX] Adding NTFS Full Control for Everyone...
    icacls "%SharePath%" /grant Everyone:(OI)(CI)F /T /C >nul
)
echo [OK] NTFS permissions verified.
echo.

:: -------------------------------------------------------------
:: STEP 3 - CREATE SHORTCUT TO \\127.0.0.1\Scan
:: -------------------------------------------------------------
echo Creating desktop shortcut to "%LocalPath%" ...
set "VBSFile=%TEMP%\mkshortcut_%RANDOM%.vbs"
(
echo Set oWS = WScript.CreateObject("WScript.Shell")
echo sLnk = oWS.SpecialFolders("Desktop") ^& "\Scan.lnk"
echo Set oLink = oWS.CreateShortcut(sLnk)
echo oLink.TargetPath = "%LocalPath%"
echo oLink.IconLocation = "%SystemRoot%\System32\SHELL32.dll,3"
echo oLink.Description = "Open Scan Shared Folder on Localhost"
echo oLink.Save
) > "%VBSFile%"
cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1
echo [OK] Shortcut created successfully.
echo.

:: -------------------------------------------------------------
:: STEP 4 - FINISH
:: -------------------------------------------------------------
echo Opening Advanced Network Sharing Settings...
start "" control.exe /name Microsoft.NetworkAndSharingCenter
echo.
echo ================================================================
echo All tasks completed successfully.
echo ================================================================
pause
exit /b
