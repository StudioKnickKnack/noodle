@echo off

odin build main_release -out:app_release.exe -strict-style -vet -no-bounds-check -o:speed -subsystem:windows
