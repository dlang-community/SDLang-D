/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.token;

import std.datetime;
import std.variant;

import sdlang_impl.symbol;
import sdlang_impl.util;

///.
alias Algebraic!(
	bool,
	string, dchar,
	int, long,
	float, double, real,
	Date, DateTime, Duration,
	void[],
	typeof(null),
) Value;

/// This only represents terminals. Nonterminals aren't
/// constructed since the AST is directly built during parsing.
struct Token
{
	Symbol symbol = sdlang_impl.symbol.symbol!"Error"; /// The "type" of this token
	Location location;
	Value value; /// Only valid when 'symbol' is symbol!"Value", otherwise null
	string data; /// Original text from source

	@disable this();
	this(Symbol symbol, Location location) ///.
	{
		this.symbol   = symbol;
		this.location = location;
	}
}
