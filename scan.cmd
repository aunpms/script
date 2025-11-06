@echo off
title Setup Scan Share (v8 - PowerShell detection)
setlocal
:: Config
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"

echo =================================================================
echo Now processing: Create and configure "%FolderName%" shared folder
echo =================================================================
echo.
echo Target folder: "%FullFolderPath%"
echo.

:: -------------------------
:: 1) Check if share exists and get its path via PowerShell (stable)
:: -------------------------
set "ExistingPath="
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "try { $s = Get-WmiObject -Class Win32_Share -Filter \"Name='%FolderName%'\" -ErrorAction SilentlyContinue; if ($s -ne $null) { $s.Path } } catch { }"`) do (
    set "ExistingPath=%%P"
)

if defined ExistingPath (
    echo [FOUND] Share name "%FolderName%" already exists.
    :: Trim possible surrounding spaces
    for /f "tokens=* delims= " %%T in ("%ExistingPath%") do set "ExistingPath=%%T"
    echo   - Required Path: "%FullFolderPath%"
    echo   - Current Path:  "%ExistingPath%"
    echo.
    if /I "%ExistingPath%" == "%FullFolderPath%" (
        echo [OK] Path is correct. Proceeding to verify permissions...
        goto VERIFY_PERMISSIONS
    ) else (
        echo [WARNING] Path is incorrect!
        echo Deleting old share pointing to "%ExistingPath%"...
        net share "%FolderName%" /delete /Y
        echo [OK] Old share deleted.
        echo.
        goto CREATE_NEW_SHARE
    )
) else (
    echo [NOT FOUND] Share name "%FolderName%" not found. Starting creation process...
    echo.
    goto CREATE_NEW_SHARE
)

:: -------------------------
:: CREATE NEW SHARE
:: -------------------------
:CREATE_NEW_SHARE
echo --- Starting new share creation process ---
mkdir "%FullFolderPath%" 2>nul
if exist "%FullFolderPath%" (
    echo [OK] Folder ensured: "%FullFolderPath%"
) else (
    echo [FAIL] Could not create folder "%FullFolderPath%".
    goto END_SCRIPT
)
echo.

echo Sharing folder (GRANT)...
net share "%FolderName%"="%FullFolderPath%" /GRANT:Everyone,FULL
if %ERRORLEVEL% equ 0 (
    echo [OK] Folder shared as "%FolderName%".
    echo ** Network Path: \\%COMPUTERNAME%\%FolderName% **
) else (
    echo [WARN] net share returned non-zero exit code (check permissions/local policy).
)
echo.

echo Setting NTFS permissions...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] NTFS permissions set: Everyone Full Control.
) else (
    echo [WARN] icacls returned non-zero exit code (UAC / ACL policy may restrict this).
)
echo.

:: -------------------------
:: CREATE SHORTCUT (Public Desktop)
:: -------------------------
:CREATE_SHORTCUT
powershell -NoProfile -Command ^
  "$Desktop = Join-Path $env:PUBLIC 'Desktop'; ^
   if (Test-Path $Desktop) { ^
     $s=(New-Object -COM WScript.Shell).CreateShortcut((Join-Path $Desktop 'Scan.lnk')); ^
     $s.TargetPath='%FullFolderPath%'; $s.Save(); Exit 0 } else { Exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo [OK] Shortcut created/updated on Public Desktop.
) else (
    echo [FAIL] Could not create shortcut (Public Desktop might not exist or rights denied).
)
echo.

:: -------------------------
:: VERIFY PERMISSIONS (enforce)
:: -------------------------
:VERIFY_PERMISSIONS
echo --- Verifying and enforcing permissions ---
echo Enforcing Share permissions (GRANT)...
net share "%FolderName%" /GRANT:Everyone,FULL
echo.
echo Enforcing NTFS permissions...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
echo.
goto CREATE_SHORTCUT

:END_SCRIPT
echo.
echo =================================================================
echo === Operation Completed ===
echo =================================================================
pause
endlocal
