// SDLang-D
// Written in the D programming language.

module sdlang.exception;

import std.exception;
import std.string;

import sdlang.util;

/// All SDLang-D defined exceptions inherit from this.
abstract class SDLangException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

/// Thrown when a syntax error is encounterd while parsing.
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

/++
Thrown when attempting to do something in the DOM that's unsupported
by the SDLang format, such as:

$(UL
$(LI Adding the same instance of a tag or attribute to more than one parent.)
$(LI Writing SDLang where:
	$(UL
	$(LI The root tag has values, attributes or a namespace. )
	$(LI An anonymous tag has a namespace. )
	$(LI An anonymous tag has no values. )
	$(LI A floating point value is infinity or NaN. )
	)
))
+/
class SDLangValidationException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

/// Thrown by the DOM on empty range and out-of-range conditions.
class SDLangRangeException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}
