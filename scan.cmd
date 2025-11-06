@echo off
setlocal enabledelayedexpansion
title Smart Setup: Verify or Create "Scan" Shared Folder

echo.
echo ================================================================
echo     Smart Setup: Verify or Create "Scan" Shared Folder
echo ================================================================
echo.

:: -------------------------------------------------------------
:: Set default target path
:: -------------------------------------------------------------
set "UserDoc=%USERPROFILE%\Documents"
set "TargetFolder=%UserDoc%\Scan"

echo Target Folder Path (default): "%TargetFolder%"
echo.

:: -------------------------------------------------------------
:: Step 1 - Check if a shared folder named "Scan" already exists
:: -------------------------------------------------------------
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command ^
    "Get-SmbShare -Name 'Scan' -ErrorAction SilentlyContinue ^| Select-Object -ExpandProperty Path"`) do (
    set "SharePath=%%A"
)

if defined SharePath (
    echo [FOUND] Shared folder "Scan" already exists.
    echo Share path detected: "%SharePath%"
) else (
    echo [MISSING] Shared folder "Scan" not found.
    echo Creating new folder and sharing as "Scan"...
    echo.

    if not exist "%TargetFolder%" (
        mkdir "%TargetFolder%"
        echo [OK] Folder created: "%TargetFolder%"
    ) else (
        echo [OK] Folder already exists, using existing one.
    )

    :: Create share
    powershell -NoProfile -Command ^
        "New-SmbShare -Name 'Scan' -Path '%TargetFolder%' -FullAccess 'Everyone' -ErrorAction SilentlyContinue | Out-Null"

    :: Verify created
    for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command ^
        "Get-SmbShare -Name 'Scan' -ErrorAction SilentlyContinue ^| Select-Object -ExpandProperty Path"`) do (
        set "SharePath=%%A"
    )

    if not defined SharePath (
        echo [ERROR] Failed to create shared folder.
        pause
        exit /b
    )
)

echo.
echo [1/3] Fixing Share Permissions...
powershell -NoProfile -Command ^
    "$s=Get-SmbShare -Name 'Scan' -ErrorAction SilentlyContinue; if($s){$s | Set-SmbShare -FullAccess 'Everyone' -ChangeAccess @() -ReadAccess @()}"
echo [OK] Share permission ensured.
echo.

echo [2/3] Ensuring NTFS Permissions...
icacls "%SharePath%" /grant Everyone:(OI)(CI)F /T /C >nul
echo [OK] NTFS permission set.
echo.

echo [3/3] Creating Shortcut...

:: Build VBS file to make desktop shortcut
set "VBSFile=%TEMP%\mkshortcut.vbs"
(
echo Set oWS = WScript.CreateObject("WScript.Shell")
echo sLinkFile = oWS.SpecialFolders("Desktop") ^& "\Scan.lnk"
echo Set oLink = oWS.CreateShortcut(sLinkFile)
echo oLink.TargetPath = "%SharePath%"
echo oLink.IconLocation = "%SystemRoot%\system32\SHELL32.dll,3"
echo oLink.Description = "Open Scan Shared Folder"
echo oLink.Save
) > "%VBSFile%"

cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1

echo [OK] Shortcut created at Desktop\Scan.lnk
echo.

echo Opening Advanced Network Sharing Settings...
control.exe /name Microsoft.NetworkAndSharingCenter

echo.
echo All tasks completed successfully.
echo ================================================================
pause
exit /b
