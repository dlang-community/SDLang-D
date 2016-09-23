SDLang-D FAQ
============

Q: What is "SDLang" vs "SDLang-D"?
---------

A: "SDLang" and "SDLang-D" are not synonymous.

"SDLang" refers to the data lanugage itself. It stands for "Simple Declarative Language". It was originally designed by Daniel Leuck and [implemented in Java](https://github.com/ikayzo/SDL). Implementations for other languages followed (such as [Ruby](http://sdl4r.rubyforge.org/) ([source](https://github.com/ikayzo/SDL.rb)), and [.NET](https://github.com/ikayzo/SDL.NET)). It and was originally abbreviated "SDL", although "SDLang" mey be better to avoud confusion with the other "SDL": [Simple DirectMedia Layer](https://www.libsdl.org/).

"SDLang-D" refers to this specific project: An implementation of the SDLang language in [D](http://dlang.org).


Q: Why are anonymous tags required to have at least one value? Regular tags don't require a value.
---------

A: That would make it too easy to confuse the following:

```
num 5
```

vs

```
num=5
```

It's a very subtle-looking difference, and yet both are very different: The first is a normal tag with a value. The second looks very similar, but it isn't - it's an attribute of an anonymous tag. 

The first form is preferred, and the second (being confusing) is disallowed.

Another reason for requiring anonymous tags to have a value is because of the next question:


Q: Why must opening curly braces be on the same line? Why can't they be placed on the *next* line, like in C?
---------

A: Partly for consistent style. But also: Unlike C, SDLang is a newline-terminated langauge. And it does support anonmous tags (tags without names). So if you have this:

```
sometag attr="foo"
{
	childtag 17
}
```

The tag `sometag` is followed by an attribute and then a newline. The newline terminates the tag. So the *following* line is a *separate* tag. The tag on the second line just happens to be an anonymous tag with no values, no attributes and one child.

Fortunately, you won't hit any accidental mistakes from this. That's because, as explained above, anonymous tags are required to have at least one value. So on the example above, you'll simply get an error instead of silent breakage and unexpected results.

So, if this is an error anyway, why not just define it to be a permissible way to add children to a tag? This is being considered for a future version of the SDLang spec, but it's unclear whether it's worth the cost: It would be a special case that's inconsistent with the rest of the langauge, complicates SDLang's formal grammar, for the only benefit of opening the door to inconsistent style.
