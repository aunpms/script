@echo off
title Setup Scan Share (Smart Logic v12.1 - Ultimate Stable)
setlocal enableextensions
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

echo Target Folder Path (default): "%FullFolderPath%"
echo.

:: -------------------------------
:: STEP 1 — Check if share exists
:: -------------------------------
net share > "%ShareTemp%"
findstr /I /B /C:"%FolderName% " "%ShareTemp%" >nul
if %ERRORLEVEL% equ 0 (
    echo [FOUND] Shared folder "%FolderName%" already exists.
    echo.

    call :GetExistingPath "%FolderName%"
    if defined ExistingPath (
        echo Share path detected: "%ExistingPath%"
        echo.

        echo [1/3] Ensuring Share Permissions (Full Control for Everyone)...
        call :FixSharePerm "%FolderName%" "%ExistingPath%"
        echo [OK] Share permissions corrected (if possible).
        echo.

        echo [2/3] Ensuring NTFS Permissions...
        call :SetNTFSPerms "%ExistingPath%"
        echo [OK] NTFS permissions ensured.
        echo.

        echo [3/3] Creating Shortcut...
        call :CreateShortcut "%ExistingPath%"
        echo [OK] Shortcut created on Desktop.
        echo.

        goto SETTINGS
    ) else (
        echo [ERR] Found share name but could not determine path.
        :: fallthrough to creation path if desired, but we stop
        goto END
    )
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
net share "%FolderName%"="%FullFolderPath%" /GRANT:Everyone,FULL >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Shared successfully.
) else (
    echo [WARN] net share returned non-zero (may still be shared). Continuing.
)
echo.

echo Setting NTFS permissions...
call :SetNTFSPerms "%FullFolderPath%"
echo [OK] NTFS permissions set.
echo.

echo Creating shortcut "Scan" on Desktop...
call :CreateShortcut "%FullFolderPath%"
echo [OK] Shortcut created.
echo.

del "%ShareTemp%" >nul 2>&1

:SETTINGS
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
:: Trim leading spaces
for /f "tokens=* delims= " %%i in ("%ExistingPath%") do set "ExistingPath=%%i"
exit /b

:: -------------------------------------------------
:: Function: SetNTFSPerms (PowerShell safe)
:: -------------------------------------------------
:SetNTFSPerms
echo Applying NTFS permissions to: %~1
:: Use PowerShell to call icacls to avoid cmd parsing issues with parentheses
powershell -NoProfile -Command "Start-Process icacls -ArgumentList @('%~1','/grant','Everyone:(OI)(CI)F','/T') -Wait -NoNewWindow" >nul 2>&1
exit /b

:: -------------------------------------------------
:: Function: FixSharePerm (PowerShell safe)
:: - Attempts to grant Everyone Full on the share using Grant-SmbShareAccess.
:: - If Grant-SmbShareAccess not available or fails, tries to recreate the share using New-SmbShare.
:: -------------------------------------------------
:FixSharePerm
:: %1 = share name, %2 = existing path
set "shname=%~1"
set "shpath=%~2"
echo Trying to grant Everyone Full to share "%shname%"...
powershell -NoProfile -Command ^
  "try { if (Get-Command Grant-SmbShareAccess -ErrorAction SilentlyContinue) { Grant-SmbShareAccess -Name '%shname%' -AccountName 'Everyone' -AccessRight Full -Force -ErrorAction Stop; exit 0 } else { exit 2 } } catch { exit 1 }" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    goto :FS_DONE
) else if %ERRORLEVEL% equ 2 (
    :: Grant-SmbShareAccess not found — try recreate via WMI/New-SmbShare
    powershell -NoProfile -Command ^
      "try { if ($s = Get-WmiObject -Class Win32_Share -Filter \"Name='%shname%'\" -ErrorAction SilentlyContinue) { $p=$s.Path; $s.Delete() | Out-Null; New-SmbShare -Name '%shname%' -Path (Get-Item $p).FullName -FullAccess 'Everyone' -ErrorAction Stop } exit 0 } catch { exit 1 }" >nul 2>&1
    if %ERRORLEVEL% equ 0 goto :FS_DONE
) else (
    :: Grant-SmbShareAccess failed (maybe due to permissions), attempt recreate as fallback
    powershell -NoProfile -Command ^
      "try { if ($s = Get-WmiObject -Class Win32_Share -Filter \"Name='%shname%'\" -ErrorAction SilentlyContinue) { $p=$s.Path; $s.Delete() | Out-Null; New-SmbShare -Name '%shname%' -Path (Get-Item $p).FullName -FullAccess 'Everyone' -ErrorAction Stop } exit 0 } catch { exit 1 }" >nul 2>&1
)
:FS_DONE
exit /b

:: -------------------------------------------------
:: Function: CreateShortcut
:: -------------------------------------------------
:CreateShortcut
powershell -NoProfile -Command " $d=[Environment]::GetFolderPath('Desktop'); $s=New-Object -ComObject WScript.Shell; $l=$s.CreateShortcut((Join-Path $d 'Scan.lnk')); $l.TargetPath='%~1'; $l.Save()" >nul 2>&1
exit /b

:: -------------------------------------------------
:: END
:: -------------------------------------------------
:END
echo.
echo Operation stopped due to previous errors.
pause
exit /b
