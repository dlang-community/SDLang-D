// SDLang-D
// Written in the D programming language.

module sdlang_.token;

import std.array;
import std.base64;
import std.conv;
import std.datetime;
import std.string;
import std.variant;

import sdlang_.symbol;
import sdlang_.util;

/// DateTime doesn't support milliseconds, but SDL's "Date Time" type does.
/// So this is needed for any SDL "Date Time" that doesn't include a time zone.
struct DateTimeFrac
{
	DateTime dateTime;
	FracSec fracSec;
}

/++
If a "Date Time" literal in the SDL file has a time zone that's not found in
your system, you get one of these instead of a SysTime. (Because it's
impossible to indicate "unknown time zone" with 'std.datetime.TimeZone'.)

The difference between this and 'DateTimeFrac' is that 'DateTimeFrac'
indicates that no time zone was specified in the SDL at all, whereas
'DateTimeFracUnknownZone' indicates that a time zone was specified but
data for it could not be found on your system.
+/
struct DateTimeFracUnknownZone
{
	DateTime dateTime;
	FracSec fracSec;
	string timeZone;

	bool opEquals(const DateTimeFracUnknownZone b) const
	{
		return opEquals(b);
	}
	bool opEquals(ref const DateTimeFracUnknownZone b) const
	{
		return
			this.dateTime == b.dateTime &&
			this.fracSec  == b.fracSec  &&
			this.timeZone == b.timeZone;
	}
}

/++
SDL's datatypes map to D's datatypes as described below.
Most are straightforward, but take special note of the date/time-related types.

Boolean:                       bool
Null:                          typeof(null)
Unicode Character:             dchar
Double-Quote Unicode String:   string
Raw Backtick Unicode String:   string
Integer (32 bits signed):      int
Long Integer (64 bits signed): long
Float (32 bits signed):        float
Double Float (64 bits signed): double
Decimal (128+ bits signed):    real
Binary (standard Base64):      ubyte[]
Time Span:                     Duration

Date (with no time at all):           Date
Date Time (no timezone):              DateTimeFrac
Date Time (with a known timezone):    SysTime
Date Time (with an unknown timezone): DateTimeFracUnknownZone
+/
alias Algebraic!(
	bool,
	string, dchar,
	int, long,
	float, double, real,
	Date, DateTimeFrac, SysTime, DateTimeFracUnknownZone, Duration,
	ubyte[],
	typeof(null),
) Value;

//TODO: Figure out how to properly handle strings/chars containing lineSep or paraSep
string toSDLString(Value value)
{
	if(value.type == typeid(typeof(null)))
		return "null";

	else if(value.type == typeid(bool))
		return value.get!bool()? "true" : "false";

	else if(value.type == typeid(string))
	{
		Appender!string buf;
		auto str = value.get!string();
		
		buf.put('"');
		
		// This loop is UTF-safe
		foreach(char ch; str)
		{
			if     (ch == '\n') buf.put(`\n`);
			else if(ch == '\r') buf.put(`\r`);
			else if(ch == '\t') buf.put(`\t`);
			else if(ch == '\"') buf.put(`\"`);
			else if(ch == '\\') buf.put(`\\`);
			else
				buf.put(ch);
		}

		buf.put('"');
		return buf.data;
	}

	else if(value.type == typeid(dchar))
	{
		Appender!string buf;
		auto ch = value.get!dchar();
		
		buf.put('\'');
		
		if     (ch == '\n') buf.put(`\n`);
		else if(ch == '\r') buf.put(`\r`);
		else if(ch == '\t') buf.put(`\t`);
		else if(ch == '\'') buf.put(`\'`);
		else if(ch == '\\') buf.put(`\\`);
		else
			buf.put(ch);

		buf.put('\'');
		return buf.data;
	}

	else if(value.type == typeid(int))
		return "%s".format(value.get!int());
	
	else if(value.type == typeid(long))
		return "%sL".format(value.get!long());

	else if(value.type == typeid(float))
		return "%.30sF".format(value.get!float());
		
	else if(value.type == typeid(double))
		return "%.30sD".format(value.get!double());

	else if(value.type == typeid(real))
		return "%.30sBD".format(value.get!real());

	else if(value.type == typeid(Date))
	{
	
	}
	else if(value.type == typeid(DateTimeFrac))
	{
	
	}
	else if(value.type == typeid(SysTime))
	{
	
	}
	else if(value.type == typeid(DateTimeFracUnknownZone))
	{
	
	}
	else if(value.type == typeid(Duration))
	{
	
	}
	else if(value.type == typeid(ubyte[]))
	{
		Appender!string buf;

		buf.put('[');
		buf.put( Base64.encode(value.get!(ubyte[])) );
		buf.put(']');

		return buf.data;
	}

	throw new Exception("Internal SDLang-D error: Unhandled value type: "~to!string(value.type));
}

