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
{
	import std.stdio;
	import std.exception;
}

import sdlang_.exception;
import sdlang_.token;
import sdlang_.util;

//TODO: This needs to know it's parent tag so it can update the tag upon name/namespace changes.
//      Also, when that's done, move "remove attribute from tag" from 'Tag.remove(Attribute)' into here.
struct Attribute
{
	string   namespace;
	string   name;
	Value    value;
	Location location;
	
	this(string namespace, string name, Value value, Location location = Location(0, 0, 0))
	{
		this.namespace = namespace;
		this.name      = name;
		this.location  = location;
		this.value     = value;
	}
	
	this(string name, Value value, Location location = Location(0, 0, 0))
	{
		this.namespace = "";
		this.name      = name;
		this.location  = location;
		this.value     = value;
	}
	
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
	Location location;
	Value[]  values;

	private string _namespace;
	@property string namespace()
	{
		return _namespace;
	}
	// This shouldn't be public until it's adjusted to properly update the parent.
	private @property void namespace(string value)
	{
		_namespace = value;

		if(parent)
		{
			parent.updateId++;
			//TODO: Adjust parent's 'tagIndicies' and '_tags'
		}
	}
	
	/// Not including namespace. Use 'fullName' if you want the namespace included.
	private string _name;
	@property string name()
	{
		return _name;
	}
	// This shouldn't be public until it's adjusted to properly update the parent.
	private @property void name(string value)
	{
		_name = value;
		if(parent)
		{
			parent.updateId++;
			//TODO: Adjust parent's '_tags'
		}
	}
	
	// Tracks dirtiness. This is incremented every time a change is made which
	// could invalidate existing ranges. This way, the ranges can detect when
	// they've been invalidated.
	private size_t updateId=0;
	
	/// This tag's name, including namespace if one exists.
	@property string fullName()
	{
		return _namespace==""? _name : text(_namespace, ":", _name);
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
		this.parent     = parent;
		this._namespace = namespace;
		this._name      = name;
		
		this.values = values;
		this.add(attributes);
		this.add(children);
	}

	private Attribute[] allAttributes; // In same order as specified in SDL file.
	private Tag[]       allTags;       // In same order as specified in SDL file.
	private string[]    allNamespaces; // In same order as specified in SDL file.

	private size_t[][string] attributeIndicies; // allAttributes[ attributes[namespace][i] ]
	private size_t[][string] tagIndicies;       // allTags[ tags[namespace][i] ]

	private Attribute[][string][string] _attributes; // attributes[namespace or "*"][name][i]
	private Tag[][string][string]       _tags;       // tags[namespace or "*"][name][i]
	
	/// Returns 'this' for chaining
	Tag add(Value val)
	{
		values ~= val;
		updateId++;
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
		_attributes["*"]           [attr.name] ~= attr;

		updateId++;
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
		if(!allNamespaces.canFind(tag._namespace))
			allNamespaces ~= tag._namespace;
		
		allTags ~= tag;
		tagIndicies[tag._namespace] ~= allTags.length-1;
		_tags[tag._namespace][tag._name] ~= tag;
		_tags["*"]           [tag._name] ~= tag;
		
		tag.parent = this;
		
		updateId++;
		return this;
	}
	
	///ditto
	Tag add(Tag[] tags)
	{
		foreach(tag; tags)
			add(tag);

		return this;
	}
	
	/// Removes 'this' from its parent (if any). Returns 'this' for convenience.
	// Inefficient ATM, but it works.
	Tag remove()
	{
		if(!parent)
			return this;
		
		void removeFromGroupedLookup(string ns)
		{
			// Remove from parent._tags[ns]
			auto sameNameTags = parent._tags[ns][_name];
			auto targetIndex = sameNameTags.length - sameNameTags.find(this).length;
			parent._tags[ns][_name] = sameNameTags[0..targetIndex] ~ sameNameTags[targetIndex+1..$];
		}
		
		// Remove from parent._tags
		removeFromGroupedLookup(_namespace);
		removeFromGroupedLookup("*");

		// Remove from parent.allTags
		auto allTagsIndex = parent.allTags.length - parent.allTags.find(this).length;
		parent.allTags = parent.allTags[0..allTagsIndex] ~ parent.allTags[allTagsIndex+1..$];

		// Remove from parent.tagIndicies
		auto sameNamespaceTags = parent.tagIndicies[_namespace];
		auto tagIndiciesIndex = sameNamespaceTags.length - sameNamespaceTags.find(allTagsIndex).length;
		parent.tagIndicies[_namespace] = sameNamespaceTags[0..tagIndiciesIndex] ~ sameNamespaceTags[tagIndiciesIndex+1..$];
		
		// Fixup other indicies
		foreach(ns, ref nsTagIndicies; parent.tagIndicies)
		foreach(k, ref v; nsTagIndicies)
		if(v > allTagsIndex)
			v--;
		
		// If namespace has no tags, remove it from parent.tagIndicies/parent._tags
		if(parent.tagIndicies[_namespace].length == 0)
		{
			parent.tagIndicies.remove(_namespace);
			parent._tags.remove(_namespace);
		}
		
		// If namespace is now empty, remove it from allNamespaces
		if(
			_namespace !in parent.tagIndicies &&
			_namespace !in parent.attributeIndicies
		)
		{
			auto allNamespacesIndex = parent.allNamespaces.length - parent.allNamespaces.find(_namespace).length;
			parent.allNamespaces = parent.allNamespaces[0..allNamespacesIndex] ~ parent.allNamespaces[allNamespacesIndex+1..$];
		}
		
		parent.updateId++;
		return this;
	}
	
