// SDLang-D
// Written in the D programming language.

module sdlang_.ast;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.string;

version(SDLang_Unittest)
version(unittest)
	import std.stdio;

import sdlang_.exception;
import sdlang_.token;
import sdlang_.util;

struct Attribute
{
	string   namespace;
	string   name;
	Location location;
	Value    value;

	@property string fullName()
	{
		return namespace==""? name : text(namespace, ":", name);
	}
	
	bool opEquals(Attribute a)
	{
		return opEquals(a);
	}
	bool opEquals(ref Attribute a)
	{
		return
			namespace == a.namespace &&
			name      == a.name      &&
			value     == a.value;
	}
	
	string toSDLString()()
	{
		Appender!string sink;
		this.toSDLString(sink);
		return sink.data;
	}

	void toSDLString(Sink)(ref Sink sink) if(isOutputRange!(Sink,char))
	{
		if(namespace != "")
		{
			sink.put(namespace);
			sink.put(':');
		}

		sink.put(name);
		sink.put('=');
		value.toSDLString(sink);
	}
}

class Tag
{
	static immutable defaultName = "content";

	Tag      parent;
	string   namespace;
	string   name;      /// Not including namespace
	Location location;
	Value[]  values;
	
	@property string fullName()
	{
		return namespace==""? name : text(namespace, ":", name);
	}

	this(Tag parent)
	{
		this.parent = parent;
	}

	this(
		Tag parent, string namespace, string name,
		Value[] values=null, Attribute[] attributes=null, Tag[] children=null
	)
	{
		this.parent    = parent;
		this.namespace = namespace;
		this.name      = name;
		
		this.values = values;
		this.add(attributes);
		this.add(children);
	}

	Attribute[] allAttributes; /// In same order as specified in SDL file.
	Tag[]       allTags;       /// In same order as specified in SDL file.
	string[]    allNamespaces; /// In same order as specified in SDL file.

	private size_t[][string] attributeIndicies; /// allAttributes[ attributes[namespace][i] ]
	private size_t[][string] tagIndicies;       /// allTags[ tags[namespace][i] ]

	private Attribute[][string][string] _attributes; /// attributes[namespace][name][i]
	private Tag[][string][string]       _tags;       /// tags[namespace][name][i]
	
	/// Returns 'this' for chaining
	Tag add(Value val)
	{
		values ~= val;
		return this;
	}
	
	///ditto
	Tag add(Value[] vals)
	{
		foreach(val; vals)
			add(val);

		return this;
	}
	
	///ditto
	Tag add(Attribute attr)
	{
		if(!allNamespaces.canFind(attr.namespace))
			allNamespaces ~= attr.namespace;
		
		allAttributes ~= attr;
		attributeIndicies[attr.namespace] ~= allAttributes.length-1;
		_attributes[attr.namespace][attr.name] ~= attr;
		
		return this;
	}
	
	///ditto
	Tag add(Attribute[] attrs)
	{
		foreach(attr; attrs)
			add(attr);

		return this;
	}
	
	///ditto
	Tag add(Tag tag)
	{
		if(!allNamespaces.canFind(tag.namespace))
			allNamespaces ~= tag.namespace;
		
		allTags ~= tag;
		tagIndicies[tag.namespace] ~= allTags.length-1;
		_tags[tag.namespace][tag.name] ~= tag;
		
		return this;
	}
	
	///ditto
	Tag add(Tag[] tags)
	{
		foreach(tag; tags)
			add(tag);

		return this;
	}
	
	struct MemberRange(T, string allMembers, string memberIndicies)
	{
		private Tag tag;
		private string namespace;

		this(Tag tag, string namespace)
		{
			this.tag = tag;
			this.namespace = namespace;
			frontIndex = 0;

			if(namespace in mixin("tag."~memberIndicies))
				endIndex = mixin("tag."~memberIndicies~"[namespace].length");
			else
				endIndex = 0;
		}
		
		@property bool empty()
		{
			return frontIndex == endIndex;
		}
		
		private size_t frontIndex;
		@property ref T front()
		{
			return this[0];
		}
		void popFront()
		{
			if(empty)
				throw new RangeError("Range is empty");

			frontIndex++;
		}

