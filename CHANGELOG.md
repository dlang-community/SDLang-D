SDLang-D - ChangeLog
====================

(Dates below are YYYY/MM/DD)

v0.10.1 - 2016-10-04
---------------------
- **Fixed:** [#50](https://github.com/Abscissa/SDLang-D/issues/50): Outputs certain floating point numbers in unsupported scientific notation.

v0.10.0 - 2016-09-25
---------------------
Big convenience enhancements to DOM interface and an improved pull parser interface. Plus documentation improvements and a couple bugfixes.

- **New:** [`SDLangException`](http://semitwist.com/sdlang-d/sdlang/exception/SDLangException.html) and subclasses now take the standard file and line parameters.
- **New:** New exceptions: [`DOMException`](http://semitwist.com/sdlang-d/sdlang/exception/DOMException.html), [`DOMNotFoundException`](http://semitwist.com/sdlang-d/sdlang/exception/DOMNotFoundException.html), [`TagNotFoundException`](http://semitwist.com/sdlang-d/sdlang/exception/TagNotFoundException.html), [`ValueNotFoundException`](http://semitwist.com/sdlang-d/sdlang/exception/ValueNotFoundException.html), [`AttributeNotFoundException`](http://semitwist.com/sdlang-d/sdlang/exception/AttributeNotFoundException.html) and [`ArgumentException`](http://semitwist.com/sdlang-d/sdlang/exception/ArgumentException.html).
- **New:** Add a simple struct [`FullName`](http://semitwist.com/sdlang-d/sdlang/util/FullName.html) to split and combine namespace/name combinations.
- **New:** [`Location.toString`](http://semitwist.com/sdlang-d/sdlang/util/Location.toString.html) takes optional output range as a sink.
- **New:** [#6](https://github.com/Abscissa/SDLang-D/issues/6): Added [`Tag.getValue`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.getValue.html) and [`Tag.getAttribute`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.getAttribute.html) to more easily obtain values and attributes when only one value is expected for a given tag name.
- **New:** [#38](https://github.com/Abscissa/SDLang-D/issues/38): Add Tag.clone/Attribute.clone to deep clone a tag (and all its children)
- **Change:** Minimum DMDFE bumped to 2.069.
- **Change:** Cleaned up the names of the [exceptions](http://semitwist.com/sdlang-d/sdlang/exception.html).
- **Change:** Deprecated `Tag.fullName` and `Attribute.fullName`. Use `Tag.getFullName().toString()` and `Attribute.getFullName().toString()` instead.
- **Change:** [#17](https://github.com/Abscissa/SDLang-D/issues/17): Remove unnecessary FileStart and FileEnd events.
- **Change:** Pull parser: [`ParserEvent`](http://semitwist.com/sdlang-d/sdlang/parser/ParserEvent.html) is now a [`TaggedAlgebraic`](https://github.com/s-ludwig/taggedalgebraic), instead of a [`std.variant.Algebraic`](http://dlang.org/phobos/std_variant.html#.Algebraic). This enables use of `final switch` and provides simpler syntax.
- **Improved:** Various documentation improvements.
- **Improved:** Improved some lexer/parser error messages.
- **Fixed:** Fixed building the CLI tool via dub.
- **Fixed:** [#27](https://github.com/Abscissa/SDLang-D/issues/27): Should get error when serializing unsupported infinity and nan.
- **Fixed:** [#44](https://github.com/Abscissa/SDLang-D/issues/44): Need better error message for ":tagname" (colon with no namespace) 
- **Fixed:** [libInputVisitor #1](https://github.com/Abscissa/libInputVisitor/issues/1): Call to Fiber crashes an application. [Windows x86_64]

v0.9.6 - 2016-08-23
---------------------
- **Fixed:** [#39](https://github.com/Abscissa/SDLang-D/pull/39): Remove references to deprecated module std.stream (@lesderid)

v0.9.5 - 2016-04-19
---------------------
- **Change:** Dropped support for DMDFE v2.066.1 and below (including LDC 0.15.1, GDC 5.2.0 and below) due to [#36](https://github.com/Abscissa/SDLang-D/pull/36).
- **Fixed:** [#34](https://github.com/Abscissa/SDLang-D/issues/34)/[#35](https://github.com/Abscissa/SDLang-D/pull/35): Bogus parse error for empty strings at EOL (@s-ludwig)
- **Fixed:** [#36](https://github.com/Abscissa/SDLang-D/pull/36): Use Duration for fractional seconds to avoid deprecation warnings. (@s-ludwig)

v0.9.4 - 2016-02-07
---------------------
- **Change:** Dropped support for DMDFE v2.065 and below (due to [#24](https://github.com/Abscissa/SDLang-D/pull/24)). Also dropped support for GDC 4.9 (but GDC 5.2 works).
- **Fixed:** [#24](https://github.com/Abscissa/SDLang-D/pull/24): Fixed deprecation message: Replace deprecated core.time.Duration.* by split.

v0.9.3 - 2015-08-13
---------------------
- **Change:** Don't need "-gc" for unittests, "-g" should do fine.
- **Fixed:** [#31](https://github.com/Abscissa/SDLang-D/issues/31): Escape sequence results in range violation error.

v0.9.2 - 2015-07-31
---------------------
- **New:** Uses [travis-ci.org](https://travis-ci.org) for continuous integration testing.
- **Change:** Updated ```package.json``` to newer ```dub.json``` name.
- **Fixed:** [#16](https://github.com/Abscissa/SDLang-D/issues/16): Now fixed for [DUB](http://code.dlang.org/getting_started) users, too: Access Violation when using the pull parser.
- **Fixed:** [#21](https://github.com/Abscissa/SDLang-D/issues/21): Remove unneeded "buildOptions" from DUB package config (fixes a DUB warning) (@schuetzm)
- **Fixed:** [#28](https://github.com/Abscissa/SDLang-D/issues/28)/[#29](https://github.com/Abscissa/SDLang-D/issues/29): Wrong line count for Windows style line breaks. (@s-ludwig)
- **Fixed:** Fixed running unittests via DUB. (Part of [#29](https://github.com/Abscissa/SDLang-D/issues/29)) (@s-ludwig)
- **Fixed:** Trailing line comments incorrectly treated as line continuation instead of newline (Related: [#20](https://github.com/Abscissa/SDLang-D/issues/20), plus [libsdl-d](https://github.com/Dicebot/libsdl-d)'s [e565f30](https://github.com/Dicebot/libsdl-d/commit/e565f302a60585cd25a8443a0439c8aec18f2515) and [c6dc722](https://github.com/Dicebot/libsdl-d/commit/c6dc72284c93a8e42ec0d9db6803e226358d5022)) (@Dicebot)
- **Improved:** [#22](https://github.com/Abscissa/SDLang-D/issues/22)/[#23](https://github.com/Abscissa/SDLang-D/issues/23): Internal improvements (@schuetzm)

v0.9.1 - 2015/03/17
---------------------
- **Fixed:** [#16](https://github.com/Abscissa/SDLang-D/issues/16): Access Violation when using the pull parser.

v0.9.0 - 2015/03/16
---------------------
- **Breaking change:** Changed package structure to use ```package.d```. Most users will be unaffected, but the internal package names have changed slightly, and users of DMD 2.063.2 and below will need to ```import sdlang.package;``` instead of ```import sdlang;``` until they upgrade their compiler. The built-in command line tool and unittests, however, do now require DMD 2.064 or newer because of this change.
- **New:** Added StAX/Pull-style parser via [pullParseFile](http://semitwist.com/sdlang-d/sdlang/parser/pullParseFile.html) and  [pullParseSource](http://semitwist.com/sdlang-d/sdlang/parser/pullParseSource.html). (Warning: FileStartEvent and FileEndEvent *might* be removed later: [#17](https://github.com/Abscissa/SDLang-D/issues/17))
- **Fixed:** Work around a DMD 2.064/2.065 segfault bug in a unittest.
- **Fixed:** [#5](https://github.com/Abscissa/SDLang-D/issues/5) & [#7](https://github.com/Abscissa/SDLang-D/issues/7): Building with Dub produces package format warnings (@ColdenCullen).
- **Fixed:** [#8](https://github.com/Abscissa/SDLang-D/issues/8): Consecutive escape sequences not getting correctly decoded.
- **Fixed:** [#11](https://github.com/Abscissa/SDLang-D/issues/11): Newline immediately after // is ignored.
- **Fixed:** [#12](https://github.com/Abscissa/SDLang-D/issues/12): Incorrectly accepts "anon tag without a value" when the tag has children.
- **Fixed:** The ```build-docs``` script was broken for newer RDMDs.
- **Improved:** Better error message for anonymous tags with no values.

v0.8.4 - 2013/09/05
---------------------
- **Fixed:** Works with DMD v2.063.2.
- **Fixed:** Updated to work with latest DUB (@s-ludwig).

v0.8.3 - 2013/03/26
---------------------
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
---------------------
- Can now output SDL. (Via ```toSDLString()``` funcs.)
- Properly handle non-Unix newlines.
- Allow ```\r``` escape sequences.
- Make DUB package: <https://github.com/rejectedsoftware/dub>
- Fixed Windows buildscript.
- Fixed build-docs script so API reference properly excludes private modules.
- Rename ```build-unittests``` -> ```build-unittest``` (for consistency with ```bin/sdlang-unittest```).

v0.8.1 - 2013/02/28
---------------------
- Initial release