	/// Removes an attribute from this tag. Returns the attribute for convenience.
	/// Throws SDLangException if attribute not found.
	// Inefficient ATM, but it works.
	Attribute remove(Attribute attr)
	{
		Attribute origAttr;
		void removeFromGroupedLookup(string ns)
		{
			// Remove from _attributes[ns]
			auto sameNameAttrs = _attributes[ns][attr.name];
			auto foundRange = sameNameAttrs.find(attr);

			if(foundRange.length == 0)
				throw new SDLangException("Cannot remove Attribute: Not found.");
			
			auto targetIndex = sameNameAttrs.length - foundRange.length;
			origAttr = sameNameAttrs[targetIndex];
			_attributes[ns][attr.name] = sameNameAttrs[0..targetIndex] ~ sameNameAttrs[targetIndex+1..$];
		}
		
		// Remove from _attributes
		removeFromGroupedLookup(attr.namespace);
		removeFromGroupedLookup("*");

		// Remove from allAttributes
		auto allAttrsIndex = allAttributes.length - allAttributes.find(attr).length;
		allAttributes = allAttributes[0..allAttrsIndex] ~ allAttributes[allAttrsIndex+1..$];

		// Remove from attributeIndicies
		auto sameNamespaceAttrs = attributeIndicies[attr.namespace];
		auto attrIndiciesIndex = sameNamespaceAttrs.length - sameNamespaceAttrs.find(allAttrsIndex).length;
		attributeIndicies[attr.namespace] = sameNamespaceAttrs[0..attrIndiciesIndex] ~ sameNamespaceAttrs[attrIndiciesIndex+1..$];
		
		// Fixup other indicies
		foreach(ns, ref nsAttrIndicies; attributeIndicies)
		foreach(k, ref v; nsAttrIndicies)
		if(v > allAttrsIndex)
			v--;
		
		// If namespace is has no attributes, remove it from attributeIndicies/_attributes
		if(attributeIndicies[attr.namespace].length == 0)
		{
			attributeIndicies.remove(attr.namespace);
			_attributes.remove(attr.namespace);
		}

		// If namespace is now empty, remove from allNamespaces
		if(
			attr.namespace !in tagIndicies &&
			attr.namespace !in attributeIndicies
		)
		{
			auto allNamespacesIndex = allNamespaces.length - allNamespaces.find(attr.namespace).length;
			allNamespaces = allNamespaces[0..allNamespacesIndex] ~ allNamespaces[allNamespacesIndex+1..$];
		}
		
		updateId++;
		return origAttr;
	}
	
	struct NamedMemberRange(T, string membersGrouped)
	{
		private Tag tag;
		private string namespace; // "*" indicates "all namespaces" (ok since it's not a valid namespace name)
		private string name;
		private size_t updateId;  // Tag's updateId when this range was created.

		this(Tag tag, string namespace, string name, size_t updateId)
		{
			this.tag       = tag;
			this.namespace = namespace;
			this.name      = name;
			this.updateId  = updateId;
			frontIndex = 0;

			if(
				namespace in mixin("tag."~membersGrouped) &&
				name in mixin("tag."~membersGrouped~"[namespace]")
			)
				endIndex = mixin("tag."~membersGrouped~"[namespace][name].length");
			else
				endIndex = 0;
		}
		
		invariant()
		{
			assert(
				this.updateId == tag.updateId,
				"This range has been invalidated by a change to the tag."
			);
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
			auto r = typeof(this)(this.tag, this.namespace, this.name, this.updateId);
			r.frontIndex = this.frontIndex;
			r.endIndex   = this.endIndex;
			return r;
		}
		
		typeof(this) opSlice()
		{
			return save();
		}
		
		typeof(this) opSlice(size_t start, size_t end)
		{
			auto r = save();
			r.frontIndex = this.frontIndex + start;
			r.endIndex   = this.frontIndex + end;
			
			if(
				r.frontIndex > this.endIndex ||
				r.endIndex > this.endIndex ||
				r.frontIndex > r.endIndex
			)
				throw new RangeError("Slice out of range");
			
			return r;
		}