		private size_t endIndex; // One past the last element
		@property ref T back()
		{
			return this[$-1];
		}
		void popBack()
		{
			if(empty)
				throw new RangeError("Range is empty");

			endIndex--;
		}
		
		alias length opDollar;
		@property size_t length()
		{
			return endIndex - frontIndex;
		}
		
		@property typeof(this) save()
		{
			auto r = typeof(this)(this.tag, this.namespace);
			r.frontIndex = this.frontIndex;
			r.endIndex   = this.endIndex;
			return r;
		}
		
		ref T opIndex(size_t index)
		{
			if(empty)
				throw new RangeError("Range is empty");

			return mixin("tag."~allMembers~"[ tag."~memberIndicies~"[namespace][frontIndex+index] ]");
		}
	}
	alias MemberRange!(Attribute, "allAttributes", "attributeIndicies") AttributeRange;
	alias MemberRange!(Tag,       "allTags",       "tagIndicies"      ) TagRange;
	static assert(isRandomAccessRange!AttributeRange);
	static assert(isRandomAccessRange!TagRange);

	@property AttributeRange attributes()
	{
		return AttributeRange(this, "");
	}
	@property TagRange tags()
	{
		return TagRange(this, "");
	}
	
	struct NamespaceAccess
	{
		string name;
		AttributeRange attributes;
		TagRange tags;
	}
	
	struct NamespaceRange
	{
		private Tag tag;

		this(Tag tag)
		{
			this.tag = tag;
			frontIndex = 0;
			endIndex = tag.allNamespaces.length;
		}
		
		@property bool empty()
		{
			return frontIndex == endIndex;
		}
		
		private size_t frontIndex;
		@property NamespaceAccess front()
		{
			return this[0];
		}
		void popFront()
		{
			if(empty)
				throw new RangeError("Range is empty");
			
			frontIndex++;
		}

		private size_t endIndex; // One past the last element
		@property NamespaceAccess back()
		{
			return this[$-1];
		}
		void popBack()
		{
			if(empty)
				throw new RangeError("Range is empty");
			
			endIndex--;
		}
		
		alias length opDollar;
		@property size_t length()
		{
			return endIndex - frontIndex;
		}
		
		@property NamespaceRange save()
		{
			auto r = NamespaceRange(this.tag);
			r.frontIndex = this.frontIndex;
			r.endIndex   = this.endIndex;
			return r;
		}
		
		NamespaceAccess opIndex(size_t index)
		{
			if(empty)
				throw new RangeError("Range is empty");

			auto namespace = tag.allNamespaces[frontIndex+index];
			return NamespaceAccess(
				namespace,
				AttributeRange(tag, namespace),
				TagRange(tag, namespace)
			);
		}
	}
	static assert(isRandomAccessRange!NamespaceRange);
	@property NamespaceRange namespaces()
	{
		return NamespaceRange(this);
	}
	
	override bool opEquals(Object o)
	{
		auto t = cast(Tag)o;
		if(!t)
			return false;
		
		if(namespace != t.namespace || name != t.name)
			return false;

		if(
			values        .length != t.values       .length ||
			allAttributes .length != t.allAttributes.length ||
			allNamespaces .length != t.allNamespaces.length ||
			allTags       .length != t.allTags      .length
		)
			return false;
		
		if(values != t.values)
			return false;

		if(allNamespaces != t.allNamespaces)
			return false;

		if(allAttributes != t.allAttributes)
			return false;
		
		// Ok because cycles are not allowed
		//TODO: Actually check for or prevent cycles.
		return allTags == t.allTags;
	}
	
	/// Treats 'this' as the root tag. Note that root tags cannot have
	/// values or attributes, and cannot be part of a namespace.
	/// If this isn't a valid root tag, 'SDLangException' will be thrown.
	string toSDLDocument()(string indent="\t", int indentLevel=0)
	{
		Appender!string sink;
		toSDLDocument(sink, indent, indentLevel);
		return sink.data;
	}
	
