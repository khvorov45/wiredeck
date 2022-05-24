@echo off

odin build code -out:build/wiredeck.exe -debug -default-to-nil-allocator -no-crt

odin run tests -out:build/tests.exe -debug
