/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.parser;

import std.file;

import sdlang_impl.ast;
import sdlang_impl.exception;
import sdlang_impl.lexer;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

version(SDLang_TraceParse)
{
	import std.stdio;

	private void trace(string file=__FILE__, size_t line=__LINE__, TArgs...)(TArgs args)
	{
		writeln(file, "(", line, "): ", args);
		stdout.flush();
	}
}

/// Returns root tag
Tag!extraInfo parseFile(ExtraInfo extraInfo = ExtraInfo.Locations)(string filename)
{
	auto source = cast(string)read(filename);
	return parseSource(source, filename);
}

/// Returns root tag
Tag!extraInfo parseSource(ExtraInfo extraInfo = ExtraInfo.Locations)(string source, string filename=null)
{
	auto lexer = new Lexer(source, filename);
	auto parser = Parser!extraInfo(lexer);
	return parser.parseRoot();
}

private struct Parser(ExtraInfo extras)
{
	Lexer lexer;
	
	private struct IDFull
	{
		string namespace;
		string name;
	}
	
	private void error(string msg)
	{
		error(lexer.front.location, msg);
	}

	private void error(Location loc, string msg)
	{
		throw new SDLangException(loc, "Error: "~msg);
	}

	/// <Root> ::= <Tags>  (Lookaheads: Anything)
	Tag!extras parseRoot()
	{
		version(SDLang_TraceParse)
			trace("Starting parse of file: ", lexer.filename);

		auto root = new Tag!extras(null, null, "root");

		static if(extras.atLeast(ExtraInfo.Locations))
			root.location = Location(lexer.filename, 0, 0, 0);

		parseTags(root);
		return root;
	}

