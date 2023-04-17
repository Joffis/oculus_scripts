@echo OFF
set ADB=..\adb\adb.exe
set DEVICE=
if not "%1"=="" set DEVICE=-s %1
%ADB% start-server
@echo.
@echo  Check the device incase USB debugging dialog popped up before continuing!
@echo.
@pause
@if "%ERRORLEVEL%" NEQ "0" goto Error
@echo Pushing OBB data folder..
%ADB% %DEVICE% push com.beatgames.beatsaber /sdcard/Android/obb/
@if "%ERRORLEVEL%" NEQ "0" goto Error
@echo.
@echo Success!
@pause
goto kill
:Error
@echo.
@echo Error during installation!
@pause
goto kill
:kill
%ADB% kill-server
exit