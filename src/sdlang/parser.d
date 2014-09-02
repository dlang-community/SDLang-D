// SDLang-D
// Written in the D programming language.

module sdlang.parser;

import std.file;

import sdlang.ast;
import sdlang.exception;
import sdlang.lexer;
import sdlang.symbol;
import sdlang.token;
import sdlang.util;

/// Returns root tag.
Tag parseFile(string filename)
{
	auto source = cast(string)read(filename);
	return parseSource(source, filename);
}

/// Returns root tag. The optional 'filename' parameter can be included
/// so that the SDL document's filename (if any) can be displayed with
/// any syntax error messages.
Tag parseSource(string source, string filename=null)
{
	auto lexer = new Lexer(source, filename);
	auto parser = Parser(lexer);
	return parser.parseRoot();
}

private struct Parser
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
		throw new SDLangParseException(loc, "Error: "~msg);
	}

	/// <Root> ::= <Tags> EOF  (Lookaheads: Anything)
	Tag parseRoot()
	{
		//trace("Starting parse of file: ", lexer.filename);
		//trace(__FUNCTION__, ": <Root> ::= <Tags> EOF  (Lookaheads: Anything)");

		auto root = new Tag(null, null, "root");
		root.location = Location(lexer.filename, 0, 0, 0);

		parseTags(root);
		
		auto token = lexer.front;
		if(!token.matches!"EOF"())
			error("Expected end-of-file, not " ~ token.symbol.name);
		
		return root;
	}

	/// <Tags> ::= <Tag> <Tags>  (Lookaheads: Ident Value)
	///        |   EOL   <Tags>  (Lookaheads: EOL)
	///        |   {empty}       (Lookaheads: Anything else)
	void parseTags(ref Tag parent)
	{
		//trace("Enter ", __FUNCTION__);
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Ident"() || token.matches!"Value"())
			{
				//trace(__FUNCTION__, ": <Tags> ::= <Tag> <Tags>  (Lookaheads: Ident Value)");
				parseTag(parent);
				continue;
			}
			else if(token.matches!"EOL"())
			{
				//trace(__FUNCTION__, ": <Tags> ::= EOL <Tags>  (Lookaheads: EOL)");
				lexer.popFront();
				continue;
			}
			else
			{
				//trace(__FUNCTION__, ": <Tags> ::= {empty}  (Lookaheads: Anything else)");
				break;
			}
		}
	}

	/// <Tag>
	///     ::= <IDFull> <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Ident)
	///     |   <Value>  <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Value)
	void parseTag(ref Tag parent)
	{
		auto token = lexer.front;
		Tag tag;
		
		if(token.matches!"Ident"())
		{
			//trace(__FUNCTION__, ": <Tag> ::= <IDFull> <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Ident)");
			auto id = parseIDFull();
			tag = new Tag(parent, id.namespace, id.name);

			//trace("Found tag named: ", tag.fullName);
		}
		else if(token.matches!"Value"())
		{
			//trace(__FUNCTION__, ": <Tag> ::= <Value>  <Values> <Attributes> <OptChild> <TagTerminator>  (Lookaheads: Value)");
			tag = new Tag(parent);
			parseValue(tag);

			//trace("Found anonymous tag.");
		}
		else
			error("Expected tag name or value, not " ~ token.symbol.name);

		tag.location = token.location;
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
			//trace(__FUNCTION__, ": <IDFull> ::= Ident <IDSuffix>  (Lookaheads: Ident)");
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
			//trace(__FUNCTION__, ": <IDSuffix> ::= ':' Ident  (Lookaheads: ':')");
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
		{
			//trace(__FUNCTION__, ": <IDSuffix> ::= {empty}  (Lookaheads: Anything else)");
			return IDFull("", firstIdent);
		}
	}

	/// <Values>
	///     ::= Value <Values>  (Lookaheads: Value)
	///     |   {empty}         (Lookaheads: Anything else)
	void parseValues(ref Tag parent)
	{
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Value"())
			{
				//trace(__FUNCTION__, ": <Values> ::= Value <Values>  (Lookaheads: Value)");
				parseValue(parent);
				continue;
			}
			else
			{
				//trace(__FUNCTION__, ": <Values> ::= {empty}  (Lookaheads: Anything else)");
				break;
			}
		}
	}

	/// Handle Value terminals that aren't part of an attribute
	void parseValue(ref Tag parent)
	{
		auto token = lexer.front;
		if(token.matches!"Value"())
		{
			//trace(__FUNCTION__, ": (Handle Value terminals that aren't part of an attribute)");
			auto value = token.value;
			//trace("In tag '", parent.fullName, "', found value: ", value);
			parent.add(value);
			
			lexer.popFront();
		}
		else
			error("Expected value, not "~token.symbol.name);
	}

	/// <Attributes>
	///     ::= <Attribute> <Attributes>  (Lookaheads: Ident)
	///     |   {empty}                   (Lookaheads: Anything else)
	void parseAttributes(ref Tag parent)
	{
		while(true)
		{
			auto token = lexer.front;
			if(token.matches!"Ident"())
			{
				//trace(__FUNCTION__, ": <Attributes> ::= <Attribute> <Attributes>  (Lookaheads: Ident)");
				parseAttribute(parent);
				continue;
			}
			else
			{
				//trace(__FUNCTION__, ": <Attributes> ::= {empty}  (Lookaheads: Anything else)");
				break;
			}
		}
	}

	/// <Attribute> ::= <IDFull> '=' Value  (Lookaheads: Ident)
	void parseAttribute(ref Tag parent)
	{
		//trace(__FUNCTION__, ": <Attribute> ::= <IDFull> '=' Value  (Lookaheads: Ident)");
		auto token = lexer.front;
		if(!token.matches!"Ident"())
			error("Expected attribute name, not "~token.symbol.name);
		
		auto id = parseIDFull();
		
		token = lexer.front;
		if(!token.matches!"="())
			error("Expected '=' after attribute name, not "~token.symbol.name);
		
		lexer.popFront();
		token = lexer.front;
		if(!token.matches!"Value"())
			error("Expected attribute value, not "~token.symbol.name);
		
		auto attr = new Attribute(id.namespace, id.name, token.value, token.location);
		parent.add(attr);
		//trace("In tag '", parent.fullName, "', found attribute '", attr.fullName, "'");
		
		lexer.popFront();
	}

	/// <OptChild>
	///      ::= '{' EOL <Tags> '}'  (Lookaheads: '{')
	///      |   {empty}             (Lookaheads: Anything else)
	void parseOptChild(ref Tag parent)
	{
		auto token = lexer.front;
		if(token.matches!"{")
		{
			//trace(__FUNCTION__, ": <OptChild> ::= '{' EOL <Tags> '}'  (Lookaheads: '{')");
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
		{
			//trace(__FUNCTION__, ": <OptChild> ::= {empty}  (Lookaheads: Anything else)");
			// Do nothing, no error.
		}
	}
	
	/// <TagTerminator>
	///     ::= EOL      (Lookahead: EOL)
	///     |   {empty}  (Lookahead: EOF)
	void parseTagTerminator(ref Tag parent)
	{
		auto token = lexer.front;
		if(token.matches!"EOL")
		{
			//trace(__FUNCTION__, ": <TagTerminator> ::= EOL  (Lookahead: EOL)");
			lexer.popFront();
		}
		else if(token.matches!"EOF")
		{
			//trace(__FUNCTION__, ": <TagTerminator> ::= {empty}  (Lookahead: EOF)");
			// Do nothing
		}
		else
			error("Expected end of tag (newline, semicolon or end-of-file), not " ~ token.symbol.name);
	}
}

// Parser's tests are part of the AST's tests over in the ast module.
