/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

import std.array;
import std.conv;
import std.stream : ByteOrderMarks, BOM;
import std.uni;
import std.utf;

import sdlang_impl.exception;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

alias sdlang_impl.util.startsWith startsWith;

///.
class Lexer
{
	string source; ///.
	Location location; ///.

	private dchar  ch;  // Current character
	private size_t pos; // Position *after* current character (an index into source)
	private dchar  nextCh;  // Lookahead character
	private size_t nextPos; // Position *after* lookahead character (an index into source)
	private bool   hasNextCh;  // If false, then there's no more lookahead, just EOF

	private Location tokenStart;    // The starting location of the token being lexed
	private size_t   tokenLength;   // Length so far of the token being lexed, in UTF-8 code units
	private size_t   tokenLength32; // Length so far of the token being lexed, in UTF-32 code units
	private string   tokenData;     // Slice of source representing the token being lexed
	
	///.
	this(string source=null, string filename=null)
	{
		if( source.startsWith( ByteOrderMarks[BOM.UTF8] ) )
			source = source[ ByteOrderMarks[BOM.UTF8].length .. $ ];
		
		foreach(bom; ByteOrderMarks)
		if( source.startsWith(bom) )
			throw new SDLangException("SDL spec only supports UTF-8, not UTF-16 or UTF-32");

		this.source = source;
		
		// Prime everything
		hasNextCh = true;
		nextCh = source.decode(nextPos);
		advanceChar();
		location = Location(filename, 0, 0, 0);
		popFront();
	}
	
	///.
	@property bool empty()
	{
		return pos == source.length;
	}
	
	///.
	Token _front = Token(symbol!"Error", Location());
	@property Token front()
	{
		return _front;
	}

