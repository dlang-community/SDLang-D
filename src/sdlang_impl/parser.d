/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.parser;

import sdlang_impl.ast;
import sdlang_impl.exception;
import sdlang_impl.lexer;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

Tag parseFile(ExtraInfo extraInfo = ExtraInfo.Locations)(string filename)
{
	auto source = cast(string)read(filename);
	return lexSource(source, filename);
}

Tag parseSource(ExtraInfo extraInfo = ExtraInfo.Locations)(string source, string filename=null)
{
	auto lexer = new Lexer(source, filename);
	return new Tag!extraInfo();
}
