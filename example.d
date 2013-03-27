import std.stdio;
import sdlang;

int main()
{
	Tag root;
	
	try
	{
		// Or:
		// root = parseFile("myFile.sdl");
		root = parseSource(`
			welcome "Hello world"

			// Uncomment this for an error:
			// badSuffix 12Q

			myNamespace:person name="Joe Coder" {
				age 36
			}
		`);
	}
	catch(SDLangParseException e)
	{
		// Messages will be of the form:
		// myFile.sdl(5:28): Error: Invalid integer suffix.
		stderr.writeln(e.msg);
		return 1;
	}
	
	// Value is a std.variant.Algebraic
	Value welcome = root.tags["welcome"][0].values[0];
	assert(welcome.type == typeid(string));
	writeln(welcome);
	
	Tag person = root.namespaces["myNamespace"].tags["person"][0];
	writeln("Name: ", person.attributes["name"][0].value);
	
	int age = person.tags["age"][0].values[0].get!int();
	writeln("Age: ", age);
	
	// Output back to SDL
	writeln("The full SDL:");
	writeln(root.toSDLDocument());
	
	return 0;
}
