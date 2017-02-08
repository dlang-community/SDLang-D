// SDLang-D
// Written in the D programming language.

module sdlang.schema;

import std.file;
import std.range;
import std.traits;
import std.variant;

import taggedalgebraic;

static import sdlang.ast;
import sdlang.exception;
import sdlang.parser;
import sdlang.token;
import sdlang.util;

struct TagOrAttr(TTag, TAttr)
{
	TTag tag;
	TAttr attr;
}

// UDAs
//TODO: For funcs that take a schema tag, check SchemaTag has @TagClass

struct Name { string name; }
struct Desc { string desc; }
struct Mixin { string mixinName; }
struct Partial { }
struct PartialMixin { }
struct Attribute { }
struct Value {}
struct Tag {}
struct TagClass {}
struct AnyTag {}
struct Opt { }
struct Root { }
struct Allow
{
	import std.datetime;

	// Neither Variant nor TaggedAlgebraic work at compile-time, so do it manually
	bool bool_;
	string string_;
	dchar dchar_;
	int int_;
	long long_;
	float float_;
	double double_;
	real real_;
	Date Date_;
	DateTimeFrac DateTimeFrac_;
	SysTime SysTime_;
	DateTimeFracUnknownZone DateTimeFracUnknownZone_;
	Duration Duration_;
	ubyte[] ubyteArray;
	typeof(null) null_;

	enum ValueType
	{
		bool_,
		string_,
		dchar_,
		int_,
		long_,
		float_,
		double_,
		real_,
		Date_,
		DateTimeFrac_,
		SysTime_,
		DateTimeFracUnknownZone_,
		Duration_,
		ubyteArray,
		null_,
	}
	ValueType type;

	this(T)(T val)
	{
		static if(is(T==bool))
		{
			bool_ = val;
			type = ValueType.bool_;
		}
		else static if(is(T==string))
		{
			string_ = val;
			type = ValueType.string_;
		}
		else static if(is(T==dchar))
		{
			dchar_ = val;
			type = ValueType.dchar_;
		}
		else static if(is(T==int))
		{
			int_ = val;
			type = ValueType.int_;
		}
		else static if(is(T==long))
		{
			long_ = val;
			type = ValueType.long_;
		}
		else static if(is(T==float))
		{
			float_ = val;
			type = ValueType.float_;
		}
		else static if(is(T==double))
		{
			double_ = val;
			type = ValueType.double_;
		}
		else static if(is(T==real))
		{
			real_ = val;
			type = ValueType.real_;
		}
		else static if(is(T==Date))
		{
			Date_ = val;
			type = ValueType.Date_;
		}
		else static if(is(T==DateTimeFrac))
		{
			DateTimeFrac_ = val;
			type = ValueType.DateTimeFrac_;
		}
		else static if(is(T==SysTime))
		{
			SysTime_ = val;
			type = ValueType.SysTime_;
		}
		else static if(is(T==DateTimeFracUnknownZone))
		{
			DateTimeFracUnknownZone_ = val;
			type = ValueType.DateTimeFracUnknownZone_;
		}
		else static if(is(T==Duration))
		{
			Duration_ = val;
			type = ValueType.Duration_;
		}
		else static if(is(T==ubyte[]))
		{
			ubyteArray = val;
			type = ValueType.ubyteArray;
		}
		else static if(is(T==typeof(null)))
		{
			null_ = val;
			type = ValueType.null_;
		}
		else
			static assert(0, "Unsupported type: "~T.stringof);
	}

	sdlang.token.Value toValue()
	{
		final switch(type)
		{
		case ValueType.bool_: return sdlang.token.Value(bool_);
		case ValueType.string_: return sdlang.token.Value(string_);
		case ValueType.dchar_: return sdlang.token.Value(dchar_);
		case ValueType.int_: return sdlang.token.Value(int_);
		case ValueType.long_: return sdlang.token.Value(long_);
		case ValueType.float_: return sdlang.token.Value(float_);
		case ValueType.double_: return sdlang.token.Value(double_);
		case ValueType.real_: return sdlang.token.Value(real_);
		case ValueType.Date_: return sdlang.token.Value(Date_);
		case ValueType.DateTimeFrac_: return sdlang.token.Value(DateTimeFrac_);
		case ValueType.SysTime_: return sdlang.token.Value(SysTime_);
		case ValueType.DateTimeFracUnknownZone_: return sdlang.token.Value(DateTimeFracUnknownZone_);
		case ValueType.Duration_: return sdlang.token.Value(Duration_);
		case ValueType.ubyteArray: return sdlang.token.Value(ubyteArray);
		case ValueType.null_: return sdlang.token.Value(null_);
		}
	}
}

