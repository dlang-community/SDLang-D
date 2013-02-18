/// SDLang-D
/// Written in the D programming language.

/// Symbol is essentially the "type" of a Token.
/// Token is like an instance of a Symbol.

module sdlang_impl.symbol;

import std.algorithm;

///.
static immutable validSymbolNames = [
	"Error",
	"EOF",
	"EOL",

	":",
	"=",
	"{",
	"}",

	"true",
	"false",
	"null",

	"Ident",
	"Value",
];

/// Use this to create a Symbol. Ex: symbol!"Value" or symbol!"="
/// Invalid names (such as symbol!"FooBar") are rejected at compile-time.
template symbol(string name)
{
	static assert(validSymbolNames.find(name), "Invalid Symbol: '"~name~"'");
	immutable symbol = _symbol(name);
}

private Symbol _symbol(string name)
{
	return Symbol(name);
}

/// This only represents terminals. Nonterminals aren't
/// constructed since the AST is directly built during parsing.
///
/// You can't create a Symbol directly. Instead, use the 'symbol'
/// template above.
struct Symbol
{
	private string _name;
	@property string name() ///.
	{
		return _name;
	}
	
	@disable this();
	private this(string name) ///.
	{
		this._name = name;
	}

	///.
	string toString()
	{
		return _name;
	}
}
