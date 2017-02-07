/+
SDLang Schema -> D Conversion Rules
===================================

Sanitize Names
--------------
- Replace all "-a" with "A"
- Replace remaining "-" with "_"
- Replace "$" with "_"
- Replace ":" with "_"
- If tag/partial, uppercase first character (or first letter?)
- If attribute, lowercase first character (or first letter?)
- Values get named "value"
- If result is a d keyword or common name like "string", append "_".

Check For (and Handle) Sanitized Name Collitions
------------------------------------------------
After sanitizing all names, check for collisions (including collisions
with auto-generated symbols like "allTags"/"allAttributes").

Ideas:

A. Error on any collisions, suggesting to disambiguate using `d:name="..."`
attribute.

B. Instead of error, just warn, and then use Symbol!"..." in place of
name (only works for tags?)

C. On collision, warn, and create a unique hash (or id#) for each collision,
being careful not to create new collisions in the process.

Converting Types
----------------

For required values/attibutes:
- If multiple types are allowed, use Value
- If exactly one type is allowed:
	- If type is null: Use bool, with "true" indicating "yes, a null is present" (will only ever be true)
	- Otherwise: Use the corresponding D type.

For optional values/attibutes:
- If multiple types are allowed, use Value
- If exactly one type is allowed:
	- If type is null: Use bool, with "true" indicating "yes, a null is present"
	- If type is already nullable (ie, string and ubyte[]), use corresponding type
	- If type isn't already nullable, use Nullable!(corresponding type)

For multiple values/attibutes allowed:
- Simply use an array

Converting tag/value/attribute/partial
--------------------------------------

Values and attributes become member variables of their tag. Their type is
determined as in "Converting Types".

Partials are converted into two parts:
- `struct` with the @Partial attribute: Containing tag class definitions and UDAs
- `mixin template`, suffixed with _Mixin, with the @PartialMixin attribute:
	Containing member declarations and mixins.

Tags:
The entire document gets a tag: final class Root!"name_of_this_schema".
For each tag inside:

xx NO xxxxxxx
If the tag is used for recursion, convert to a `final class`. Otherwise,
a nested struct. Either way, create one member variable for it, next to
its definition. If "tags" or "tags-opt", make the member variable an array.
xx NO xxxxxxx

Convert to a nested `final class` with appropriate AnyTag/allTags definition.

Create one member variable of this class type, next to the `final class`
definition. If "tags" or "tags-opt", make the member variable an array.
+/

////////////////////////////////////////////////////////////////////////

module sdlang.sdlangSchema;

static import sdlang.ast;
static import sdlang.schema;
static import sdlang.token;
static import taggedalgebraic;

Root!"sdlangSchema" parseFile(string name)(string filename)
	if(name=="sdlangSchema")
{
	return sdlang.schema.parseFile!(Root!"sdlangSchema")(filename);
}

Root!"sdlangSchema" parseSource(string name)(string source, string filename=null)
	if(name=="sdlangSchema")
{
	return sdlang.schema.parseSource!(Root!"sdlangSchema")(source, filename);
}

private alias ps = parseSource!"sdlangSchema";
private alias pf = parseFile!"sdlangSchema";

final class Root(string name) if(name=="sdlangSchema")
{
	/++
	Schema:
	--------
	partial "allow-basic-types" \
		allow="*" \
		allow="null" \
		allow="bool" \
		allow="string" \
		allow="numeric" \
		allow="int" \
		allow="int32" \
		allow="int64" \
		allow="float" \
		allow="float32" \
		allow="float64" \
		allow="float128" \
		allow="date" \
		allow="datetime" \
		allow="timespan" \
		allow="binary"
	--------
	+/
	@(sdlang.schema.Name("allow-basic-types"))
	@(sdlang.schema.Partial)
	@(sdlang.schema.Allow("*"))
	@(sdlang.schema.Allow("null"))
	@(sdlang.schema.Allow("bool"))
	@(sdlang.schema.Allow("string"))
	@(sdlang.schema.Allow("numeric"))
	@(sdlang.schema.Allow("int"))
	@(sdlang.schema.Allow("int32"))
	@(sdlang.schema.Allow("int64"))
	@(sdlang.schema.Allow("float"))
	@(sdlang.schema.Allow("float32"))
	@(sdlang.schema.Allow("float64"))
	@(sdlang.schema.Allow("float128"))
	@(sdlang.schema.Allow("date"))
	@(sdlang.schema.Allow("datetime"))
	@(sdlang.schema.Allow("timespan"))
	@(sdlang.schema.Allow("binary"))
	struct AllowBasicTypes
	{
		// Empty
	}

	@(sdlang.schema.Name("allow-basic-types"))
	@(sdlang.schema.PartialMixin)
	mixin template AllowBasicTypes_Mixin()
	{
		// Empty
	}

	template Symbol(string name) if(name == "allow-basic-types")
	{ alias Symbol = AllowBasicTypes; }

	/++
	Schema:
	--------
	partial "val-common" {
		attr-opt  "mixin"     type="string" desc="Name of a value, attribute or partial"
		attrs-opt "type"      type="string" mixin="allow-basic-types" default="*"
		attrs-opt "allow"     type="*" // Should this imply "type" or agree with "type"?
		attr-opt  "allow-any" type="string" mixin="allow-basic-types" // Implies "type"
		attr-opt  "desc"      type="string" desc="Description of value (helpful since values don't have names)"
	}
	--------
	+/
	@(sdlang.schema.Name("val-common"))
	@(sdlang.schema.Partial)
	struct ValCommon
	{
		// Empty
	}

	@(sdlang.schema.Name("val-common"))
	@(sdlang.schema.PartialMixin)
	mixin template ValCommon_Mixin()
	{
		/// Name of a value, attribute or partial
		@(sdlang.schema.Desc("Name of a value, attribute or partial"))
		@(sdlang.schema.Name("mixin"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string mixin_;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("type"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string[] type = ["*"];

		@(sdlang.schema.Name("allow"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) sdlang.token.Value[] allow;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("allow-any"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string allowAny;

		/// Description of value (helpful since values don't have names)
		@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
		@(sdlang.schema.Name("desc"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string desc;
	}

	template Symbol(string name) if(name == "val-common")
	{ alias Symbol = ValCommon; }

	/++
	Schema:
	--------
	partial "attr-common" {
		val type="string" desc="Attribute's name"
		mixin "val-common"
		attr-opt "desc" type="string" desc="Description of attribute"
	}
	--------
	+/
	@(sdlang.schema.Name("attr-common"))
	@(sdlang.schema.Mixin("val-common"))
	@(sdlang.schema.Partial)
	struct AttrCommon
	{
		// Empty
	}

	@(sdlang.schema.Name("attr-common"))
	@(sdlang.schema.PartialMixin)
	mixin template AttrCommon_Mixin()
	{
		/// Attribute's name
		@(sdlang.schema.Desc("Attribute's name"))
		@(sdlang.schema.Value)
		string value;
		
		// START mixin ValCommon_Mixin;
		//mixin ValCommon_Mixin;
		/// Name of a value, attribute or partial
		@(sdlang.schema.Desc("Name of a value, attribute or partial"))
		@(sdlang.schema.Name("mixin"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string mixin_;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("type"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string[] type = ["*"];

		@(sdlang.schema.Name("allow"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) sdlang.token.Value[] allow;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("allow-any"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string allowAny;

		/// Description of value (helpful since values don't have names)
		@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
		@(sdlang.schema.Name("desc"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string desc;
		// END mixin ValCommon_Mixin;
		
		/// Description of attribute
		@(sdlang.schema.Desc("Description of attribute"))
		@(sdlang.schema.Name("desc"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string desc;
	}

	template Symbol(string name) if(name == "attr-common")
	{ alias Symbol = AttrCommon; }

	/++
	Schema:
	--------
	partial "opt-common" {
		attr-opt "default" type="*"
	}
	--------
	+/
	@(sdlang.schema.Name("opt-common"))
	@(sdlang.schema.Partial)
	struct OptCommon
	{
		// Empty
	}

	@(sdlang.schema.Name("opt-common"))
	@(sdlang.schema.PartialMixin)
	mixin template OptCommon_Mixin()
	{
		@(sdlang.schema.Name("default"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) sdlang.token.Value default_;
	}

	template Symbol(string name) if(name == "opt-common")
	{ alias Symbol = OptCommon; }

	/++
	Schema:
	--------
	partial "tag-variations" {
		tags-opt "tag"      mixin="tag-common" desc="Required tag"
		tags-opt "tags"     mixin="tag-common" desc="Required tag, allow multiples"
		tags-opt "tag-opt"  mixin="tag-common" desc="Optional tag"
		tags-opt "tags-opt" mixin="tag-common" desc="Optional tag, allow multiples"
	}
	--------
	+/
	@(sdlang.schema.Name("tag-variations"))
	@(sdlang.schema.Partial)
	struct TagVariations
	{
		/// Required tag
		@(sdlang.schema.Name("tag"))
		@(sdlang.schema.Desc("Required tag"))
		@(sdlang.schema.Mixin("tag-common"))
		static final class Tag
		{
			// START mixin TagCommon_Mixin;
			//mixin TagCommon_Mixin;
			/// Tag's name
			@(sdlang.schema.Desc("Tag's name"))
			@(sdlang.schema.Value)
			string value;
			
			/// Description of tag
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Desc("Description of tag"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;

			/// Required value
			@(sdlang.schema.Name("val"))
			@(sdlang.schema.Desc("Required value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Val[] val;

			/// Required value, allow multiples
			@(sdlang.schema.Name("vals"))
			@(sdlang.schema.Desc("Required value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Vals[] vals;

			/// Optional value
			@(sdlang.schema.Name("val-opt"))
			@(sdlang.schema.Desc("Optional value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValOpt[] valOpt;

			/// Optional value, allow multiples
			@(sdlang.schema.Name("vals-opt"))
			@(sdlang.schema.Desc("Optional value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValsOpt[] valsOpt;

			/// Required attribute
			@(sdlang.schema.Name("attr"))
			@(sdlang.schema.Desc("Required attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attr[] attr;

			/// Required attribute, allow multiples
			@(sdlang.schema.Name("attrs"))
			@(sdlang.schema.Desc("Required attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attrs[] attrs;

			/// Optional attribute
			@(sdlang.schema.Name("attr-opt"))
			@(sdlang.schema.Desc("Optional attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrOpt[] attrOpt;

			/// Optional attribute, allow multiples
			@(sdlang.schema.Name("attrs-opt"))
			@(sdlang.schema.Desc("Optional attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrsOpt[] attrsOpt;

			// START mixin TagVariations_Mixin;
			//mixin TagVariations_Mixin;
			/// Required tag
			@(sdlang.schema.Name("tag"))
			@(sdlang.schema.Desc("Required tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tag[] tag;

			/// Required tag, allow multiples
			@(sdlang.schema.Name("tags"))
			@(sdlang.schema.Desc("Required tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tags[] tags;

			/// Optional tag
			@(sdlang.schema.Name("tag-opt"))
			@(sdlang.schema.Desc("Optional tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagOpt[] tagOpt;
			
			/// Optional tag, allow multiples
			@(sdlang.schema.Name("tags-opt"))
			@(sdlang.schema.Desc("Optional tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagsOpt[] tagsOpt;
			// END mixin TagVariations_Mixin;

			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Tag)
			TagCommon.Mixin[] mixin_;
			// END mixin TagCommon_Mixin;
			
			private union AnyTagBase
			{
				TagCommon.Val val;
				TagCommon.Vals vals;
				TagCommon.ValOpt valOpt;
				TagCommon.ValsOpt valsOpt;
				TagCommon.Attr attr;
				TagCommon.Attrs attrs;
				TagCommon.AttrOpt attrOpt;
				TagCommon.AttrsOpt attrsOpt;
				TagVariations.Tag tag;
				TagVariations.Tags tags;
				TagVariations.TagOpt tagOpt;
				TagVariations.TagsOpt tagsOpt;
				TagCommon.Mixin mixin_;
			}
			alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
			AnyTag[] allTags;

			sdlang.ast.Attribute[] allAttributes;
		}
		
		template Symbol(string name) if(name == "tag")
		{ alias Symbol = Tag; }

		/// Required tag, allow multiples
		@(sdlang.schema.Name("tags"))
		@(sdlang.schema.Desc("Required tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		static final class Tags
		{
			// START mixin TagCommon_Mixin;
			//mixin TagCommon_Mixin;
			/// Tag's name
			@(sdlang.schema.Desc("Tag's name"))
			@(sdlang.schema.Value)
			string value;
			
			/// Description of tag
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Desc("Description of tag"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;

			/// Required value
			@(sdlang.schema.Name("val"))
			@(sdlang.schema.Desc("Required value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Val[] val;

			/// Required value, allow multiples
			@(sdlang.schema.Name("vals"))
			@(sdlang.schema.Desc("Required value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Vals[] vals;

			/// Optional value
			@(sdlang.schema.Name("val-opt"))
			@(sdlang.schema.Desc("Optional value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValOpt[] valOpt;

			/// Optional value, allow multiples
			@(sdlang.schema.Name("vals-opt"))
			@(sdlang.schema.Desc("Optional value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValsOpt[] valsOpt;

			/// Required attribute
			@(sdlang.schema.Name("attr"))
			@(sdlang.schema.Desc("Required attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attr[] attr;

			/// Required attribute, allow multiples
			@(sdlang.schema.Name("attrs"))
			@(sdlang.schema.Desc("Required attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attrs[] attrs;

			/// Optional attribute
			@(sdlang.schema.Name("attr-opt"))
			@(sdlang.schema.Desc("Optional attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrOpt[] attrOpt;

			/// Optional attribute, allow multiples
			@(sdlang.schema.Name("attrs-opt"))
			@(sdlang.schema.Desc("Optional attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrsOpt[] attrsOpt;

			// START mixin TagVariations_Mixin;
			//mixin TagVariations_Mixin;
			/// Required tag
			@(sdlang.schema.Name("tag"))
			@(sdlang.schema.Desc("Required tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tag[] tag;

			/// Required tag, allow multiples
			@(sdlang.schema.Name("tags"))
			@(sdlang.schema.Desc("Required tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tags[] tags;

			/// Optional tag
			@(sdlang.schema.Name("tag-opt"))
			@(sdlang.schema.Desc("Optional tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagOpt[] tagOpt;
			
			/// Optional tag, allow multiples
			@(sdlang.schema.Name("tags-opt"))
			@(sdlang.schema.Desc("Optional tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagsOpt[] tagsOpt;
			// END mixin TagVariations_Mixin;

			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Tag)
			TagCommon.Mixin[] mixin_;
			// END mixin TagCommon_Mixin;
			
			private union AnyTagBase
			{
				TagCommon.Val val;
				TagCommon.Vals vals;
				TagCommon.ValOpt valOpt;
				TagCommon.ValsOpt valsOpt;
				TagCommon.Attr attr;
				TagCommon.Attrs attrs;
				TagCommon.AttrOpt attrOpt;
				TagCommon.AttrsOpt attrsOpt;
				TagVariations.Tag tag;
				TagVariations.Tags tags;
				TagVariations.TagOpt tagOpt;
				TagVariations.TagsOpt tagsOpt;
				TagCommon.Mixin mixin_;
			}
			alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
			AnyTag[] allTags;

			sdlang.ast.Attribute[] allAttributes;
		}
		
		template Symbol(string name) if(name == "tags")
		{ alias Symbol = Tags; }

		/// Optional tag
		@(sdlang.schema.Name("tag-opt"))
		@(sdlang.schema.Desc("Optional tag"))
		@(sdlang.schema.Mixin("tag-common"))
		static final class TagOpt
		{
			// START mixin TagCommon_Mixin;
			//mixin TagCommon_Mixin;
			/// Tag's name
			@(sdlang.schema.Desc("Tag's name"))
			@(sdlang.schema.Value)
			string value;
			
			/// Description of tag
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Desc("Description of tag"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;

			/// Required value
			@(sdlang.schema.Name("val"))
			@(sdlang.schema.Desc("Required value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Val[] val;

			/// Required value, allow multiples
			@(sdlang.schema.Name("vals"))
			@(sdlang.schema.Desc("Required value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Vals[] vals;

			/// Optional value
			@(sdlang.schema.Name("val-opt"))
			@(sdlang.schema.Desc("Optional value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValOpt[] valOpt;

			/// Optional value, allow multiples
			@(sdlang.schema.Name("vals-opt"))
			@(sdlang.schema.Desc("Optional value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValsOpt[] valsOpt;

			/// Required attribute
			@(sdlang.schema.Name("attr"))
			@(sdlang.schema.Desc("Required attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attr[] attr;

			/// Required attribute, allow multiples
			@(sdlang.schema.Name("attrs"))
			@(sdlang.schema.Desc("Required attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attrs[] attrs;

			/// Optional attribute
			@(sdlang.schema.Name("attr-opt"))
			@(sdlang.schema.Desc("Optional attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrOpt[] attrOpt;

			/// Optional attribute, allow multiples
			@(sdlang.schema.Name("attrs-opt"))
			@(sdlang.schema.Desc("Optional attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrsOpt[] attrsOpt;

			// START mixin TagVariations_Mixin;
			//mixin TagVariations_Mixin;
			/// Required tag
			@(sdlang.schema.Name("tag"))
			@(sdlang.schema.Desc("Required tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tag[] tag;

			/// Required tag, allow multiples
			@(sdlang.schema.Name("tags"))
			@(sdlang.schema.Desc("Required tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tags[] tags;

			/// Optional tag
			@(sdlang.schema.Name("tag-opt"))
			@(sdlang.schema.Desc("Optional tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagOpt[] tagOpt;
			
			/// Optional tag, allow multiples
			@(sdlang.schema.Name("tags-opt"))
			@(sdlang.schema.Desc("Optional tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagsOpt[] tagsOpt;
			// END mixin TagVariations_Mixin;

			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Tag)
			TagCommon.Mixin[] mixin_;
			// END mixin TagCommon_Mixin;
			
			private union AnyTagBase
			{
				TagCommon.Val val;
				TagCommon.Vals vals;
				TagCommon.ValOpt valOpt;
				TagCommon.ValsOpt valsOpt;
				TagCommon.Attr attr;
				TagCommon.Attrs attrs;
				TagCommon.AttrOpt attrOpt;
				TagCommon.AttrsOpt attrsOpt;
				TagVariations.Tag tag;
				TagVariations.Tags tags;
				TagVariations.TagOpt tagOpt;
				TagVariations.TagsOpt tagsOpt;
				TagCommon.Mixin mixin_;
			}
			alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
			AnyTag[] allTags;

			sdlang.ast.Attribute[] allAttributes;
		}

		template Symbol(string name) if(name == "tag-opt")
		{ alias Symbol = TagOpt; }
		
		/// Optional tag, allow multiples
		@(sdlang.schema.Name("tags-opt"))
		@(sdlang.schema.Desc("Optional tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		static final class TagsOpt
		{
			// START mixin TagCommon_Mixin;
			//mixin TagCommon_Mixin;
			/// Tag's name
			@(sdlang.schema.Desc("Tag's name"))
			@(sdlang.schema.Value)
			string value;
			
			/// Description of tag
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Desc("Description of tag"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;

			/// Required value
			@(sdlang.schema.Name("val"))
			@(sdlang.schema.Desc("Required value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Val[] val;

			/// Required value, allow multiples
			@(sdlang.schema.Name("vals"))
			@(sdlang.schema.Desc("Required value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Tag)
			TagCommon.Vals[] vals;

			/// Optional value
			@(sdlang.schema.Name("val-opt"))
			@(sdlang.schema.Desc("Optional value"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValOpt[] valOpt;

			/// Optional value, allow multiples
			@(sdlang.schema.Name("vals-opt"))
			@(sdlang.schema.Desc("Optional value, allow multiples"))
			@(sdlang.schema.Mixin("val-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.ValsOpt[] valsOpt;

			/// Required attribute
			@(sdlang.schema.Name("attr"))
			@(sdlang.schema.Desc("Required attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attr[] attr;

			/// Required attribute, allow multiples
			@(sdlang.schema.Name("attrs"))
			@(sdlang.schema.Desc("Required attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Tag)
			TagCommon.Attrs[] attrs;

			/// Optional attribute
			@(sdlang.schema.Name("attr-opt"))
			@(sdlang.schema.Desc("Optional attribute"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrOpt[] attrOpt;

			/// Optional attribute, allow multiples
			@(sdlang.schema.Name("attrs-opt"))
			@(sdlang.schema.Desc("Optional attribute, allow multiples"))
			@(sdlang.schema.Mixin("attr-common"))
			@(sdlang.schema.Mixin("opt-common"))
			@(sdlang.schema.Tag)
			TagCommon.AttrsOpt[] attrsOpt;

			// START mixin TagVariations_Mixin;
			//mixin TagVariations_Mixin;
			/// Required tag
			@(sdlang.schema.Name("tag"))
			@(sdlang.schema.Desc("Required tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tag[] tag;

			/// Required tag, allow multiples
			@(sdlang.schema.Name("tags"))
			@(sdlang.schema.Desc("Required tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.Tags[] tags;

			/// Optional tag
			@(sdlang.schema.Name("tag-opt"))
			@(sdlang.schema.Desc("Optional tag"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagOpt[] tagOpt;
			
			/// Optional tag, allow multiples
			@(sdlang.schema.Name("tags-opt"))
			@(sdlang.schema.Desc("Optional tag, allow multiples"))
			@(sdlang.schema.Mixin("tag-common"))
			@(sdlang.schema.Tag)
			TagVariations.TagsOpt[] tagsOpt;
			// END mixin TagVariations_Mixin;

			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Tag)
			TagCommon.Mixin[] mixin_;
			// END mixin TagCommon_Mixin;
			
			private union AnyTagBase
			{
				TagCommon.Val val;
				TagCommon.Vals vals;
				TagCommon.ValOpt valOpt;
				TagCommon.ValsOpt valsOpt;
				TagCommon.Attr attr;
				TagCommon.Attrs attrs;
				TagCommon.AttrOpt attrOpt;
				TagCommon.AttrsOpt attrsOpt;
				TagVariations.Tag tag;
				TagVariations.Tags tags;
				TagVariations.TagOpt tagOpt;
				TagVariations.TagsOpt tagsOpt;
				TagCommon.Mixin mixin_;
			}
			alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
			AnyTag[] allTags;

			sdlang.ast.Attribute[] allAttributes;
		}

		template Symbol(string name) if(name == "tags-opt")
		{ alias Symbol = TagsOpt; }
	}

	@(sdlang.schema.Name("tag-variations"))
	@(sdlang.schema.PartialMixin)
	mixin template TagVariations_Mixin()
	{
		/// Required tag
		@(sdlang.schema.Name("tag"))
		@(sdlang.schema.Desc("Required tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tag[] tag;

		/// Required tag, allow multiples
		@(sdlang.schema.Name("tags"))
		@(sdlang.schema.Desc("Required tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tags[] tags;

		/// Optional tag
		@(sdlang.schema.Name("tag-opt"))
		@(sdlang.schema.Desc("Optional tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagOpt[] tagOpt;
		
		/// Optional tag, allow multiples
		@(sdlang.schema.Name("tags-opt"))
		@(sdlang.schema.Desc("Optional tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagsOpt[] tagsOpt;
	}

	template Symbol(string name) if(name == "tag-variations")
	{ alias Symbol = TagVariations; }

	/++
	Schema:
	--------
	partial "tag-common" {
		val type="string" desc="Tag's name"
		attr-opt "desc" type="string" desc="Description of tag"

		// Tags/Attributes can appear in any order.
		// Values must appear in the order defined by schema.
		// Optional values must come after required values?
		
		tags-opt "val"      mixin="val-common" desc="Required value"
		tags-opt "vals"     mixin="val-common" desc="Required value, allow multiples"
		tags-opt "val-opt"  mixin="val-common" mixin="opt-common" desc="Optional value"
		tags-opt "vals-opt" mixin="val-common" mixin="opt-common" desc="Optional value, allow multiples"

		tags-opt "attr"      mixin="attr-common" desc="Required attribute"
		tags-opt "attrs"     mixin="attr-common" desc="Required attribute, allow multiples"
		tags-opt "attr-opt"  mixin="attr-common" mixin="opt-common" desc="Optional attribute"
		tags-opt "attrs-opt" mixin="attr-common" mixin="opt-common" desc="Optional attribute, allow multiples"

		mixin "tag-variations"
		
		tags-opt "mixin" {
			val type="string" desc="Name of a tag or partial"
		}
	}
	--------
	+/
	@(sdlang.schema.Name("tag-common"))
	@(sdlang.schema.Partial)
	struct TagCommon
	{
		/// Required value
		@(sdlang.schema.Name("val"))
		@(sdlang.schema.Desc("Required value"))
		@(sdlang.schema.Mixin("val-common"))
		static final class Val
		{
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Required value, allow multiples
		@(sdlang.schema.Name("vals"))
		@(sdlang.schema.Desc("Required value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		static final class Vals
		{
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Optional value
		@(sdlang.schema.Name("val-opt"))
		@(sdlang.schema.Desc("Optional value"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		static final class ValOpt
		{
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;

			// START mixin OptCommon_Mixin;
			//mixin OptCommon_Mixin;
			@(sdlang.schema.Name("default"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value default_;
			// END mixin OptCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Optional value, allow multiples
		@(sdlang.schema.Name("vals-opt"))
		@(sdlang.schema.Desc("Optional value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		static final class ValsOpt
		{
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;

			// START mixin OptCommon_Mixin;
			//mixin OptCommon_Mixin;
			@(sdlang.schema.Name("default"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value default_;
			// END mixin OptCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Required attribute
		@(sdlang.schema.Name("attr"))
		@(sdlang.schema.Desc("Required attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		static final class Attr
		{
			// START mixin AttrCommon_Mixin;
			//mixin AttrCommon_Mixin;
			/// Attribute's name
			@(sdlang.schema.Desc("Attribute's name"))
			@(sdlang.schema.Value)
			string value;
			
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			//@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			//@(sdlang.schema.Name("desc"))
			//@(sdlang.schema.Attribute)
			//@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;
			
			/// Description of attribute
			@(sdlang.schema.Desc("Description of attribute"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin AttrCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Required attribute, allow multiples
		@(sdlang.schema.Name("attrs"))
		@(sdlang.schema.Desc("Required attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		static final class Attrs
		{
			// START mixin AttrCommon_Mixin;
			//mixin AttrCommon_Mixin;
			/// Attribute's name
			@(sdlang.schema.Desc("Attribute's name"))
			@(sdlang.schema.Value)
			string value;
			
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			//@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			//@(sdlang.schema.Name("desc"))
			//@(sdlang.schema.Attribute)
			//@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;
			
			/// Description of attribute
			@(sdlang.schema.Desc("Description of attribute"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin AttrCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Optional attribute
		@(sdlang.schema.Name("attr-opt"))
		@(sdlang.schema.Desc("Optional attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		static final class AttrOpt
		{
			// START mixin AttrCommon_Mixin;
			//mixin AttrCommon_Mixin;
			/// Attribute's name
			@(sdlang.schema.Desc("Attribute's name"))
			@(sdlang.schema.Value)
			string value;
			
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			//@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			//@(sdlang.schema.Name("desc"))
			//@(sdlang.schema.Attribute)
			//@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;
			
			/// Description of attribute
			@(sdlang.schema.Desc("Description of attribute"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin AttrCommon_Mixin;

			// START mixin OptCommon_Mixin;
			//mixin OptCommon_Mixin;
			@(sdlang.schema.Name("default"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value default_;
			// END mixin OptCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		/// Optional attribute, allow multiples
		@(sdlang.schema.Name("attrs-opt"))
		@(sdlang.schema.Desc("Optional attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		static final class AttrsOpt
		{
			// START mixin AttrCommon_Mixin;
			//mixin AttrCommon_Mixin;
			/// Attribute's name
			@(sdlang.schema.Desc("Attribute's name"))
			@(sdlang.schema.Value)
			string value;
			
			// START mixin ValCommon_Mixin;
			//mixin ValCommon_Mixin;
			/// Name of a value, attribute or partial
			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string mixin_;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("type"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string[] type = ["*"];

			@(sdlang.schema.Name("allow"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value[] allow;

			@(sdlang.schema.Mixin("allow-basic-types"))
			@(sdlang.schema.Name("allow-any"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string allowAny;

			/// Description of value (helpful since values don't have names)
			//@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
			//@(sdlang.schema.Name("desc"))
			//@(sdlang.schema.Attribute)
			//@(sdlang.schema.Opt) string desc;
			// END mixin ValCommon_Mixin;
			
			/// Description of attribute
			@(sdlang.schema.Desc("Description of attribute"))
			@(sdlang.schema.Name("desc"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string desc;
			// END mixin AttrCommon_Mixin;

			// START mixin OptCommon_Mixin;
			//mixin OptCommon_Mixin;
			@(sdlang.schema.Name("default"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) sdlang.token.Value default_;
			// END mixin OptCommon_Mixin;

			sdlang.ast.Attribute[] allAttributes;
		}

		@(sdlang.schema.Name("mixin"))
		final class Mixin
		{
			/// Name of a tag or partial
			@(sdlang.schema.Desc("Name of a tag or partial"))
			@(sdlang.schema.Value)
			string value;
		}
	}

	@(sdlang.schema.Name("tag-common"))
	@(sdlang.schema.PartialMixin)
	mixin template TagCommon_Mixin()
	{
		/// Tag's name
		@(sdlang.schema.Desc("Tag's name"))
		@(sdlang.schema.Value)
		string value;
		
		/// Description of tag
		@(sdlang.schema.Name("desc"))
		@(sdlang.schema.Desc("Description of tag"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string desc;

		/// Required value
		@(sdlang.schema.Name("val"))
		@(sdlang.schema.Desc("Required value"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Tag)
		TagCommon.Val[] val;

		/// Required value, allow multiples
		@(sdlang.schema.Name("vals"))
		@(sdlang.schema.Desc("Required value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Tag)
		TagCommon.Vals[] vals;

		/// Optional value
		@(sdlang.schema.Name("val-opt"))
		@(sdlang.schema.Desc("Optional value"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.ValOpt[] valOpt;

		/// Optional value, allow multiples
		@(sdlang.schema.Name("vals-opt"))
		@(sdlang.schema.Desc("Optional value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.ValsOpt[] valsOpt;

		/// Required attribute
		@(sdlang.schema.Name("attr"))
		@(sdlang.schema.Desc("Required attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Tag)
		TagCommon.Attr[] attr;

		/// Required attribute, allow multiples
		@(sdlang.schema.Name("attrs"))
		@(sdlang.schema.Desc("Required attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Tag)
		TagCommon.Attrs[] attrs;

		/// Optional attribute
		@(sdlang.schema.Name("attr-opt"))
		@(sdlang.schema.Desc("Optional attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.AttrOpt[] attrOpt;

		/// Optional attribute, allow multiples
		@(sdlang.schema.Name("attrs-opt"))
		@(sdlang.schema.Desc("Optional attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.AttrsOpt[] attrsOpt;

		// START mixin TagVariations_Mixin;
		//mixin TagVariations_Mixin;
		/// Required tag
		@(sdlang.schema.Name("tag"))
		@(sdlang.schema.Desc("Required tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tag[] tag;

		/// Required tag, allow multiples
		@(sdlang.schema.Name("tags"))
		@(sdlang.schema.Desc("Required tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tags[] tags;

		/// Optional tag
		@(sdlang.schema.Name("tag-opt"))
		@(sdlang.schema.Desc("Optional tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagOpt[] tagOpt;
		
		/// Optional tag, allow multiples
		@(sdlang.schema.Name("tags-opt"))
		@(sdlang.schema.Desc("Optional tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagsOpt[] tagsOpt;
		// END mixin TagVariations_Mixin;

		@(sdlang.schema.Name("mixin"))
		@(sdlang.schema.Tag)
		TagCommon.Mixin[] mixin_;
	}

	template Symbol(string name) if(name == "tag-common")
	{ alias Symbol = TagCommon; }

	/++
	Schema:
	--------
	mixin "tag-variations"
	--------
	+/
	// START mixin TagVariations_Mixin;
	//mixin TagVariations_Mixin;
	/// Required tag
	@(sdlang.schema.Name("tag"))
	@(sdlang.schema.Desc("Required tag"))
	@(sdlang.schema.Mixin("tag-common"))
	@(sdlang.schema.Tag)
	TagVariations.Tag[] tag;

	/// Required tag, allow multiples
	@(sdlang.schema.Name("tags"))
	@(sdlang.schema.Desc("Required tag, allow multiples"))
	@(sdlang.schema.Mixin("tag-common"))
	@(sdlang.schema.Tag)
	TagVariations.Tags[] tags;

	/// Optional tag
	@(sdlang.schema.Name("tag-opt"))
	@(sdlang.schema.Desc("Optional tag"))
	@(sdlang.schema.Mixin("tag-common"))
	@(sdlang.schema.Tag)
	TagVariations.TagOpt[] tagOpt;
	
	/// Optional tag, allow multiples
	@(sdlang.schema.Name("tags-opt"))
	@(sdlang.schema.Desc("Optional tag, allow multiples"))
	@(sdlang.schema.Mixin("tag-common"))
	@(sdlang.schema.Tag)
	TagVariations.TagsOpt[] tagsOpt;
	// END mixin TagVariations_Mixin;

	@(sdlang.schema.Name("mixin"))
	@(sdlang.schema.Tag)
	TagCommon.Mixin[] mixin_;
	@(sdlang.schema.Name("mixin"))
	final class Mixin
	{
		/// Name of a tag or partial
		@(sdlang.schema.Desc("Name of a tag or partial"))
		@(sdlang.schema.Value)
		string value;
	}

	/++
	Schema:
	--------
	tag "partial" {
		val type="string" desc="Partial's name"
		mixin "val-common"
		mixin "opt-common"
		mixin "tag-common"
	}
	--------
	+/
	@(sdlang.schema.Name("partial"))
	static final class Partial
	{
		/// Partial's name
		@(sdlang.schema.Desc("Partial's name"))
		@(sdlang.schema.Value)
		string value;
		
		// START mixin ValCommon_Mixin;
		//mixin ValCommon_Mixin;
		/// Name of a value, attribute or partial
		//@(sdlang.schema.Desc("Name of a value, attribute or partial"))
		//@(sdlang.schema.Name("mixin"))
		//@(sdlang.schema.Attribute)
		//@(sdlang.schema.Opt) string mixin_;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("type"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string[] type = ["*"];

		@(sdlang.schema.Name("allow"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) sdlang.token.Value[] allow;

		@(sdlang.schema.Mixin("allow-basic-types"))
		@(sdlang.schema.Name("allow-any"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string allowAny;

		/// Description of value (helpful since values don't have names)
		//@(sdlang.schema.Desc("Description of value (helpful since values don't have names)"))
		//@(sdlang.schema.Name("desc"))
		//@(sdlang.schema.Attribute)
		//@(sdlang.schema.Opt) string desc;
		// END mixin ValCommon_Mixin;

		// START mixin OptCommon_Mixin;
		//mixin OptCommon_Mixin;
		@(sdlang.schema.Name("default"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) sdlang.token.Value default_;
		// END mixin OptCommon_Mixin;

		// START mixin TagCommon_Mixin;
		//mixin TagCommon_Mixin;
		/// Tag's name
		//@(sdlang.schema.Desc("Tag's name"))
		//@(sdlang.schema.Value)
		//string value;
		
		/// Description of tag
		@(sdlang.schema.Name("desc"))
		@(sdlang.schema.Desc("Description of tag"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Opt) string desc;

		/// Required value
		@(sdlang.schema.Name("val"))
		@(sdlang.schema.Desc("Required value"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Tag)
		TagCommon.Val[] val;

		/// Required value, allow multiples
		@(sdlang.schema.Name("vals"))
		@(sdlang.schema.Desc("Required value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Tag)
		TagCommon.Vals[] vals;

		/// Optional value
		@(sdlang.schema.Name("val-opt"))
		@(sdlang.schema.Desc("Optional value"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.ValOpt[] valOpt;

		/// Optional value, allow multiples
		@(sdlang.schema.Name("vals-opt"))
		@(sdlang.schema.Desc("Optional value, allow multiples"))
		@(sdlang.schema.Mixin("val-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.ValsOpt[] valsOpt;

		/// Required attribute
		@(sdlang.schema.Name("attr"))
		@(sdlang.schema.Desc("Required attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Tag)
		TagCommon.Attr[] attr;

		/// Required attribute, allow multiples
		@(sdlang.schema.Name("attrs"))
		@(sdlang.schema.Desc("Required attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Tag)
		TagCommon.Attrs[] attrs;

		/// Optional attribute
		@(sdlang.schema.Name("attr-opt"))
		@(sdlang.schema.Desc("Optional attribute"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.AttrOpt[] attrOpt;

		/// Optional attribute, allow multiples
		@(sdlang.schema.Name("attrs-opt"))
		@(sdlang.schema.Desc("Optional attribute, allow multiples"))
		@(sdlang.schema.Mixin("attr-common"))
		@(sdlang.schema.Mixin("opt-common"))
		@(sdlang.schema.Tag)
		TagCommon.AttrsOpt[] attrsOpt;

		// START mixin TagVariations_Mixin;
		//mixin TagVariations_Mixin;
		/// Required tag
		@(sdlang.schema.Name("tag"))
		@(sdlang.schema.Desc("Required tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tag[] tag;

		/// Required tag, allow multiples
		@(sdlang.schema.Name("tags"))
		@(sdlang.schema.Desc("Required tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.Tags[] tags;

		/// Optional tag
		@(sdlang.schema.Name("tag-opt"))
		@(sdlang.schema.Desc("Optional tag"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagOpt[] tagOpt;
		
		/// Optional tag, allow multiples
		@(sdlang.schema.Name("tags-opt"))
		@(sdlang.schema.Desc("Optional tag, allow multiples"))
		@(sdlang.schema.Mixin("tag-common"))
		@(sdlang.schema.Tag)
		TagVariations.TagsOpt[] tagsOpt;
		// END mixin TagVariations_Mixin;

		//@(sdlang.schema.Name("mixin"))
		//@(sdlang.schema.Tag)
		//TagCommon.Mixin[] mixin_;
		// END mixin TagCommon_Mixin;

		//TODO: Adapt this pattern to handle disambiguating a Value vs a tag/attr named "value" 
		@(sdlang.schema.Name("mixin"))
		@(sdlang.schema.Attribute)
		@(sdlang.schema.Tag)
		@(sdlang.schema.TagOrAttr)
		Mixin_TagOrAttr mixin_;
		struct Mixin_TagOrAttr
		{
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Tag)
			TagCommon.Mixin[] tag;

			@(sdlang.schema.Desc("Name of a value, attribute or partial"))
			@(sdlang.schema.Name("mixin"))
			@(sdlang.schema.Attribute)
			@(sdlang.schema.Opt) string attr;
		}

		private union AnyTagBase
		{
			TagCommon.Val val;
			TagCommon.Vals vals;
			TagCommon.ValOpt valOpt;
			TagCommon.ValsOpt valsOpt;
			TagCommon.Attr attr;
			TagCommon.Attrs attrs;
			TagCommon.AttrOpt attrOpt;
			TagCommon.AttrsOpt attrsOpt;
			TagVariations.Tag tag;
			TagVariations.Tags tags;
			TagVariations.TagOpt tagOpt;
			TagVariations.TagsOpt tagsOpt;
			TagCommon.Mixin mixin_;
		}
		alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
		AnyTag[] allTags;

		sdlang.ast.Attribute[] allAttributes;
	}
	@(sdlang.schema.Name("partial"))
	@(sdlang.schema.Tag)
	@(sdlang.schema.Opt) Partial[] partial;

	template Symbol(string name) if(name == "partial")
	{ alias Symbol = Partial; }

	private union AnyTagBase
	{
		TagVariations.Tag tag;
		TagVariations.Tags tags;
		TagVariations.TagOpt tagOpt;
		TagVariations.TagsOpt tagsOpt;
	}
	alias AnyTag = taggedalgebraic.TaggedAlgebraic!AnyTagBase;
	AnyTag[] allTags;

	@(sdlang.schema.Name("dummy"))
	@(sdlang.schema.Attribute)
	@(sdlang.schema.Opt) string dummy;
}
