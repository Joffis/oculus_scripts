@echo OFF
:: Set ADB ad AAPT path as you wish, relative or absolute
SET ADB=.\adb\adb.exe
SET AAPT=.\adb\aapt.exe
:: ADB Device name (use only for more than one device connected, otherwise leave empty)
SET DEVICE=

:: Don't change anything below here
cd /D "%~dp0"
IF "%mode%"=="" SET mode=install
echo Oculus AutoInstall
echo.
SETLOCAL EnableDelayedExpansion
IF NOT "!DEVICE!"=="" SET DEVICE=-s !DEVICE!
SET EXECPATH=%~dp0.
IF NOT "%~1"=="" SET EXECPATH=%~1

IF NOT EXIST "%EXECPATH%" (
	echo Error: path %EXECPATH% not exits. Aborting...
	GOTO Exit
)

IF NOT EXIST "!ADB!" (
	echo Error: ADB not found at !ADB! Aborting...
	GOTO Exit
)
FOR /F "usebackq tokens=* delims=" %%F IN (`dir "!ADB!" /B /S`) DO (SET ADB=%%F)
echo Using ADB from !ADB!

IF NOT EXIST "!AAPT!" (
	echo Error: AAPT not found at !AAPT! Aborting...
	GOTO Exit
)
FOR /F "usebackq tokens=* delims=" %%F IN (`dir "!AAPT!" /B /S`) DO (SET AAPT=%%F)
echo Using AAPT from !AAPT! 

FOR /F "usebackq tokens=* delims=" %%F IN (`where "%EXECPATH%":*.apk`) DO (SET apk=%%F)
FOR %%A IN ("!apk!") DO (SET apk_name=%%~nxA)
IF "!apk!"=="" (
	echo Error: No APK found. Aborting...
	echo.
	GOTO Exit
)
echo.
echo Using APK from !apk!
echo.

FOR /F "usebackq tokens=2,4 delims='" %%a IN (`CALL "!AAPT!" d badging "!apk!" ^| findstr "package"`) DO (
	SET PKGDIR=%%a
	SET PKGVER=%%b
)
SET expected_obb_name=main.!PKGVER!.!PKGDIR!
SET expected_obb_name2=main.!PKGDIR!

SET obbalwaysok=
FOR /R "%EXECPATH%\" %%G IN (*.obb) DO (
	SET obbpresent=yes
	IF NOT "%mode%"=="install" (GOTO :endofobbcheck)
	SET obb=%%G
	FOR %%A IN ("!obb!") DO (
		SET obb_name=%%~nxA
		SET obb_extension=%%~xA
	)

	echo Using OBB from !obb!
	
	SET obbok=
	SET tmpout=
	FOR /F "usebackq tokens=* delims=" %%A IN (`echo !obb_name! ^| findstr /b "!expected_obb_name!" 2^>nul`) DO SET tmpout=%%A
	IF NOT "!tmpout!"=="" (
		SET obbok=yes
	) ELSE (
		FOR /F "usebackq tokens=* delims=" %%A IN (`echo !obb_name! ^| findstr /b "!expected_obb_name2!" 2^>nul`) DO SET tmpout=%%A
		IF NOT "!tmpout!"=="" (
			SET obbok=yes
		) ELSE (
			FOR /F "usebackq tokens=* delims=" %%A IN (`echo !obb_name! ^| findstr /b "patch" 2^>nul`) DO SET tmpout=%%A
			IF NOT "!tmpout!"=="" (
				FOR /F "usebackq tokens=* delims=" %%A IN (`echo !obb_name! ^| findstr "!expected_obb_name2!" 2^>nul`) DO SET tmpout=%%A
				IF NOT "!tmpout!"=="" (
					SET obbok=yes
				)
			)
		)
	)
	
	IF NOT "!obbok!"=="yes" IF NOT "!obbalwaysok!"=="yes" (
		echo Your OBB filename is : !obb_name!
		echo But I think should be: !expected_obb_name!*!obb_extension!
		echo                   or : !expected_obb_name2!*!obb_extension!
		echo                   or : patch*!expected_obb_name2!*!obb_extension!
		SET /P YESNO="Continue anyway? (Y/N/A): "
		IF "!YESNO!"=="a" (
			SET obbalwaysok=yes
		)
		IF "!YESNO!"=="A" (
			SET obbalwaysok=yes
		)
		IF NOT "!YESNO!"=="y" IF NOT "!YESNO!"=="Y" (
			echo Aborting...
			GOTO Exit
		)
	)
)

:endofobbcheck

FOR /R "%EXECPATH%\%PKGDIR%\" %%G IN (*.*) DO (
	SET extrafile=%%G
	FOR %%A IN ("!extrafile!") DO (
		SET extrafile_name=%%~nxA
		SET extrafile_extension=%%~xA
	)
	IF NOT "!extrafile_extension!"==".obb" (
		echo Unexpected file from !extrafile! 
		SET obbpresent=yes
		IF NOT "%mode%"=="install" (GOTO :endofextrafilecheck)
		SET /P YESNO="This is not a standard file but will be copied as an OBB file. Continue anyway? (Y/N/A): "
		IF "!YESNO!"=="a" (
			GOTO endofextrafilecheck
		)
		IF "!YESNO!"=="A" (
			GOTO endofextrafilecheck
		)
		IF NOT "!YESNO!"=="y" IF NOT "!YESNO!"=="Y" (
			echo Aborting...
			GOTO Exit
		)	
	)
)