	///ditto
	void toSDLDocument(Sink)(ref Sink sink, string indent="\t", int indentLevel=0)
		if(isOutputRange!(Sink,char))
	{
		if(values.length > 0)
			throw new SDLangException("Root tags cannot have any values, only child tags.");

		if(allAttributes.length > 0)
			throw new SDLangException("Root tags cannot have any attributes, only child tags.");

		if(namespace != "")
			throw new SDLangException("Root tags cannot have a namespace.");
		
		foreach(tagsByNamespace; _tags)
		foreach(tagsByName; tagsByNamespace)
		foreach(tag; tagsByName)
			tag.toSDLString(sink, indent, indentLevel);
	}
	
	/// Output this entire tag in SDL format. Does *not* treat 'this' as
	/// a root tag. If you intend this to be the root of a standard SDL
	/// document, use 'toSDLDocument' instead.
	string toSDLString()(string indent="\t", int indentLevel=0)
	{
		Appender!string sink;
		toSDLString(sink, indent, indentLevel);
		return sink.data;
	}
	
	///ditto
	private void toSDLString(Sink)(ref Sink sink, string indent="\t", int indentLevel=0)
		if(isOutputRange!(Sink,char))
	{
		if(name == "" && values.length == 0)
			throw new SDLangException("Anonymous tags must have at least one value.");
		
		if(name == "" && namespace != "")
			throw new SDLangException("Anonymous tags cannot have a namespace.");
	
		// Indent
		foreach(i; 0..indentLevel)
			sink.put(indent);
		
		// Name
		if(namespace != "")
		{
			sink.put(namespace);
			sink.put(':');
		}
		sink.put(name);
		
		// Values
		foreach(i, v; values)
		{
			// Omit the first space for anonymous tags
			if(name != "" || i > 0)
				sink.put(' ');
			
			v.toSDLString(sink);
		}
		
		// Attributes
		foreach(attrsByNamespace; _attributes)
		foreach(attrsByName; attrsByNamespace)
		foreach(attr; attrsByName)
		{
			sink.put(' ');
			attr.toSDLString(sink);
		}
		
		// Child tags
		bool foundChild=false;
		foreach(tagsByNamespace; _tags)
		foreach(tagsByName; tagsByNamespace)
		foreach(tag; tagsByName)
		{
			if(!foundChild)
			{
				sink.put(" {\n");
				foundChild = true;
			}

			tag.toSDLString(sink, indent, indentLevel+1);
		}
		if(foundChild)
		{
			foreach(i; 0..indentLevel)
				sink.put(indent);

			sink.put("}\n");
		}
		else
			sink.put("\n");
	}

	/// Not the most efficient, but it works.
	string toDebugString()
	{
		Appender!string buf;
		
		buf.put("\n");
		buf.put("Tag ");
		if(namespace != "")
		{
			buf.put("[");
			buf.put(namespace);
			buf.put("]");
		}
		buf.put("'%s':\n".format(name));

		// Values
		foreach(val; values)
			buf.put("    (%s): %s\n".format(.toString(val.type), val));

		// Attributes
		foreach(attrNamespace; _attributes.keys.sort)
		foreach(attrName; _attributes[attrNamespace].keys.sort)
		foreach(attr; _attributes[attrNamespace][attrName])
		{
			string namespaceStr;
			if(attr.namespace != "")
				namespaceStr = "["~attr.namespace~"]";
			
			buf.put(
				"    %s%s(%s): %s\n".format(
					namespaceStr, attr.name, .toString(attr.value.type), attr.value
				)
			);
		}
		
		// Children
		foreach(tagNamespace; _tags.keys.sort)
		foreach(tagName; _tags[tagNamespace].keys.sort)
		foreach(tag; _tags[tagNamespace][tagName])
			buf.put( tag.toDebugString().replace("\n", "\n    ") );
		
		return buf.data;
	}
}

