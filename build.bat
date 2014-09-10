@echo off
rdmd --build-only -wi -version=sdlangTestApp -Isrc  -I..\libInputVisitor -ofbin\sdlang %* src/sdlang/package.d
