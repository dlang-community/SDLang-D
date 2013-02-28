@echo off
rdmd --build-only -version=SDLang_TestApp -Isrc -ofbin/sdlang %* src/sdlang.d
