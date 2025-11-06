@echo off
title Setup Scan Share (v7 - English + Findstr /B Fix)
:: No CHCP needed for English

echo =================================================================
echo Now processing: Create and configure "Scan" shared folder
echo =================================================================
echo.

:: 1. Define folder name and path
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
set "ExistingPath="
set "ShareListFile=%TEMP%\sharelist_%RANDOM%.txt"

echo Target folder: "%FullFolderPath%"
echo.

:: 2. Check if "Scan" share already exists
echo Checking if share name "%FolderName%" already exists...

:: [FIX] Use a temp file instead of a pipe (|) for reliability
net share > "%ShareListFile%"

:: [FIX v7] Add /B to match only at the BEGINNING of the line
:: This prevents false positives from shares like "MyScan"
findstr /I /B /C:"%FolderName% " "%ShareListFile%" > nul

if %ERRORLEVEL% equ 0 (
    :: 2.1 If "Scan" share exists
    echo [FOUND] Share name "%FolderName%" already exists.
    
    :: 2.2 Check if the path is correct
    echo Checking existing share path...
    
    :: [FIX] Use 'skip=1' and 'tokens=1,*' to get the 2nd line (the path)
    for /f "skip=1 tokens=1,*" %%a in ('net share %FolderName%') do (
        set "ExistingPath=%%b"
        goto :GotPath
    )
    :GotPath
    
    :: Trim leading spaces from the path
    if defined ExistingPath (
        for /f "tokens=* delims= " %%i in ("%ExistingPath%") do set "ExistingPath=%%i"
    )

    echo   - Required Path: "%FullFolderPath%"
    echo   - Current Path:  "%ExistingPath%"
    echo.

    :: 2.3 Compare paths (case-insensitive)
    if /I "%ExistingPath%" == "%FullFolderPath%" (
        :: Path is correct - proceed to verify permissions
        echo [OK] Path is correct. Proceeding to verify permissions...
        goto :VERIFY_PERMISSIONS
    ) else (
        :: Path is incorrect - delete old share and create new one
        echo [WARNING] Path is incorrect!
        echo Deleting old share pointing to "%ExistingPath%"...
        net share %FolderName% /delete /Y
        echo [OK] Old share deleted.
        echo.
        goto :CREATE_NEW_SHARE
    )

) else (
    :: 2.4 If "Scan" share does not exist - proceed to create
    echo [NOT FOUND] Share name "%FolderName%" not found. Starting creation process...
    echo.
    goto :CREATE_NEW_SHARE
)


:: =================================================================
:: SECTION: CREATE NEW SHARE
:: =================================================================
:CREATE_NEW_SHARE
echo --- Starting new share creation process ---
:: 3. Create folder
mkdir "%FullFolderPath%"
if exist "%FullFolderPath%" (
    echo [OK] Folder created.
) else (
    echo [FAIL] Could not create folder.
    goto :END_SCRIPT
)
echo.

:: 4. Share the folder
echo Sharing folder (GRANT)...
net share %FolderName%="%FullFolderPath%" /GRANT:Everyone,FULL
echo [OK] Folder shared as "%FolderName%".
echo ** Network Path: \\%COMPUTERNAME%\%FolderName% **
echo.

:: 5. Set NTFS permissions
echo Setting NTFS permissions...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T
echo [OK] NTFS permissions set: Everyone Full Control.
echo.

:: 6. Create Shortcut
echo Creating shortcut...
goto :CREATE_SHORTCUT


:: =================================================================
:: SECTION: VERIFY EXISTING PERMISSIONS
:: =================================================================
:VERIFY_PERMISSIONS
echo --- Verifying and enforcing permissions ---
:: 4. (Verify) Enforce Share permissions
echo Enforcing Share permissions (GRANT)...
net share %FolderName% /GRANT:Everyone,FULL
echo [OK] Share permissions set: Everyone Full Control.
echo.

:: 5. (Verify) Enforce NTFS permissions
echo Enforcing NTFS permissions...
icacls "%FullFolderPath%" /grant Everyone:(OI)(CI)F /T
echo [OK] NTFS permissions set: Everyone Full Control.
echo.

:: 6. (Verify) Create Shortcut
echo Checking/Creating shortcut...
goto :CREATE_SHORTCUT


:: =================================================================
:: COMMON SECTION
:: =================================================================
:CREATE_SHORTCUT
powershell -Command "$Desktop = Join-Path $env:PUBLIC -ChildPath 'Desktop'; If (Test-Path $Desktop) { $s=(New-Object -COM WScript.Shell).CreateShortcut((Join-Path $Desktop 'Scan.lnk')); $s.TargetPath='%FullFolderPath%'; $s.Save(); Exit 0 } Else { Write-Error 'Public Desktop not found.'; Exit 1 }"
if %ERRORLEVEL% equ 0 (
    echo [OK] Shortcut created/updated on Public Desktop.
) else (
    echo [FAIL] Could not create shortcut (Public Desktop might not exist).
)
echo.

:: 7. Open Advanced Sharing Settings (runs in all cases)
echo Opening "Advanced Sharing Settings" window...
control.exe /name Microsoft.NetworkAndSharingCenter /page Advanced

echo =================================================================
echo === Operation Completed ===
echo =================================================================

:END_SCRIPT
:: Clean up the temp file
if exist "%ShareListFile%" del "%ShareListFile%"
pause
