How to use SDLang-D (Tutorial / API Overview)
=============================================

SDLang-D offers two ways to work with SDLang: DOM style and pull (aka "StAX") style. DOM style is easier and more convenient and can both read and write SDLang. Pull style is faster and more efficient, although it's only used for reading SDLang, not writing it.

This document explains how to use SDLang-D in the DOM style. If you're familiar with pull/StAX style parsing for other languages, such as XML, then SDLang-D's pull parser should be straightforward to understand. See [pullParseFile](http://semitwist.com/sdlang-d/sdlang/parser/pullParseFile.html) and [pullParseSource](http://semitwist.com/sdlang-d/sdlang/parser/pullParseSource.html) in the [API reference](http://semitwist.com/sdlang-d/sdlang.html) for details and a simple example. You can also see SDLang-D's source as a real-world example, as the DOM tree itself is built using the pull parser, in less than 50 lines of code (just search [`parser.d`](https://github.com/Abscissa/SDLang-D/blob/master/src/sdlang/parser.d) for ```DOMParser```).

**Contents**
- [Installation](#installation)
- [Importing](#importing)
- [Main Interface: Parsing SDLang](#main-interface-parsing-sdlang)
- [DOM Example](#dom-example)
- [DOM API Summary](#dom-api-summary)
- [Outputting SDLang](#outputting-sdlang)

Installation
------------

The list of officially supported D compiler versions is always available in [.travis.yml](https://github.com/Abscissa/SDLang-D/blob/master/.travis.yml).

The recommended way to use SDLang-D is via [DUB](http://code.dlang.org/getting_started). Just add a dependency to ```sdlang-d``` in your project's ```dub.json``` or ```dub.sdl``` file [as shown here](http://code.dlang.org/packages/sdlang-d). Then simply build your project with DUB as usual.

Alternatively, you can ```git clone``` both SDLang-D and the latest versions of [libInputVisitor](https://github.com/Abscissa/libInputVisitor) and [TaggedAlgebraic](https://github.com/s-ludwig/taggedalgebraic), and include ```-I{path to SDLang-D}/src -I{path to libInputVisitor} -I{path to TaggedAlgebraic}/source``` when running the compiler.

Note that prior to DMD 2.071.0, ```-inline``` causes some problems. It causes SDLang-D to segfault when parsing a Base64 value. As of DMD 2.071.0 and up, ```-inline``` works fine.

Importing
---------

To use SDLang-D, first import the module `sdlang`:

```d
import sdlang;
```

If you're not using DUB, then you must also include the paths to the sources of SDLang-D and its dependencies when you compile:

```
rdmd --build-only -I{path to sdlang-d}/src -I{path to libInputVisitor} -I{path to TaggedAlgebraic}/source {other flags} yourProgram.d
```
Main Interface: Parsing SDLang
------------------------------

If doing your own pull parsing, follow the documentation and example for [pullParseFile](semitwist.com/sdlang-d/sdlang/parser/pullParseFile.html) and [pullParseSource](semitwist.com/sdlang-d/sdlang/parser/pullParseSource.html).

If using DOM mode instead of the pull parser, the main interface for SDLang-D is the two parse functions:

```d
/// Returns root tag.
Tag parseFile(string filename);

/// Returns root tag. The optional 'filename' parameter can be included
/// so that the SDLang document's filename (if any) can be displayed with
/// any syntax error messages.
Tag parseSource(string source, string filename=null);
```

Beyond that, your interactions with SDLang-D will be via `class Tag`,
`struct Attribute` and [`alias Value`](semitwist.com/sdlang-d/sdlang/token/Value.html) (an instantiation of [std.variant.Algebraic](http://dlang.org/phobos/std_variant.html)).

DOM Example
-----------

[example.d](https://github.com/Abscissa/SDLang-D/blob/master/example.d):
```d
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
		// myFile.sdl(6:17): Error: Invalid integer suffix.
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
		catch(AttributeNotFoundException e)
			stderr.writeln(person.location, ": Error: 'person' requires a string value");

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
```

Compile and run:
```console
> dub example.d
Hello world! Address is 192.168.1.100:8080
Person's Name: Joe Coder
Id: 7
Yum!
------------------------
message
ip-address
misc-values
misc-attrs
devs:person
------------------------
All integer values in misc-values:
11
22
------------------------
All misc-attrs attributes:
int a=11
immutable(char)[] a=Up
int foo:a=22
bool flag=true
------------------------
message "Hello world!"
ip-address "192.168.1.100" port=8080
misc-values 11 "Up" 3.14000000000000012434497875802D null "On the roof" 22
misc-attrs a=11 a="Up" foo:a=22 flag=true
devs:person "Joe Coder" 1.5D id=7 extras:has-kid=true {
        has-cake true
        namespace:person "Sam Coder" id=12 {
                message "Hello world!"
        }
}
```

Another example, using the more powerful range-based DOM interfaces instead of the get/expect convenience functions, is in [`example2.d`](https://github.com/Abscissa/SDLang-D/blob/master/example2.d). Be aware however, the integer-based indexing [might get removed](https://github.com/Abscissa/SDLang-D/issues/47) in a later version of SDLang-D.

DOM API Summary
---------------

You can view the full API reference for [`Tag`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.html) and [`Attribute`](http://semitwist.com/sdlang-d/sdlang/ast/Attribute.html), but put simply:

Value is an instantiation of [std.variant.Algebraic](http://dlang.org/phobos/std_variant.html). See the [summary of `Value`](semitwist.com/sdlang-d/sdlang/token/Value.html).

The `Tag` and `Attribute` APIs work as follows (where ```{...}``` means optional, and ```|``` means or):

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

Outputting SDLang
-----------------

To generate SDLang, first build up a DOM using [`Tag.this`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.this.html), [`Attribute.this`](http://semitwist.com/sdlang-d/sdlang/ast/Attribute.this.html), [`Tag.add`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.add.html), [`Tag.values`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.values.html), and [`Attribute.value`](http://semitwist.com/sdlang-d/sdlang/ast/Attribute.value.html):

```d
auto nameTag = new Tag(null, "name", [Value("my-cool-project")]);
auto root = new Tag(null, null, null, null, [nameTag]);

auto sdlangDependencyTag = new Tag(null, "dependency", [Value("sdlang-d")]);
auto sdlangVersionAttr = new Attribute(null, "version", [Value("~>0.10.1")]);
sdlangDependencyTag.add(sdlangVersionAttr);

root.add(sdlangDependencyTag);
```

Remember, the root tag is simply used as a collection of tags. As such, its namespace must be blank and it cannot have any values or attributes. It can, however, have any name (which will be ignored), and it is allowed to have a parent (also ignored).

Then, simply call [`Tag.toSDLDocument()`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.toSDLDocument.html) on your root tag:

```d
import std.file;
std.file.write("dub.sdl", root.toSDLDocument());
```

Additionally, you can generate just a portion of SDLang, instead of a full ducument, via [`Tag.toSDLString()`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.toSDLString.html), [`Attribute.toSDLString()`](http://semitwist.com/sdlang-d/sdlang/ast/Attribute.toSDLString.html) and [`toSDLString(Value)`](http://semitwist.com/sdlang-d/sdlang/token/toSDLString.html).

The [`Tag.toSDLDocument()`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.toSDLDocument.html) function and [`toSDLString()`](http://semitwist.com/sdlang-d/sdlang/ast/Tag.toSDLString.html) functions can optionally take an OutputRange sink instead of allocating and returning a string. The Tag-based functions also have optional parameters to customize the indent style and starting depth.