/// This only represents terminals. Nonterminals aren't
/// constructed since the AST is directly built during parsing.
struct Token
{
	Symbol symbol = sdlang_.symbol.symbol!"Error"; /// The "type" of this token
	Location location;
	Value value; /// Only valid when 'symbol' is symbol!"Value", otherwise null
	string data; /// Original text from source

	@disable this();
	this(Symbol symbol, Location location, Value value=Value(null), string data=null)
	{
		this.symbol   = symbol;
		this.location = location;
		this.value    = value;
		this.data     = data;
	}
	
	/// Tokens with differing symbols are always unequal.
	/// Tokens with differing values are always unequal.
	/// Tokens with differing Value types are always unequal.
	/// Member 'location' is always ignored for comparison.
	/// Member 'data' is ignored for comparison *EXCEPT* when the symbol is Ident.
	bool opEquals(Token b)
	{
		return opEquals(b);
	}
	bool opEquals(ref Token b) ///ditto
	{
		if(
			this.symbol     != b.symbol     ||
			this.value.type != b.value.type ||
			this.value      != b.value
		)
			return false;
		
		if(this.symbol == .symbol!"Ident")
			return this.data == b.data;
		
		return true;
	}
	
	bool matches(string symbolName)()
	{
		return this.symbol == .symbol!symbolName;
	}
}

version(SDLang_Unittest)
unittest
{
	import std.stdio;
	writeln("Unittesting sdlang token...");
	stdout.flush();
	
	auto loc  = Location("", 0, 0, 0);
	auto loc2 = Location("a", 1, 1, 1);

	assert(Token(symbol!"EOL",loc) == Token(symbol!"EOL",loc ));
	assert(Token(symbol!"EOL",loc) == Token(symbol!"EOL",loc2));
	assert(Token(symbol!":",  loc) == Token(symbol!":",  loc ));
	assert(Token(symbol!"EOL",loc) != Token(symbol!":",  loc ));
	assert(Token(symbol!"EOL",loc,Value(null),"\n") == Token(symbol!"EOL",loc,Value(null),"\n"));

	assert(Token(symbol!"EOL",loc,Value(null),"\n") == Token(symbol!"EOL",loc,Value(null),";" ));
	assert(Token(symbol!"EOL",loc,Value(null),"A" ) == Token(symbol!"EOL",loc,Value(null),"B" ));
	assert(Token(symbol!":",  loc,Value(null),"A" ) == Token(symbol!":",  loc,Value(null),"BB"));
	assert(Token(symbol!"EOL",loc,Value(null),"A" ) != Token(symbol!":",  loc,Value(null),"A" ));

	assert(Token(symbol!"Ident",loc,Value(null),"foo") == Token(symbol!"Ident",loc,Value(null),"foo"));
	assert(Token(symbol!"Ident",loc,Value(null),"foo") != Token(symbol!"Ident",loc,Value(null),"BAR"));

	assert(Token(symbol!"Value",loc,Value(null),"foo") == Token(symbol!"Value",loc, Value(null),"foo"));
	assert(Token(symbol!"Value",loc,Value(null),"foo") == Token(symbol!"Value",loc2,Value(null),"foo"));
	assert(Token(symbol!"Value",loc,Value(null),"foo") == Token(symbol!"Value",loc, Value(null),"BAR"));
	assert(Token(symbol!"Value",loc,Value(   7),"foo") == Token(symbol!"Value",loc, Value(   7),"BAR"));
	assert(Token(symbol!"Value",loc,Value(   7),"foo") != Token(symbol!"Value",loc, Value( "A"),"foo"));
	assert(Token(symbol!"Value",loc,Value(   7),"foo") != Token(symbol!"Value",loc, Value(   2),"foo"));
	assert(Token(symbol!"Value",loc,Value(cast(int)7)) != Token(symbol!"Value",loc, Value(cast(long)7)));
	assert(Token(symbol!"Value",loc,Value(cast(float)1.2)) != Token(symbol!"Value",loc, Value(cast(double)1.2)));
}
