@echo off
rdmd --build-only -c -Isrc -I../libInputVisitor -I../taggedalgebraic/source -Dddocs_tmp -X -Xfdocs/docs.json --force src/sdlang/package.d
rmdir /S /Q docs_tmp > NUL 2> NUL
del src\sdlang\package.exe
ddox filter docs/docs.json --ex sdlang.lexer --ex sdlang.symbol --ex libInputVisitor --ex taggedalgebraic --min-protection Public
ddox generate-html docs/docs.json docs/public --navigation-type=ModuleTree --override-macros=ddoc/macros.ddoc