// Parsing

SchemaTag parseFile(SchemaTag)(string filename)
{
	auto source = cast(string)read(filename);
	return parseSource!SchemaTag(source, filename);
}

SchemaTag parseSource(SchemaTag)(string source, string filename=null)
{
	auto tag = new SchemaTag();
	auto parseEvents = pullParseSource(source, filename);
	parseSource(tag, parseEvents, filename);
	return tag;
}

private void parseSource(SchemaTag, Range)(SchemaTag tag, ref Range parseEvents, string filename)
	if(isInputRange!Range)
{
import std.stdio;
	foreach(event; parseEvents)
	final switch(event.kind)
	{
	case ParserEvent.Kind.tagStart:
		auto e = cast(TagStartEvent) event;
		auto tagFullName = FullName.combine(e.namespace, e.name);
		auto safeName = sanitizeMemberName(tagFullName);

		writeln("SchemaTag: ", SchemaTag.stringof);
		writeln("tag safeName: ", safeName);
		// Set matching member variable
		bool found=false;
		foreach(memberName; __traits(allMembers, SchemaTag))
		if(memberName == safeName)
		{
			static if(hasUDA!(__traits(getMember, tag, memberName), sdlang.schema.Tag))
			{
				assert(!found);
				found = true;

				static if(hasUDA!(__traits(getMember, tag, memberName), sdlang.schema.TagOrAttr))
				{
					static if(isDynamicArray!(typeof(__traits(getMember, tag, memberName).tag)))
					{
						auto newTag = new ElementType!(typeof(__traits(getMember, tag, memberName).tag));
						__traits(getMember, tag, memberName).tag ~= newTag;
					}
					else
					{
						auto newTag = new typeof(__traits(getMember, tag, memberName).tag);
						__traits(getMember, tag, memberName).tag = newTag;
					}
				}
				else
				{
					static if(isDynamicArray!(typeof(__traits(getMember, tag, memberName))))
					{
						auto newTag = new ElementType!(typeof(__traits(getMember, tag, memberName)));
						__traits(getMember, tag, memberName) ~= newTag;
					}
					else
					{
						auto newTag = new typeof(__traits(getMember, tag, memberName));
						__traits(getMember, tag, memberName) = newTag;
					}
				}
				parseEvents.popFront();
				parseSource(newTag, parseEvents, filename);
				
				// Add to allTags
				tag.allTags ~= SchemaTag.AnyTag(newTag);
			}
		}
		if(!found)
			throw new ParseException(e.location,
				"Unexpected tag '"~tagFullName~"'");
		break;

	case ParserEvent.Kind.tagEnd:
		//TODO: Check for non-optional tags/attrs/values that are missing
		return;

	case ParserEvent.Kind.value:
		auto e = cast(ValueEvent) event;
		
		// Tag has member "value" which is marked with @Value?
		static if(hasMember!(SchemaTag, "value") && hasUDA!(tag.value, sdlang.schema.Value))
			storeValue(tag.value, e.value, null, e.location);
		else
			throw new ParseException(e.location, "This tag doesn't accept any values");
		break;

	case ParserEvent.Kind.attribute:
		auto e = cast(AttributeEvent) event;
		auto attrFullName = FullName.combine(e.namespace, e.name);
		auto safeName = sanitizeMemberName(attrFullName);

		//TODO: Validate value

		writeln("atr safeName: ", safeName);
		// Set matching member variable
		foreach(memberName; __traits(allMembers, SchemaTag))
		if(memberName == safeName)
		{
			static if(hasUDA!(__traits(getMember, tag, memberName), sdlang.schema.Attribute))
			{
				static if(hasUDA!(__traits(getMember, tag, memberName), sdlang.schema.TagOrAttr))
					storeValue(__traits(getMember, tag, memberName).attr, e.value, attrFullName, e.location);
				else
					storeValue(__traits(getMember, tag, memberName), e.value, attrFullName, e.location);
			}
		}

		//TODO: Error if no such attribute name exists for the tag

		// Add to allAttributes, if available
		static if(hasMember!(SchemaTag, "allAttributes"))
		{
			tag.allAttributes ~=
				new sdlang.ast.Attribute(e.namespace, e.name, e.value, e.location);
		}
		break;
	}
}

