@echo off

rem odin build code -out:build/wiredeck.exe -debug -default-to-nil-allocator -no-crt

rem odin run tests -out:build/tests.exe -debug

call shell.bat

del build\SDL\*.obj
del build\SDL.pdb
cl /nologo /c ^
	/Zi ^
	/Fobuild\SDL\ /Fdbuild\SDL.pdb ^
	/Icode\SDL\include ^
	-DSDL_AUDIO_DISABLED ^
	-DSDL_HAPTIC_DISABLED ^
	-DSDL_HIDAPI_DISABLED ^
	-DSDL_SENSOR_DISABLED ^
	-DSDL_THREADS_DISABLED ^
	-DSDL_TIMERS_DISABLED ^
	-DSDL_JOYSTICK_DISABLED ^
	code\SDL\src\core\windows\*.c ^
	code\SDL\src\atomic\*.c ^
	code\SDL\src\thread\*.c ^
	code\SDL\src\thread\generic\*.c ^
	code\SDL\src\events\*.c ^
	code\SDL\src\file\*.c ^
	code\SDL\src\stdlib\*.c ^
	code\SDL\src\libm\*.c ^
	code\SDL\src\timer\*.c ^
	code\SDL\src\timer\windows\*.c ^
	code\SDL\src\video\*.c ^
	code\SDL\src\video\yuv2rgb\*.c ^
	code\SDL\src\video\windows\*.c ^
	code\SDL\src\render\*.c ^
	code\SDL\src\render\software\*.c ^
	code\SDL\src\cpuinfo\*.c ^
	code\SDL\src\loadso\windows\*.c ^
	code\SDL\src\*.c

del build\SDL.lib
lib /nologo build\SDL\*.obj -out:build\SDL.lib

del build\wiredeck*
cl /nologo ^
	/Zi ^
	/Febuild/wiredeck.exe /Fobuild/wiredeck.obj /Fdbuild/wiredeck.pdb ^
	code\wiredeck.c ^
	/link build/sdl.lib Ole32.lib Advapi32.lib Winmm.lib User32.lib Gdi32.lib OleAut32.lib Imm32.lib Shell32.lib Version.lib
