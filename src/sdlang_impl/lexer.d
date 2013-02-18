/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

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

	// Poor-man's yield, but fast.
	// Only to be used in popFront.
	private template yield(alias symbolName)
	{
		enum yield = "
			{
				_front = makeToken!"~symbolName.stringof~";
				advanceChar();
				return;
			}
		";
	}

	///.
	void popFront()
	{
		//TODO: Finish implementing this

		eatWhite();

		// -- Main Lexer -------------
		
		enum State
		{
			normal,
			rawString,
			ident_true,   // ident or true
			ident_false,  // ident or false
			ident_on_off, // ident or on or off
			ident_null,   // ident or null
			ident,
		}
		
		auto startCh  = ch;
		auto startPos = pos;
		State state   = State.normal;
		tokenStart    = location;
		tokenLength   = 1;
		tokenLength32 = 1;
		bool failedKeywordOn  = false;
		bool failedKeywordOff = false;
		while(true)
		{
			final switch(state)
			{
			case State.normal:
				
				if(ch == '=')
					mixin(yield!"=");
				
				else if(ch == '{')
					mixin(yield!"{");
				
				else if(ch == '}')
					mixin(yield!"}");
				
				else if(ch == ':')
					mixin(yield!":");
				
				else if(ch == ';' || ch == '\n')
					mixin(yield!"EOL");
				
				else if(ch == 't' && !isEndOfIdent())
					state = State.ident_true;

				else if(ch == 'f' && !isEndOfIdent())
					state = State.ident_false;

				else if(ch == 'o' && !isEndOfIdent())
					state = State.ident_on_off;

				else if(ch == 'n' && !isEndOfIdent())
					state = State.ident_null;

				else if(isAlpha(ch) || ch == '_')
				{
					state = State.ident;
					goto case State.ident;
				}

				else if(ch == '`')
					state = State.rawString;

				else
					mixin(yield!"Error");
									
				break;

			case State.rawString:
				if(ch == '`')
					mixin(yield!"Value");
				break;

			case State.ident_true:
				final switch(checkKeyword("true", &isEndOfIdent))
				{
				case KeywordResult.Failed:   state = State.ident; break;
				case KeywordResult.Continue: break;
				case KeywordResult.Accept:   mixin(yield!"true");
				}
				if(state == State.ident)
					goto case State.ident;
				break;

			case State.ident_false:
				final switch(checkKeyword("false", &isEndOfIdent))
				{
				case KeywordResult.Failed:   state = State.ident; break;
				case KeywordResult.Continue: break;
				case KeywordResult.Accept:   mixin(yield!"false");
				}
				if(state == State.ident)
					goto case State.ident;
				break;

			case State.ident_on_off:
				if(!failedKeywordOn)
				final switch(checkKeyword("on", &isEndOfIdent))
				{
				case KeywordResult.Failed:   failedKeywordOn = true; break;
				case KeywordResult.Continue: break;
				case KeywordResult.Accept:   mixin(yield!"true");
				}

				if(!failedKeywordOff)
				final switch(checkKeyword("off", &isEndOfIdent))
				{
				case KeywordResult.Failed:   failedKeywordOff = true; break;
				case KeywordResult.Continue: break;
				case KeywordResult.Accept:   mixin(yield!"false");
				}
				
				if(isEndOfIdent() || (failedKeywordOn && failedKeywordOff))
				{
					state = State.ident;
					goto case State.ident;
				}
				break;

			case State.ident_null:
				final switch(checkKeyword("null", &isEndOfIdent))
				{
				case KeywordResult.Failed:   state = State.ident; break;
				case KeywordResult.Continue: break;
				case KeywordResult.Accept:   mixin(yield!"null");
				}
				if(state == State.ident)
					goto case State.ident;
				break;

			case State.ident:
				if(isEndOfIdent())
					mixin(yield!"Ident");
				break;
			}

			if(hasNextCh)
				advanceChar();
			else
			{
				// Reached EOF

				/+if(state == State.backslash)
					throw new SDLangException(
						location,
						"Error: No newline after line-continuation backslash"
					);

				else if(state == State.blockComment)
					throw new SDLangException(
						location,
						"Error: Unterminated block comment"
					);

				else+/
					mixin(yield!"EOF"); // Done, reached EOF
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

	/// Does lookahead character indicate the end of an ident?
	private bool isEndOfIdent()
	{
		if(!hasNextCh)
			return true;
		
		if(isAlpha(nextCh))
			return false;
		
		if(isNumber(nextCh))
			return false;
		
		return
			nextCh != '-' &&
			nextCh != '_' &&
			nextCh != '.' &&
			nextCh != '$';
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
				else if(ch == '\n' || !isWhite(ch))
					return; // Done

				break;
			
			case State.backslash:
				if(ch == '\n')
					state = State.normal;

				else if(!isWhite(ch))
					throw new SDLangException(
						location,
						"Error: Only whitespace can come after a line-continuation backslash"
					);
				break;
			
			case State.lineComment:
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
						"Error: No newline after line-continuation backslash"
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
