@echo off
:: scan.cmd - Create/verify a shared "Scan" folder with Everyone full control (NTFS + Share)
:: Works on Windows 7 / 10 / 11 (Home/Pro). Run as Administrator.
:: By: auto-generated script. Adjust as needed.

setlocal enabledelayedexpansion

:: ---------------------------
:: Elevation / Admin check
:: ---------------------------
necho Checking for Administrator privileges...
net session >nul 2>&1
nif %ERRORLEVEL% NEQ 0 (
n    echo Not running as administrator. Attempting to relaunch elevated...
n    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '' -Verb RunAs" >nul 2>&1
n    if %ERRORLEVEL% NEQ 0 (
n        echo Failed to elevate. Please right-click and 'Run as administrator'.
n        pause
n    )
n    exit /b
n)
necho Running as administrator.

:: ---------------------------
:: Variables
:: ---------------------------
set "COMPUTER=%COMPUTERNAME%"
set "USERDOC=%USERPROFILE%\Documents"
set "SCANFOLDER=%USERDOC%\Scan"
set "SHARENAME=Scan"
set "UNC=\\%COMPUTER%\%SHARENAME%"
echo Computer name: %COMPUTER%
echo Documents path: %USERDOC%

:: ---------------------------
:: Helper: trim leading spaces (for parsing net share output)
:: ---------------------------
:trim
set "_tmp=%~1"
for /f "tokens=*" %%A in ("%_tmp%") do set "%~2=%%A"
exit /b

:: ---------------------------
:: Check if a share named Scan exists on this machine
:: ---------------------------
necho Checking for existing share " %SHARENAME% "...
net share %SHARENAME% >"%temp%\share_info.txt" 2>nul
nif %ERRORLEVEL% EQU 0 (
    echo Share exists. Parsing share path...
    
    for /f "usebackq delims=" %%L in ("%temp%\share_info.txt") do (
        echo %%L | findstr /b /c:"Path" >nul 2>&1
        if not errorlevel 1 (
            set "line=%%L"
            call :trim "!line:Path=" tmpline"
            rem tmpline contains the path with leading spaces, trim again
            for /f "tokens=*" %%P in ("!tmpline!") do set "SHAREPATH=%%P"
        )
    )
    if defined SHAREPATH (
        echo Share path detected: "!SHAREPATH!"
    ) else (
        echo Could not determine share path from net share output.
    )
    del "%temp%\share_info.txt" >nul 2>&1
) else (
    echo Share not found.
)

:: ---------------------------
:: Ensure folder exists (Documents\Scan)
:: ---------------------------
if exist "%SCANFOLDER%\" (
    echo Folder exists: %SCANFOLDER%
) else (
    echo Folder does not exist. Creating: %SCANFOLDER%
    md "%SCANFOLDER%" 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create folder %SCANFOLDER%. Exiting.
        pause
        exit /b 1
    ) else (
        echo Created folder.
    )
)

:: If share exists but points to a different path, we'll prefer the existing share path for permission checks
nif defined SHAREPATH (
    set "TARGETPATH=%SHAREPATH%"
) else (
    set "TARGETPATH=%SCANFOLDER%"
)
echo Using path: "%TARGETPATH%" for share and NTFS permission adjustments.

:: ---------------------------
:: Ensure NTFS permissions include Everyone: Full (recursively)
:: ---------------------------
echo Setting NTFS permissions (Everyone Full) on "%TARGETPATH%" ...
:: Use icacls: grant Everyone full, object inherit and container inherit
icacls "%TARGETPATH%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
nif %ERRORLEVEL% EQU 0 (
    echo NTFS permissions updated to give Everyone Full Control (recursive).
) else (
    echo Failed to update NTFS permissions with icacls. You may need to adjust manually.
)

:: ---------------------------
:: Ensure share exists and has Everyone full control on the share permission
:: ---------------------------
echo Ensuring share "%SHARENAME%" exists and has Everyone full share-permission...
:: If share exists and points to a different path, we'll delete and recreate it to point to TARGETPATH
net share %SHARENAME% >nul 2>&1
nif %ERRORLEVEL% EQU 0 (
    echo Share "%SHARENAME%" already exists. Recreating it to ensure correct permissions and path...
    net share %SHARENAME% /delete >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to delete existing share. Attempting to continue and re-create.
    ) else (
        echo Deleted old share.
    )
)

n:: Create the share with Everyone full
net share %SHARENAME%="%TARGETPATH%" /GRANT:Everyone,FULL >nul 2>&1
nif %ERRORLEVEL% EQU 0 (
    echo Share "%SHARENAME%" created with Everyone=FULL on path "%TARGETPATH%".
) else (
    echo Failed to create share "%SHARENAME%". It might be in use or your system may not support /GRANT syntax. Attempting fallback: create without /GRANT and advise manual change...
    net share %SHARENAME%="%TARGETPATH%" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Share created without explicit grant. Please adjust share permissions manually to allow Everyone Full Control.
    ) else (
        echo Could not create the share. Please create a share named "%SHARENAME%" pointing to "%TARGETPATH%" and grant Everyone Full Control.
    )
)

:: Double-check: test UNC access locally by writing a test file to the share (this verifies both NTFS and share write)
set "TESTFILE=\\%COMPUTER%\%SHARENAME%\__scan_test.txt"
echo Testing write access to %TESTFILE% ...
echo This is a test > "%TESTFILE%" 2>nul
nif %ERRORLEVEL% EQU 0 (
    echo Write test succeeded. Removing test file...
    del "%TESTFILE%" >nul 2>&1
) else (
    echo Write test failed. Share or NTFS permissions might not allow Everyone to write. Please check manually.
)

:: ---------------------------
:: Create a Shortcut on the current user's Desktop pointing to the UNC path
:: ---------------------------
set "DESKTOP=%USERPROFILE%\Desktop"
set "LNK=%DESKTOP%\Scan (\\%COMPUTER%\%SHARENAME%).lnk"
echo Creating shortcut on Desktop: "%LNK%" -> "%UNC%"
powershell -NoProfile -Command "
$W = New-Object -ComObject WScript.Shell; 
$S = $W.CreateShortcut('%LNK%'); 
$S.TargetPath = '%UNC%'; 
$S.WorkingDirectory = '%UNC%'; 
$S.WindowStyle = 1; 
$S.Save();" >nul 2>&1
nif %ERRORLEVEL% EQU 0 (
    echo Shortcut created on Desktop.
) else (
    echo Failed to create shortcut via PowerShell. You can manually create a shortcut to %UNC%.
)

echo.
echo === Summary ===
necho Share Name: %SHARENAME%
necho Share UNC: %UNC%
necho Share Path (on disk): %TARGETPATH%
echo NTFS: Everyone should have Full Control (applied via icacls).
echo Share permission: attempted to grant Everyone Full on share (if supported by OS).
echo Shortcut placed on Desktop for the current user.
echo.
necho If anything failed, run this script as Administrator and check event messages above.
pause
endlocal
exit /b 0