	/// <Tags> ::= <Tag> <Tags>  (Lookaheads: Ident Value)
	///        |   EOL   <Tags>  (Lookaheads: EOL)
	///        |   {empty}       (Lookaheads: Anything else)
	void parseTags(ref Tag!extras parent)
	{
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Ident"() || token.matches!"Value"())
			{
				parseTag(parent);
				continue;
			}
			else if(token.matches!"EOL"())
			{
				lexer.popFront();
				continue;
			}
			else
				break;
		}
	}

	/// <Tag>
	///     ::= <IDFull> <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Ident)
	///     |   <Value>  <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Value)
	void parseTag(ref Tag!extras parent)
	{
		auto token = lexer.front;
		Tag!extras tag;
		
		if(token.matches!"Ident"())
		{
			auto id = parseIDFull();
			tag = new Tag!extras(parent, id.namespace, id.name);

			version(SDLang_TraceParse)
				trace("Found tag named: ", tag.fullName);
		}
		else if(token.matches!"Value"())
		{
			tag = new Tag!extras(parent);
			parseValue(tag);

			version(SDLang_TraceParse)
				trace("Found anonymous tag.");
		}
		else
			error("Expected tag name or value, not " ~ token.symbol.name);

		static if(extras.atLeast(ExtraInfo.Locations))
			tag.location = token.location;
		
		parent.tags[tag.namespace][tag.name] ~= tag;

		parseValues(tag);
		parseAttributes(tag);
		parseOptChild(tag);
		parseTagTerminator(tag);
	}

	/// <IDFull> ::= Ident <IDSuffix>  (Lookaheads: Ident)
	IDFull parseIDFull()
	{
		auto token = lexer.front;
		if(token.matches!"Ident"())
		{
			lexer.popFront();
			return parseIDSuffix(token.data);
		}
		else
		{
			error("Expected namespace or identifier, not " ~ token.symbol.name);
			assert(0);
		}
	}

	/// <IDSuffix>
	///     ::= ':' Ident  (Lookaheads: ':')
	///     ::= {empty}    (Lookaheads: Anything else)
	IDFull parseIDSuffix(string firstIdent)
	{
		auto token = lexer.front;
		if(token.matches!":"())
		{
			lexer.popFront();
			token = lexer.front;
			if(token.matches!"Ident"())
			{
				lexer.popFront();
				return IDFull(firstIdent, token.data);
			}
			else
			{
				error("Expected name, not " ~ token.symbol.name);
				assert(0);
			}
		}
		else
			return IDFull("", firstIdent);
	}

	/// <Values>
	///     ::= Value <Values>  (Lookaheads: Value)
	///     |   {empty}         (Lookaheads: Anything else)
	void parseValues(ref Tag!extras parent)
	{
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Value"())
			{
				parseValue(parent);
				continue;
			}
			else
				break;
		}
	}

	/// Handle Value terminals that aren't part of an attribute
	void parseValue(ref Tag!extras parent)
	{
		auto token = lexer.front;
		if(token.matches!"Value"())
		{
			auto value = token.value;
			version(SDLang_TraceParse)
				trace("In tag '", parent.fullName, "', found value: ", value);

			parent.values ~= value;
			static if(extras.atLeast(ExtraInfo.All))
				parent.valueTokens ~= token;
			
			lexer.popFront();
		}
		else
			error("Expected value, not "~token.symbol.name);
	}

	/// <Attributes>
	///     ::= <Attribute> <Attributes>  (Lookaheads: Ident)
	///     |   {empty}                   (Lookaheads: Anything else)
	void parseAttributes(ref Tag!extras parent)
	{
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Ident"())
			{
				parseAttribute(parent);
				continue;
			}
			else
				break;
		}
	}

	/// <Attribute> ::= <IDFull> '=' Value  (Lookaheads: Ident)
	void parseAttribute(ref Tag!extras parent)
	{
		auto token = lexer.front;
		if(!token.matches!"Ident"())
			error("Expected attribute name, not "~token.symbol.name);
		
		auto id = parseIDFull();
		Attribute!extras attr;
		attr.namespace = id.namespace;
		attr.name      = id.name;

		static if(extras.atLeast(ExtraInfo.Locations))
			attr.location = token.location;
		
		token = lexer.front;
		if(!token.matches!"="())
			error("Expected '=' after attribute name, not "~token.symbol.name);
		
		lexer.popFront();
		token = lexer.front;
		if(!token.matches!"Value"())
			error("Expected attribute value, not "~token.symbol.name);
		
		attr.value = token.value;
		static if(extras.atLeast(ExtraInfo.All))
			attr.valueToken = token;
		
		parent.attributes[attr.namespace][attr.name] ~= attr;
		version(SDLang_TraceParse)
			trace("In tag '", parent.fullName, "', found attribute '", attr.fullName, "'");
		
		lexer.popFront();
	}

	/// <OptChild>
	///      ::= '{' EOL <Tags> '}'  (Lookaheads: '{')
	///      |   {empty}             (Lookaheads: Anything else)
	void parseOptChild(ref Tag!extras parent)
	{
		auto token = lexer.front;
		if(token.matches!"{")
		{
			lexer.popFront();
			token = lexer.front;
			if(!token.matches!"EOL"())
				error("Expected newline or semicolon after '{', not "~token.symbol.name);
			
			lexer.popFront();
			parseTags(parent);
			
			token = lexer.front;
			if(!token.matches!"}"())
				error("Expected '}' after child tags, not "~token.symbol.name);
			lexer.popFront();
		}
		else
			{ /+ Do nothing, no error. +/ }
	}
	
	/// <TagTerminator>
	///     ::= EOL  (Lookahead: EOL)
	///     |   EOF  (Lookahead: EOF)
	void parseTagTerminator(ref Tag!extras parent)
	{
		auto token = lexer.front;
		if(token.matches!"EOL" || token.matches!"EOF")
		{
			lexer.popFront();
		}
		else
			error("Expected end of tag (newline, semicolon or end-of-file), not " ~ token.symbol.name);
	}
}
