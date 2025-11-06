@echo off
title Setup Scan Share (Smart Logic v13 - VBS Hybrid Edition)
setlocal enableextensions
echo =================================================================
echo     Smart Setup: Verify or Create "Scan" Shared Folder
echo =================================================================
echo.

:: -----------------------------------
:: Config
:: -----------------------------------
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
set "ShareTemp=%TEMP%\sharelist_%RANDOM%.txt"
set "VBSFile=%TEMP%\_scanhelper_%RANDOM%.vbs"

echo Target Folder Path (default): "%FullFolderPath%"
echo.

:: -----------------------------------
:: STEP 1 — Check if share exists
:: -----------------------------------
net share > "%ShareTemp%"
findstr /I /B /C:"%FolderName% " "%ShareTemp%" >nul
if %ERRORLEVEL% EQU 0 (
    echo [FOUND] Shared folder "%FolderName%" already exists.
    echo.

    call :GetExistingPath "%FolderName%"
    if defined ExistingPath (
        echo Share path detected: "%ExistingPath%"
        echo.

        echo [1/3] Fixing Share Permissions...
        call :RunVBS "powershell -NoProfile -Command \"Remove-SmbShare -Name '%FolderName%' -Force -ErrorAction SilentlyContinue; New-SmbShare -Name '%FolderName%' -Path '%ExistingPath%' -FullAccess 'Everyone'\"" >nul
        echo [OK] Share permission ensured.
        echo.

        echo [2/3] Ensuring NTFS Permissions...
        call :RunVBS "icacls \"%ExistingPath%\" /grant Everyone:(OI)(CI)F /T" >nul
        echo [OK] NTFS permission set.
        echo.

        echo [3/3] Creating Shortcut...
        call :CreateShortcut "%ExistingPath%"
        echo [OK] Shortcut created.
        echo.
        goto SETTINGS
    )
) else (
    echo [NOT FOUND] No share named "%FolderName%" found.
    echo Creating new shared folder...
    echo.

    if not exist "%FullFolderPath%" (
        mkdir "%FullFolderPath%" >nul 2>&1
        if not exist "%FullFolderPath%" (
            echo [FAIL] Could not create folder.
            goto END
        )
        echo [OK] Folder created: "%FullFolderPath%"
    ) else (
        echo [OK] Folder already exists: "%FullFolderPath%"
    )
    echo.

    echo Sharing folder...
    call :RunVBS "powershell -NoProfile -Command \"New-SmbShare -Name '%FolderName%' -Path '%FullFolderPath%' -FullAccess 'Everyone'\"" >nul
    echo [OK] Shared successfully.
    echo.

    echo Setting NTFS Permissions...
    call :RunVBS "icacls \"%FullFolderPath%\" /grant Everyone:(OI)(CI)F /T" >nul
    echo [OK] NTFS permission set.
    echo.

    echo Creating shortcut on Desktop...
    call :CreateShortcut "%FullFolderPath%"
    echo [OK] Shortcut created.
    echo.
)

del "%ShareTemp%" >nul 2>&1

:SETTINGS
echo Opening Advanced Network Sharing Settings...
start "" control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced
echo.
echo All tasks completed successfully.
echo =================================================================
pause
exit /b


:: -------------------------------------------------
:: Function: RunVBS
:: Creates a temporary VBS to execute a PowerShell or command silently
:: -------------------------------------------------
:RunVBS
(
    echo Set sh = CreateObject("WScript.Shell")
    echo sh.Run "%~1", 0, True
) > "%VBSFile%"
cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1
exit /b


:: -------------------------------------------------
:: Function: CreateShortcut
:: -------------------------------------------------
:CreateShortcut
(
    echo Set oWS = WScript.CreateObject("WScript.Shell")
    echo sLinkFile = oWS.SpecialFolders("Desktop") ^& "\Scan.lnk"
    echo Set oLink = oWS.CreateShortcut(sLinkFile)
    echo oLink.TargetPath = "%~1"
    echo oLink.Save
) > "%VBSFile%"
cscript //nologo "%VBSFile%" >nul 2>&1
del "%VBSFile%" >nul 2>&1
exit /b


:: -------------------------------------------------
:: Function: GetExistingPath
:: -------------------------------------------------
:GetExistingPath
set "ExistingPath="
for /f "skip=1 tokens=1,*" %%a in ('net share %~1 2^>nul') do (
    if not defined ExistingPath set "ExistingPath=%%b"
)
for /f "tokens=* delims= " %%i in ("%ExistingPath%") do set "ExistingPath=%%i"
exit /b
