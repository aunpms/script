@echo off
setlocal enabledelayedexpansion
title Smart Setup: Detect Physical Drive "Scan" Folder

echo.
echo ================================================================
echo   Smart Setup: Detect Physical Drive "Scan" Folder (v2.1)
echo ================================================================
echo.

set "ShareTemp=%TEMP%\sharelist_%RANDOM%.txt"
set "SharePath="

:: -------------------------------------------------------------
:: Step 1 - Detect existing share
:: -------------------------------------------------------------
net share > "%ShareTemp%"
findstr /I /B /C:"Scan " "%ShareTemp%" >nul
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=1,* delims= " %%a in ('net share Scan ^| findstr /R /C:"Path"') do (
        set "ExistingPath=%%b"
    )
    set "ExistingPath=!ExistingPath:~0!"
    echo [FOUND] Shared folder "Scan" already exists.
    echo Share path detected: "!ExistingPath!"
    set "SharePath=!ExistingPath!"
    del "%ShareTemp%" >nul 2>&1
    goto :SET_PERMS
)
del "%ShareTemp%" >nul 2>&1

echo [MISSING] Shared folder "Scan" not found.
echo Searching all PHYSICAL drives for folder named "Scan"...
echo.

:: -------------------------------------------------------------
:: Step 2 - Get only physical drives (Fixed/Removable)
:: -------------------------------------------------------------
set "DriveList=%TEMP%\drivelist_%RANDOM%.txt"
wmic logicaldisk where "DriveType=2 or DriveType=3" get DeviceID /value | find "=" > "%DriveList%"

set "FoundList=%TEMP%\foundscan_%RANDOM%.txt"
del "%FoundList%" >nul 2>&1

for /f "tokens=2 delims==" %%D in (%DriveList%) do (
    echo   Scanning drive %%D ...
    for /f "delims=" %%F in ('dir /s /b /a:d "%%D\Scan" 2^>nul') do (
        echo %%F>>"%FoundList%"
    )
)

if exist "%FoundList%" (
    echo.
    echo Possible "Scan" folders found:
    echo ------------------------------------------
    set /a idx=0
    for /f "delims=" %%X in (%FoundList%) do (
        set /a idx+=1
        echo [!idx!] %%X
    )
    echo ------------------------------------------
    echo.
    set /p choice=Enter number to share that folder (or press Enter to skip): 
    if not defined choice (
        echo No folder selected. Creating new one in Documents.
        set "SharePath=%USERPROFILE%\Documents\Scan"
        mkdir "%SharePath%" 2>nul
    ) else (
        set /a n=0
        for /f "delims=" %%X in (%FoundList%) do (
            set /a n+=1
            if "!n!"=="%choice%" set "SharePath=%%X"
        )
        if not defined SharePath (
            echo Invalid selection. Creating new folder in Documents.
            set "SharePath=%USERPROFILE%\Documents\Scan"
            mkdir "%SharePath%" 2>nul
        )
    )
) else (
    echo No existing "Scan" folder found on any physical drive.
    echo Creating new folder in Documents...
    set "SharePath=%USERPROFILE%\Documents\Scan"
    mkdir "%SharePath%" 2>nul
)

del "%FoundList%" >nul 2>&1
del "%DriveList%" >nul 2>&1
echo.
echo Selected folder: "%SharePath%"
echo.

:: -------------------------------------------------------------
:: Step 3 - Create Share
:: -------------------------------------------------------------
echo Creating shared folder "Scan" at "%SharePath%" ...
net share Scan="%SharePath%" /GRANT:Everyone,FULL >nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create shared folder.
    pause
    exit /b
)
echo [OK] Shared folder created successfully.
echo.

:SET_PERMS
:: -------------------------------------------------------------
:: Step 4 - Permissions
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
:: Step 5 - Shortcut
:: -------------------------------------------------------------
echo [3/3] Creating Desktop Shortcut...
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
:: Step 6 - Done
:: -------------------------------------------------------------
echo Opening Advanced Network Sharing Settings...
start "" control.exe /name Microsoft.NetworkAndSharingCenter

echo.
echo ================================================================
echo All tasks completed successfully.
echo ================================================================
pause
exit /b
