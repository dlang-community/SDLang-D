// SDLang-D
// Written in the D programming language.

module sdlang_.exception;

import std.exception;
import std.string;

import sdlang_.util;

class SDLangException : Exception
{
	Location location;
	bool hasLocation;

	this(string msg)
	{
		hasLocation = false;
		super(msg);
	}

	this(Location location, string msg)
	{
		hasLocation = true;
		super("%s: %s".format(location.toString(), msg));
	}
}
