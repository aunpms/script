@echo off
setlocal enabledelayedexpansion
title Smart Setup: Verify or Create "Scan" Shared Folder

echo.
echo ================================================================
echo     Smart Setup: Verify or Create "Scan" Shared Folder
echo ================================================================
echo.

:: -------------------------------------------------------------
:: Set default path
:: -------------------------------------------------------------
set "UserDoc=%USERPROFILE%\Documents"
set "DefaultFolder=%UserDoc%\Scan"
set "ShareTemp=%TEMP%\sharelist_%RANDOM%.txt"

echo Target Folder Path (default): "%DefaultFolder%"
echo.

:: -------------------------------------------------------------
:: Step 1 - Detect if "Scan" is already shared (use net share)
:: -------------------------------------------------------------
net share > "%ShareTemp%"
findstr /I /B /C:"Scan " "%ShareTemp%" >nul
if %ERRORLEVEL% EQU 0 (
    echo [FOUND] Shared folder "Scan" already exists.
    for /f "tokens=1,* delims= " %%a in ('net share Scan ^| findstr /R /C:"Path"') do (
        set "ExistingPath=%%b"
    )
    set "ExistingPath=!ExistingPath:~0!"
    echo Share path detected: "!ExistingPath!"
    echo.
    set "SharePath=!ExistingPath!"
) else (
    echo [MISSING] Shared folder "Scan" not found.
    echo Creating new folder and sharing as "Scan"...
    echo.

    if not exist "%DefaultFolder%" (
        mkdir "%DefaultFolder%"
        echo [OK] Folder created: "%DefaultFolder%"
    ) else (
        echo [OK] Folder already exists, using existing one.
    )

    net share Scan="%DefaultFolder%" /GRANT:Everyone,FULL >nul
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create shared folder.
        del "%ShareTemp%" >nul 2>&1
        pause
        exit /b
    )
    set "SharePath=%DefaultFolder%"
)

del "%ShareTemp%" >nul 2>&1
echo.

:: -------------------------------------------------------------
:: Step 2 - Fix Permissions (Share + NTFS)
:: -------------------------------------------------------------
echo [1/3] Ensuring Share Permissions...
powershell -NoProfile -Command ^
    "$s=Get-WmiObject -Class Win32_Share -Filter \"Name='Scan'\"; if($s){$p=$s.Path; $s.Delete()|Out-Null; cmd /c 'net share Scan=\"'+$p+'\" /GRANT:Everyone,FULL >nul'}"
echo [OK] Share permissions ensured.
echo.

echo [2/3] Ensuring NTFS Permissions...
icacls "%SharePath%" /grant Everyone:(OI)(CI)F /T /C >nul
echo [OK] NTFS permissions ensured.
echo.

:: -------------------------------------------------------------
:: Step 3 - Create Shortcut (accurate target)
:: -------------------------------------------------------------
echo [3/3] Creating Shortcut...

set "VBSFile=%TEMP%\mkshortcut_%RANDOM%.vbs"
(
echo Set oWS = WScript.CreateObject("WScript.Shell")
echo sLnk = oWS.SpecialFolders("Desktop") ^& "\Scan.lnk"
echo Set oLink = oWS.CreateShortcut(sLnk)
echo oLink.TargetPath = "%SharePath%"
echo oLink.IconLocation = "%SystemRoot%\System32\SHELL32.dll,3"
echo oLink.Description = "Open Scan Shared Folder"
echo oLink.Save
) > "%VBSFile%"

cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1

echo [OK] Shortcut created.
echo.

:: -------------------------------------------------------------
:: Step 4 - Finish
:: -------------------------------------------------------------
echo Opening Advanced Network Sharing Settings...
start "" control.exe /name Microsoft.NetworkAndSharingCenter

echo.
echo ================================================================
echo All tasks completed successfully.
echo ================================================================
pause
exit /b
