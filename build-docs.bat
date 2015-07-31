@echo off
rdmd --build-only -c -Isrc -I../libInputVisitor -D -X -Xfdocs/docs.json --force src/sdlang/package.d
ddox filter docs/docs.json --ex sdlang.lexer --ex sdlang.symbol --ex libInputVisitor --min-protection Public
ddox generate-html docs/docs.json docs --override-macros=ddoc/macros.ddoc