// attrFullName is null if this is just a value instead of an attribute
void storeValue(T)(ref T tagMember, sdlang.token.Value value, string attrFullName, Location location)
{
	static if(is(typeof(tagMember) == sdlang.token.Value))
	{
		tagMember = value;
	}
	else static if(is(typeof(tagMember) == sdlang.token.Value[]))
	{
		tagMember ~= value;
	}
	else if(typeid(typeof(tagMember)) == value.type)
	{
		tagMember = value.get!(typeof(tagMember));
	}
	else if(isDynamicArray!(typeof(tagMember)) &&
		typeid(ElementType!(typeof(tagMember))) == value.type)
	{
		tagMember ~= value.get!(ElementType!(typeof(tagMember)));
	}
	else
	{
		auto msg = (attrFullName is null)?
			"Wrong type for value. " :
			"Wrong type for attribute '"~attrFullName~"'. ";
			
		//TODO: Fix this message to use ElementType!T if tagMember is an AcceptsMultiple
		throw new ParseException(location,
			msg~"Should be '"~typeof(tagMember).stringof~"', not '"~value.type.toString~"'");
	}
}

// Output

alias toSDLString = sdlang.token.toSDLString;

string toSDLString(SchemaTag)(SchemaTag tag)
	if(is(SchemaTag==class) && hasUDA!(SchemaTag, sdlang.schema.TagClass))
{
	Appender!string sink;
	toSDLString(tag, sink);
	return sink.data;
}

//TODO: Validate (Or just leave it up to "Integrety check" functions)
void toSDLString(SchemaTag, Sink)(SchemaTag tag, ref Sink sink, string indent="\t", string fullIndent=null)
	if(is(SchemaTag==class) && hasUDA!(SchemaTag, sdlang.schema.TagClass) && isOutputRange!(Sink, char))
{
	enum isRoot = hasUDA!(SchemaTag, sdlang.schema.Root);
	static if(isRoot)
	{
		static if(hasMember!(SchemaTag, "allTags"))
			toSDLString(tag.allTags, sink, indent, fullIndent);
	}
	else
	{
		// Name
		sink.put(fullIndent);
		sink.put(getUDAs!(SchemaTag, sdlang.schema.Name)[0].name);
		sink.put(" ");

		// Values
		static if(hasMember!(SchemaTag, "value"))
		{
			//TODO: Ensure not root
			// I don't know WhyTF this FQN is needed even with the "alias toSDLString =..." up above. WTF?!?!
			sdlang.token.toSDLString(tag.value, sink);

			bool hasValues = false;
			static if(isDynamicArray!(typeof(tag.value)))
			if(tag.value.length > 0)
				hasValues = true;

			if(hasValues)
				sink.put(" ");
		}

		// Attributes
		static if(hasMember!(SchemaTag, "allAttributes"))
		if(tag.allAttributes.length > 0)
		{
			//TODO: Ensure not root
			sdlang.token.toSDLString(tag.allAttributes, sink);
			sink.put(" ");
		}

		// Children
		static if(hasMember!(SchemaTag, "allTags"))
		if(tag.allTags.length > 0)
		{
			// Open
			sink.put("{\n");

			// Tags
			auto newIndent = fullIndent ~ indent;
			toSDLString(tag.allTags, sink, indent, newIndent);

			// Close
			sink.put(fullIndent);
			sink.put("}");
		}	
	
		sink.put("\n");
	}
}

void toSDLString(TAnyTag, Sink)(TAnyTag[] tags, ref Sink sink, string indent="\t", string fullIndent=null)
	if(is(TAnyTag==struct) && isInstanceOf!(TaggedAlgebraic, TAnyTag) /+hasUDA!(TAnyTag, sdlang.schema.AnyTag)+/ && isOutputRange!(Sink, char))
{
	foreach(childTag; tags)
	foreach(i, T; Fields!(TAnyTag.Union))
	if(cast(int) childTag.kind == i)
		toSDLString(cast(T) childTag, sink, indent, fullIndent);
}

// Integrety check
//TODO: Validate root doesn't have values/attributes
//TODO: Validate it's valid SDL
//TODO: Validate it's valid schema
//TODO: Ensure allAttributes and allTags agree with other member vars


// Util

TypeInfo typeInfo(TA)(TA tagged) if(isInstanceOf!(TaggedAlgebraic, TA))
{

	auto kind = tagged.kind;
	return Fields!(TA.Union)[cast(int)kind].typeinfo;
	//foreach(i, memberName; TypeEnum!(TA.Union))
}