:endofextrafilecheck

IF "!obbpresent!"=="" (
	echo No OBB found... bypassing OBB %mode%
) ELSE (
	echo.
	SET ADBSTARTED=yes
	FOR /F "usebackq tokens=* delims=" %%A IN (`CALL "!ADB!" !DEVICE! shell "echo $EXTERNAL_STORAGE"`) DO SET STORAGE=%%A
	IF "!STORAGE!"=="" (
		echo Error getting storage location. Aborting...
		GOTO Exit
	)	
)

SET ADBSTARTED=yes
FOR /F "usebackq tokens=* delims=" %%A IN (`CALL "!ADB!" !DEVICE! shell pm list packages !PKGDIR!`) DO SET is_installed=%%A
IF "!is_installed!"=="" (
	IF "%mode%"=="uninstall" (
		echo.
		echo APK not installed on device. Aborting...
		GOTO Exit
	)
) ELSE (
	IF "%mode%"=="install" (
		SET /P YESNO="APK is already installed on device. Do you want to install anyway? (Y/N): "
		IF "!YESNO!"=="y" (SET YESNO=Y)
		IF NOT "!YESNO!"=="Y" (
			echo Aborting...
			GOTO Exit
		)
	)
)		

echo.
IF "%mode%"=="install" (
	call :setsize "!apk!"
	echo Installing !size!Mb APK... ^(no progress count, please wait Success message^)
	SET ERRORLEVEL=0
	"!ADB!" !DEVICE! install -g -r "!apk!"
	IF ERRORLEVEL 1 (
		echo Error installing the APK file
		GOTO Exit
	)
	echo Success installing APK

	FOR /R "%EXECPATH%\" %%G IN (*.obb) DO (
		SET obb=%%G
		FOR %%A IN ("!obb!") DO (SET obb_name=%%~nxA)
		echo.
		call :setsize "!obb!"
		echo installing !size!Mb OBB...
		SET ERRORLEVEL=0
		"!ADB!" !DEVICE! push "!obb!" !STORAGE!/Android/obb/!PKGDIR!/!obb_name!
		IF ERRORLEVEL 1 (
			echo Error installing the OBB file
			GOTO Exit
		)
		echo Success installing OBB
	)

	FOR /R "%EXECPATH%\%PKGDIR%\" %%G IN (*.*) DO (
		SET extrafile=%%G
		FOR %%A IN ("!extrafile!") DO (
			SET extrafile_name=%%~nxA
			SET extrafile_extension=%%~xA
		)
		IF NOT "!extrafile_extension!"==".obb" (
			echo.
			call :setsize "!extrafile!"
			echo installing !size!Mb file...
			SET ERRORLEVEL=0
			"!ADB!" !DEVICE! push "!extrafile!" !STORAGE!/Android/obb/!PKGDIR!/!extrafile_name!
			IF ERRORLEVEL 1 (
				echo Error installing the file
				GOTO Exit
			)
			echo Success installing file
		)
	)
	
	echo.
	FOR /F "usebackq tokens=2 delims='" %%a IN (`CALL "!AAPT!" d permissions "!apk!" ^| findstr "uses-permission"`) DO (
		echo Setting permission %%a
		"!ADB!" !DEVICE! shell pm grant !PKGDIR! %%a 1>nul 2>nul
	)
) ELSE IF "%mode%"=="uninstall" (
	SET /P YESNO="Do you want to keep game data (saves, etc.)? (Y/N): "
	IF "!YESNO!"=="y" (SET YESNO=Y)
	IF NOT "!YESNO!"=="Y" (
		echo Uninstalling APK and data...
		SET ERRORLEVEL=0
		"!ADB!" !DEVICE! shell pm uninstall !PKGDIR!
		IF ERRORLEVEL 1 (
			echo Error uninstalling the APK file and data
			GOTO Exit
		)
		echo Success uninstalling APK and data
	) ELSE (
		echo Uninstalling APK keeping data...
		SET ERRORLEVEL=0
		"!ADB!" !DEVICE! shell pm uninstall -k !PKGDIR!
		IF ERRORLEVEL 1 (
			echo Error uninstalling the APK file keeping data
			GOTO Exit
		)
		echo Success uninstalling APK, but keeping data 
	)

	IF NOT "!obbpresent!"=="" (
		echo.
		echo Uninstalling OBB files...
		SET ERRORLEVEL=0
		"!ADB!" !DEVICE! shell rm -rfv !STORAGE!/Android/obb/!PKGDIR!
		IF ERRORLEVEL 1 (
			echo Error uninstalling OBB file
			GOTO Exit
		)
		echo Success uninstalling OBB
	)	
)

echo.
echo Job Done
echo.

:Exit
IF "!ADBSTARTED!"=="yes" (CALL "!ADB!" kill-server)
pause
exit

:setsize
SET tmp=
SET size=
SET tmp=%~z1
SET /A size=%tmp:~0,-3% 2>nul
IF "%size%"=="" (
	SET /A "size=%tmp%/1024"
)
IF "%size%" LSS "1024" (
	SET size=less than 1
) ELSE (
	SET /A "size/=1024"
)
GOTO :eof