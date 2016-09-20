// SDLang-D
// Written in the D programming language.

module sdlang.exception;

import std.exception;
import std.string;

import sdlang.util;

abstract class SDLangException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class SDLangParseException : SDLangException
{
	Location location;
	bool hasLocation;

	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		hasLocation = false;
		super(msg, file, line);
	}

	this(Location location, string msg, string file = __FILE__, size_t line = __LINE__)
	{
		hasLocation = true;
		super("%s: %s".format(location.toString(), msg), file, line);
	}
}

class SDLangValidationException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

class SDLangRangeException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}
