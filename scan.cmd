@echo off
setlocal enabledelayedexpansion

:: --- Get Computer Name ---
set "COMPUTERNAME=%COMPUTERNAME%"
echo Computer Name: %COMPUTERNAME%

:: --- Set Scan folder path ---
set "USERDOCS=%USERPROFILE%\Documents"
set "SCANFOLDER=%USERDOCS%\Scan"

:: --- Check if Scan folder exists ---
if not exist "%SCANFOLDER%" (
    echo [INFO] Scan folder not found. Creating...
    mkdir "%SCANFOLDER%"
) else (
    echo [INFO] Scan folder exists.
)

:: --- Set NTFS permissions (Everyone Full Control) ---
echo [INFO] Setting NTFS permissions...
powershell -Command "icacls '%SCANFOLDER%' /grant Everyone:(OI)(CI)F /T"

:: --- Check if folder is shared ---
set "SHARENAME=Scan"
net share | findstr /i "%SHARENAME%" >nul
if %errorlevel%==0 (
    echo [INFO] Share already exists.
) else (
    echo [INFO] Creating SMB share...
    powershell -Command "New-SmbShare -Name '%SHARENAME%' -Path '%SCANFOLDER%' -FullAccess 'Everyone'"
)

:: --- Set Share Permissions (Everyone Full Control) ---
echo [INFO] Setting share permissions...
powershell -Command "Get-SmbShare -Name '%SHARENAME%' | Set-SmbShare -FullAccess Everyone"

:: --- Create Shortcut on Desktop ---
set "SHORTCUT=%USERPROFILE%\Desktop\Scan.lnk"
echo [INFO] Creating shortcut on Desktop...
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT%'); $Shortcut.TargetPath = '\\%COMPUTERNAME%\%SHARENAME%'; $Shortcut.Save()"

echo [DONE] Scan folder ready and shortcut created.
pause
