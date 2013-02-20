/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

import std.array;
import std.base64;
import std.conv;
import std.stream : ByteOrderMarks, BOM;
import std.uni;
import std.utf;
import std.variant;

import sdlang_impl.exception;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

alias sdlang_impl.util.startsWith startsWith;

// Kind of a poor-man's yield, but fast.
// Only to be used inside Lexer.popFront.
private template accept(string symbolName)
{
	enum accept = acceptImpl!(symbolName, null);
}
private template accept(string symbolName, alias value)
{
	static assert(symbolName == "Value", "Only a Value symbol can take a value.");
	enum accept = acceptImpl!(symbolName, value);
}
private template acceptImpl(string symbolName, alias value)
{
	enum acceptImpl = ("
		{
			_front = makeToken!"~symbolName.stringof~";
			_front.value = "~value.stringof~";
			return;
		}
	").replace("\n", "");
}

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
	
	// Length so far of the token being lexed, not including current char
	private size_t tokenLength;   // Length in UTF-8 code units
	private size_t tokenLength32; // Length in UTF-32 code units
	
	///.
	this(string source=null, string filename=null)
	{
		_front = Token(symbol!"Error", Location());

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
	Token _front;// = Token(symbol!"Error", Location());
	@property Token front()
	{
		return _front;
	}

	///.
	@property bool isEOF()
	{
		return location.index == source.length;
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
	
	/// Is current character the last one in an ident?
	private bool isEndOfIdentCached = false;
	private bool _isEndOfIdent;
	private bool isEndOfIdent()
	{
		if(!isEndOfIdentCached)
		{
			if(!hasNextCh)
				_isEndOfIdent = true;
			else
				_isEndOfIdent = !isIdentChar(nextCh);
			
			isEndOfIdentCached = true;
		}
		
		return _isEndOfIdent;
	}

	/// Is 'ch' a character that's allowed *somewhere* in an identifier?
	private bool isIdentChar(dchar ch)
	{
		if(isAlpha(ch))
			return true;
		
		else if(isNumber(ch))
			return true;
		
		else
			return 
				ch == '-' ||
				ch == '_' ||
				ch == '.' ||
				ch == '$';
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
	private KeywordResult checkKeyword(dstring keyword32)
	{
		// Still within length of keyword
		if(tokenLength32 < keyword32.length)
		{
			if(ch == keyword32[tokenLength32])
				return KeywordResult.Continue;
			else
				return KeywordResult.Failed;
		}

		// At position after keyword
		else if(tokenLength32 == keyword32.length)
		{
			if(!isIdentChar(ch))
			{
				assert(source[tokenStart.index..location.index] == to!string(keyword32));
				return KeywordResult.Accept;
			}
			else
				return KeywordResult.Failed;
		}

		assert(0, "Fell off end of keyword to check");
	}

	enum ErrorOnEOF { No, Yes }

	/// Advance one code point.
	/// Returns false if EOF was reached
	private void advanceChar(ErrorOnEOF errorOnEOF)
	{
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

		if(!hasNextCh)
		{
			if(errorOnEOF == ErrorOnEOF.Yes)
				throw new SDLangException(location, "Error: Unexpected end of file");

			return;
		}

		if(nextPos == source.length)
		{
			nextCh = dchar.init;
			hasNextCh = false;
			return;
		}

		tokenLength32++;
		tokenLength = location.index - tokenStart.index;
		
		nextCh = source.decode(posAfterLookahead);
		isEndOfIdentCached = false;
	}

	///.
	void popFront()
	{
		// -- Main Lexer -------------

		eatWhite();

		if(isEOF)
			mixin(accept!"EOF");
		
		tokenStart    = location;
		tokenLength   = 0;
		tokenLength32 = 0;
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
		
		else if(isAlpha(ch) || ch == '_')
			lexIdentKeyword();

		else if(ch == '"')
			lexRegularString();

		else if(ch == '`')
			lexRawString();
		
		else if(ch == '\'')
			lexCharacter();

		else if(ch == '[')
			lexBinary();

		else if(ch == '-' || isDigit(ch))
			lexNumeric();

		else
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!"Error");
		}
	}

	/// Lex Ident or Keyword
	private void lexIdentKeyword()
	{
		assert(isAlpha(ch) || ch == '_');
		
		// Keyword
		struct Key
		{
			dstring name;
			Value value;
			bool failed = false;
		}
		static Key[5] keywords;
		static keywordsInited = false;
		if(!keywordsInited)
		{
			// Value (as a std.variant-based type) can't be statically inited
			keywords[0] = Key("true",  Value(true ));
			keywords[1] = Key("false", Value(false));
			keywords[2] = Key("on",    Value(true ));
			keywords[3] = Key("off",   Value(false));
			keywords[4] = Key("null",  Value(null ));
			keywordsInited = true;
		}
		
		foreach(ref key; keywords)
			key.failed = false;
		
		auto numKeys = keywords.length;

		do
		{
			foreach(ref key; keywords)
			if(!key.failed)
			{
				final switch(checkKeyword(key.name))
				{
				case KeywordResult.Accept:
					auto v = key.value;
					mixin(accept!("Value", v));
				
				case KeywordResult.Continue:
					break;
				
				case KeywordResult.Failed:
					key.failed = true;
					numKeys--;
					break;
				}
			}

			if(numKeys == 0)
			{
				lexIdent();
				return;
			}

			advanceChar(ErrorOnEOF.No);

		} while(!isEOF);

		mixin(accept!"Ident");
	}

	/// Lex Ident
	private void lexIdent()
	{
		if(tokenLength == 0)
			assert(isAlpha(ch) || ch == '_');
		
		while(!isEOF && isIdentChar(ch))
			advanceChar(ErrorOnEOF.No);

		mixin(accept!"Ident");
	}
	
	/// Lex regular string
	private void lexRegularString()
	{
		assert(ch == '"');

		Appender!string buf;
		size_t spanStart = nextPos;
		
		// Doesn't include current character
		void updateBuf()
		{
			if(location.index == spanStart)
				return;

			buf.put( source[spanStart..location.index] );
		}
		
		do
		{
			advanceChar(ErrorOnEOF.Yes);

			if(ch == '\\')
			{
				updateBuf();
				
				advanceChar(ErrorOnEOF.Yes);
				if(isNewline(ch))
					eatWhite();
				else
				{
					//TODO: Is this list of escape chars 100% complete and correct?
					switch(ch)
					{
					case 'n': buf.put('\n'); break;
					case 't': buf.put('\t'); break;
					
					// Handles ' " \ and anything else
					default: buf.put(ch); break;
					}

					advanceChar(ErrorOnEOF.Yes);
				}
				spanStart = location.index;
			}

			else if(isNewline(ch))
				throw new SDLangException(
					location,
					"Error: Unescaped newlines are only allowed in raw strings, not regular strings."
				);

		} while(ch != '"');
		
		updateBuf();
		advanceChar(ErrorOnEOF.No); // Skip closing double-quote
		auto value = buf.data;
		mixin(accept!("Value", value));
	}

	/// Lex raw string
	private void lexRawString()
	{
		assert(ch == '`');
		
		do
			advanceChar(ErrorOnEOF.Yes);
		while(ch != '`');
		
		advanceChar(ErrorOnEOF.No); // Skip closing back-tick
		auto value = source[tokenStart.index+1..location.index-1];
		mixin(accept!("Value", value));
	}
	
	/// Lex character literal
	private void lexCharacter()
	{
		assert(ch == '\'');
		advanceChar(ErrorOnEOF.Yes); // Skip opening single-quote
		
		auto value = ch;
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

		mixin(accept!("Value", value));
	}
	
	/// Lex base64 binary literal
	private void lexBinary()
	{
		assert(ch == '[');
		advanceChar(ErrorOnEOF.Yes);
		
		void eatBase64Whitespace()
		{
			while(!isEOF && isWhite(ch))
			{
				if(isNewline(ch))
					advanceChar(ErrorOnEOF.Yes);
				
				if(!isEOF && isWhite(ch))
					eatWhite();
			}
		}
		
		eatBase64Whitespace();

		// Iterates all valid base64 characters, ending at ']'.
		// Skips all whitespace. Throws on invalid chars.
		struct Base64InputRange
		{
			Lexer *lexer;
			
			@property bool empty()
			{
				return lexer.ch == ']';
			}

			//char _front;
			@property dchar front()
			{
				return lexer.ch;

				// The only valid Base64 chars happen to be valid
				// non-extended ASCII (and therefore single-code-unit UTF-8),
				// so this is Unicode-safe.
				//return lexer.source[lexer.location.index];
			}
			
			void popFront()
			{
				auto lex = lexer;
				lex.advanceChar(lex.ErrorOnEOF.Yes);

				eatBase64Whitespace();
				
				if(lex.isEOF)
					throw new SDLangException(lex.location, "Error: Unexpected end of file");

				if(lex.ch != ']' && !lex.isBase64(lex.ch))
					throw new SDLangException(
						lex.location,
						"Error: Invalid character in base64 binary literal."
					);
			}
		}
		
		// This is a slow ugly hack. It's necessary because Base64.decode
		// currently requires the source to have known length.
		//TODO: Remove this when DMD issue #9543 is fixed.
		dchar[] tmpBuf = array(Base64InputRange(&this));

		Appender!(ubyte[]) outputBuf;
		// Ugly workaround for DMD issue #9102
		//TODO: Remove this when DMD #9102 is fixed
		struct OutputBuf
		{
			void put(ubyte ch)
			{
				outputBuf.put(ch);
			}
		}
		
		try
			//Base64.decode(Base64InputRange(&this), OutputBuf());
			Base64.decode(tmpBuf, OutputBuf());

		//TODO: Starting with dmd 2.062, this should be a Base64Exception
		catch(Exception e)
		{
			throw new SDLangException(
				location,
				"Error: Invalid character in base64 binary literal."
			);
		}
		
		advanceChar(ErrorOnEOF.No); // Skip ']'
		auto value = outputBuf.data;
		mixin(accept!("Value", value));
	}
	
	/// Lex [0-9]+, but without emitting a token.
	/// This is used by the other numeric parsing functions.
	private void lexNumericFragment()
	{
		if(!isDigit(ch))
			throw new SDLangException(location, "Error: Expected a digit 0-9.");
		
		do
		{
			advanceChar(ErrorOnEOF.No);
		} while(!isEOF && isDigit(ch));
	}

	/// Lex anything that starts with 0-9 or '-'. Ints, floats, dates, etc.
	//TODO: How does spec handle invalid suffix like "12a"? An error? Or a value and ident?
	//TODO: Does spec allow negative dates?
	private void lexNumeric()
	{
		assert(ch == '-' || isDigit(ch));

		// Check for negative
		bool isNegative = ch == '-';
		if(isNegative)
			advanceChar(ErrorOnEOF.Yes);

		//TODO: Does spec allow "1." or ".1"? If so, lexNumericFragment() needs to accept ""
		
		lexNumericFragment();
		
		// Long integer (64-bit signed)?
		if(ch == 'L' || ch == 'l')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!("Value", null));
		}
		
		// Some floating point?
		else if(ch == '.')
			lexFloatingPoint();
		
		// Some date?
		else if(ch == '/')
			lexDate();
		
		// Some time span?
		else if(ch == ':' || ch == 'd')
			lexTimeSpan();

		// Integer (32-bit signed)
		else
			mixin(accept!("Value", null));
	}
	
	/// Lex any floating-point literal (after the initial numeric fragment was lexed)
	private void lexFloatingPoint()
	{
		assert(ch == '.');
		advanceChar(ErrorOnEOF.No);
		
		lexNumericFragment();
		
		// Float (32-bit signed)?
		if(ch == 'F' || ch == 'f')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!("Value", null));
		}

		// Double float (64-bit signed) with suffix?
		else if(ch == 'D' || ch == 'd')
		{
			advanceChar(ErrorOnEOF.No);
			mixin(accept!("Value", null));
		}

		// Decimal (128+ bits signed)?
		//TODO: Does spec allow mixed-case suffix?
		else if(ch == 'B' || ch == 'b')
		{
			advanceChar(ErrorOnEOF.Yes);
			if(ch == 'D' || ch == 'd')
			{
				advanceChar(ErrorOnEOF.No);
				mixin(accept!("Value", null));
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
			mixin(accept!("Value", null));
	}

	/// Lex date or datetime (after the initial numeric fragment was lexed)
	//TODO: How does the spec handle a date (not datetime) followed by an int?
	//TODO: SDL site implies datetime can have milliseconds without seconds. Is this true?
	private void lexDate()
	{
		assert(ch == '/');
		
		// Lex months
		advanceChar(ErrorOnEOF.Yes); // Skip '/'
		lexNumericFragment();

		// Lex days
		if(ch != '/')
			throw new SDLangException(location, "Error: Invalid date format: Missing days.");
		advanceChar(ErrorOnEOF.Yes); // Skip '/'
		lexNumericFragment();
		
		// Date?
		if(isEOF)
			mixin(accept!("Value", null));
		
		//TODO: Is this the proper way to handle the space between date and time?
		while(!isEOF && isWhite(ch) && !isNewline(ch))
			advanceChar(ErrorOnEOF.No);
		
		// Note: Date (not datetime) may contain trailing whitespace at this point.
		
		// Date?
		if(isEOF || !isDigit(ch))
			mixin(accept!("Value", null));
		
		// Lex hours
		lexNumericFragment();
		
		// Lex minutes
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid date-time format: Missing minutes.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		lexNumericFragment();
		
		// Lex seconds, if exists
		if(ch == ':')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip ':'
			lexNumericFragment();
		}
		
		// Lex milliseconds, if exists
		if(ch == '.')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '.'
			lexNumericFragment();
		}

		// Lex zone, if exists
		//TODO: Make sure the end of this is detected correctly.
		if(ch == '-')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '-'
			
			if(!isAlpha(ch))
				throw new SDLangException(location, "Error: Invalid timezone.");
			
			while(!isEOF && !isWhite(ch))
				advanceChar(ErrorOnEOF.No);
		}
		
		mixin(accept!("Value", null));
	}

	/// Lex time span (after the initial numeric fragment was lexed)
	private void lexTimeSpan()
	{
		assert(ch == ':' || ch == 'd');
		
		// Lexed days?
		bool hasDays = ch == 'd';
		if(hasDays)
		{
			advanceChar(ErrorOnEOF.Yes); // Skip 'd'

			// Lex hours
			if(ch != ':')
				throw new SDLangException(location, "Error: Invalid time span format: Missing hours.");
			advanceChar(ErrorOnEOF.Yes); // Skip ':'
			lexNumericFragment();
		}

		// Lex minutes
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid time span format: Missing minutes.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		lexNumericFragment();

		// Lex seconds
		if(ch != ':')
			throw new SDLangException(location, "Error: Invalid time span format: Missing seconds.");
		advanceChar(ErrorOnEOF.Yes); // Skip ':'
		lexNumericFragment();
		
		// Lex milliseconds, if exists
		if(ch == '.')
		{
			advanceChar(ErrorOnEOF.Yes); // Skip '.'
			lexNumericFragment();
		}
		
		mixin(accept!("Value", null));
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