version(SDLang_Unittest)
unittest
{
	import sdlang_.parser;
	writeln("Unittesting sdlang ast...");
	stdout.flush();
	
	void testRandomAccessRange(R, E)(R range, E[] expected, bool function(E, E) equals=null)
	{
		static assert(isRandomAccessRange!R);
		static assert(is(ElementType!R == E));
		static assert(hasLength!R);
		static assert(!isInfinite!R);

		assert(range.length == expected.length);
		if(range.length == 0)
		{
			assert(range.empty);
			return;
		}
		
		static bool defaultEquals(E e1, E e2)
		{
			return e1 == e2;
		}
		if(equals is null)
			equals = &defaultEquals;
		
		assert(equals(range.front, expected[0]));
		assert(equals(range.front, expected[0]));  // Ensure consistent result from '.front'
		assert(equals(range.front, expected[0]));  // Ensure consistent result from '.front'

		assert(equals(range.back, expected[$-1]));
		assert(equals(range.back, expected[$-1]));  // Ensure consistent result from '.back'
		assert(equals(range.back, expected[$-1]));  // Ensure consistent result from '.back'
		
		// Forward iteration
		auto original = range.save;
		auto r2 = range.save;
		foreach(i; 0..expected.length)
		{
			//trace("Forward iteration: ", i);
			
			// Test length/empty
			assert(range.length == expected.length - i);
			assert(range.length == r2.length);
			assert(!range.empty);
			assert(!r2.empty);
			
			// Test front
			assert(equals(range.front, expected[i]));
			assert(equals(range.front, r2.front));

			// Test back
			assert(equals(range.back, expected[$-1]));
			assert(equals(range.back, r2.back));

			// Test opIndex(0)
			assert(equals(range[0], expected[i]));
			assert(equals(range[0], r2[0]));

			// Test opIndex($-1)
			assert(equals(range[$-1], expected[$-1]));
			assert(equals(range[$-1], r2[$-1]));

			// Test popFront
			range.popFront();
			assert(range.length == r2.length - 1);
			r2.popFront();
			assert(range.length == r2.length);
		}
		assert(range.empty);
		assert(r2.empty);
		assert(original.length == expected.length);
		
		// Backwards iteration
		range = original.save;
		r2    = original.save;
		foreach(i; iota(0, expected.length).retro())
		{
			//trace("Backwards iteration: ", i);

			// Test length/empty
			assert(range.length == i+1);
			assert(range.length == r2.length);
			assert(!range.empty);
			assert(!r2.empty);
			
			// Test front
			assert(equals(range.front, expected[0]));
			assert(equals(range.front, r2.front));

			// Test back
			assert(equals(range.back, expected[i]));
			assert(equals(range.back, r2.back));

			// Test opIndex(0)
			assert(equals(range[0], expected[0]));
			assert(equals(range[0], r2[0]));

			// Test opIndex($-1)
			assert(equals(range[$-1], expected[i]));
			assert(equals(range[$-1], r2[$-1]));

			// Test popBack
			range.popBack();
			assert(range.length == r2.length - 1);
			r2.popBack();
			assert(range.length == r2.length);
		}
		assert(range.empty);
		assert(r2.empty);
		assert(original.length == expected.length);
		
		// Random access
		range = original.save;
		r2    = original.save;
		foreach(i; 0..expected.length)
		{
			//trace("Random access: ", i);

			// Test length/empty
			assert(range.length == expected.length);
			assert(range.length == r2.length);
			assert(!range.empty);
			assert(!r2.empty);
			
			// Test front
			assert(equals(range.front, expected[0]));
			assert(equals(range.front, r2.front));

			// Test back
			assert(equals(range.back, expected[$-1]));
			assert(equals(range.back, r2.back));

			// Test opIndex(i)
			assert(equals(range[i], expected[i]));
			assert(equals(range[i], r2[i]));
		}
		assert(!range.empty);
		assert(!r2.empty);
		assert(original.length == expected.length);
	}

	Tag root;
	root = parseSource("");
	testRandomAccessRange(root.attributes, cast(          Attribute[])[]);
	testRandomAccessRange(root.tags,       cast(                Tag[])[]);
	testRandomAccessRange(root.namespaces, cast(Tag.NamespaceAccess[])[]);
	
	root = parseSource(`
		blue 3 "Lee" isThree=true
		blue 5 "Chan" 12345 isThree=false
		stuff:orange 1 2 3 2 1
		stuff:square points=4 dimensions=2 points="Still four"
		stuff:triangle data:points=3 data:dimensions=2
		nothing
		namespaces small:A=1 med:A=2 big:A=3 small:B=10 big:B=30
		
		people visitor:a=1 b=2 {
			chiyo "Small" "Flies?" nemesis="Car" score=100
			yukari
			visitor:sana
			tomo
			visitor:hayama
		}
	`);

	auto loc = Location(0, 0, 0);
	auto blue3 = new Tag(
		null, "", "blue",
		[ Value(3), Value("Lee") ],
		[ Attribute("", "isThree", loc, Value(true)) ],
		null
	);
	auto blue5 = new Tag(
		null, "", "blue",
		[ Value(5), Value("Chan"), Value(12345) ],
		[ Attribute("", "isThree", loc, Value(false)) ],
		null
	);
	auto orange = new Tag(
		null, "stuff", "orange",
		[ Value(1), Value(2), Value(3), Value(2), Value(1) ],
		null,
		null
	);
	auto square = new Tag(
		null, "stuff", "square",
		null,
		[
			Attribute("", "points", loc, Value(4)),
			Attribute("", "dimensions", loc, Value(2)),
			Attribute("", "points", loc, Value("Still four")),
		],
		null
	);
	auto triangle = new Tag(
		null, "stuff", "triangle",
		null,
		[
			Attribute("data", "points", loc, Value(3)),
			Attribute("data", "dimensions", loc, Value(2)),
		],
		null
	);
	auto nothing = new Tag(
		null, "", "nothing",
		null, null, null
	);
	auto namespaces = new Tag(
		null, "", "namespaces",
		null,
		[
			Attribute("small", "A", loc, Value(1)),
			Attribute("med",   "A", loc, Value(2)),
			Attribute("big",   "A", loc, Value(3)),
			Attribute("small", "B", loc, Value(10)),
			Attribute("big",   "B", loc, Value(30)),
		],
		null
	);
	auto chiyo = new Tag(
		null, "", "chiyo",
		[ Value("Small"), Value("Flies?") ],
		[
			Attribute("", "nemesis", loc, Value("Car")),
			Attribute("", "score", loc, Value(100)),
		],
		null
	);
	auto yukari = new Tag(
		null, "", "yukari",
		null, null, null
	);
	auto sana = new Tag(
		null, "visitor", "sana",
		null, null, null
	);
	auto tomo = new Tag(
		null, "", "tomo",
		null, null, null
	);
	auto hayama = new Tag(
		null, "visitor", "hayama",
		null, null, null
	);
	auto people = new Tag(
		null, "", "people",
		null,
		[
			Attribute("visitor", "a", loc, Value(1)),
			Attribute("", "b", loc, Value(2)),
		],
		[chiyo, yukari, sana, tomo, hayama]
	);
	
	assert(blue3      .opEquals( blue3      ));
	assert(blue5      .opEquals( blue5      ));
	assert(orange     .opEquals( orange     ));
	assert(square     .opEquals( square     ));
	assert(triangle   .opEquals( triangle   ));
	assert(nothing    .opEquals( nothing    ));
	assert(namespaces .opEquals( namespaces ));
	assert(people     .opEquals( people     ));
	assert(chiyo      .opEquals( chiyo      ));
	assert(yukari     .opEquals( yukari     ));
	assert(sana       .opEquals( sana       ));
	assert(tomo       .opEquals( tomo       ));
	assert(hayama     .opEquals( hayama     ));
	
	assert(!blue3.opEquals(orange));
	assert(!blue3.opEquals(people));
	assert(!blue3.opEquals(sana));
	assert(!blue3.opEquals(blue5));
	assert(!blue5.opEquals(blue3));
	
	alias Tag.NamespaceAccess NSA;
	static bool namespaceEquals(NSA n1, NSA n2)
	{
		return n1.name == n2.name;
	}
	
	testRandomAccessRange(root.attributes, cast(Attribute[])[]);
	testRandomAccessRange(root.tags,       [blue3, blue5, nothing, namespaces, people]);
	testRandomAccessRange(root.namespaces, [NSA(""), NSA("stuff")], &namespaceEquals);
	testRandomAccessRange(root.namespaces[0].tags, [blue3, blue5, nothing, namespaces, people]);
	testRandomAccessRange(root.namespaces[1].tags, [orange, square, triangle]);

	testRandomAccessRange(blue3.attributes, [ Attribute("", "isThree", loc, Value(true)) ]);
	testRandomAccessRange(blue3.tags,       cast(Tag[])[]);
	testRandomAccessRange(blue3.namespaces, [NSA("")], &namespaceEquals);
	
	testRandomAccessRange(blue5.attributes, [ Attribute("", "isThree", loc, Value(false)) ]);
	testRandomAccessRange(blue5.tags,       cast(Tag[])[]);
	testRandomAccessRange(blue5.namespaces, [NSA("")], &namespaceEquals);
	
	testRandomAccessRange(orange.attributes, cast(Attribute[])[]);
	testRandomAccessRange(orange.tags,       cast(Tag[])[]);
	testRandomAccessRange(orange.namespaces, cast(NSA[])[], &namespaceEquals);
	
	testRandomAccessRange(square.attributes, [
		Attribute("", "points", loc, Value(4)),
		Attribute("", "dimensions", loc, Value(2)),
		Attribute("", "points", loc, Value("Still four")),
	]);
	testRandomAccessRange(square.tags,       cast(Tag[])[]);
	testRandomAccessRange(square.namespaces, [NSA("")], &namespaceEquals);
	
	testRandomAccessRange(triangle.attributes, cast(Attribute[])[]);
	testRandomAccessRange(triangle.tags,       cast(Tag[])[]);
	testRandomAccessRange(triangle.namespaces, [NSA("data")], &namespaceEquals);
	testRandomAccessRange(triangle.namespaces[0].attributes, [
		Attribute("data", "points", loc, Value(3)),
		Attribute("data", "dimensions", loc, Value(2)),
	]);
	
	testRandomAccessRange(nothing.attributes, cast(Attribute[])[]);
	testRandomAccessRange(nothing.tags,       cast(Tag[])[]);
	testRandomAccessRange(nothing.namespaces, cast(NSA[])[], &namespaceEquals);
	
	testRandomAccessRange(namespaces.attributes, cast(Attribute[])[]);
	testRandomAccessRange(namespaces.tags,       cast(Tag[])[]);
	testRandomAccessRange(namespaces.namespaces, [NSA("small"), NSA("med"), NSA("big")], &namespaceEquals);
	testRandomAccessRange(namespaces.namespaces[0].attributes, [
		Attribute("small", "A", loc, Value(1)),
		Attribute("small", "B", loc, Value(10)),
	]);
	testRandomAccessRange(namespaces.namespaces[1].attributes, [
		Attribute("med", "A", loc, Value(2)),
	]);
	testRandomAccessRange(namespaces.namespaces[2].attributes, [
		Attribute("big", "A", loc, Value(3)),
		Attribute("big", "B", loc, Value(30)),
	]);

	testRandomAccessRange(chiyo.attributes, [
		Attribute("", "nemesis", loc, Value("Car")),
		Attribute("", "score", loc, Value(100)),
	]);
	testRandomAccessRange(chiyo.tags,       cast(Tag[])[]);
	testRandomAccessRange(chiyo.namespaces, [NSA("")], &namespaceEquals);
	
	testRandomAccessRange(yukari.attributes, cast(Attribute[])[]);
	testRandomAccessRange(yukari.tags,       cast(Tag[])[]);
	testRandomAccessRange(yukari.namespaces, cast(NSA[])[], &namespaceEquals);
	
	testRandomAccessRange(sana.attributes, cast(Attribute[])[]);
	testRandomAccessRange(sana.tags,       cast(Tag[])[]);
	testRandomAccessRange(sana.namespaces, cast(NSA[])[], &namespaceEquals);
	
	testRandomAccessRange(people.attributes,         [Attribute("", "b", loc, Value(2))]);
	testRandomAccessRange(people.tags,               [chiyo, yukari, tomo]);
	testRandomAccessRange(people.namespaces,         [NSA("visitor"), NSA("")], &namespaceEquals);
	testRandomAccessRange(people.namespaces[0].attributes, [Attribute("visitor", "a", loc, Value(1))]);
	testRandomAccessRange(people.namespaces[1].attributes, [Attribute("", "b", loc, Value(2))]);
	testRandomAccessRange(people.namespaces[0].tags,       [sana, hayama]);
	testRandomAccessRange(people.namespaces[1].tags,       [chiyo, yukari, tomo]);
}
