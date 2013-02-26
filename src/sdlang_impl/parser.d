/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.parser;

import std.file;

import sdlang_impl.ast;
import sdlang_impl.exception;
import sdlang_impl.lexer;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

/// Returns root tag
Tag!extraInfo parseFile(ExtraInfo extraInfo = ExtraInfo.Locations)(string filename)
{
	auto source = cast(string)read(filename);
	return parseSource(source, filename);
}

/// Returns root tag
Tag!extraInfo parseSource(ExtraInfo extraInfo = ExtraInfo.Locations)(string source, string filename=null)
{
	auto lexer = new Lexer(source, filename);
	auto parser = Parser!extraInfo(lexer);
	return parser.parseRoot();
}

private struct Parser(ExtraInfo extras)
{
	Lexer lexer;
	
	Tag!extras parseRoot()
	{
		auto root = new Tag!extras("root");
		parseTags(root);
		return root;
	}

	Tag!extras parseTags(ref Tag!extras tag)
	{
		return null;
	}
}
