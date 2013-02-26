@echo off
rdmd --build-only -Isrc -ofbin\sdlang-unittest -unittest -version=SDLang_Unittest -debug -gc %* src/sdlang.d
