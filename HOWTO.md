How to use SDLang-D (Tutorial / API Overview)
=============================================

SDLang-D offers two ways to work with SDLang: DOM style and StAX/Pull style. DOM style is easier and more convenient and can both read and write SDLang. StAX/Pull style is faster and more efficient, although it's only used for reading SDLang, not writing it.

This document explains how to use SDLang-D in the DOM style. If you're familiar with StAX/Pull style parsing for other languages, such as XML, then SDLang-D's StAX/Pull parser should be fairly straightforward to understand. See [pullParseFile](http://semitwist.com/sdlang-d/sdlang/parser/pullParseFile.html) and [pullParseSource](http://semitwist.com/sdlang-d/sdlang/parser/pullParseSource.html) in the [API reference](http://semitwist.com/sdlang-d/sdlang.html) for details. You can also see SDLang-D's source as a real-world example, as the DOM parser is built directly on top of the StAX/Pull parser (just search ```parser.d``` for ```DOMParser```).

**Contents**
- [Installation](#installation)
- [Importing](#importing)
- [Example](#example)
- [Main Interface: Parsing SDLang](#main-interface-parsing-sdlang)
- [Value](#value)
- [DOM API Summary](#dom-api-summary)
- [DOM Example](#dom-example)
- [Outputting SDLang](#outputting-sdlang)

Installation
------------

The list of officially supported D compiler versions is always available in [.travis.yml](https://github.com/Abscissa/SDLang-D/blob/master/.travis.yml).

The recommended way to use SDLang-D is via [DUB](http://code.dlang.org/getting_started). Just add a dependency to ```sdlang-d``` in your project's ```dub.json``` or ```dub.sdl``` file [as shown here](http://code.dlang.org/packages/sdlang-d). Then simply build your project with DUB as usual.

Alternatively, you can ```git clone``` both SDLang-D and the latest versions of [libInputVisitor](https://github.com/Abscissa/libInputVisitor) and [TaggedAlgebraic](https://github.com/s-ludwig/taggedalgebraic), and include ```-I{path to SDLang-D}/src -I{path to libInputVisitor} -I{path to TaggedAlgebraic}/source``` when running the compiler.

Note that prior to DMD 2.071.0, ```-inline``` causes some problems. It causes SDLang-D to segfault when parsing a Base64 value. As of DMD 2.071.0 and up, ```-inline``` works fine.

Importing
---------

To use SDLang-D, first import the module ```sdlang```:

```d
import sdlang;
```

If you're not using DUB, then you must also include the paths to the sources of SDLang-D and its dependencies when you compile:

```
rdmd --build-only -I{path to sdlang-d}/src -I{path to libInputVisitor} -I{path to TaggedAlgebraic}/source {other flags} yourProgram.d
```

Example
-------

[example.d](https://github.com/Abscissa/SDLang-D/blob/master/example.d):
```d
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
```

Compile and run:
```console
> dub example.d
Person's Name: Joe Coder
Id: 7
Birthday: 1970-Dec-06
Yum!
------------------------
All top-level tags:
name
welcome
misc-values
misc-attrs
ip-address
myNamespace:person
------------------------
First misc-values int:    11
First misc-values string: Up
All misc-values values:
  11
  Up
  3.14
  null
  On the roof
  22
Found null?: true
All misc-values integer values:
11
22
------------------------
First misc-attrs A= int:    11
First misc-attrs A= string: Up
Num attributes in default namespace: 3
Num attributes in foo namespace: 1
All misc-attrs attributes:
A: 11
A: Up
foo:A: 22
bar:A: 33
B: 44
------------------------
The full SDLang:
------------------------
name "Frank"
welcome "Hello world"
misc-values 11 "Up" 3.14000000000000012434497875802D null "On the roof" 22
misc-attrs A=11 A="Up" foo:A=22 bar:A=33 B=44
ip-address "192.168.1.100" port=8080
myNamespace:person "Joe Coder" id=7 {
        birthday 1970/12/6
        has-cake true
        homepage "http://sdlang.org"
        dir "foo" {
                file "bar.txt"
        }
}
```

Main Interface: Parsing SDLang
------------------------------

The main interface for SDLang-D is the two parse functions:

```d
/// Returns root tag.
Tag parseFile(string filename);

/// Returns root tag. The optional 'filename' parameter can be included
/// so that the SDLang document's filename (if any) can be displayed with
/// any syntax error messages.
Tag parseSource(string source, string filename=null);
```

Beyond that, your interactions with SDLang-D will be via ```class Tag```,
```struct Attribute``` and ```alias Value``` (an instantiation of [std.variant.Algebraic](http://dlang.org/phobos/std_variant.html)).

Value
-----

The type ```Value``` is an instantiation of [std.variant.Algebraic](http://dlang.org/phobos/std_variant.html). It's defined like this:

```
SDLang's datatypes map to D's datatypes as described below.
Most are straightforward, but take special note of the date/time-related types.

Boolean:                       bool
Null:                          typeof(null)
Unicode Character:             dchar
Double-Quote Unicode String:   string
Raw Backtick Unicode String:   string
Integer (32 bits signed):      int
Long Integer (64 bits signed): long
Float (32 bits signed):        float
Double Float (64 bits signed): double
Decimal (128+ bits signed):    real
Binary (standard Base64):      ubyte[]
Time Span:                     Duration

Date (with no time at all):           Date
Date Time (no timezone):              DateTimeFrac
Date Time (with a known timezone):    SysTime
Date Time (with an unknown timezone): DateTimeFracUnknownZone
```
```d
alias Algebraic!(
    bool,
    string, dchar,
    int, long,
    float, double, real,
    Date, DateTimeFrac, SysTime, DateTimeFracUnknownZone, Duration,
    ubyte[],
    typeof(null),
) Value;
```

DOM API Summary
---------------

You can view the full API reference for [Tag](http://semitwist.com/sdlang-d/sdlang/ast/Tag.html) and [Attribute](http://semitwist.com/sdlang-d/sdlang/ast/Attribute.html), but put simply, the Tag and Attribute APIs work as follows (where ```{...}``` means optional, and ```|``` means or):

```d
// Attribute: ------------------------------------------------------------

// Constructors:
Attribute.this(string namespace, string name, Value value,
               Location location = Location(0, 0, 0))
Attribute.this(string name, Value value,
               Location location = Location(0, 0, 0))

Attribute.namespace  // string: "" if no namespace
Attribute.name       // string: "" if anonymous
Attribute.location   // Location: filename, line, column and index in original SDLang file
Attribute.value      // Value
Attribute.parent     // Tag: Read-only
Tag.getFullName().toString() // string: Returns "namespace:name" if there's a namespace

// Tag: ------------------------------------------------------------------

// Constructors:
Tag.this(Tag parent = null)
Tag.this(string namespace, string name,
         Value[] values=null, Attribute[] attributes=null, Tag[] children=null)
Tag.this(Tag parent,
         string namespace, string name,
         Value[] values=null, Attribute[] attributes=null, Tag[] children=null)

Tag.namespace // string: "" if no namespace
Tag.name      // string: "" if anonymous
Tag.location  // Location: filename, line, column and index in original SDLang file
Tag.values    // Value[]
Tag.parent    // Tag: Read-only
Tag.getFullName().toString() // string: Returns "namespace:name" if there's a namespace

Tag.remove()   // Removes this tag from its parent
Tag.add(Tag   | Attribute   | Value  )   // Adds a member to this tag
Tag.add(Tag[] | Attribute[] | Value[])   // Adds multiple members to this tag

Tag.toSDLDocument  // Create a full SDLang document. Call on a root tag.
Tag.toSDLString    // A fragment of an SDLang document. Just one tag.

// Convenience functions: ------------------------------------------------

// Accept "namespace:name" notation for all names.
// 
// If what you're searching for can't be found:
//   "get" functions: Return an optional default value
//   "expect" functions: Throw a subclass of DOMNotFoundException
//
// Functions returning one Value or Attribute are templates on value's actual
// type, so you can just use 'int', 'string', etc, no need to use the 'Value'
// algebraic type.
Tag.getTag(name, [defaultVal])
Tag.getValue!T([defaultVal])
Tag.getTagValue!T(name, [defaultVal])
Tag.getAttribute!T(name, [defaultVal])
Tag.getTagAttribute!T(tagName, attrName, [defaultVal])

Tag.expectTag(name)
Tag.expectValue!T()
Tag.expectTagValue!T(name)
Tag.expectAttribute!T(name)
Tag.expectTagAttribute!T(tagName, attrName)

// Returns all values of a tag in a 'Value[]'
Tag.getTagValues(string fullTagName, Value[] defaultValues = null)

// Returns random-access range of all attributes of a tag (defaults to only attrs without a namespace)
Tag.getTagAttributes(string fullTagName, string attributeNamespace = null)

// Full-featured range interfaces: ---------------------------------------

// Optional '.maybe' implies "If I lookup (by string) a name or namespace
// that doesn't exist, then return an empty range instead of throwing."
Tag{.maybe}.namespaces                       // RandomAccessRange
Tag{.maybe}.namespaces[string or index]      // Access child tags/attributes (see below)
Tag{.maybe}.namespaces[startIndex..endIndex] // Slicable
string (in|!in) Tag{.maybe}.namespaces       // Check if namespace exists

// Access child tags/attributes:
// - Optional '.maybe' explained above.
// - Optional '.all' means "All namespaces".
// - The default namespace is "".
Tag{.maybe}{.all | .namespaces[string or index]}.tags        // RandomAccessRange
Tag{.maybe}{.all | .namespaces[string or index]}.attributes  // RandomAccessRange

(tags|attributes)[index]                // Normal RandomAccessRange indexing
(tags|attributes)[startIndex..endIndex] // Slicable (but the slice can't use 'in' or '[string]')
string (in|!in) (tags|attributes)       // Check if a tag/attribute name exists
(tags|attributes)[string]               // Slicable RandomAccessRange of
                                        // tags/attributes with a specific name
```

All of the interfaces above are shallow. For example:

* ```Tag{.maybe}.namespaces``` only contains namespaces used by the current tag's attributes and immediate children - not descendants.
* ```.maybe```-ness ends when you reach another Tag. So, ```Tag.maybe.namespaces["invalid-namespace"].tags["invalid-name"]``` is ok and won't throw, but the following will throw: ```Tag.maybe.namespaces["ok-namespace"].tags["ok-name"][0].tags["invalid-name"]```.

Ranges will be invalidated if you add/remove/rename any child tags, attributes or namespaces, on the Tag which the Range operates on. But, if assertions and struct invariants are enabled, then this will be detected and any further attempt to use the invalidated range will throw an assertion failure.

Since this library is designed primarily for reading and writing SDLang files, it's optimized for building and navigating trees rather than manipulating them. Keep in mind that removing or renaming tags, attributes or namespaces may be slow. If you're concerned about speed, it might be best to minimize direct manipulations and prefer using use the SDLang-D data structures as pure input/output.

DOM Example
-----------

Consider the following SDLang adapted from the [SDL Language Guide](http://sdl.ikayzo.org/display/SDL/Language+Guide) [[mirror](http://semitwist.com/sdl-mirror/Language+Guide.html)]

```
person "Akiko" "Johnson" dimensions:height=68 {
    son "Nouhiro" "Johnson"
    daughter "Sabrina" "Johnson" location="Italy" {
        info:hobbies "swimming" "surfing"
        info:languages "English" "Italian"
        info:smoker false
    }
}
```

That can be navigated like this:

[example2.d](https://github.com/Abscissa/SDLang-D/blob/master/example2.d):
```d
Tag root = parseSource(theSdlExampleAbove);

// Get the person tag:
//
// SDLang supports multiple tags/attributes with the same name,
// therefore the [0] is needed.
Tag akiko = root.tags["person"][0];
assert( akiko.namespace == "" ); // Default namespace is ""
assert( akiko.name == "person" );
assert( akiko.values.length == 2 );
assert( akiko.values[0] == Value("Akiko") );
assert( akiko.values[1] == Value("Johnson") );

// Anonymous tags are named "": (Note: This is different from the Java SDL
// where anonymous tags are named "content".)
assert( root.tags[""][0].values[0].get!string().startsWith("This is ") );
assert( root.tags[""][0].values[1] == Value(123) );
assert( root.tags[""][1].values[0] == Value("Another anon tag") );

// Get Akiko-san's height attribute:
//
// Her attribute "height" is in the namespace "dimensions",
// so it must be accessed that way:
assert( "height" !in akiko.attributes );
assert( "height" in akiko.namespaces["dimensions"].attributes );
assert( "height" in akiko.all.attributes );  // 'all' looks in all namespaces
assert( akiko.all.attributes["height"].length == 1 );

Attribute akikoHeight = akiko.all.attributes["height"][0];
assert( akikoHeight.namespace == "dimensions" );
assert( akikoHeight.name == "height" );
assert( akikoHeight.value == Value(68) );
assert( akikoHeight.parent is akiko );

// She has no "weight" attribute:
assertThrown!SDLangRangeException( akiko.attributes["weight"] );
assertThrown!SDLangRangeException( akiko.all.attributes["weight"] );

// Use 'maybe' to get an empty range instead of an exception.
// This works on tags and namespaces, too.
assert( akiko.maybe.attributes["weight"].empty );
assert( akiko.maybe.all.attributes["weight"].empty );
assert( akiko.maybe.attributes["height"].empty );
assert( akiko.maybe.all.attributes["height"].length == 1 );
assert( akiko.maybe.namespaces["foo"].attributes["bar"].empty );
assert( akiko.maybe.namespaces["foo"].tags["bar"].empty );

// Show Akiko-san's child tags:
foreach(Tag child; akiko.tags)
	writeln(child.name); // Output: son daughter
writeln("--------------");

foreach(Tag child; akiko.namespaces["pet"].tags)
	writeln(child.name); // Output: kitty
writeln("--------------");

foreach(Tag child; akiko.all.tags)
	writeln(child.name); // Output: son kitty daughter
writeln("--------------");

// Get Akiko-san's daughter:
Tag daughter = akiko.tags["daughter"][0];

// You can also manually specify "default namepace",
// or lookup by index insetad of name. This works on attributes, too:
assert(daughter is akiko.namespaces[""].tags["daughter"][0]);
assert(daughter is akiko.tags[1]);      // Second child of Akiko-san
assert(daughter is akiko.all.tags[2]);  // Third if you include pets

// Akiko-san's namespaces, in order of first appearance in the SDLang file:
assert(akiko.namespaces[0].name == "dimensions"); // First found in attribute "height"
assert(akiko.namespaces[1].name == "");           // First found in child "son"
assert(akiko.namespaces[2].name == "pet");        // First found in child "kitty"

// Everything is a random-access range:
// (Although 'Tag.values' is currently just a plain-old array)
auto allDaughters = akiko.all.tags.filter!(c => c.name == "daughter")();
assert( array(allDaughters).length == 1 );
assert( allDaughters.front is daughter );

// Everything can be safely modified. If assertions and struct invariants
// are enabled, any already-existing ranges will automatically detect when
// they've been potentially invalidated and throw an assertion failure.
//
// Keep in mind, the library is optimized for lookups, so removing and
// renaming tags, attributes or namespaces may be slow.
daughter.attributes["location"][0].value = Value("England");

auto kitty = akiko.all.tags["kitty"][0];
kitty.name = "cat";
assert( "kitty" !in akiko.all.tags );
assert( kitty is akiko.all.tags["cat"][0] );

akikoHeight.namespace = "stats";
assert( "dimensions" !in akiko.namespaces );
assert( "stats" in akiko.namespaces );
assert( akikoHeight == akiko.namespaces["stats"].attributes["height"][0] );

// Add/remove child tag. Also works with attributes.
Tag son = akiko.tags["son"][0];
Tag hobbies = daughter.tags["hobbies"][0];
// 'hobbies' is already attached to a parent tag.
assertThrown!SDLangValidationException( son.add(hobbies) );
hobbies.remove(); // Remove from daughter
son.add(hobbies); // Ok

/*
Output the modified SDLang document:

"This is an anonymous tag with two values" 123
"Another anon tag"
person "Akiko" "Johnson" stats:height=68 {
	son "Nouhiro" "Johnson" {
		hobbies "swimming" "surfing"
	}
	pet:cat "Neko"
	daughter "Sabrina" "Johnson" location="England" {
		languages "English" "Italian"
		smoker false
	}
}
*/
stdout.rawWrite( root.toSDLDocument() );
writeln("--------------");

// Root tags cannot be part of a namespace or contain any values or attributes
assertThrown!SDLangValidationException( daughter.toSDLDocument() );
assertThrown!SDLangValidationException( kitty.toSDLDocument() );

root.add( new Attribute("attributeNamespace", "attributeName", Value(3)) );
assertThrown!SDLangValidationException( root.toSDLDocument() );

// But you can still convert such tags, or any other Tag, Attribute or Value,
// to an SDLang string with 'toSDLString':
// 
// pet:cat "Neko"
stdout.rawWrite( kitty.toSDLString() );
```

Outputting SDLang
-----------------

To output SDLang, simply call ```Tag.toSDLDocument()``` on whichever tag is your "root" tag. The root tag is simply used as a collection of tags. As such, its namespace must be blank and it cannot have any values or attributes. It can, however, have any name (which will be ignored), and it is allowed to have a parent (also ignored).

Additionally, tags, attributes and values all have a ```toSDLString()``` function, to convert just one Tag (any tag, not just a root tag), Attribute or Value to an SDLang string.

The ```Tag.toSDLDocument()``` function and ```toSDLString()``` functions can optionally take an OutputRange sink instead of allocating and returning a string. The Tag-based functions also have optional parameters to customize the indent style and starting depth.

```d
class Tag
{
...
	/// Treats 'this' as the root tag. Note that root tags cannot have
	/// values or attributes, and cannot be part of a namespace.
	/// If this isn't a valid root tag, 'SDLangValidationException' will be thrown.
	string toSDLDocument()(string indent="\t", int indentLevel=0);
	void toSDLDocument(Sink)(ref Sink sink, string indent="\t", int indentLevel=0)
		if(isOutputRange!(Sink,char));
	
	/// Output this entire tag in SDLang format. Does *not* treat 'this' as
	/// a root tag. If you intend this to be the root of a standard SDLang
	/// document, use 'toSDLDocument' instead.
	string toSDLString()(string indent="\t", int indentLevel=0);
	void toSDLString(Sink)(ref Sink sink, string indent="\t", int indentLevel=0)
		if(isOutputRange!(Sink,char));
...
}

struct Attribute
{
...
	string toSDLString()();
	void toSDLString(Sink)(ref Sink sink) if(isOutputRange!(Sink,char));
...
}

string toSDLString(T)(T value) if(
	is( T : Value  ) ||
	is( T : bool   ) ||
	is( T : string ) ||
	/+...etc...+/
);
void toSDLString(Sink)(Value value, ref Sink sink) if(isOutputRange!(Sink,char));
void toSDLString(Sink)(typeof(null) value, ref Sink sink) if(isOutputRange!(Sink,char));
void toSDLString(Sink)(bool value, ref Sink sink) if(isOutputRange!(Sink,char));
void toSDLString(Sink)(string value, ref Sink sink) if(isOutputRange!(Sink,char));
//...etc...
```
