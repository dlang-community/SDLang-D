/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.ast;

import sdlang_impl.token;
import sdlang_impl.util;

enum ExtraInfo
{
	None,      // Minimal info, minimal size
	Locations, // Include Location info
	All,       // Include Location and original Token info
}
bool atLeast(ExtraInfo extraInfo, ExtraInfo minimum)
{
	return cast(int)extraInfo >= cast(int)minimum;
}

struct Attribute(ExtraInfo extraInfo = ExtraInfo.Locations)
{
	string name;
	Value  value;

	static if(extraInfo.atLeast(ExtraInfo.Locations))
		Location location;

	static if(extraInfo.atLeast(ExtraInfo.All))
		Token valueToken;
}

class Tag(ExtraInfo extraInfo = ExtraInfo.Locations)
{
	static immutable defaultName = "content";

	string  name;
	Value[] values;

	Attribute!extraInfo[string][] attributes;
	Tag!extraInfo[string][]       tags;

	static if(extraInfo.atLeast(ExtraInfo.Locations))
		Location location;

	static if(extraInfo.atLeast(ExtraInfo.All))
		Token[] valueTokens;
	
	this(string name=null)
	{
		this.name = name;
	}
}
