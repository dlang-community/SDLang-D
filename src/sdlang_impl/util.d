/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.util;

import std.algorithm;
import std.string;

alias immutable(ubyte)[] ByteString;

auto startsWith(T)(string haystack, T needle)
	if( is(T:ByteString) || is(T:string) )
{
	return std.algorithm.startsWith( cast(ByteString)haystack, cast(ByteString)needle );
}

struct Location
{
	string file; /// Filename (including path)
	int line; /// Zero-indexed
	int col;  /// Zero-indexed, Tab counts as 1
	
	this(int line, int col=0)
	{
		this.line = line;
		this.col  = col;
	}
	
	this(string file, int line, int col=0)
	{
		this.file = file;
		this.line = line;
		this.col  = col;
	}
	
	string toString()
	{
		return "%s(%s:%s)".format(file, line+1, col+1);
	}
}
