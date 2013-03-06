// SDLang-D
// Written in the D programming language.

module sdlang_.ast;

import std.array;
import std.conv;
import std.range;
import std.string;

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
	
	string toSDLString()()
	{
		Appender!string sink;
		toSDLString(sink);
		return sink.data;
	}

	void toSDLString(Sink)(ref Sink sink, string indent="\t", int indentLevel=0) if(isOutputRange!(Sink,char))
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
		foreach(attrsByNamespace; attributes)
		foreach(attrsByName; attrsByNamespace)
		foreach(attr; attrsByName)
		{
			sink.put(' ');
			attr.toSDLString(sink);
		}
		
		// Child tags
		bool foundChild=false;
		foreach(tagsByNamespace; tags)
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
