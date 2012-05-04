/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

import std.stream : ByteOrderMarks, BOM;

import sdlang_impl.exception;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

alias sdlang_impl.util.startsWith startsWith;

///.
struct Lexer
{
	string source; ///.
	string filename; ///.

	///.
	this(string source, string filename=null)
	{
		if( source.startsWith( ByteOrderMarks[BOM.UTF8] ) )
			source = source[ ByteOrderMarks[BOM.UTF8].length .. $ ];
		
		foreach(bom; ByteOrderMarks)
		if( source.startsWith(bom) )
			throw new SDLangException("SDL spec only supports UTF-8, not UTF-16 or UTF-32");

		this.source   = source;
		this.filename = filename;
	}
	
	bool done = false;
	///.
	@property bool empty()
	{
		//TODO: Implement this
		if(!done)
		{
			done = true;
			return false;
		}
		return true;
	}
	
	///.
	@property Token front()
	{
		//TODO: Implement this
		return Token(symbol!"EOF");
	}
	
	///.
	void popFront()
	{
		//TODO: Implement this
	}
}
