/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.util;

import std.algorithm;
import std.string;

enum sdlangVersion = "0.8";

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
	size_t index; /// Index into the source
	
	this(int line, int col, int index)
	{
		this.line  = line;
		this.col   = col;
		this.index = index;
	}
	
	this(string file, int line, int col, int index)
	{
		this.file  = file;
		this.line  = line;
		this.col   = col;
		this.index = index;
	}
	
	string toString()
	{
		return "%s(%s:%s)".format(file, line+1, col+1);
	}
}
