/// SDLang-D
/// Written in the D programming language.

/++
Library for parsing SDL (Simple Declarative Language).
SDL: http://sdl.ikayzo.org/display/SDL/Language+Guide

Author:
$(WEB www.semitwist.com, Nick Sabalausky)

This should work with DMD 2.061 and up.

To compile manually:
	rdmd --build-only -Isrc -ofbin/sdlang [dmd/rdmd options] src/sdlang.d

You can also compile with stbuild (part of SemiTwist D Tools):
	semitwist-stbuild all [release|debug|all]

	Installation instructions for SemiTwist D Tools are here:
		http://semitwist.com/goldie/Start/Install/
+/

module sdlang;

import std.array;
import std.datetime;
import std.file;
import std.stdio;

import sdlang_impl.exception;
import sdlang_impl.lexer;
import sdlang_impl.symbol;
import sdlang_impl.token;

int main(string[] args)
{
	if(args.length != 2)
	{
		stderr.writeln("Usage: sdlang filename.sdl");
		return 1;
	}
	
	auto filename = args[1];
	auto source = cast(string)read(filename);

	Lexer lexer;
	try
	{
		lexer = new Lexer(source, filename);
		
		foreach(tok; lexer)
		{
			// Value
			string value;
			if(tok.symbol == symbol!"Value")
				value = tok.value.hasValue? toString(tok.value.type) : "{null}";
			
			value = value==""? "\t" : "("~value~":"~tok.value.toString()~") ";

			// Data
			auto data = tok.data.replace("\n", "").replace("\r", "");
			if(data != "")
				data = "\t|"~tok.data~"|";
			
			// Display
			writeln(
				tok.location.toString, ":\t",
				tok.symbol.name, value,
				data
			);
			
			if(tok.symbol.name == "Error")
				break;
		}
	}
	catch(SDLangException e)
	{
		stderr.writeln(e.msg);
		return 1;
	}

	return 0;
}

string toString(TypeInfo ti)
{
	if     (ti == typeid( bool         )) return "bool";
	else if(ti == typeid( string       )) return "string";
	else if(ti == typeid( dchar        )) return "dchar";
	else if(ti == typeid( int          )) return "int";
	else if(ti == typeid( long         )) return "long";
	else if(ti == typeid( float        )) return "float";
	else if(ti == typeid( double       )) return "double";
	else if(ti == typeid( real         )) return "real";
	else if(ti == typeid( Date         )) return "Date";
	else if(ti == typeid( DateTimeFrac )) return "DateTimeFrac";
	else if(ti == typeid( SysTime      )) return "SysTime";
	else if(ti == typeid( Duration     )) return "Duration";
	else if(ti == typeid( ubyte[]      )) return "ubyte[]";
	else if(ti == typeid( typeof(null) )) return "null";
	
	return "{unknown}";
}
