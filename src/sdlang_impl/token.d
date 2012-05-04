/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.token;

import std.datetime;
import std.variant;

import sdlang_impl.symbol;

///.
alias Algebraic!(
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
	Symbol symbol; /// The "type" of this token
	Value value; /// Only valid when 'symbol' is symbol!"Value", otherwise null
	string data; /// Original text from source
	int line; /// Zero-indexed
	int col;  /// Zero-indexed, Tab counts as 1

	@disable this();
	this(Symbol symbol) ///.
	{
		this.symbol = symbol;
		value = null;
	}
}
