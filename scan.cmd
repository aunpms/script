@echo off
:: scan.cmd - Create/verify a shared "Scan" folder with Everyone full control (NTFS + Share)
:: Works on Windows 7 / 10 / 11 (Home/Pro). Run as Administrator.
:: By: auto-generated script. Adjust as needed.

setlocal enabledelayedexpansion

:: ---------------------------
:: Elevation / Admin check
:: ---------------------------
echo Checking for Administrator privileges...
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Not running as administrator. Attempting to relaunch elevated...
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '' -Verb RunAs" >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to elevate. Please right-click and 'Run as administrator'.
        pause
    )
    exit /b
)
echo Running as administrator.

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
echo Checking for existing share "%SHARENAME%"...
net share %SHARENAME% >"%temp%\share_info.txt" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Share exists. Parsing share path...
    for /f "usebackq delims=" %%L in ("%temp%\share_info.txt") do (
        echo %%L | findstr /b /c:"Path" >nul 2>&1
        if not errorlevel 1 (
            set "line=%%L"
            call :trim "!line:Path=" tmpline"
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

:: ---------------------------
:: Determine target path for share and NTFS permission
:: ---------------------------
if defined SHAREPATH (
    set "TARGETPATH=%SHAREPATH%"
) else (
    set "TARGETPATH=%SCANFOLDER%"
)
echo Using path: "%TARGETPATH%" for share and NTFS permission adjustments.

:: ---------------------------
:: Ensure NTFS permissions include Everyone: Full (recursively)
:: ---------------------------
echo Setting NTFS permissions (Everyone Full) on "%TARGETPATH%" ...
icacls "%TARGETPATH%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo NTFS permissions updated to give Everyone Full Control (recursive).
) else (
    echo Failed to update NTFS permissions with icacls. You may need to adjust manually.
)

:: ---------------------------
:: Ensure share exists and has Everyone full control on the share permission
:: ---------------------------
echo Ensuring share "%SHARENAME%" exists and has Everyone full share-permission...
net share %SHARENAME% >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Share "%SHARENAME%" already exists. Recreating it to ensure correct permissions and path...
    net share %SHARENAME% /delete >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to delete existing share. Attempting to continue and re-create.
    ) else (
        echo Deleted old share.
    )
)
net share %SHARENAME%="%TARGETPATH%" /GRANT:Everyone,FULL >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Share "%SHARENAME%" created with Everyone=FULL on path "%TARGETPATH%".
) else (
    echo Failed to create share "%SHARENAME%". Attempting fallback...
    net share %SHARENAME%="%TARGETPATH%" >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Share created without explicit grant. Adjust permissions manually.
    ) else (
        echo Could not create the share. Please create manually.
    )
)

:: ---------------------------
:: Test write access to the share
:: ---------------------------
set "TESTFILE=\\%COMPUTER%\%SHARENAME%\__scan_test.txt"
echo Testing write access to %TESTFILE% ...
echo This is a test > "%TESTFILE%" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Write test succeeded. Removing test file...
    del "%TESTFILE%" >nul 2>&1
) else (
    echo Write test failed. Share or NTFS permissions might not allow Everyone to write.
)

:: ---------------------------
:: Create a Shortcut on Desktop pointing to the UNC path
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
if %ERRORLEVEL% EQU 0 (
    echo Shortcut created on Desktop.
) else (
    echo Failed to create shortcut. You can manually create a shortcut to %UNC%.
)

echo.
echo === Summary ===
echo Share Name: %SHARENAME%
echo Share UNC: %UNC%
echo Share Path (on disk): %TARGETPATH%
echo NTFS: Everyone should have Full Control (applied via icacls).
echo Share permission: attempted to grant Everyone Full on share.
echo Shortcut placed on Desktop for current user.
echo.
echo If anything failed, run this script as Administrator and check messages above.
pause
endlocal
exit /b 0
