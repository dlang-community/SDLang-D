/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

import std.stream : ByteOrderMarks, BOM;
import std.uni;
import std.utf;

import sdlang_impl.exception;
import sdlang_impl.symbol;
import sdlang_impl.token;
import sdlang_impl.util;

alias sdlang_impl.util.startsWith startsWith;

///.
struct Lexer
{
	string source; ///.
	Location location; ///.

	/+private+/ dchar  ch;  // Current character
	/+private+/ size_t pos; // Position *after* current character (an index into source)
	private dchar  nextCh;  // Lookahead character
	private size_t nextPos; // Position *after* lookahead character
	private bool   hasNextCh;  // If false, then there's no more lookahead, just EOF
	
	///.
	this(string source, string filename=null)
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
		location = Location(filename, 0, 0);
	}
	
	///.
	@property bool empty()
	{
		return pos == source.length;
	}
	
	///.
	@property Token front()
	{
		pos = source.length;
		//TODO: Implement this
		if(empty)
			return Token(symbol!"EOF", location);
		return Token(symbol!"Error", location);
	}
	
	///.
	void popFront()
	{
		//TODO: Implement this
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

		pos = nextPos;
		ch  = nextCh;
		if(pos == source.length)
		{
			nextCh = dchar.init;
			hasNextCh = false;
			return;
		}
		
		nextCh = source.decode(nextPos);
	}

	/// Advances past whitespace and comments
	/+private+/ void eatWhite()
	{
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
					if(hasNextCh && nextCh == ch)
					{
						advanceChar();
						state = State.lineComment;
					}
					else if(ch == '/' && hasNextCh && nextCh == '*')
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
				if(hasNextCh && nextCh == '\n')
					state = State.normal;
				break;
			
			case State.blockComment:
				if(ch == '*')
				{
					if(hasNextCh && nextCh == '/')
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
