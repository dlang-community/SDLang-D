// SDLang-D
// Written in the D programming language.

module sdlang.token;

import std.array;
import std.base64;
import std.conv;
import std.datetime;
import std.meta;
import std.range;
import std.string;
import std.traits;
import std.typetuple;
import std.variant;

import sdlang.exception;
import sdlang.symbol;
import sdlang.util;

/// DateTime doesn't support milliseconds, but SDLang's "Date Time" type does.
/// So this is needed for any SDL "Date Time" that doesn't include a time zone.
struct DateTimeFrac
{
	DateTime dateTime;
	Duration fracSecs;
	static if(is(FracSec)) {
	    deprecated("Use fracSecs instead.") {
		@property FracSec fracSec() const { return FracSec.from!"hnsecs"(fracSecs.total!"hnsecs"); }
		@property void fracSec(FracSec v) { fracSecs = v.hnsecs.hnsecs; }
	    }
	}
}

/++
If a "Date Time" literal in the SDL file has a time zone that's not found in
your system, you get one of these instead of a SysTime. (Because it's
impossible to indicate "unknown time zone" with `std.datetime.TimeZone`.)

The difference between this and `DateTimeFrac` is that `DateTimeFrac`
indicates that no time zone was specified in the SDL at all, whereas
`DateTimeFracUnknownZone` indicates that a time zone was specified but
data for it could not be found on your system.
+/
struct DateTimeFracUnknownZone
{
	DateTime dateTime;
	Duration fracSecs;
	static if(is(FracSec)) {
	    deprecated("Use fracSecs instead.") {
		@property FracSec fracSec() const { return FracSec.from!"hnsecs"(fracSecs.total!"hnsecs"); }
		@property void fracSec(FracSec v) { fracSecs = v.hnsecs.hnsecs; }
	    }
	}
	string timeZone;

	bool opEquals(const DateTimeFracUnknownZone b) const
	{
		return opEquals(b);
	}
	bool opEquals(ref const DateTimeFracUnknownZone b) const
	{
		return
			this.dateTime == b.dateTime &&
			this.fracSecs  == b.fracSecs  &&
			this.timeZone == b.timeZone;
	}
}

/++
SDLang's datatypes map to D's datatypes as described below.
Most are straightforward, but take special note of the date/time-related types.

---------------------------------------------------------------
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
---------------------------------------------------------------
+/
alias ValueTypes = TypeTuple!(
	bool,
	string, dchar,
	int, long,
	float, double, real,
	Date, DateTimeFrac, SysTime, DateTimeFracUnknownZone, Duration,
	ubyte[],
	typeof(null),
);

alias Value = Algebraic!( ValueTypes ); ///ditto
enum isValueType(T) = staticIndexOf!(T, ValueTypes) != -1;

enum isSink(T) =
	isOutputRange!T &&
	is(ElementType!(T)[] == string);

string toSDLString(T)(T value) if(is(T==Value) || isValueType!T)
{
	Appender!string sink;
	toSDLString(value, sink);
	return sink.data;
}

/// Throws SDLangException if value is infinity, -infinity or NaN, because
/// those are not currently supported by the SDLang spec.
void toSDLString(Sink)(Value value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	foreach(T; ValueTypes)
	{
		if(value.type == typeid(T))
		{
			toSDLString( value.get!T(), sink );
			return;
		}
	}
	
	throw new Exception("Internal SDLang-D error: Unhandled type of Value. Contains: "~value.toString());
}

@("toSDLString on infinity and NaN")
unittest
{
	import std.exception;
	
	auto floatInf    = float.infinity;
	auto floatNegInf = -float.infinity;
	auto floatNaN    = float.nan;

	auto doubleInf    = double.infinity;
	auto doubleNegInf = -double.infinity;
	auto doubleNaN    = double.nan;

	auto realInf    = real.infinity;
	auto realNegInf = -real.infinity;
	auto realNaN    = real.nan;

	assertNotThrown( toSDLString(0.0F) );
	assertNotThrown( toSDLString(0.0)  );
	assertNotThrown( toSDLString(0.0L) );
	
	assertThrown!ValidationException( toSDLString(floatInf) );
	assertThrown!ValidationException( toSDLString(floatNegInf) );
	assertThrown!ValidationException( toSDLString(floatNaN) );

	assertThrown!ValidationException( toSDLString(doubleInf) );
	assertThrown!ValidationException( toSDLString(doubleNegInf) );
	assertThrown!ValidationException( toSDLString(doubleNaN) );

	assertThrown!ValidationException( toSDLString(realInf) );
	assertThrown!ValidationException( toSDLString(realNegInf) );
	assertThrown!ValidationException( toSDLString(realNaN) );
	
	assertThrown!ValidationException( toSDLString(Value(floatInf)) );
	assertThrown!ValidationException( toSDLString(Value(floatNegInf)) );
	assertThrown!ValidationException( toSDLString(Value(floatNaN)) );

	assertThrown!ValidationException( toSDLString(Value(doubleInf)) );
	assertThrown!ValidationException( toSDLString(Value(doubleNegInf)) );
	assertThrown!ValidationException( toSDLString(Value(doubleNaN)) );

	assertThrown!ValidationException( toSDLString(Value(realInf)) );
	assertThrown!ValidationException( toSDLString(Value(realNegInf)) );
	assertThrown!ValidationException( toSDLString(Value(realNaN)) );
}

