@echo off
rdmd --build-only -Isrc -ofbin/sdlang %* src/sdlang.d
