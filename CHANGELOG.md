v0.9.2 - TBD
=====================
- **Change:** Updated ```package.json``` to newer ```dub.json``` name.
- **Fixed:** [#16](https://github.com/Abscissa/SDLang-D/issues/16): Now fixed for [DUB](http://code.dlang.org/getting_started) users, too: Access Violation when using the pull parser.
- **Fixed:** [#21](https://github.com/Abscissa/SDLang-D/issues/21): Remove unneeded "buildOptions" from DUB package config (fixes a DUB warning) (@schuetzm)
- **Fixed:** [#28](https://github.com/Abscissa/SDLang-D/issues/28)/[#29](https://github.com/Abscissa/SDLang-D/issues/29): Wrong line count for Windows style line breaks. (@s-ludwig)
- **Fixed:** Fixed running unittests via DUB. (Part of [#29](https://github.com/Abscissa/SDLang-D/issues/29)) (@s-ludwig)
- **Improved:** [#22](https://github.com/Abscissa/SDLang-D/issues/22)/[#23](https://github.com/Abscissa/SDLang-D/issues/23): Internal improvements (@schuetzm)

v0.9.1 - 2015/03/17
=====================
- **Fixed:** [#16](https://github.com/Abscissa/SDLang-D/issues/16): Access Violation when using the pull parser.

v0.9.0 - 2015/03/16
=====================
- **Breaking change:** Changed package structure to use ```package.d```. Most users will be unaffected, but the internal package names have changed slightly, and users of DMD 2.063.2 and below will need to ```import sdlang.package;``` instead of ```import sdlang;``` until they upgrade their compiler. The built-in command line tool and unittests, however, do now require DMD 2.064 or newer because of this change.
- **New:** Added StAX/Pull-style parser via [pullParseFile](http://semitwist.com/sdlang-d-api/sdlang/parser/pullParseFile.html) and  [pullParseSource](http://semitwist.com/sdlang-d-api/sdlang/parser/pullParseSource.html). (Warning: FileStartEvent and FileEndEvent *might* be removed later: [#17](https://github.com/Abscissa/SDLang-D/issues/17))
- **Fixed:** Work around a DMD 2.064/2.065 segfault bug in a unittest.
- **Fixed:** [#5](https://github.com/Abscissa/SDLang-D/issues/5) & [#7](https://github.com/Abscissa/SDLang-D/issues/7): Building with Dub produces package format warnings (@ColdenCullen).
- **Fixed:** [#8](https://github.com/Abscissa/SDLang-D/issues/8): Consecutive escape sequences not getting correctly decoded.
- **Fixed:** [#11](https://github.com/Abscissa/SDLang-D/issues/11): Newline immediately after // is ignored.
- **Fixed:** [#12](https://github.com/Abscissa/SDLang-D/issues/12): Incorrectly accepts "anon tag without a value" when the tag has children.
- **Fixed:** The ```build-docs``` script was broken for newer RDMDs.
- **Improved:** Better error message for anonymous tags with no values.

v0.8.4 - 2013/09/05
=====================
- **Fixed:** Works with DMD v2.063.2.
- **Fixed:** Updated to work with latest DUB (@s-ludwig).

v0.8.3 - 2013/03/26
=====================
- **Breaking change:** ```Tag```'s interface has been completely overhauled to provide a clean, safe and easy-to-use range-based system.
- **Breaking change:** Improved ```Attribute``` constructor, for convenience.
- **Breaking change:** Split ```SDLangException``` into an exception hierarchy. The ```location``` and ```hasLocation``` members have been moved into ```SDLangParseException```.
- **Breaking change:** ```Attribute``` is now a class.
- **New:** Added ```Tag.add(...)``` for adding values, attributes and children to a tag.
- **New:** Added ```Tag.toSDLDocument()``` to properly treat ```this``` as the root tag.
- **Fixed:** Non-sink overloads of ```Tag.toSDLDocument``` and ```Tag.toSDLString``` now support the optional ```indent``` and ```indentLevel``` params.
- **Fixed:** Functions that convert tags to strings now output the attributes/children in their original order.
- **Improved:** Improved and expanded GitHub-based documentation.

v0.8.2 - 2013/03/05
=====================
- Can now output SDL. (Via ```toSDLString()``` funcs.)
- Properly handle non-Unix newlines.
- Allow ```\r``` escape sequences.
- Make DUB package: <https://github.com/rejectedsoftware/dub>
- Fixed Windows buildscript.
- Fixed build-docs script so API reference properly excludes private modules.
- Rename ```build-unittests``` -> ```build-unittest``` (for consistency with ```bin/sdlang-unittest```).

v0.8.1 - 2013/02/28
=====================
- Initial release