void toSDLString(Sink)(typeof(null) value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put("null");
}

void toSDLString(Sink)(bool value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put(value? "true" : "false");
}

//TODO: Figure out how to properly handle strings/chars containing lineSep or paraSep
void toSDLString(Sink)(string value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put('"');
	
	// This loop is UTF-safe
	foreach(char ch; value)
	{
		if     (ch == '\n') sink.put(`\n`);
		else if(ch == '\r') sink.put(`\r`);
		else if(ch == '\t') sink.put(`\t`);
		else if(ch == '\"') sink.put(`\"`);
		else if(ch == '\\') sink.put(`\\`);
		else
			sink.put(ch);
	}

	sink.put('"');
}

void toSDLString(Sink)(dchar value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put('\'');
	
	if     (value == '\n') sink.put(`\n`);
	else if(value == '\r') sink.put(`\r`);
	else if(value == '\t') sink.put(`\t`);
	else if(value == '\'') sink.put(`\'`);
	else if(value == '\\') sink.put(`\\`);
	else
		sink.put(value);

	sink.put('\'');
}

void toSDLString(Sink)(int value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put( "%s".format(value) );
}

void toSDLString(Sink)(long value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put( "%sL".format(value) );
}

private void checkUnsupportedFloatingPoint(T)(T value) if(isFloatingPoint!T)
{
	import std.exception;
	import std.math;
	
	enforce!ValidationException(
		!isInfinity(value),
		"SDLang does not currently support infinity for floating-point types"
	);

	enforce!ValidationException(
		!isNaN(value),
		"SDLang does not currently support NaN for floating-point types"
	);
}

private string trimmedDecimal(string str)
{
	Appender!string sink;
	trimmedDecimal(str, sink);
	return sink.data;
}

private void trimmedDecimal(Sink)(string str, ref Sink sink) if(isOutputRange!(Sink,char))
{
	// Special case
	if(str == ".")
	{
		sink.put("0");
		return;
	}

	for(auto i=str.length-1; i>0; i--)
	{
		if(str[i] == '.')
		{
			// Trim up to here, PLUS trim trailing '.'
			sink.put(str[0..i]);
			return;
		}
		else if(str[i] != '0')
		{
			// Trim up to here
			sink.put(str[0..i+1]);
			return;
		}
	}
	
	// Nothing to trim
	sink.put(str);
}

@("trimmedDecimal")
unittest
{
	assert(trimmedDecimal("123.456000") == "123.456");
	assert(trimmedDecimal("123.456")    == "123.456");
	assert(trimmedDecimal("123.000")    == "123");
	assert(trimmedDecimal("123.0")      == "123");
	assert(trimmedDecimal("123.")       == "123");
	assert(trimmedDecimal("123")        == "123");
	assert(trimmedDecimal("1.")         == "1");
	assert(trimmedDecimal("1")          == "1");
	assert(trimmedDecimal("0")          == "0");
	assert(trimmedDecimal(".")          == "0");
}

void toSDLString(Sink)(float value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	checkUnsupportedFloatingPoint(value);
	"%.10f".format(value).trimmedDecimal(sink);
	sink.put("F");
}

void toSDLString(Sink)(double value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	checkUnsupportedFloatingPoint(value);
	"%.30f".format(value).trimmedDecimal(sink);
	sink.put("D");
}

void toSDLString(Sink)(real value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	checkUnsupportedFloatingPoint(value);
	"%.90f".format(value).trimmedDecimal(sink);
	sink.put("BD");
}

