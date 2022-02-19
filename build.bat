clang-cl -Od -Z7 -nologo -c -TC -D_CRT_SECURE_NO_WARNINGS -Fobuild\tinyfiledialog.obj .\code\tinyfiledialogs\tinyfiledialogs.c
llvm-lib -nologo build\tinyfiledialog.obj -out:build\tinyfiledialog.lib

odin build code -debug -out:build/wiredeck.exe