		ref T opIndex(size_t index)
		{
			if(empty)
				throw new RangeError("Range is empty");

			return mixin("tag."~membersGrouped~"[namespace][name][frontIndex+index]");
		}
	}

	struct MemberRange(T, string allMembers, string memberIndicies, string membersGrouped)
	{
		private Tag tag;
		private string namespace; // "*" indicates "all namespaces" (ok since it's not a valid namespace name)
		private bool isMaybe;
		private size_t updateId;  // Tag's updateId when this range was created.
		private size_t initialEndIndex;

		this(Tag tag, string namespace, bool isMaybe)
		{
			this.tag       = tag;
			this.namespace = namespace;
			this.updateId  = tag.updateId;
			this.isMaybe   = isMaybe;
			frontIndex = 0;

			if(namespace == "*")
				initialEndIndex = mixin("tag."~allMembers~".length");
			else if(namespace in mixin("tag."~memberIndicies))
				initialEndIndex = mixin("tag."~memberIndicies~"[namespace].length");
			else
				initialEndIndex = 0;
			
			endIndex = initialEndIndex;
		}
		
		invariant()
		{
			assert(
				this.updateId == tag.updateId,
				"This range has been invalidated by a change to the tag."
			);
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
			auto r = typeof(this)(this.tag, this.namespace, this.isMaybe);
			r.frontIndex      = this.frontIndex;
			r.endIndex        = this.endIndex;
			r.initialEndIndex = this.initialEndIndex;
			r.updateId        = this.updateId;
			return r;
		}
		
		typeof(this) opSlice()
		{
			return save();
		}
		
		typeof(this) opSlice(size_t start, size_t end)
		{
			auto r = save();
			r.frontIndex = this.frontIndex + start;
			r.endIndex   = this.frontIndex + end;
			
			if(
				r.frontIndex > this.endIndex ||
				r.endIndex > this.endIndex ||
				r.frontIndex > r.endIndex
			)
				throw new RangeError("Slice out of range");
			
			return r;
		}
		
		ref T opIndex(size_t index)
		{
			if(empty)
				throw new RangeError("Range is empty");

			if(namespace == "*")
				return mixin("tag."~allMembers~"[ frontIndex+index ]");
			else
				return mixin("tag."~allMembers~"[ tag."~memberIndicies~"[namespace][frontIndex+index] ]");
		}
		
		alias NamedMemberRange!(T,membersGrouped) ThisNamedMemberRange;
		ThisNamedMemberRange opIndex(string name)
		{
			if(frontIndex != 0 || endIndex != initialEndIndex)
			{
				throw new SDLangException(
					"Cannot lookup tags/attributes by name on a subset of a range, "~
					"only across the entire tag. "~
					"Please make sure you haven't called popFront or popBack on this "~
					"range and that you aren't using a slice of the range."
				);
			}
			
			if(!isMaybe && empty)
				throw new RangeError("Range is empty");
			
			if(!isMaybe && name !in this)
				throw new RangeError(`No such `~T.stringof~` named: "`~namespace~`"`);

			return ThisNamedMemberRange(tag, namespace, name, updateId);
		}

		bool opBinaryRight(string op)(string name) if(op=="in")
		{
			if(frontIndex != 0 || endIndex != initialEndIndex)
			{
				throw new SDLangException(
					"Cannot lookup tags/attributes by name on a subset of a range, "~
					"only across the entire tag. "~
					"Please make sure you haven't called popFront or popBack on this "~
					"range and that you aren't using a slice of the range."
				);
			}
			
			return
				namespace in mixin("tag."~membersGrouped) &&
				name in mixin("tag."~membersGrouped~"[namespace]") && 
				mixin("tag."~membersGrouped~"[namespace][name].length") > 0;
		}
	}

	struct NamespaceRange
	{
		private Tag tag;
		private bool isMaybe;
		private size_t updateId;  // Tag's updateId when this range was created.

		this(Tag tag, bool isMaybe)
		{
			this.tag      = tag;
			this.isMaybe  = isMaybe;
			this.updateId = tag.updateId;
			frontIndex = 0;
			endIndex = tag.allNamespaces.length;
		}

		invariant()
		{
			assert(
				this.updateId == tag.updateId,
				"This range has been invalidated by a change to the tag."
			);
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
			auto r = NamespaceRange(this.tag, this.isMaybe);
			r.frontIndex = this.frontIndex;
			r.endIndex   = this.endIndex;
			r.updateId   = this.updateId;
			return r;
		}
		
		typeof(this) opSlice()
		{
			return save();
		}
		
		typeof(this) opSlice(size_t start, size_t end)
		{
			auto r = save();
			r.frontIndex = this.frontIndex + start;
			r.endIndex   = this.frontIndex + end;
			
			if(
				r.frontIndex > this.endIndex ||
				r.endIndex > this.endIndex ||
				r.frontIndex > r.endIndex
			)
				throw new RangeError("Slice out of range");
			
			return r;
		}
		