// Regression test: Issue #50
@("toSDLString: No scientific notation")
unittest
{
	import std.algorithm, sdlang.parser;
	auto tag = parseSource(`
	foo \
		420000000000000000000f \
		42000000000000000000000000000000000000d \
		420000000000000000000000000000000000000000000000000000000000000bd \
	`).getTag("foo");
	import std.stdio;
	writeln(tag.values[0].toSDLString);
	writeln(tag.values[1].toSDLString);
	writeln(tag.values[2].toSDLString);
	
	assert(!tag.values[0].toSDLString.canFind("+"));
	assert(!tag.values[0].toSDLString.canFind("-"));
	
	assert(!tag.values[1].toSDLString.canFind("+"));
	assert(!tag.values[1].toSDLString.canFind("-"));
	
	assert(!tag.values[2].toSDLString.canFind("+"));
	assert(!tag.values[2].toSDLString.canFind("-"));
}

void toSDLString(Sink)(Date value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put(to!string(value.year));
	sink.put('/');
	sink.put(to!string(cast(int)value.month));
	sink.put('/');
	sink.put(to!string(value.day));
}

void toSDLString(Sink)(DateTimeFrac value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	toSDLString(value.dateTime.date, sink);
	sink.put(' ');
	sink.put("%.2s".format(value.dateTime.hour));
	sink.put(':');
	sink.put("%.2s".format(value.dateTime.minute));
	
	if(value.dateTime.second != 0)
	{
		sink.put(':');
		sink.put("%.2s".format(value.dateTime.second));
	}

	if(value.fracSecs != 0.msecs)
	{
		sink.put('.');
		sink.put("%.3s".format(value.fracSecs.total!"msecs"));
	}
}

void toSDLString(Sink)(SysTime value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	auto dateTimeFrac = DateTimeFrac(cast(DateTime)value, value.fracSecs);
	toSDLString(dateTimeFrac, sink);
	
	sink.put("-");
	
	auto tzString = value.timezone.name;
	
	// If name didn't exist, try abbreviation.
	// Note that according to std.datetime docs, on Windows the
	// stdName/dstName may not be properly abbreviated.
	version(Windows) {} else
	if(tzString == "")
	{
		auto tz = value.timezone;
		auto stdTime = value.stdTime;
		
		if(tz.hasDST())
			tzString = tz.dstInEffect(stdTime)? tz.dstName : tz.stdName;
		else
			tzString = tz.stdName;
	}
	
	if(tzString == "")
	{
		auto offset = value.timezone.utcOffsetAt(value.stdTime);
		sink.put("GMT");

		if(offset < seconds(0))
		{
			sink.put("-");
			offset = -offset;
		}
		else
			sink.put("+");
		
		sink.put("%.2s".format(offset.split.hours));
		sink.put(":");
		sink.put("%.2s".format(offset.split.minutes));
	}
	else
		sink.put(tzString);
}

void toSDLString(Sink)(DateTimeFracUnknownZone value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	auto dateTimeFrac = DateTimeFrac(value.dateTime, value.fracSecs);
	toSDLString(dateTimeFrac, sink);
	
	sink.put("-");
	sink.put(value.timeZone);
}

void toSDLString(Sink)(Duration value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	if(value < seconds(0))
	{
		sink.put("-");
		value = -value;
	}
	
	auto days = value.total!"days"();
	if(days != 0)
	{
		sink.put("%s".format(days));
		sink.put("d:");
	}

	sink.put("%.2s".format(value.split.hours));
	sink.put(':');
	sink.put("%.2s".format(value.split.minutes));
	sink.put(':');
	sink.put("%.2s".format(value.split.seconds));

	if(value.split.msecs != 0)
	{
		sink.put('.');
		sink.put("%.3s".format(value.split.msecs));
	}
}

void toSDLString(Sink)(ubyte[] value, ref Sink sink) if(isOutputRange!(Sink,char))
{
	sink.put('[');
	sink.put( Base64.encode(value) );
	sink.put(']');
}

/// This only represents terminals. Nonterminals aren't
/// constructed since the AST is directly built during parsing.
struct Token
{
	Symbol symbol = sdlang.symbol.symbol!"Error"; /// The "type" of this token
	Location[2] range;
	Value value; /// Only valid when `symbol` is `symbol!"Value"`, otherwise null
	string data; /// Original text from source

	@disable this();
	this(Symbol symbol, Location[2] range, Value value=Value(null), string data=null)
	{
		this.symbol   = symbol;
		this.range    = range;
		this.value    = value;
		this.data     = data;
	}
	
	/// Tokens with differing symbols are always unequal.
	/// Tokens with differing values are always unequal.
	/// Tokens with differing Value types are always unequal.
	/// Member `location` is always ignored for comparison.
	/// Member `data` is ignored for comparison *EXCEPT* when the symbol is Ident.
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
		
