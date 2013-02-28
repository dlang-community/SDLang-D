// SDLang-D
// Written in the D programming language.

/++
SDLang-D v0.8.1: Library for parsing SDL (Simple Declarative Language).

Import this module to use SDLang-D as a library.

This should work with DMD 2.061 and up.

Homepage: http://github.com/Abscissa/SDLang-D
API:      http://semitwist.com/sdlang-d-api
SDL:      http://sdl.ikayzo.org/display/SDL/Language+Guide

Authors: Nick Sabalausky ("Abscissa") http://semitwist.com/contact
+/

module sdlang;

import std.array;
import std.datetime;
import std.file;
import std.stdio;

import sdlang_.ast;
import sdlang_.exception;
import sdlang_.lexer;
import sdlang_.parser;
import sdlang_.symbol;
import sdlang_.token;
import sdlang_.util;

// Expose main public API
public import sdlang_.ast       : Attribute, Tag;
public import sdlang_.exception : SDLangException;
public import sdlang_.parser    : parseFile, parseSource;
public import sdlang_.token     : Value, Token, DateTimeFrac, DateTimeFracUnknownZone;
public import sdlang_.util      : sdlangVersion, Location;

version(SDLang_Unittest)
	void main() {}

version(SDLang_TestApp)
{
	int main(string[] args)
	{
		if(args.length != 3 || (args[1] != "lex" && args[1] != "parse"))
		{
			stderr.writeln("SDLang-D v", sdlangVersion);
			stderr.writeln("Usage: sdlang [lex|parse] filename.sdl");
			return 1;
		}
		
		auto filename = args[2];

		try
		{
			if(args[1] == "lex")
				doLex(filename);
			else
				doParse(filename);
		}
		catch(SDLangException e)
		{
			stderr.writeln(e.msg);
			return 1;
		}
		
		return 0;
	}

	void doLex(string filename)
	{
		auto source = cast(string)read(filename);
		auto lexer = new Lexer(source, filename);
		
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

	void doParse(string filename)
	{
		auto root = parseFile(filename);
		stdout.rawWrite(root.toDebugString());
		writeln();
	}
}
