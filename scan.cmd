@echo off
title Setup Scan Share (Smart Logic v11.7 - Powershell Safe)
setlocal enableextensions enabledelayedexpansion
echo =================================================================
echo     Smart Setup: Verify or Create "Scan" Shared Folder
echo =================================================================
echo.

:: -------------------------------
:: Config
:: -------------------------------
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
set "ShareTemp=%TEMP%\sharelist_%RANDOM%.txt"

echo Target Folder Path: "%FullFolderPath%"
echo.

:: -------------------------------
:: STEP 1 — Check if a share named "Scan" exists
:: -------------------------------
net share > "%ShareTemp%"
findstr /I /B /C:"%FolderName% " "%ShareTemp%" >nul
if %ERRORLEVEL% equ 0 (
    echo [FOUND] Shared folder "%FolderName%" already exists.
    echo.

    call :GetExistingPath "%FolderName%"
    if defined ExistingPath (
        echo Share path: "%ExistingPath%"
        echo.

        echo Verifying Share permissions...
        net share "%FolderName%" /GRANT:Everyone,FULL >nul
        echo [OK] Share permissions ensured.
        echo.

        echo Verifying NTFS permissions...
        call :SetNTFSPerms "%ExistingPath%"
        echo [OK] NTFS permissions ensured.
        echo.
    )
    del "%ShareTemp%" >nul 2>&1
    goto CREATE_SHORTCUT
)

echo [NOT FOUND] No share named "%FolderName%" found.
echo Creating folder and new share...
echo.

if not exist "%FullFolderPath%" (
    mkdir "%FullFolderPath%" >nul 2>&1
    if exist "%FullFolderPath%" (
        echo [OK] Folder created: "%FullFolderPath%"
    ) else (
        echo [FAIL] Could not create folder.
        goto END
    )
) else (
    echo [OK] Folder already exists: "%FullFolderPath%"
)
echo.

echo Sharing folder as "%FolderName%"...
net share "%FolderName%"="%FullFolderPath%" /GRANT:Everyone,FULL >nul
if %ERRORLEVEL% equ 0 (
    echo [OK] Shared successfully.
) else (
    echo [FAIL] Failed to share folder.
    goto END
)
echo.

echo Setting NTFS permissions...
call :SetNTFSPerms "%FullFolderPath%"
echo [OK] NTFS permissions set.
echo.

del "%ShareTemp%" >nul 2>&1

:: -------------------------------
:: STEP 6 — Create Desktop Shortcut
:: -------------------------------
:CREATE_SHORTCUT
echo Creating shortcut "Scan" on Desktop...
powershell -NoProfile -Command ^
  "$d=[Environment]::GetFolderPath('Desktop');" ^
  "$s=New-Object -ComObject WScript.Shell;" ^
  "$l=$s.CreateShortcut((Join-Path $d 'Scan.lnk'));" ^
  "$l.TargetPath='%FullFolderPath%';$l.Save()" >nul 2>&1

if %ERRORLEVEL% equ 0 (
    echo [OK] Shortcut created on Desktop.
) else (
    echo [WARN] Could not create shortcut.
)
echo.

:: -------------------------------
:: STEP 7 — Open Advanced Sharing Settings
:: -------------------------------
echo Opening Advanced Network and Sharing Settings...
start "" control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced
echo.

echo =================================================================
echo === All tasks completed successfully ===
echo =================================================================
pause
endlocal
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

:: -------------------------------------------------
:: Function: SetNTFSPerms  (now using PowerShell)
:: -------------------------------------------------
:SetNTFSPerms
echo Applying NTFS permissions to: %~1
powershell -NoProfile -Command ^
  "Start-Process icacls -ArgumentList '\"%~1\" /grant Everyone:(OI)(CI)F /T' -Wait -WindowStyle Hidden" >nul 2>&1
exit /b
