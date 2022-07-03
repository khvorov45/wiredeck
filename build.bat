@echo off

if exist shell.bat call shell.bat

cl /nologo /Zi /diagnostics:column ^
	/D_CRT_SECURE_NO_WARNINGS /DPLATFORM_WINDOWS /W3 ^
	/Fdbuild.pdb ^
	build.c ^
	/link Shell32.lib && build.exe
