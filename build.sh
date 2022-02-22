gcc -g -c ./code/tinyfiledialogs/tinyfiledialogs.c -o build/tinyfiledialog.obj
ar rcs build/tinyfiledialog.a build/tinyfiledialog.obj

odin build code -debug -out:build/wiredeck