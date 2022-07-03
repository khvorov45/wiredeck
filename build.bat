@echo off

rem odin build code -out:build/wiredeck.exe -debug -default-to-nil-allocator -no-crt

rem odin run tests -out:build/tests.exe -debug

call shell.bat

cl /nologo /Zi /diagnostics:column ^
	/D_CRT_SECURE_NO_WARNINGS /DPLATFORM_WINDOWS /W3 ^
	/Fdbuild.pdb ^
	build.c ^
	/link Shell32.lib && build.exe
