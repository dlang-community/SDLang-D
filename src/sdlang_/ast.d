// SDLang-D
// Written in the D programming language.

module sdlang_.ast;

import std.array;
import std.conv;
import std.string;

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

	Attribute[][string][string] attributes; /// attributes[namespace][name][0..$]
	Tag[][string][string]       tags;       /// tags[namespace][name][0..$]

	this(Tag parent)
	{
		this.parent = parent;
	}

	this(Tag parent, string namespace, string name)
	{
		this.parent    = parent;
		this.namespace = namespace;
		this.name      = name;
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
		foreach(attrNamespace; attributes.keys.sort)
		foreach(attrName; attributes[attrNamespace].keys.sort)
		foreach(attr; attributes[attrNamespace][attrName])
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
		foreach(tagNamespace; tags.keys.sort)
		foreach(tagName; tags[tagNamespace].keys.sort)
		foreach(tag; tags[tagNamespace][tagName])
			buf.put( tag.toDebugString().replace("\n", "\n    ") );
		
		return buf.data;
	}
}