		NamespaceAccess opIndex(size_t index)
		{
			if(empty)
				throw new RangeError("Range is empty");

			auto namespace = tag.allNamespaces[frontIndex+index];
			return NamespaceAccess(
				namespace,
				AttributeRange(tag, namespace, isMaybe),
				TagRange(tag, namespace, isMaybe)
			);
		}
		
		NamespaceAccess opIndex(string namespace)
		{
			if(!isMaybe && empty)
				throw new RangeError("Range is empty");
			
			if(!isMaybe && namespace !in this)
				throw new RangeError(`No such namespace: "`~namespace~`"`);
			
			return NamespaceAccess(
				namespace,
				AttributeRange(tag, namespace, isMaybe),
				TagRange(tag, namespace, isMaybe)
			);
		}
		
		// Inefficient when range is a slice or has used popFront/popBack, but it works.
		bool opBinaryRight(string op)(string namespace) if(op=="in")
		{
			if(frontIndex == 0 && endIndex == tag.allNamespaces.length)
			{
				return
					namespace in tag.attributeIndicies ||
					namespace in tag.tagIndicies;
			}
			else
				// Slower fallback method
				return tag.allNamespaces[frontIndex..endIndex].canFind(namespace);
		}
	}

	struct NamespaceAccess
	{
		string name;
		AttributeRange attributes;
		TagRange tags;
	}

	alias MemberRange!(Attribute, "allAttributes", "attributeIndicies", "_attributes") AttributeRange;
	alias MemberRange!(Tag,       "allTags",       "tagIndicies",       "_tags"      ) TagRange;
	static assert(isRandomAccessRange!AttributeRange);
	static assert(isRandomAccessRange!TagRange);
	static assert(isRandomAccessRange!NamespaceRange);

	/// Access all attributes that don't have a namespace
	@property AttributeRange attributes()
	{
		return AttributeRange(this, "", false);
	}

	/// Access all direct-child tags that don't have a namespace
	@property TagRange tags()
	{
		return TagRange(this, "", false);
	}
	
	/// Access all namespaces in this tag, and the attributes/tags within them.
	@property NamespaceRange namespaces()
	{
		return NamespaceRange(this, false);
	}

	/// Access all attributes and tags regardless of namespace.
	@property NamespaceAccess all()
	{
		// "*" isn't a valid namespace name, so we can use it to indicate "all namespaces"
		return NamespaceAccess(
			"*",
			AttributeRange(this, "*", false),
			TagRange(this, "*", false)
		);
	}

	struct MaybeAccess
	{
		Tag tag;

		/// Access all attributes that don't have a namespace
		@property AttributeRange attributes()
		{
			return AttributeRange(tag, "", true);
		}

		/// Access all direct-child tags that don't have a namespace
		@property TagRange tags()
		{
			return TagRange(tag, "", true);
		}
		
		/// Access all namespaces in this tag, and the attributes/tags within them.
		@property NamespaceRange namespaces()
		{
			return NamespaceRange(tag, true);
		}

		/// Access all attributes and tags regardless of namespace.
		@property NamespaceAccess all()
		{
			// "*" isn't a valid namespace name, so we can use it to indicate "all namespaces"
			return NamespaceAccess(
				"*",
				AttributeRange(tag, "*", true),
				TagRange(tag, "*", true)
			);
		}
	}
	
	/// Access 'attributes', 'tags', 'namespaces' and 'all' like normal,
	/// except that looking up a non-existant name/namespace with
	/// opIndex(string) results in an empty array instead of a thrown RangeError.
	@property MaybeAccess maybe()
	{
		return MaybeAccess(this);
	}
	
