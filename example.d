/+ dub.sdl:
	name "example"
	dependency "sdlang-d" version="~>0.9.6"
+/

import std.algorithm;
import std.array;
import std.datetime;
import std.stdio;
import sdlang;

// Try running: dub example.d
// Or:          dub example.d -- yourData.sdl
int main(string[] args)
{
	Tag root;
	
	try
	{
		if(args.length > 1)
			root = parseFile(args[1]);
		else
		{
			root = parseSource(`
				name    "Frank"        // Required
				welcome "Hello world"  // Optional

				// Uncomment this for an error:
				//badSuffix 12Q

				misc-values 11 "Up" 3.14 null "On the roof" 22
				misc-attrs  A=11 A="Up" foo:A=22 bar:A=33 B=44

				// Default: "127.0.0.1" port=80
				ip-address "192.168.1.100" port=8080

				myNamespace:person "Joe Coder" id=7 {
					birthday 1970/12/06
					has-cake true
				}
			`);
		}
	}
	catch(ParseException e)
	{
		// Messages will look like:
		// myFile.sdl(6:17): Error: Invalid integer suffix.
		stderr.writeln(e.msg);
		return 1;
	}
	
	// Required tag: Throws ValueNotFoundException if not found
	string name = root.expectTagValue!string("name");

	// Optional tag: Returns string.init is not found
	string welcome = root.getTagValue!string("welcome");
	
	// Get address
	string ipAddress = root.getTagValue!string("address", "127.0.0.1");
	int port = root.getTagAttribute!int("address", "port", 80);
	
	// Optional tag: Could have said "myNamespace:person",
	//               but let's allow any namespace.
	Tag person = root.getTag("*:person");
	if(person !is null)
	{
		// Required Name
		try
			writeln("Person's Name: ", person.expectValue!string());
		catch(AttributeNotFoundException e)
		{
			// Custom errors with file/line info:
			stderr.writeln(person.location,
				": Error: 'person' tag requires a string attribute 'name'");
		}

		// Attribute: Id
		int id = person.getAttribute!int("id", 99999);
		writeln("Id: ", id);

		// Tag: Birthday
		Date birthday = person.getTagValue!Date("birthday");
		if(birthday != Date.init)
			writeln("Birthday: ", birthday);

		// Tag: Cake?
		if(person.getTagValue!bool("has-cake"))
			writeln("Yum!");
	}

	// All top-level tags:
	writeln("------------------------");
	writeln("All top-level tags:");
	root.all.tags.each!( (Tag tag) => writeln(tag.getFullName) );
	
	// Misc values and range support
	Tag miscValues = root.getTag("misc-values");
	writeln("------------------------");
	writeln("First misc-values int:    ", miscValues.expectValue!int());
	writeln("First misc-values string: ", miscValues.expectValue!string());
	writeln("All misc-values values:");
	bool foundNull;
	foreach(Value value; miscValues.values)
	{
		if(value.type == typeid(null))
			foundNull = true;

		writeln("  ", value);
	}
	writeln("Found null?: ", foundNull);
	
	writeln("All misc-values integer values:");
	miscValues.values
		.filter!((Value v) => v.type == typeid(int))
		.map!((Value v) => v.get!int)
		.each!writeln;

	// Misc attributes and range support
	Tag miscAttrs = root.getTag("misc-attrs");
	writeln("------------------------");
	writeln("First misc-attrs A= int:    ", miscAttrs.expectAttribute!int("A"));
	writeln("First misc-attrs A= string: ", miscAttrs.expectAttribute!string("A"));

	auto attrsDefaultNamespace = miscAttrs.attributes;
	auto attrsFooNamespace     = miscAttrs.namespaces["foo"].attributes;
	auto allAttrs              = miscAttrs.all.attributes;
	writeln("Num attributes in default namespace: ", attrsDefaultNamespace.length);
	writeln("Num attributes in foo namespace: ", attrsFooNamespace.length);
	writeln("All misc-attrs attributes:");
	allAttrs.each!(
		(Attribute a) => writeln(a.getFullName, ": ", a.value)
	);

	// Add new children tags to person tag
	auto newSDLangRoot = parseSource(`
		homepage "http://sdlang.org"
		dir "foo" {
			file "bar.txt"
		}
	`);
	newSDLangRoot.all.tags.each!( (Tag t) => person.add(t.clone) );

	// Output back to SDLang
	writeln("------------------------");
	writeln("The full SDLang:");
	writeln("------------------------");
	writeln(root.toSDLDocument());
	
	return 0;
}
