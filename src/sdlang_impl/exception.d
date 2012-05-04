/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.exception;

import std.exception;

///.
class SDLangException : Exception
{
	///.
	this(string msg)
	{
		super(msg);
	}
}
