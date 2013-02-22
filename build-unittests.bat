@echo off
rdmd --build-only -Isrc -ofbin\sdlang-unittest -unittest -version=unittest_sdlang -debug -gc %* src/sdlang.d
