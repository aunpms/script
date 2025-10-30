@echo off
REM --- สคริปต์ที่ถูกแทนที่ข้อมูลจริงแล้ว ---
REM ข้อมูล:
REM แชร์เครือข่าย: \\192.168.0.4\it\master
REM ชื่อผู้ใช้: ttadmin
REM รหัสผ่าน: Testtech!234Sys
REM โฟลเดอร์ที่ต้องการคัดลอก (โปรแกรมหลัก): TEST TECH 1.53
REM ไฟล์ Shortcut ที่ต้องการคัดลอก: TEST TECH 1.53.lnk
REM ปลายทาง: C:\ (จะสร้างโฟลเดอร์ TEST TECH 1.53 ไว้ใน C:\)

SET "SHARE_PATH=\\192.168.0.4\it\master"
SET "USERNAME=ttadmin"
SET "PASSWORD=Testtech!234Sys"
SET "FOLDER_NAME=TEST TECH 1.53"
SET "SHORTCUT_NAME=TEST TECH 1.53.lnk" REM ชื่อไฟล์ Shortcut เต็ม
SET "LOCAL_DRIVE=T:"
SET "LOCAL_DESTINATION=C:\TEST TECH 1.53"
SET "DESKTOP_PATH=%USERPROFILE%\Desktop"

REM 1. เชื่อมต่อ (Map) ไดรฟ์เครือข่ายด้วยรหัสผ่าน
echo Drive connecting %LOCAL_DRIVE% to %SHARE_PATH%...
net use %LOCAL_DRIVE% "%SHARE_PATH%" /user:%USERNAME% %PASSWORD%

REM 2. ตรวจสอบว่าการเชื่อมต่อสำเร็จหรือไม่
IF ERRORLEVEL 1 (
    echo WARNING!!: Can't connect network drive! 
    goto :cleanup
)

REM 3. คัดลอกโฟลเดอร์โปรแกรมหลักจากไดรฟ์ที่เชื่อมต่อแล้ว
echo Copying %FOLDER_NAME% to %LOCAL_DESTINATION%...
xcopy "%LOCAL_DRIVE%\%FOLDER_NAME%" "%LOCAL_DESTINATION%" /E /I /H /Y

REM 4. คัดลอกไฟล์ Shortcut ไปยัง Desktop (ขั้นตอนใหม่)
echo.
echo Copying Shortcut %SHORTCUT_NAME% to Desktop...
copy "%LOCAL_DRIVE%\%SHORTCUT_NAME%" "%DESKTOP_PATH%" /Y

REM 5. ทำความสะอาด: ยกเลิกการเชื่อมต่อไดรฟ์เครือข่าย
:cleanup
echo.
echo Terminating drive %LOCAL_DRIVE%...
net use %LOCAL_DRIVE% /delete

echo.
echo Complete


REM *** หมายเหตุ: คำสั่ง 'pause' จะถูกลบออกเพื่อให้สคริปต์ลบตัวเองได้ทันทีหลังจากเสร็จสิ้น ***
REM หากต้องการให้หยุดดูก่อนลบตัวเอง ให้ย้าย 'pause' ไปอยู่ก่อน 'del "%~f0"'
REM แต่ถ้าใส่ 'pause' ไว้หลัง 'del "%~f0"' สคริปต์จะถูกลบแล้วทำให้ 'pause' ไม่สามารถทำงานได้ 
REM ในเวอร์ชันนี้ ผมได้ลบ 'pause' ออกตามหลักการทำงานของสคริปต์ติดตั้งที่ต้องการลบตัวเองอัตโนมัติ

exit