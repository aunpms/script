@echo off
title Setup Scan Share (Smart Mode v10)
setlocal enableextensions enabledelayedexpansion
echo =================================================================
echo  Smart Setup: Create or Verify "Scan" Shared Folder
echo =================================================================
echo.

:: -------------------------------
:: Config
:: -------------------------------
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"

echo Target Folder: "%FullFolderPath%"
echo.

:: -------------------------------
:: Check if share exists (PowerShell)
:: -------------------------------
set "ExistingPath="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "try { $s = Get-WmiObject -Class Win32_Share -Filter \"Name='%FolderName%'\" -ErrorAction SilentlyContinue; if ($s) { $s.Path } } catch {}"`) do (
    set "ExistingPath=%%P"
)

if not defined ExistingPath (
    echo [NOT FOUND] Share "%FolderName%" not found. Creating new one...
    if not exist "%FullFolderPath%" (
        mkdir "%FullFolderPath%" >nul 2>&1
        if exist "%FullFolderPath%" (
            echo [OK] Folder created: "%FullFolderPath%"
        ) else (
            echo [FAIL] Could not create folder. Exiting.
            goto END
        )
    ) else (
        echo [OK] Folder already exists.
    )
    echo Sharing folder...
    net share "%FolderName%"="%FullFolderPath%" /GRANT:Everyone,FULL >nul
    if %ERRORLEVEL% equ 0 (
        echo [OK] Shared successfully as "%FolderName%"
    ) else (
        echo [FAIL] Failed to share folder. Check permissions.
        goto END
    )
) else (
    echo [FOUND] Share "%FolderName%" exists.
    echo Checking path and permissions...
    for /f "tokens=* delims= " %%T in ("%ExistingPath%") do set "ExistingPath=%%T"
    echo   - Share Path: "%ExistingPath%"
    echo   - Expected Path: "%FullFolderPath%"
    echo.
    if /I "%ExistingPath%" NEQ "%FullFolderPath%" (
        echo [WARN] Path mismatch, updating share...
        net share "%FolderName%" /delete /Y >nul
        net share "%FolderName%"="%FullFolderPath%" /GRANT:Everyone,FULL >nul
        echo [OK] Recreated share with correct path.
    ) else (
        echo [OK] Path correct. Checking permissions...
        net share "%FolderName%" /GRANT:Everyone,FULL >nul
        echo [OK] Permissions enforced (Everyone = Full Control)
    )
)
echo.

:: -------------------------------
:: Set NTFS permissions
:: -------------------------------
echo Verifying NTFS permissions...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
echo [OK] NTFS permissions enforced (Everyone = Full Control)
echo.

:: -------------------------------
:: Create Desktop Shortcut
:: -------------------------------
echo Creating shortcut on desktop...
powershell -NoProfile -Command ^
  "$desktop = [Environment]::GetFolderPath('Desktop');" ^
  "$link = Join-Path $desktop 'Scan.lnk';" ^
  "$s = (New-Object -COM WScript.Shell).CreateShortcut($link);" ^
  "$s.TargetPath = '%FullFolderPath%'; $s.Save();" >nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Shortcut created on Desktop.
) else (
    echo [FAIL] Could not create shortcut.
)
echo.

:: -------------------------------
:: Open Advanced Sharing Settings
:: -------------------------------
echo Opening Advanced Network and Sharing Settings...
control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced
echo.

echo =================================================================
echo === All operations completed successfully ===
echo =================================================================
pause
endlocal