	// Kind of a poor-man's yield, but fast.
	// Only to be used inside popFront.
	private template accept(alias symbolName)
	{
		enum accept = ("
			{
				_front = makeToken!"~symbolName.stringof~";
				advanceChar();
				return;
			}
		").replace("\n", "");
	}

	private template gotoState(string stateName)
	{
		enum gotoState = ("
			{
				state = "~stateName~";
				goto case "~stateName~";
			}
		").replace("\n", "");
	}

	private enum LexerState
	{
		normal,
		regularString,
		rawString,
		ident_true,   // ident or true
		ident_false,  // ident or false
		ident_on_off, // ident or on or off
		ident_null,   // ident or null
		ident,
	}

	///.
	void popFront()
	{
		//TODO: Finish implementing this

		eatWhite();

		// -- Main Lexer -------------
		
		auto startCh     = ch;
		auto startPos    = pos;
		LexerState state = LexerState.normal;
		tokenStart       = location;
		tokenLength      = 1;
		tokenLength32    = 1;
		bool failedKeywordOn  = false;
		bool failedKeywordOff = false;
		isEndOfIdentCached = false;
		while(true)
		{
			final switch(state)
			{
			case LexerState.normal:
				
				if(ch == '=')
					mixin(accept!"=");
				
				else if(ch == '{')
					mixin(accept!"{");
				
				else if(ch == '}')
					mixin(accept!"}");
				
				else if(ch == ':')
					mixin(accept!":");
				
				//TODO: Should this include all isNewline()? (except for \r, right?)
				else if(ch == ';' || ch == '\n')
					mixin(accept!"EOL");
				
				else if(ch == 't' && !isEndOfIdent())
					mixin(gotoState!"LexerState.ident_true");

				else if(ch == 'f' && !isEndOfIdent())
					mixin(gotoState!"LexerState.ident_false");

				else if(ch == 'o' && !isEndOfIdent())
					mixin(gotoState!"LexerState.ident_on_off");

				else if(ch == 'n' && !isEndOfIdent())
					mixin(gotoState!"LexerState.ident_null");

				else if(isAlpha(ch) || ch == '_')
					mixin(gotoState!"LexerState.ident");

				else if(ch == '"')
				{
					advanceChar();
					mixin(gotoState!"LexerState.regularString");
				}

				else if(ch == '`')
				{
					advanceChar();
					mixin(gotoState!"LexerState.rawString");
				}

				else
					mixin(accept!"Error");

			case LexerState.regularString:

				if(ch == '\\')
				{
					advanceChar();
					if(isNewline(ch))
						eatWhite();
				}

				else if(ch == '"')
					mixin(accept!"Value");

				else if(isNewline(ch))
					throw new SDLangException(
						location,
						"Error: Unescaped newlines are only allowed in raw strings, not regular strings."
					);

				break;

			case LexerState.rawString:
				if(ch == '`')
					mixin(accept!"Value");
				break;

			case LexerState.ident_true:
				auto r = checkKeyword("true", &isEndOfIdent);
				if     (r == KeywordResult.Accept) mixin(accept!"Value");
				else if(r == KeywordResult.Failed) mixin(gotoState!"LexerState.ident");
				break;

			case LexerState.ident_false:
				auto r = checkKeyword("false", &isEndOfIdent);
				if     (r == KeywordResult.Accept) mixin(accept!"Value");
				else if(r == KeywordResult.Failed) mixin(gotoState!"LexerState.ident");
				break;

			case LexerState.ident_on_off:
				if(!failedKeywordOn)
				{
					auto r = checkKeyword("on", &isEndOfIdent);
					if     (r == KeywordResult.Accept) mixin(accept!"Value");
					else if(r == KeywordResult.Failed) failedKeywordOn = true;
				}

				if(!failedKeywordOff)
				{
					auto r = checkKeyword("off", &isEndOfIdent);
					if     (r == KeywordResult.Accept) mixin(accept!"Value");
					else if(r == KeywordResult.Failed) failedKeywordOff = true;
				}
				
				if(isEndOfIdent() || (failedKeywordOn && failedKeywordOff))
					mixin(gotoState!"LexerState.ident");
				break;

			case LexerState.ident_null:
				auto r = checkKeyword("null", &isEndOfIdent);
				if     (r == KeywordResult.Accept) mixin(accept!"Value");
				else if(r == KeywordResult.Failed) mixin(gotoState!"LexerState.ident");
				break;

			case LexerState.ident:
				if(isEndOfIdent())
					mixin(accept!"Ident");
				break;
			}

			if(hasNextCh)
				advanceChar();
			else
			{
				// Reached EOF

				/+if(state == LexerState.backslash)
					throw new SDLangException(
						location,
						"Error: Missing newline after line-continuation backslash"
					);

				else if(state == LexerState.blockComment)
					throw new SDLangException(
						location,
						"Error: Unterminated block comment"
					);

				else+/
					mixin(accept!"EOF"); // Done, reached EOF
			}
		}
	}
	
	private Token makeToken(string symbolName)()
	{
		auto tok = Token(symbol!symbolName, tokenStart);
		tok.data = source[tokenStart.index..pos];
		return tok;
	}
	
	/// Check the lookahead character
	private bool lookahead(dchar ch)
	{
		return hasNextCh && nextCh == ch;
	}

	private bool isNewline(dchar ch)
	{
		//TODO: Not entirely sure if this list is 100% complete and correct per spec.
		return ch == '\n' || ch == '\r' || ch == lineSep || ch == paraSep;
	}
	
	/// Does lookahead character indicate the end of an ident?
	private bool isEndOfIdentCached = false;
	private bool _isEndOfIdent;
	private bool isEndOfIdent()
	{
		if(!isEndOfIdentCached)
		{
			if(!hasNextCh)
				_isEndOfIdent = true;
			
			else if(isAlpha(nextCh))
				_isEndOfIdent = false;
			
			else if(isNumber(nextCh))
				_isEndOfIdent = false;
			
			else
				_isEndOfIdent =
					nextCh != '-' &&
					nextCh != '_' &&
					nextCh != '.' &&
					nextCh != '$';
			
			isEndOfIdentCached = true;
		}
		
		return _isEndOfIdent;
	}

	private enum KeywordResult
	{
		Accept,   // Keyword is matched
		Continue, // Keyword is not matched *yet*
		Failed,   // Keyword doesn't match
	}
	private KeywordResult checkKeyword(dstring keyword32, bool delegate() dgIsAtEnd)
	{
		// Shorter than keyword
		if(tokenLength32 < keyword32.length)
		{
			if(ch == keyword32[tokenLength32-1] && !dgIsAtEnd())
				return KeywordResult.Continue;
			else
				return KeywordResult.Failed;
		}

		// Same length as keyword
		else if(tokenLength32 == keyword32.length)
		{
			if(ch == keyword32[tokenLength32-1] && dgIsAtEnd())
			{
				assert(source[tokenStart.index..pos] == to!string(keyword32));
				return KeywordResult.Accept;
			}
			else
				return KeywordResult.Failed;
		}

		// Longer than keyword
		else
			return KeywordResult.Failed;
	}

	/// Advance one code point
	private void advanceChar()
	{
		//TODO: Should this include all isNewline()? (except for \r, right?)
		if(ch == '\n')
		{
			location.line++;
			location.col = 0;
		}
		else
			location.col++;

		location.index = pos;

		pos = nextPos;
		ch  = nextCh;
		if(pos == source.length)
		{
			nextCh = dchar.init;
			hasNextCh = false;
			return;
		}

		tokenLength32++;
		tokenLength = pos - tokenStart.index;
		tokenData   = source[tokenStart.index..pos];
		
		nextCh = source.decode(nextPos);
		isEndOfIdentCached = false;
	}

	/// Advances past whitespace and comments
	private void eatWhite()
	{
		// -- Comment/Whitepace Lexer -------------

		enum State
		{
			normal,
			backslash,    // Got "\\", Eating whitespace until "\n"
			lineComment,  // Got "#" or "//" or "--", Eating everything until "\n"
			blockComment, // Got "/*", Eating everything until "*/"
		}
		
		State state = State.normal;
		while(true)
		{
			final switch(state)
			{
			case State.normal:

				if(ch == '\\')
					state = State.backslash;

				else if(ch == '#')
					state = State.lineComment;

				else if(ch == '/' || ch == '-')
				{
					if(lookahead(ch))
					{
						advanceChar();
						state = State.lineComment;
					}
					else if(ch == '/' && lookahead('*'))
					{
						advanceChar();
						state = State.blockComment;
					}
					else
						return; // Done
				}
				//TODO: Should this include all isNewline()? (except for \r, right?)
				else if(ch == '\n' || !isWhite(ch))
					return; // Done

				break;
			
			case State.backslash:
				//TODO: Should this include all isNewline()? (except for \r, right?)
				if(ch == '\n')
					state = State.normal;

				else if(!isWhite(ch))
					throw new SDLangException(
						location,
						"Error: Only whitespace can come after a line-continuation backslash"
					);
				break;
			
			case State.lineComment:
				//TODO: Should this include all isNewline()? (except for \r, right?)
				if(lookahead('\n'))
					state = State.normal;
				break;
			
			case State.blockComment:
				if(ch == '*')
				{
					if(lookahead('/'))
					{
						advanceChar();
						state = State.normal;
					}
					else
						return; // Done
				}
				break;
			}
			
			if(hasNextCh)
				advanceChar();
			else
			{
				// Reached EOF

				if(state == State.backslash)
					throw new SDLangException(
						location,
						"Error: Missing newline after line-continuation backslash"
					);

				else if(state == State.blockComment)
					throw new SDLangException(
						location,
						"Error: Unterminated block comment"
					);

				else
					return; // Done, reached EOF
			}
		}
	}
}
