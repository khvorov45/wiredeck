@echo off

rem odin build code -out:build/wiredeck.exe -debug -default-to-nil-allocator -no-crt

rem odin run tests -out:build/tests.exe -debug

call shell.bat

cl /nologo /Zi /diagnostics:column /D_CRT_SECURE_NO_WARNINGS /DPLATFORM_WINDOWS /W3 build.c /link Shell32.lib && build.exe

rem del build\SDL\*.obj
rem del build\SDL.pdb
rem cl /nologo /c ^
rem 	/Zi ^
rem 	/Fobuild\SDL\ /Fdbuild\SDL.pdb ^
rem 	/Icode\SDL\include ^
rem 	-DSDL_AUDIO_DISABLED ^
rem 	-DSDL_HAPTIC_DISABLED ^
rem 	-DSDL_HIDAPI_DISABLED ^
rem 	-DSDL_SENSOR_DISABLED ^
rem 	-DSDL_THREADS_DISABLED ^
rem 	-DSDL_TIMERS_DISABLED ^
rem 	-DSDL_JOYSTICK_DISABLED ^
rem 	code\SDL\src\core\windows\*.c ^
rem 	code\SDL\src\atomic\*.c ^
rem 	code\SDL\src\thread\*.c ^
rem 	code\SDL\src\thread\generic\*.c ^
rem 	code\SDL\src\events\*.c ^
rem 	code\SDL\src\file\*.c ^
rem 	code\SDL\src\stdlib\*.c ^
rem 	code\SDL\src\libm\*.c ^
rem 	code\SDL\src\timer\*.c ^
rem 	code\SDL\src\timer\windows\*.c ^
rem 	code\SDL\src\video\*.c ^
rem 	code\SDL\src\video\yuv2rgb\*.c ^
rem 	code\SDL\src\video\windows\*.c ^
rem 	code\SDL\src\render\*.c ^
rem 	code\SDL\src\render\software\*.c ^
rem 	code\SDL\src\cpuinfo\*.c ^
rem 	code\SDL\src\loadso\windows\*.c ^
rem 	code\SDL\src\*.c

rem del build\SDL.lib
rem lib /nologo build\SDL\*.obj -out:build\SDL.lib

rem del build\wiredeck*
rem cl /nologo ^
rem 	/Zi ^
rem 	/Febuild/wiredeck.exe /Fobuild/wiredeck.obj /Fdbuild/wiredeck.pdb ^
rem 	code\wiredeck.c ^
rem 	/link build/sdl.lib Ole32.lib Advapi32.lib Winmm.lib User32.lib Gdi32.lib OleAut32.lib Imm32.lib Shell32.lib Version.lib
