/+ dub.sdl:
	name "example"
	dependency "sdlang-d" version="~>0.10.1"
+/

import std.algorithm;
import std.stdio;
import sdlang;

/// To run: dub basicExample.d
int main()
{
	Tag root;
	try
	{
		// Or: parseSource("path/to/somefile.sdl");
		root = parseSource(`
			message "Hello world!"   // Required

			// Optional, default is "127.0.0.1" port=80
			ip-address "192.168.1.100" port=8080

			// Uncomment this for an error:
			//badSuffix 12Q

			misc-values 11 "Up" 3.14 null "On the roof" 22
			misc-attrs  a=11 a="Up" foo:a=22 flag=true

			// Name is required
			devs:person "Joe Coder" id=7 {
				has-cake true
			}
		`); 
	}
	catch(ParseException e)
	{
		// Sample error:
		// myFile.sdl(8:16): Error: Invalid integer suffix.
		stderr.writeln(e.msg);
		return 1;
	}
	
	// Basics
	auto ipAddress = root.getTagValue!string("ip-address", "127.0.0.1");
	auto port      = root.getTagAttribute!int("ip-address", "port", 80);
	auto message   = root.expectTagValue!string("message"); // Throws if not found
	writeln(message, " Address is ", ipAddress, ":", port);

	// Person tag
	Tag person = root.getTag("devs:person"); 
	assert(person.name == "person");
	assert(person.namespace == "devs"); // Default namespace is ""
	assert(person.getFullName.toString == "devs:person");
	if(person !is null)
	{
		try
			writeln("Person's Name: ", person.expectValue!string());
		catch(ValueNotFoundException e)
			e.writeCustomMsg("Error: 'person' requires a string value");

		int id = person.getAttribute!int("id", 99999);
		writeln("Id: ", id);

		if(person.getTagValue!bool("has-cake"))
			writeln("Yum!");
	}

	// List top-level tags in all namespaces
	// (omit "all" to only search in default namespace)
	writeln("------------------------");
	root.all.tags.each!( (Tag t) => writeln(t.getFullName) );
	
	// Get values and their types
	Tag miscValues = root.getTag("misc-values");
	writeln("------------------------");
	writeln("All integer values in misc-values:");
	miscValues.values
		.filter!((Value v) => v.type == typeid(int))
		.map!((Value v) => v.get!int)
		.each!writeln;

	// Misc attributes and range support
	Tag miscAttrs = root.getTag("misc-attrs");
	writeln("------------------------");
	auto allAttrs = miscAttrs.all.attributes;
	writeln("All misc-attrs attributes:");
	allAttrs.each!(
		(Attribute a) => writeln(a.value.type, " ", a.getFullName, "=", a.value)
	);

	// Add new data to person tag
	person.values ~= Value(1.5); // Values is an array
	person.add( new Attribute("extras", "has-kid", Value(true)) );
	auto childId = new Attribute(null, "id", Value(12));
	auto messageCopy = root.getTag("message").clone;
	person.add( new Tag("namespace", "person", [Value("Sam Coder")], [childId], [messageCopy]) );

	// Output back to SDLang
	writeln("------------------------");
	writeln(root.toSDLDocument());
	
	return 0;
}
