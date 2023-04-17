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
@echo Uninstalling old beatsaber if it exists..
%ADB% %DEVICE% shell pm uninstall com.beatgames.beatsaber
@echo Uninstalling old bmbf if it exists..
%ADB% %DEVICE% shell pm uninstall com.weloveoculus.BMBF
@echo Installing BS..
%ADB% %DEVICE% install -g com.beatgames.beatsaber.apk
@if "%ERRORLEVEL%" NEQ "0" goto Error
@echo Installing BMBF..
%ADB% %DEVICE% install -g com.weloveoculus.BMBF.apk
@if "%ERRORLEVEL%" NEQ "0" goto Error
@echo.
@echo Success, now open beat saber once, close it and then open BMBF, follow its installation process.
@echo When BMBF is installed and working fine, return to PC and use AddDLC.bat for the official dlc packs.
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