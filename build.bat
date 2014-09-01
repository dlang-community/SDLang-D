@echo off
rdmd --build-only -wi -version=sdlangTestApp -Isrc -ofbin\sdlang %* src/sdlang/package.d
