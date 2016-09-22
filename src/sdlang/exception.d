// SDLang-D
// Written in the D programming language.

module sdlang.exception;

import std.exception;
import std.string;

import sdlang.util;

/// Abstract parent class of all SDLang-D defined exceptions.
abstract class SDLangException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

/// Thrown when a syntax error is encounterd while parsing.
class ParseException : SDLangException
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

/// Compatibility alias
deprecated("The new name is ParseException")
alias SDLangParseException = ParseException;

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
class ValidationException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

/// Compatibility alias
deprecated("The new name is ValidationException")
alias SDLangValidationException = ValidationException;


/// Thrown by the DOM on empty range and out-of-range conditions.
class DOMRangeException : SDLangException
{
	this(string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line);
	}
}

/// Compatibility alias
deprecated("The new name is DOMRangeException")
alias SDLangRangeException = DOMRangeException;

/// Abstract parent class of `TagNotFoundException`, `ValueNotFoundException`
/// and `AttributeNotFoundException`.
///
/// Thrown by the DOM's `sdlang.ast.Tag.expectTag`, etc. functions if a matching element isn't found.
abstract class DOMNotFoundException : SDLangException
{
	FullName tagName;

	this(FullName tagName, string msg, string file = __FILE__, size_t line = __LINE__)
	{
		this.tagName = tagName;
		super(msg, file, line);
	}
}

/// Thrown by the DOM's `sdlang.ast.Tag.expectTag`, etc. functions if a Tag isn't found.
class TagNotFoundException : DOMNotFoundException
{
	this(FullName tagName, string msg, string file = __FILE__, size_t line = __LINE__)
	{
		super(tagName, msg, file, line);
	}
}

/// Thrown by the DOM's `sdlang.ast.Tag.expectValue`, etc. functions if a Value isn't found.
class ValueNotFoundException : DOMNotFoundException
{
	/// Expected type for the not-found value.
	TypeInfo valueType;

	this(FullName tagName, TypeInfo valueType, string msg, string file = __FILE__, size_t line = __LINE__)
	{
		this.valueType = valueType;
		super(tagName, msg, file, line);
	}
}

/// Thrown by the DOM's `sdlang.ast.Tag.expectAttribute`, etc. functions if an Attribute isn't found.
class AttributeNotFoundException : DOMNotFoundException
{
	FullName attributeName;

	/// Expected type for the not-found attribute's value.
	TypeInfo valueType;

	this(FullName tagName, FullName attributeName, TypeInfo valueType, string msg,
		string file = __FILE__, size_t line = __LINE__)
	{
		this.valueType = valueType;
		this.attributeName = attributeName;
		super(tagName, msg, file, line);
	}
}