		if(this.symbol == .symbol!"Ident"
			|| this.symbol == .symbol!"EOL")
			return this.data == b.data;
		
		return true;
	}
	
	bool matches(string symbolName)()
	{
		return this.symbol == .symbol!symbolName;
	}

	deprecated("Access `range[0]` instead")
	inout(Location) location() inout pure nothrow @nogc @safe
	{
		return range[0];
	}

	string toRawString()
	{
		import std.conv : to;

		return text("Token(`", symbol, "`, [",
			range[0].toRawString, " .. ", range[1].toRawString,
			"], ", value, ", ", [data].to!string[1 .. $ - 1], ")");
	}
}

@("sdlang token")
unittest
{
	Location[2] loc  = (Location[2]).init;
	Location[2] loc2 = [Location.init, Location("a", 1, 1, 1)];

	assert(Token(symbol!"EOL",loc) == Token(symbol!"EOL",loc ));
	assert(Token(symbol!"EOL",loc) == Token(symbol!"EOL",loc2));
	assert(Token(symbol!":",  loc) == Token(symbol!":",  loc ));
	assert(Token(symbol!"EOL",loc) != Token(symbol!":",  loc ));
	assert(Token(symbol!"EOL",loc,Value(null),"\n") == Token(symbol!"EOL",loc,Value(null),"\n"));

	assert(Token(symbol!"EOL",loc,Value(null),"\n") != Token(symbol!"EOL",loc,Value(null),";" ));
	assert(Token(symbol!"EOL",loc,Value(null),"A" ) != Token(symbol!"EOL",loc,Value(null),"B" ));
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

@("sdlang Value.toSDLString()")
unittest
{
	// Bool and null
	assert(Value(null ).toSDLString() == "null");
	assert(Value(true ).toSDLString() == "true");
	assert(Value(false).toSDLString() == "false");
	
	// Base64 Binary
	assert(Value(cast(ubyte[])"hello world".dup).toSDLString() == "[aGVsbG8gd29ybGQ=]");

	// Integer
	assert(Value(cast( int) 7).toSDLString() ==  "7");
	assert(Value(cast( int)-7).toSDLString() == "-7");
	assert(Value(cast( int) 0).toSDLString() ==  "0");

	assert(Value(cast(long) 7).toSDLString() ==  "7L");
	assert(Value(cast(long)-7).toSDLString() == "-7L");
	assert(Value(cast(long) 0).toSDLString() ==  "0L");

	// Floating point
	import std.stdio;
	writeln(1.5f);
	writeln(Value(cast(float) 1.5).toSDLString());
	assert(Value(cast(float) 1.5).toSDLString() ==  "1.5F");
	assert(Value(cast(float)-1.5).toSDLString() == "-1.5F");
	assert(Value(cast(float)   0).toSDLString() ==    "0F");
	assert(Value(cast(float)0.25).toSDLString() == "0.25F");

	assert(Value(cast(double) 1.5).toSDLString() ==  "1.5D");
	assert(Value(cast(double)-1.5).toSDLString() == "-1.5D");
	assert(Value(cast(double)   0).toSDLString() ==    "0D");
	assert(Value(cast(double)0.25).toSDLString() == "0.25D");

	assert(Value(cast(real) 1.5).toSDLString() ==  "1.5BD");
	assert(Value(cast(real)-1.5).toSDLString() == "-1.5BD");
	assert(Value(cast(real)   0).toSDLString() ==    "0BD");
	assert(Value(cast(real)0.25).toSDLString() == "0.25BD");

	// String
	assert(Value("hello"  ).toSDLString() == `"hello"`);
	assert(Value(" hello ").toSDLString() == `" hello "`);
	assert(Value(""       ).toSDLString() == `""`);
	assert(Value("hello \r\n\t\"\\ world").toSDLString() == `"hello \r\n\t\"\\ world"`);
	assert(Value("日本語").toSDLString() == `"日本語"`);

	// Chars
	assert(Value(cast(dchar) 'A').toSDLString() ==  `'A'`);
	assert(Value(cast(dchar)'\r').toSDLString() == `'\r'`);
	assert(Value(cast(dchar)'\n').toSDLString() == `'\n'`);
	assert(Value(cast(dchar)'\t').toSDLString() == `'\t'`);
	assert(Value(cast(dchar)'\'').toSDLString() == `'\''`);
	assert(Value(cast(dchar)'\\').toSDLString() == `'\\'`);
	assert(Value(cast(dchar) '月').toSDLString() ==  `'月'`);

	// Date
	assert(Value(Date( 2004,10,31)).toSDLString() == "2004/10/31");
	assert(Value(Date(-2004,10,31)).toSDLString() == "-2004/10/31");

	// DateTimeFrac w/o Frac
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15))).toSDLString() == "2004/10/31 14:30:15");
	assert(Value(DateTimeFrac(DateTime(2004,10,31,   1, 2, 3))).toSDLString() == "2004/10/31 01:02:03");
	assert(Value(DateTimeFrac(DateTime(-2004,10,31, 14,30,15))).toSDLString() == "-2004/10/31 14:30:15");

	// DateTimeFrac w/ Frac
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15), 123.msecs)).toSDLString() == "2004/10/31 14:30:15.123");
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15), 120.msecs)).toSDLString() == "2004/10/31 14:30:15.120");
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15), 100.msecs)).toSDLString() == "2004/10/31 14:30:15.100");
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15),  12.msecs)).toSDLString() == "2004/10/31 14:30:15.012");
	assert(Value(DateTimeFrac(DateTime(2004,10,31,  14,30,15),   1.msecs)).toSDLString() == "2004/10/31 14:30:15.001");
	assert(Value(DateTimeFrac(DateTime(-2004,10,31, 14,30,15), 123.msecs)).toSDLString() == "-2004/10/31 14:30:15.123");

	// DateTimeFracUnknownZone
	assert(Value(DateTimeFracUnknownZone(DateTime(2004,10,31, 14,30,15), 123.msecs, "Foo/Bar")).toSDLString() == "2004/10/31 14:30:15.123-Foo/Bar");

	// SysTime
	assert(Value(SysTime(DateTime(2004,10,31, 14,30,15), new immutable SimpleTimeZone( hours(0)             ))).toSDLString() == "2004/10/31 14:30:15-GMT+00:00");
	assert(Value(SysTime(DateTime(2004,10,31,  1, 2, 3), new immutable SimpleTimeZone( hours(0)             ))).toSDLString() == "2004/10/31 01:02:03-GMT+00:00");
	assert(Value(SysTime(DateTime(2004,10,31, 14,30,15), new immutable SimpleTimeZone( hours(2)+minutes(10) ))).toSDLString() == "2004/10/31 14:30:15-GMT+02:10");
	assert(Value(SysTime(DateTime(2004,10,31, 14,30,15), new immutable SimpleTimeZone(-hours(5)-minutes(30) ))).toSDLString() == "2004/10/31 14:30:15-GMT-05:30");
	assert(Value(SysTime(DateTime(2004,10,31, 14,30,15), new immutable SimpleTimeZone( hours(2)+minutes( 3) ))).toSDLString() == "2004/10/31 14:30:15-GMT+02:03");
	assert(Value(SysTime(DateTime(2004,10,31, 14,30,15), 123.msecs, new immutable SimpleTimeZone( hours(0) ))).toSDLString() == "2004/10/31 14:30:15.123-GMT+00:00");

	// Duration
	assert( "12:14:42"         == Value( days( 0)+hours(12)+minutes(14)+seconds(42)+msecs(  0)).toSDLString());
	assert("-12:14:42"         == Value(-days( 0)-hours(12)-minutes(14)-seconds(42)-msecs(  0)).toSDLString());
	assert( "00:09:12"         == Value( days( 0)+hours( 0)+minutes( 9)+seconds(12)+msecs(  0)).toSDLString());
	assert( "00:00:01.023"     == Value( days( 0)+hours( 0)+minutes( 0)+seconds( 1)+msecs( 23)).toSDLString());
	assert( "23d:05:21:23.532" == Value( days(23)+hours( 5)+minutes(21)+seconds(23)+msecs(532)).toSDLString());
	assert( "23d:05:21:23.530" == Value( days(23)+hours( 5)+minutes(21)+seconds(23)+msecs(530)).toSDLString());
	assert( "23d:05:21:23.500" == Value( days(23)+hours( 5)+minutes(21)+seconds(23)+msecs(500)).toSDLString());
	assert("-23d:05:21:23.532" == Value(-days(23)-hours( 5)-minutes(21)-seconds(23)-msecs(532)).toSDLString());
	assert("-23d:05:21:23.500" == Value(-days(23)-hours( 5)-minutes(21)-seconds(23)-msecs(500)).toSDLString());
	assert( "23d:05:21:23"     == Value( days(23)+hours( 5)+minutes(21)+seconds(23)+msecs(  0)).toSDLString());
}
