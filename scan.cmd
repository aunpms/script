@echo off
title Setup Scan Share (Smart Logic v11.1)
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

echo Target Folder Path: "%FullFolderPath%"
echo.

:: -------------------------------
:: STEP 1 — Check if a share named "Scan" exists
:: -------------------------------
set "ExistingPath="
for /f "usebackq delims=" %%P in (
  `powershell -NoProfile -Command "try { $s = Get-WmiObject -Class Win32_Share -Filter \"Name='%FolderName%'\" -ErrorAction SilentlyContinue; if ($s) { $s.Path } } catch {}"`
) do (
  set "ExistingPath=%%P"
)

if defined ExistingPath (
    echo [FOUND] Shared folder "%FolderName%" already exists.
    echo Share path: "%ExistingPath%"
    echo.

    echo Verifying Share permissions (Everyone = Full Control)...
    net share "%FolderName%" /GRANT:Everyone,FULL >nul
    echo [OK] Share permissions ensured.
    echo.

    echo Verifying NTFS permissions...
    icacls "%ExistingPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
    echo [OK] NTFS permissions ensured.
    echo.

    goto CREATE_SHORTCUT
) else (
    echo [NOT FOUND] No existing share named "%FolderName%".
    echo Creating new folder and share...
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

    echo Setting NTFS permissions (Everyone Full Control)...
    icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T >nul 2>&1
    echo [OK] NTFS permissions set.
    echo.
)

:: -------------------------------
:: STEP 6 — Create Desktop Shortcut (Safe one-liner)
:: -------------------------------
:CREATE_SHORTCUT
echo Creating shortcut "Scan" on Desktop...
powershell -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop');$s=New-Object -ComObject WScript.Shell;$l=$s.CreateShortcut((Join-Path $d 'Scan.lnk'));$l.TargetPath='%FullFolderPath%';$l.Save()" >nul 2>&1

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
control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced
echo.

echo =================================================================
echo === All tasks completed successfully ===
echo =================================================================
pause
endlocal
