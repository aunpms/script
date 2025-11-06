@echo off
title สร้างและตั้งค่าแชร์โฟลเดอร์ Scan (v3 - แก้ไข Findstr)
chcp 874 > nul

echo =================================================================
echo กำลังดำเนินการ: สร้างและตั้งค่าแชร์โฟลเดอร์ "Scan"
echo =================================================================
echo.

:: 1. กำหนดชื่อและเส้นทางของโฟลเดอร์
set "FolderName=Scan"
set "FolderBaseDir=%USERPROFILE%\Documents"
set "FullFolderPath=%FolderBaseDir%\%FolderName%"
set "ExistingPath="

echo โฟลเดอร์เป้าหมาย: "%FullFolderPath%"
echo.

:: 2. ตรวจสอบว่ามี Share "Scan" อยู่แล้วหรือไม่
echo กำลังตรวจสอบว่ามี Share ชื่อ "%FolderName%" อยู่หรือไม่...
net share | findstr /I /C:"%FolderName% " > nul

if %ERRORLEVEL% equ 0 (
    :: 2.1 ถ้ามี Share "Scan" อยู่แล้ว
    echo [? ตรวจพบ] มี Share ชื่อ "%FolderName%" อยู่แล้ว
    
    :: 2.2 ตรวจสอบว่า Path ถูกต้องหรือไม่
    echo กำลังตรวจสอบเส้นทาง (Path) ของ Share ที่มีอยู่...
    
    :: [FIX] ใช้ 'skip=1' และ 'tokens=1,*' เพื่อดึงบรรทัดที่ 2 (เส้นทาง) โดยไม่สนว่าเป็นภาษาอะไร
    for /f "skip=1 tokens=1,*" %%a in ('net share %FolderName%') do (
        set "ExistingPath=%%b"
        goto :GotPath
    )
    :GotPath
    
    :: ลบช่องว่างนำหน้าออกจาก Path ที่ดึงมาได้
    if defined ExistingPath (
        for /f "tokens=* delims= " %%i in ("%ExistingPath%") do set "ExistingPath=%%i"
    )

    echo   - เส้นทางที่ต้องการ: "%FullFolderPath%"
    echo   - เส้นทางปัจจุบัน:   "%ExistingPath%"
    echo.

    :: 2.3 เปรียบเทียบ Path (แบบไม่สนตัวพิมพ์เล็ก/ใหญ่)
    if /I "%ExistingPath%" == "%FullFolderPath%" (
        :: Path ถูกต้อง - ไปที่ขั้นตอนการตรวจสอบสิทธิ์
        echo [? สำเร็จ] Path ถูกต้อง, กำลังไปที่ขั้นตอนตรวจสอบสิทธิ์...
        goto :VERIFY_PERMISSIONS
    ) else (
        :: Path ไม่ถูกต้อง - ลบ Share เก่าทิ้ง แล้วไปสร้างใหม่
        echo [! แจ้งเตือน] Path ไม่ถูกต้อง!
        echo กำลังลบ Share เก่าที่ชี้ไปที่ "%ExistingPath%"...
        net share %FolderName% /delete /Y
        echo [? สำเร็จ] ลบ Share เก่าเรียบร้อยแล้ว
        echo.
        goto :CREATE_NEW_SHARE
    )

) else (
    :: 2.4 ถ้าไม่มี Share "Scan" - ไปที่ขั้นตอนการสร้างใหม่
    echo [? ต