	override bool opEquals(Object o)
	{
		auto t = cast(Tag)o;
		if(!t)
			return false;
		
		if(_namespace != t._namespace || _name != t._name)
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

		if(_namespace != "")
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
		if(_name == "" && values.length == 0)
			throw new SDLangException("Anonymous tags must have at least one value.");
		
		if(_name == "" && _namespace != "")
			throw new SDLangException("Anonymous tags cannot have a namespace.");
	
		// Indent
		foreach(i; 0..indentLevel)
			sink.put(indent);
		
		// Name
		if(_namespace != "")
		{
			sink.put(_namespace);
			sink.put(':');
		}
		sink.put(_name);
		
		// Values
		foreach(i, v; values)
		{
			// Omit the first space for anonymous tags
			if(_name != "" || i > 0)
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
		if(_namespace != "")
		{
			buf.put("[");
			buf.put(_namespace);
			buf.put("]");
		}
		buf.put("'%s':\n".format(_name));

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

	auto blue3 = new Tag(
		null, "", "blue",
		[ Value(3), Value("Lee") ],
		[ Attribute("isThree", Value(true)) ],
		null
	);
	auto blue5 = new Tag(
		null, "", "blue",
		[ Value(5), Value("Chan"), Value(12345) ],
		[ Attribute("isThree", Value(false)) ],
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
			Attribute("points", Value(4)),
			Attribute("dimensions", Value(2)),
			Attribute("points", Value("Still four")),
		],
		null
	);
	auto triangle = new Tag(
		null, "stuff", "triangle",
		null,
		[
			Attribute("data", "points", Value(3)),
			Attribute("data", "dimensions", Value(2)),
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
			Attribute("small", "A", Value(1)),
			Attribute("med",   "A", Value(2)),
			Attribute("big",   "A", Value(3)),
			Attribute("small", "B", Value(10)),
			Attribute("big",   "B", Value(30)),
		],
		null
	);
	auto chiyo = new Tag(
		null, "", "chiyo",
		[ Value("Small"), Value("Flies?") ],
		[
			Attribute("nemesis", Value("Car")),
			Attribute("score", Value(100)),
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
			Attribute("visitor", "a", Value(1)),
			Attribute("b", Value(2)),
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
	assert(""        in root.namespaces);
	assert("stuff"   in root.namespaces);
	assert("foobar" !in root.namespaces);
	testRandomAccessRange(root.namespaces[     ""].tags, [blue3, blue5, nothing, namespaces, people]);
	testRandomAccessRange(root.namespaces["stuff"].tags, [orange, square, triangle]);
	testRandomAccessRange(root.all.attributes, cast(Attribute[])[]);
	testRandomAccessRange(root.all.tags,       [blue3, blue5, orange, square, triangle, nothing, namespaces, people]);
	testRandomAccessRange(root.all.tags[],     [blue3, blue5, orange, square, triangle, nothing, namespaces, people]);
	testRandomAccessRange(root.all.tags[3..6], [square, triangle, nothing]);
	assert("blue"    in root.tags);
	assert("nothing" in root.tags);
	assert("people"  in root.tags);
	assert("orange" !in root.tags);
	assert("square" !in root.tags);
	assert("foobar" !in root.tags);
	assert("blue"    in root.all.tags);
	assert("nothing" in root.all.tags);
	assert("people"  in root.all.tags);
	assert("orange"  in root.all.tags);
	assert("square"  in root.all.tags);
	assert("foobar" !in root.all.tags);
	assert("orange"  in root.namespaces["stuff"].tags);
	assert("square"  in root.namespaces["stuff"].tags);
	assert("square"  in root.namespaces["stuff"].tags);
	assert("foobar" !in root.attributes);
	assert("foobar" !in root.all.attributes);
	assert("foobar" !in root.namespaces["stuff"].attributes);
	assert("blue"   !in root.attributes);
	assert("blue"   !in root.all.attributes);
	assert("blue"   !in root.namespaces["stuff"].attributes);
	testRandomAccessRange(root.tags["nothing"],                    [nothing]);
	testRandomAccessRange(root.tags["blue"],                       [blue3, blue5]);
	testRandomAccessRange(root.namespaces["stuff"].tags["orange"], [orange]);
	testRandomAccessRange(root.all.tags["nothing"],                [nothing]);
	testRandomAccessRange(root.all.tags["blue"],                   [blue3, blue5]);
	testRandomAccessRange(root.all.tags["orange"],                 [orange]);

	assertThrown!RangeError(root.tags["foobar"]);
	assertThrown!RangeError(root.all.tags["foobar"]);
	assertThrown!RangeError(root.namespaces["foobar"].tags["foobar"]);
	assertThrown!RangeError(root.attributes["foobar"]);
	assertThrown!RangeError(root.all.attributes["foobar"]);
	assertThrown!RangeError(root.namespaces["foobar"].attributes["foobar"]);

	testRandomAccessRange(root.maybe.tags["nothing"],                    [nothing]);
	testRandomAccessRange(root.maybe.tags["blue"],                       [blue3, blue5]);
	testRandomAccessRange(root.maybe.namespaces["stuff"].tags["orange"], [orange]);
	testRandomAccessRange(root.maybe.all.tags["nothing"],                [nothing]);
	testRandomAccessRange(root.maybe.all.tags["blue"],                   [blue3, blue5]);
	testRandomAccessRange(root.maybe.all.tags["blue"][],                 [blue3, blue5]);
	testRandomAccessRange(root.maybe.all.tags["blue"][0..1],             [blue3]);
	testRandomAccessRange(root.maybe.all.tags["blue"][1..2],             [blue5]);
	testRandomAccessRange(root.maybe.all.tags["orange"],                 [orange]);
	testRandomAccessRange(root.maybe.tags["foobar"],                      cast(Tag[])[]);
	testRandomAccessRange(root.maybe.all.tags["foobar"],                  cast(Tag[])[]);
	testRandomAccessRange(root.maybe.namespaces["foobar"].tags["foobar"], cast(Tag[])[]);
	testRandomAccessRange(root.maybe.attributes["foobar"],                      cast(Attribute[])[]);
	testRandomAccessRange(root.maybe.all.attributes["foobar"],                  cast(Attribute[])[]);
	testRandomAccessRange(root.maybe.namespaces["foobar"].attributes["foobar"], cast(Attribute[])[]);

	testRandomAccessRange(blue3.attributes,     [ Attribute("isThree", Value(true)) ]);
	testRandomAccessRange(blue3.tags,           cast(Tag[])[]);
	testRandomAccessRange(blue3.namespaces,     [NSA("")], &namespaceEquals);
	testRandomAccessRange(blue3.all.attributes, [ Attribute("isThree", Value(true)) ]);
	testRandomAccessRange(blue3.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(blue5.attributes,     [ Attribute("isThree", Value(false)) ]);
	testRandomAccessRange(blue5.tags,           cast(Tag[])[]);
	testRandomAccessRange(blue5.namespaces,     [NSA("")], &namespaceEquals);
	testRandomAccessRange(blue5.all.attributes, [ Attribute("isThree", Value(false)) ]);
	testRandomAccessRange(blue5.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(orange.attributes,     cast(Attribute[])[]);
	testRandomAccessRange(orange.tags,           cast(Tag[])[]);
	testRandomAccessRange(orange.namespaces,     cast(NSA[])[], &namespaceEquals);
	testRandomAccessRange(orange.all.attributes, cast(Attribute[])[]);
	testRandomAccessRange(orange.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(square.attributes, [
		Attribute("points", Value(4)),
		Attribute("dimensions", Value(2)),
		Attribute("points", Value("Still four")),
	]);
	testRandomAccessRange(square.tags,       cast(Tag[])[]);
	testRandomAccessRange(square.namespaces, [NSA("")], &namespaceEquals);
	testRandomAccessRange(square.all.attributes, [
		Attribute("points", Value(4)),
		Attribute("dimensions", Value(2)),
		Attribute("points", Value("Still four")),
	]);
	testRandomAccessRange(square.all.tags, cast(Tag[])[]);
	
	testRandomAccessRange(triangle.attributes, cast(Attribute[])[]);
	testRandomAccessRange(triangle.tags,       cast(Tag[])[]);
	testRandomAccessRange(triangle.namespaces, [NSA("data")], &namespaceEquals);
	testRandomAccessRange(triangle.namespaces[0].attributes, [
		Attribute("data", "points", Value(3)),
		Attribute("data", "dimensions", Value(2)),
	]);
	assert("data"    in triangle.namespaces);
	assert("foobar" !in triangle.namespaces);
	testRandomAccessRange(triangle.namespaces["data"].attributes, [
		Attribute("data", "points", Value(3)),
		Attribute("data", "dimensions", Value(2)),
	]);
	testRandomAccessRange(triangle.all.attributes, [
		Attribute("data", "points", Value(3)),
		Attribute("data", "dimensions", Value(2)),
	]);
	testRandomAccessRange(triangle.all.tags, cast(Tag[])[]);
	
	testRandomAccessRange(nothing.attributes,     cast(Attribute[])[]);
	testRandomAccessRange(nothing.tags,           cast(Tag[])[]);
	testRandomAccessRange(nothing.namespaces,     cast(NSA[])[], &namespaceEquals);
	testRandomAccessRange(nothing.all.attributes, cast(Attribute[])[]);
	testRandomAccessRange(nothing.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(namespaces.attributes,   cast(Attribute[])[]);
	testRandomAccessRange(namespaces.tags,         cast(Tag[])[]);
	testRandomAccessRange(namespaces.namespaces,   [NSA("small"), NSA("med"), NSA("big")], &namespaceEquals);
	testRandomAccessRange(namespaces.namespaces[], [NSA("small"), NSA("med"), NSA("big")], &namespaceEquals);
	testRandomAccessRange(namespaces.namespaces[1..2], [NSA("med")], &namespaceEquals);
	testRandomAccessRange(namespaces.namespaces[0].attributes, [
		Attribute("small", "A", Value(1)),
		Attribute("small", "B", Value(10)),
	]);
	testRandomAccessRange(namespaces.namespaces[1].attributes, [
		Attribute("med", "A", Value(2)),
	]);
	testRandomAccessRange(namespaces.namespaces[2].attributes, [
		Attribute("big", "A", Value(3)),
		Attribute("big", "B", Value(30)),
	]);
	testRandomAccessRange(namespaces.namespaces[1..2][0].attributes, [
		Attribute("med", "A", Value(2)),
	]);
	assert("small"   in namespaces.namespaces);
	assert("med"     in namespaces.namespaces);
	assert("big"     in namespaces.namespaces);
	assert("foobar" !in namespaces.namespaces);
	assert("small"  !in namespaces.namespaces[1..2]);
	assert("med"     in namespaces.namespaces[1..2]);
	assert("big"    !in namespaces.namespaces[1..2]);
	assert("foobar" !in namespaces.namespaces[1..2]);
	testRandomAccessRange(namespaces.namespaces["small"].attributes, [
		Attribute("small", "A", Value(1)),
		Attribute("small", "B", Value(10)),
	]);
	testRandomAccessRange(namespaces.namespaces["med"].attributes, [
		Attribute("med", "A", Value(2)),
	]);
	testRandomAccessRange(namespaces.namespaces["big"].attributes, [
		Attribute("big", "A", Value(3)),
		Attribute("big", "B", Value(30)),
	]);
	testRandomAccessRange(namespaces.all.attributes, [
		Attribute("small", "A", Value(1)),
		Attribute("med",   "A", Value(2)),
		Attribute("big",   "A", Value(3)),
		Attribute("small", "B", Value(10)),
		Attribute("big",   "B", Value(30)),
	]);
	testRandomAccessRange(namespaces.all.attributes[], [
		Attribute("small", "A", Value(1)),
		Attribute("med",   "A", Value(2)),
		Attribute("big",   "A", Value(3)),
		Attribute("small", "B", Value(10)),
		Attribute("big",   "B", Value(30)),
	]);
	testRandomAccessRange(namespaces.all.attributes[2..4], [
		Attribute("big",   "A", Value(3)),
		Attribute("small", "B", Value(10)),
	]);
	testRandomAccessRange(namespaces.all.tags, cast(Tag[])[]);
	assert("A"      !in namespaces.attributes);
	assert("B"      !in namespaces.attributes);
	assert("foobar" !in namespaces.attributes);
	assert("A"       in namespaces.all.attributes);
	assert("B"       in namespaces.all.attributes);
	assert("foobar" !in namespaces.all.attributes);
	assert("A"       in namespaces.namespaces["small"].attributes);
	assert("B"       in namespaces.namespaces["small"].attributes);
	assert("foobar" !in namespaces.namespaces["small"].attributes);
	assert("A"       in namespaces.namespaces["med"].attributes);
	assert("B"      !in namespaces.namespaces["med"].attributes);
	assert("foobar" !in namespaces.namespaces["med"].attributes);
	assert("A"       in namespaces.namespaces["big"].attributes);
	assert("B"       in namespaces.namespaces["big"].attributes);
	assert("foobar" !in namespaces.namespaces["big"].attributes);
	assert("foobar" !in namespaces.tags);
	assert("foobar" !in namespaces.all.tags);
	assert("foobar" !in namespaces.namespaces["small"].tags);
	assert("A"      !in namespaces.tags);
	assert("A"      !in namespaces.all.tags);
	assert("A"      !in namespaces.namespaces["small"].tags);
	testRandomAccessRange(namespaces.namespaces["small"].attributes["A"], [
		Attribute("small", "A", Value(1)),
	]);
	testRandomAccessRange(namespaces.namespaces["med"].attributes["A"], [
		Attribute("med", "A", Value(2)),
	]);
	testRandomAccessRange(namespaces.namespaces["big"].attributes["A"], [
		Attribute("big", "A", Value(3)),
	]);
	testRandomAccessRange(namespaces.all.attributes["A"], [
		Attribute("small", "A", Value(1)),
		Attribute("med",   "A", Value(2)),
		Attribute("big",   "A", Value(3)),
	]);
	testRandomAccessRange(namespaces.all.attributes["B"], [
		Attribute("small", "B", Value(10)),
		Attribute("big",   "B", Value(30)),
	]);

	testRandomAccessRange(chiyo.attributes, [
		Attribute("nemesis", Value("Car")),
		Attribute("score", Value(100)),
	]);
	testRandomAccessRange(chiyo.tags,       cast(Tag[])[]);
	testRandomAccessRange(chiyo.namespaces, [NSA("")], &namespaceEquals);
	testRandomAccessRange(chiyo.all.attributes, [
		Attribute("nemesis", Value("Car")),
		Attribute("score", Value(100)),
	]);
	testRandomAccessRange(chiyo.all.tags, cast(Tag[])[]);
	
	testRandomAccessRange(yukari.attributes,     cast(Attribute[])[]);
	testRandomAccessRange(yukari.tags,           cast(Tag[])[]);
	testRandomAccessRange(yukari.namespaces,     cast(NSA[])[], &namespaceEquals);
	testRandomAccessRange(yukari.all.attributes, cast(Attribute[])[]);
	testRandomAccessRange(yukari.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(sana.attributes,     cast(Attribute[])[]);
	testRandomAccessRange(sana.tags,           cast(Tag[])[]);
	testRandomAccessRange(sana.namespaces,     cast(NSA[])[], &namespaceEquals);
	testRandomAccessRange(sana.all.attributes, cast(Attribute[])[]);
	testRandomAccessRange(sana.all.tags,       cast(Tag[])[]);
	
	testRandomAccessRange(people.attributes,         [Attribute("b", Value(2))]);
	testRandomAccessRange(people.tags,               [chiyo, yukari, tomo]);
	testRandomAccessRange(people.namespaces,         [NSA("visitor"), NSA("")], &namespaceEquals);
	testRandomAccessRange(people.namespaces[0].attributes, [Attribute("visitor", "a", Value(1))]);
	testRandomAccessRange(people.namespaces[1].attributes, [Attribute("b", Value(2))]);
	testRandomAccessRange(people.namespaces[0].tags,       [sana, hayama]);
	testRandomAccessRange(people.namespaces[1].tags,       [chiyo, yukari, tomo]);
	assert("visitor" in people.namespaces);
	assert(""        in people.namespaces);
	assert("foobar" !in people.namespaces);
	testRandomAccessRange(people.namespaces["visitor"].attributes, [Attribute("visitor", "a", Value(1))]);
	testRandomAccessRange(people.namespaces[       ""].attributes, [Attribute("b", Value(2))]);
	testRandomAccessRange(people.namespaces["visitor"].tags,       [sana, hayama]);
	testRandomAccessRange(people.namespaces[       ""].tags,       [chiyo, yukari, tomo]);
	testRandomAccessRange(people.all.attributes, [
		Attribute("visitor", "a", Value(1)),
		Attribute("b", Value(2)),
	]);
	testRandomAccessRange(people.all.tags, [chiyo, yukari, sana, tomo, hayama]);
	
	people.tags["tomo"][0].remove();
	people.namespaces["visitor"].tags["hayama"][0].remove();
	people.tags["chiyo"][0].remove();
	testRandomAccessRange(people.tags,               [yukari]);
	testRandomAccessRange(people.namespaces,         [NSA("visitor"), NSA("")], &namespaceEquals);
	testRandomAccessRange(people.namespaces[0].tags, [sana]);
	testRandomAccessRange(people.namespaces[1].tags, [yukari]);
	assert("visitor" in people.namespaces);
	assert(""        in people.namespaces);
	assert("foobar" !in people.namespaces);
	testRandomAccessRange(people.namespaces["visitor"].tags, [sana]);
	testRandomAccessRange(people.namespaces[       ""].tags, [yukari]);
	testRandomAccessRange(people.all.tags, [yukari, sana]);
	
	people.tags["yukari"][0].remove();
	people.namespaces["visitor"].tags["sana"][0].remove();
	testRandomAccessRange(people.tags,               cast(Tag[])[]);
	testRandomAccessRange(people.namespaces,         [NSA("visitor"), NSA("")], &namespaceEquals);
	testRandomAccessRange(people.namespaces[0].tags, cast(Tag[])[]);
	testRandomAccessRange(people.namespaces[1].tags, cast(Tag[])[]);
	assert("visitor" in people.namespaces);
	assert(""        in people.namespaces);
	assert("foobar" !in people.namespaces);
	testRandomAccessRange(people.namespaces["visitor"].tags, cast(Tag[])[]);
	testRandomAccessRange(people.namespaces[       ""].tags, cast(Tag[])[]);
	testRandomAccessRange(people.all.tags, cast(Tag[])[]);
	
	assertThrown!SDLangException( people.remove(Attribute("visitor", "a", Value(2))) );
	assertThrown!SDLangException( people.remove(Attribute("b", Value(1))) );
	people.remove(Attribute("visitor", "a", Value(1)));
	testRandomAccessRange(people.attributes,               [Attribute("b", Value(2))]);
	testRandomAccessRange(people.namespaces,               [NSA("")], &namespaceEquals);
	testRandomAccessRange(people.namespaces[0].attributes, [Attribute("b", Value(2))]);
	assert("visitor" !in people.namespaces);
	assert(""         in people.namespaces);
	assert("foobar"  !in people.namespaces);
	testRandomAccessRange(people.namespaces[""].attributes, [Attribute("b", Value(2))]);
	testRandomAccessRange(people.all.attributes, [
		Attribute("b", Value(2)),
	]);
	
	people.remove(Attribute("b", Value(2)));
	testRandomAccessRange(people.attributes, cast(Attribute[])[]);
	testRandomAccessRange(people.namespaces, cast(NSA[])[], &namespaceEquals);
	assert("visitor" !in people.namespaces);
	assert(""        !in people.namespaces);
	assert("foobar"  !in people.namespaces);
	testRandomAccessRange(people.all.attributes, cast(Attribute[])[]);
}
