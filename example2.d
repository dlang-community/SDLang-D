/+ dub.sdl:
	name "example"
	dependency "sdlang-d" version="~>0.10.1"
+/

/// To build and run: dub example2.d
///
/// NOTE: The integer-based indexing shown here might get removed in a later
/// version of SDLang-D. See $(LINK2 https://github.com/Abscissa/SDLang-D/issues/47, #47)
import std.algorithm;
import std.array;
import std.exception;
import std.stdio;
import sdlang;

enum theSdlExampleAbove = `
	"This is an anonymous tag with two values" 123
	"Another anon tag"

	person "Akiko" "Johnson" dimensions:height=68 {
		son "Nouhiro" "Johnson"
		pet:kitty "Neko"
		daughter "Sabrina" "Johnson" location="Italy" {
			hobbies "swimming" "surfing"
			languages "English" "Italian"
			smoker false
		}
	}
`;

void main()
{
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
	assertThrown!DOMRangeException( akiko.attributes["weight"] );
	assertThrown!DOMRangeException( akiko.all.attributes["weight"] );
	
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
	assertThrown!ValidationException( son.add(hobbies) );
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
	assertThrown!ValidationException( daughter.toSDLDocument() );
	assertThrown!ValidationException( kitty.toSDLDocument() );

	root.add( new Attribute("attributeNamespace", "attributeName", Value(3)) );
	assertThrown!ValidationException( root.toSDLDocument() );
	
	// But you can still convert such tags, or any other Tag, Attribute or Value,
	// to an SDLang string with 'toSDLString':
	// 
	// pet:cat "Neko"
	stdout.rawWrite( kitty.toSDLString() );
}
