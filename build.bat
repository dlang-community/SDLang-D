@echo off
rdmd --build-only -wi -version=SDLang_TestApp -Isrc -ofbin/sdlang %* src/sdlang.d
