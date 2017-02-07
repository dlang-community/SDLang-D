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

struct Name { string name; }
struct Desc { string desc; }
struct Mixin { string mixinName; }
struct Partial { }
struct PartialMixin { }
struct Attribute { }
struct Value {}
struct Tag {}
struct Opt { }
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
		foreach(memberName; __traits(allMembers, SchemaTag)) {
		//writeln("memberName: ", memberName);
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
			}
			
		}}
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
		{
			//TODO: Merge this with corresponding section in ParserEvent.Kind.attribute:
			//      They're identical aside from exception message
			static if(is(typeof(tag.value) == sdlang.token.Value))
			{
				tag.value = e.value;
			}
			else static if(is(typeof(tag.value) == sdlang.token.Value[]))
			{
				tag.value ~= e.value;
			}
			else if(typeid(typeof(tag.value)) == e.value.type)
			{
				tag.value = e.value.get!(typeof(tag.value));
			}
			else if(isDynamicArray!(typeof(tag.value)) &&
				typeid(ElementType!(typeof(tag.value))) == e.value.type)
			{
				tag.value ~= e.value.get!(ElementType!(typeof(tag.value)));
			}
			else
			{
				//TODO: Fix this message to use ElementType!T if tag.value is an AcceptsMultiple
				throw new ParseException(e.location,
					"Wrong type for value. "~
					"Should be '"~typeof(tag.value).stringof~"', not '"~e.value.type.toString~"'");
			}
		}
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
					auto member = __traits(getMember, tag, memberName).attr;
				else
					auto member = __traits(getMember, tag, memberName);

				//TODO: Merge this with corresponding section in ParserEvent.Kind.value:
				//      They're identical aside from exception message
				static if(is(typeof(member) == sdlang.token.Value))
				{
					member = e.value;
				}
				else static if(is(typeof(member) == sdlang.token.Value[]))
				{
					member ~= e.value;
				}
				else if(typeid(typeof(member)) == e.value.type)
				{
					member = e.value.get!(typeof(member));
				}
				else if(isDynamicArray!(typeof(member)) &&
					typeid(ElementType!(typeof(member))) == e.value.type)
				{
					member ~= e.value.get!(ElementType!(typeof(member)));
				}
				else
				{
					//TODO: Fix this message to use ElementType!T if member is an AcceptsMultiple
					throw new ParseException(e.location,
						"Wrong type for attribute '"~attrFullName~"'. "~
						"Should be '"~typeof(member).stringof~"', not '"~e.value.type.toString~"'");
				}
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
	import std.stdio;
	import sdlang.sdlangSchema;
	auto root = sdlang.sdlangSchema.parseFile!"sdlangSchema"("sdlangSchema.sdl");
	writeln("root: ", root);
	writeln("__traits(allMembers, root): \n");
	foreach(name; __traits(allMembers, typeof(root)))
		writeln("  ", name);

	string makeStr(T)(T t)
	{
		import std.conv;
		string str = text("len=", t.length);
		foreach(elem; t)
		{
			str ~= "\n  ";
			str ~= elem.value;
		}
		return str;
	}

	writeln("root.mixin_: ", makeStr(root.mixin_));
	writeln("root.partial: ", makeStr(root.partial));
	writeln("root.tag: ", makeStr(root.tag));
	writeln("root.tags: ", makeStr(root.tags));
	writeln("root.tagOpt: ", makeStr(root.tagOpt));
	writeln("root.tagsOpt: ", makeStr(root.tagsOpt));
}
