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
	Location location; /// Location of current character in source

	private dchar  ch;         // Current character
	private dchar  nextCh;     // Lookahead character
	private size_t nextPos;    // Position of lookahead character (an index into source)
	private bool   hasNextCh;  // If false, then there's no more lookahead, just EOF
	private size_t posAfterLookahead; // Position after lookahead character (an index into source)

	private Location tokenStart;    // The starting location of the token being lexed
	private size_t   tokenLength;   // Length so far of the token being lexed, in UTF-8 code units
	private size_t   tokenLength32; // Length so far of the token being lexed, in UTF-32 code units
	
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
		nextCh = source.decode(posAfterLookahead);
		advanceChar(ErrorOnEOF.Yes); //TODO: Emit EOL on parsing empty string
		location = Location(filename, 0, 0, 0);
		popFront();
	}
	
	///.
	@property bool empty()
	{
		return _front.symbol == symbol!"EOF";
	}
	
	///.
	Token _front = Token(symbol!"Error", Location());
	@property Token front()
	{
		return _front;
	}

	///.
	@property bool isEOF()
	{
		return nextPos == source.length;
	}

	// Kind of a poor-man's yield, but fast.
	// Only to be used inside popFront.
	private template accept(alias symbolName)
	{
		enum accept = ("
			{
				_front = makeToken!"~symbolName.stringof~";
				return;
			}
		").replace("\n", "");
	}

	private Token makeToken(string symbolName)()
	{
		auto tok = Token(symbol!symbolName, tokenStart);
		tok.data = source[tokenStart.index..location.index];
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

	/// Is 'ch' a valid base 64 character?
	private bool isBase64(dchar ch)
	{
		if(ch >= 'A' && ch <= 'Z')
			return true;

		if(ch >= 'a' && ch <= 'z')
			return true;

		if(ch >= '0' && ch <= '9')
			return true;
		
		return ch == '+' || ch == '/' || ch == '=';
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

	private bool isDigit(dchar ch)
	{
		return ch >= '0' && ch <= '9';
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
				assert(source[tokenStart.index..nextPos] == to!string(keyword32));
				return KeywordResult.Accept;
			}
			else
				return KeywordResult.Failed;
		}

		// Longer than keyword
		else
			return KeywordResult.Failed;
	}

	enum ErrorOnEOF { No, Yes }

	/// Advance one code point.
	/// Returns false if EOF was reached
	private bool advanceChar(ErrorOnEOF errorOnEOF)
	{
		if(!hasNextCh)
		{
			if(errorOnEOF == ErrorOnEOF.No)
				return false;
			else
				throw new SDLangException(
					location,
					"Error: Unexpected end of file"
				);
		}
		
		//TODO: Should this include all isNewline()? (except for \r, right?)
		if(ch == '\n')
		{
			location.line++;
			location.col = 0;
		}
		else
			location.col++;

		location.index = nextPos;

		nextPos = posAfterLookahead;
		ch      = nextCh;
		if(nextPos == source.length)
		{
			nextCh = dchar.init;
			hasNextCh = false;
			return true;
		}

		tokenLength32++;
		tokenLength = nextPos - tokenStart.index;
		
		nextCh = source.decode(posAfterLookahead);
		isEndOfIdentCached = false;
		return true;
	}

	///.
	void popFront()
	{
		//TODO: Finish implementing this
		// -- Main Lexer -------------

		eatWhite();

		if(isEOF)
			mixin(accept!"EOF");
		
		tokenStart    = location;
		tokenLength   = 1;
		tokenLength32 = 1;
		isEndOfIdentCached = false;
		
		if(ch == '=')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"=");
		}
		
		else if(ch == '{')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"{");
		}
		
		else if(ch == '}')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"}");
		}
		
		else if(ch == ':')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!":");
		}
		
		//TODO: Should this include all isNewline()? (except for \r, right?)
		else if(ch == ';' || ch == '\n')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"EOL");
		}
		
		else if(ch == 't' && !isEndOfIdent())
			parseIdentTrue();

		else if(ch == 'f' && !isEndOfIdent())
			parseIdentFalse();

		else if(ch == 'o' && !isEndOfIdent())
			parseIdentOnOff();

		else if(ch == 'n' && !isEndOfIdent())
			parseIdentNull();

		else if(isAlpha(ch) || ch == '_')
			parseIdent();

		else if(ch == '"')
			parseRegularString();

		else if(ch == '`')
			parseRawString();
		
		else if(ch == '\'')
			parseCharacter();

		else if(ch == '[')
			parseBinary();

		else if(ch == '-' || isDigit(ch))
			parseNumeric();

		else
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"Error");
		}
	}
	
	/// Parse Ident or 'true'
	private void parseIdentTrue()
	{
		assert(ch == 't' && !isEndOfIdent());

		while(!isEndOfIdent())
		{
			if(!advanceChar(ErrorOnEOF.No))
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!"Ident");
			}
			
			final switch(checkKeyword("true", &isEndOfIdent))
			{
			case KeywordResult.Accept:   advanceChar(ErrorOnEOF.No); mixin(accept!"Value");
			case KeywordResult.Continue: break;
			case KeywordResult.Failed:   parseIdent(); return;
			}
		}

		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Ident");
	}

	/// Parse Ident or 'false'
	private void parseIdentFalse()
	{
		assert(ch == 'f' && !isEndOfIdent());
		
		while(!isEndOfIdent())
		{
			if(!advanceChar(ErrorOnEOF.No))
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!"Ident");
			}
			
			final switch(checkKeyword("false", &isEndOfIdent))
			{
			case KeywordResult.Accept:   advanceChar(ErrorOnEOF.No); mixin(accept!"Value");
			case KeywordResult.Continue: break;
			case KeywordResult.Failed:   parseIdent(); return;
			}
		}

		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Ident");
	}

	/// Parse Ident or 'on' or 'off'
	private void parseIdentOnOff()
	{
		assert(ch == 'o' && !isEndOfIdent());
		
		bool failedKeywordOn  = false;
		bool failedKeywordOff = false;

		while(!isEndOfIdent())
		{
			if(!advanceChar(ErrorOnEOF.No))
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!"Ident");
			}
			
			if(!failedKeywordOn)
			{
				final switch(checkKeyword("on", &isEndOfIdent))
				{
				case KeywordResult.Accept:   advanceChar(ErrorOnEOF.No); mixin(accept!"Value");
				case KeywordResult.Continue: break;
				case KeywordResult.Failed:   failedKeywordOn = true; break;
				}
			}

			if(!failedKeywordOff)
			{
				final switch(checkKeyword("off", &isEndOfIdent))
				{
				case KeywordResult.Accept:   advanceChar(ErrorOnEOF.No); mixin(accept!"Value");
				case KeywordResult.Continue: break;
				case KeywordResult.Failed:   failedKeywordOff = true; break;
				}
			}
			
			if(failedKeywordOn && failedKeywordOff)
			{
				parseIdent();
				return;
			}
		}

		parseIdent();
	}

	/// Parse Ident or 'null'
	private void parseIdentNull()
	{
		assert(ch == 'n' && !isEndOfIdent());
		
		while(!isEndOfIdent())
		{
			if(!advanceChar(ErrorOnEOF.No))
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!"Ident");
			}
			
			final switch(checkKeyword("null", &isEndOfIdent))
			{
			case KeywordResult.Accept:   advanceChar(ErrorOnEOF.No); mixin(accept!"Value");
			case KeywordResult.Continue: break;
			case KeywordResult.Failed:   parseIdent(); return;
			}
		}
	
		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Ident");
	}

	/// Parse Ident
	private void parseIdent()
	{
		assert(isAlpha(ch) || ch == '_');
		
		bool hasMore = true;
		while(hasMore && !isEndOfIdent())
			hasMore = advanceChar(ErrorOnEOF.No);

		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Ident");
	}
	
	/// Parse regular string
	private void parseRegularString()
	{
		assert(ch == '"');
		
		do
		{
			advanceChar(ErrorOnEOF.Yes);

			if(ch == '\\')
			{
				advanceChar(ErrorOnEOF.Yes);
				if(isNewline(ch))
					eatWhite();
				else
					advanceChar(ErrorOnEOF.Yes);
			}

			else if(isNewline(ch))
				throw new SDLangException(
					location,
					"Error: Unescaped newlines are only allowed in raw strings, not regular strings."
				);

		} while(ch != '"');
		
		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Value");
	}

	/// Parse raw string
	private void parseRawString()
	{
		assert(ch == '`');
		
		do
			advanceChar(ErrorOnEOF.Yes);
		while(ch != '`');
		
		advanceChar(ErrorOnEOF.No);
		mixin(accept!"Value");
	}
	
	/// Parse character literal
	private void parseCharacter()
	{
		assert(ch == '\'');
		advanceChar(ErrorOnEOF.Yes); // Skip opening single-quote
		
		advanceChar(ErrorOnEOF.Yes); // Skip the character itself

		if(ch == '\'')
			advanceChar(ErrorOnEOF.No); // Skip closing single-quote
		else
		{
			throw new SDLangException(
				location,
				"Error: Expected closing single-quote."
			);
		}

		mixin(accept!"Value");
	}
	
	/// Parse base64 binary literal
	private void parseBinary()
	{
		assert(ch == '[');
		
		do
		{
			advanceChar(ErrorOnEOF.Yes);
			
			if(isWhite(ch))
				eatWhite();
			
			if(ch == ']' || isNewline(ch))
				continue;
			
			if(!isBase64(ch))
				throw new SDLangException(
					location,
					"Error: Invalid character in base64 binary literal."
				);
		} while(ch != ']');
		
		advanceChar(ErrorOnEOF.No); // Skip ']'
		mixin(accept!"Value");
	}
	
	/// Parse [0-9]+, but without emitting a token.
	/// This is used by the other numeric parsing functions.
	private void parseNumericFragment()
	{
		if(!isDigit(ch))
			throw new SDLangException(location, "Error: Expected a digit 0-9.");
		
		do
		{
			if(!advanceChar(ErrorOnEOF.No))
				return;
		
		} while(isDigit(ch));
	}

	/// Parse anything that starts with 0-9 or '-'. Ints, floats, dates, etc.
	//TODO: How does spec handle invalid suffix like "12a"? An error? Or a value and ident?
	//TODO: Does spec allow negative dates?
	private void parseNumeric()
	{
		assert(ch == '-' || isDigit(ch));

		// Check for negative
		bool isNegative = ch == '-';
		if(isNegative)
			advanceChar(ErrorOnEOF.Yes);

		//TODO: Does spec allow "1." or ".1"? If so, parseNumericFragment() needs to accept ""
		
		parseNumericFragment();
		
		// Long integer (64-bit signed)?
		if(ch == 'L' || ch == 'l')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"Value");
		}
		
		// Some floating point?
		else if(ch == '.')
			parseFloatingPoint();
		
		// Some date?
		else if(ch == '/')
			parseDate();
		
		// Some time span?
		else if(ch == ':' || ch == 'd')
			parseTimeSpan();

		// Integer (32-bit signed)
		else
			mixin(accept!"Value");
	}
	
	/// Parse any floating-point literal (after the initial numeric fragment was parsed)
	private void parseFloatingPoint()
	{
		assert(ch == '.');
		advanceChar(ErrorOnEOF.No);
		
		parseNumericFragment();
		
		// Float (32-bit signed)?
		if(ch == 'F' || ch == 'f')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"Value");
		}

		// Double float (64-bit signed) with suffix?
		else if(ch == 'D' || ch == 'd')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"Value");
		}

		// Decimal (128+ bits signed)?
		//TODO: Does spec allow mixed-case suffix?
		else if(ch == 'B' || ch == 'b')
		{
			advanceChar(ErrorOnEOF.Yes);
			if(ch == 'D' || ch == 'd')
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!"Value");
			}

			//TODO: How does spec actually handle "1.23ba"?
			else
			{
				throw new SDLangException(
					location,
					"Error: Invalid floating point suffix."
				);
			}
		}

		// Double float (64-bit signed) without suffix
		else
			mixin(accept!"Value");
	}

	/// Parse date or datetime (after the initial numeric fragment was parsed)
	//TODO: How does the spec handle a date (not datetime) followed by an int?
	//TODO: SDL site implies datetime can have milliseconds without seconds. Is this true?
	private void parseDate()
	{
		assert(ch == '/');
		
		// Parse months
		advanceChar(ErrorOnEOF.Yes); // Skip '/'
		parseNumericFragment();

		// Parse days
		if(ch != '/')
			throw new SDLangException(location, "Error: Invalid date format: Missing days.");
		advanceChar(ErrorOnEOF.Yes); // Skip '/'
		parseNumericFragment();
		
		// Date?
		if(isEOF)
			mixin(accept!"Value");
		
		//TODO: Is this the proper way to handle the space between date and time?
		while(!isEOF && isWhite(ch) && !isNewline(ch))
			advanceChar(ErrorOnEOF.No);
		
		// Note: Date (not datetime) may contain trailing whitespace at this point.
		
		// Date?
		if(isEOF || !isDigit(ch))
			mixin(accept!"Value");
		
		// Parse hours
		parseNumericFragment();
		
		// Parse minutes
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid date-time format: Missing minutes.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		parseNumericFragment();
		
		// Parse seconds, if exists
		if(ch == ':')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip ':'
			parseNumericFragment();
		}
		
		// Parse milliseconds, if exists
		if(ch == '.')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '.'
			parseNumericFragment();
		}

		// Parse zone, if exists
		//TODO: Make sure the end of this is detected correctly.
		if(ch == '-')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '-'
			
			if(!isAlpha(ch))
				throw new SDLangException(location, "Error: Invalid timezone.");
			
			while(!isEOF && !isWhite(ch))
				advanceChar(ErrorOnEOF.No);
		}
		
		mixin(accept!"Value");
	}

	/// Parse time span (after the initial numeric fragment was parsed)
	private void parseTimeSpan()
	{
		assert(ch == ':' || ch == 'd');
		
		// Parsed days?
		bool hasDays = ch == 'd';
		if(hasDays)
		{
			advanceChar(ErrorOnEOF.Yes); // Skip 'd'

			// Parse hours
			if(ch != ':')
				throw new SDLangException(location, "Error: Invalid time span format: Missing hours.");
			advanceChar(ErrorOnEOF.Yes); // Skip ':'
			parseNumericFragment();
		}

		// Parse minutes
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid time span format: Missing minutes.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		parseNumericFragment();

		// Parse seconds
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid time span format: Missing seconds.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		parseNumericFragment();
		
		// Parse milliseconds, if exists
		if(ch == '.')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '.'
			parseNumericFragment();
		}
		
		mixin(accept!"Value");
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

		if(isEOF)
			return;
		
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
						advanceChar(ErrorOnEOF.No);
						state = State.lineComment;
					}
					else if(ch == '/' && lookahead('*'))
					{
						advanceChar(ErrorOnEOF.No);
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
						advanceChar(ErrorOnEOF.No);
						state = State.normal;
					}
					else
						return; // Done
				}
				break;
			}
			
			advanceChar(ErrorOnEOF.No);
			if(isEOF)
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
