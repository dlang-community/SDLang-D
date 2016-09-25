Spec v2 Wishlist
================

There has been talk, some including the original designer of the SDLang language, about an updated version of the language. No big huge changes, mainly just fixing some minor but nagging issues. This page is here to help keep track of what's being considered.

- [#13](https://github.com/Abscissa/SDLang-D/issues/13) (also "Case 8" at [#9](https://github.com/Abscissa/SDLang-D/issues/9)): Allow `:tagname`, ie anon namespace and tagname prefixed with colon. There is ample reason to allow this (and it could be argued the spec *seems* to intend allowing it), but the original Java implementation rejects it, so SDLang-D rejects it as well.

- [#26](https://github.com/Abscissa/SDLang-D/issues/26): Support infinity and NaN for floating-point types. (Reported to be sanctioned by original creator).

- Do...something...about opening curly-braces on a new line. Due to the grammar being newline-terminated, this is not allowed since it would get parsed as "One tag with no children, followed by a *separate* anonymous tag *with* children". However, this is unintuitive and confusing to new users. Plus, anonymous tags with no values are already intentionally disallowed anyway (for other reasons), so it should technically be possible to either allow it (but that might make for weird/confusing grammar, too), or issue a more meaningful error message.

- A simpler, more disciplined and well-defined grammar for dates and times. Currently, they are very lax and permissive, and not defined anywhere. As far as I can tell, the rules currently amount to "Whatever Java's date/time tools allow".

- Nested `/+ +/` block comments. I *hate* non-nesting block comments with a passion. In any language, it completely breaks commenting-out a block of code *every* time the block just happens to *already* have a block comment, which is just, so...stoopid. Nesting is trivial to implement and should be everywhere block comments exist.

- \uXXXX style unicode escapes for string and character literals. Contrary to what the [original langauge guide](http://semitwist.com/sdl-mirror/Language+Guide.html) claims, such escapes are useful for non-printing codes, combining characters, and any code points that aren't easily viewed.
