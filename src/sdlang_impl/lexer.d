/// SDLang-D
/// Written in the D programming language.

module sdlang_impl.lexer;

import sdlang_impl.symbol;
import sdlang_impl.token;

///.
struct Lexer
{
	string source; ///.
	string filename; ///.

	///.
	this(string source, string filename=null)
	{
		this.source   = source;
		this.filename = filename;
	}
	
	bool done = false;
	///.
	@property bool empty()
	{
		//TODO: Implement this
		if(!done)
		{
			done = true;
			return false;
		}
		return true;
	}
	
	///.
	@property Token front()
	{
		//TODO: Implement this
		return Token(symbol!"EOF");
	}
	
	///.
	void popFront()
	{
		//TODO: Implement this
	}
}