TypeInfo arrayTypeInfo(TA)(TA tagged) if(isInstanceOf!(TaggedAlgebraic, TA))
{
	auto kind = tagged.kind;
	return (Fields!(TA.Union)[cast(int)kind])[].typeinfo;
	//foreach(i, memberName; TypeEnum!(TA.Union))
}

string sanitizeTypeName(string name)
{
	//TODO: Imlement this for real

	switch(name)
	{
	case "allow-basic-types": return "AllowBasicTypes";
	case "val-common": return "ValCommon";
	case "attr-common": return "AttrCommon";
	case "opt-common": return "OptCommon";
	case "tag-variations": return "TagVariations";
	case "tag": return "TagVariations.Tag";
	case "tags": return "TagVariations.Tags";
	case "tag-opt": return "TagVariations.TagOpt";
	case "tags-opt": return "TagVariations.TagsOpt";
	case "tag-common": return "TagCommon";
	case "val": return "TagCommon.Val";
	case "vals": return "TagCommon.Vals";
	case "val-opt": return "TagCommon.ValOpt";
	case "vals-opt": return "TagCommon.ValsOpt";
	case "attr": return "TagCommon.Attr";
	case "attrs": return "TagCommon.Attrs";
	case "attr-opt": return "TagCommon.AttrOpt";
	case "attrs-opt": return "TagCommon.AttrsOpt";
	case "mixin": return "TagCommon.Mixin";
	case "partial": return "Partial";
	default: return name;
	}
}

string sanitizeMemberName(string name)
{
	//TODO: Imlement this for real

	switch(name)
	{
	case "allow-basic-types": return "allowBasicTypes";
	case "val-common": return "valCommon";
	case "attr-common": return "attrCommon";
	case "opt-common": return "optCommon";
	case "tag-variations": return "tagVariations";
	case "tag": return "tag";
	case "tags": return "tags";
	case "tag-opt": return "tagOpt";
	case "tags-opt": return "tagsOpt";
	case "tag-common": return "tagCommon";
	case "val": return "val";
	case "vals": return "vals";
	case "val-opt": return "valOpt";
	case "vals-opt": return "valsOpt";
	case "attr": return "attr";
	case "attrs": return "attrs";
	case "attr-opt": return "attrOpt";
	case "attrs-opt": return "attrsOpt";
	case "mixin": return "mixin_";
	case "partial": return "partial";
	default: return name;
	}
}

@("parse schema")
unittest
{
	import std.conv;
	import std.stdio;
	import sdlang.sdlangSchema;

	bool[string] membersOfObject;
	foreach(member; __traits(allMembers, Object))
		membersOfObject[member] = true;

	void writeTagMembers(TagType)(string varName, TagType tag)
	{
		writeln(TagType.stringof, " ", varName, ": ");
		foreach(name; __traits(allMembers, TagType))
		if(name !in membersOfObject)
			writeln("  ", name);
	}

	void writeArray(T)(string varName, T t)
	{
		import std.conv;
		write(varName);
		write(text(": len=", t.length));
		foreach(elem; t)
		{
			static if(hasMember!(typeof(elem), "value"))
				write("\n  ", elem.value);
			else static if(hasMember!(typeof(elem), "allAttributes"))
				write("\n  attrs: ", elem.allAttributes);
			else
				write("\n  NUTHIN");
		}
		writeln();
	}

	auto root = sdlang.sdlangSchema.parseFile!"sdlangSchema"("sdlangSchema.sdl");
	writeTagMembers("root", root);

	writeArray("root.mixin_", root.mixin_);
	writeArray("root.partial", root.partial);
	writeArray("root.tag", root.tag);
	writeArray("root.tags", root.tags);
	writeArray("root.tagOpt", root.tagOpt);
	writeArray("root.tagsOpt", root.tagsOpt);

	writeTagMembers("root.mixin_[0]", root.mixin_[0]);
	writeTagMembers("root.tagsOpt[0]", root.tagsOpt[0]);
	writeTagMembers("root.partial[0]", root.partial[0]);

	writeln("root.tagsOpt[0].value: ", root.tagsOpt[0].value);
	writeArray("root.tagsOpt[0].val", root.tagsOpt[0].val);
	writeln("root.tagsOpt[1].value: ", root.tagsOpt[1].value);
	writeArray("root.tagsOpt[1].val", root.tagsOpt[1].val);
	writeArray("root.tagsOpt[1].mixin_", root.tagsOpt[1].mixin_);

	writeln("---------------------------------");
	
	writeln(toSDLString(root));
}
