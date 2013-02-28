@echo off
rdmd --build-only -lib -Isrc -D -X -Xfdocs/docs.json --force src/sdlang.d
ddox filter docs/docs.json --ex sdlang_impl.lexer --ex sdlang_impl.symbol --min-protection Public
ddox generate-html docs/docs.json docs
