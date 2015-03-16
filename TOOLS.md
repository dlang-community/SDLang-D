Included tools and scripts
==========================

Lex or Parse an SDL file
------------------------

```console
> build
> bin/sdlang lex sample.sdl
(...output...)
> bin/sdlang parse sample.sdl
(...output...)
> bin/sdlang to-sdl sample.sdl
(...output...)
```

Or, you can use [DUB](https://github.com/rejectedsoftware/dub):

```console
> dub build
> (...same as above...)
```

Unittests
---------

```console
> build-unittest
> bin/sdlang-unittest
(...output...)
```

Or, you can use [DUB](https://github.com/rejectedsoftware/dub):

```console
> dub build --config=unittest
> bin/sdlang-unittest
```

Build API Reference
-------------------

Make sure [ddox](https://github.com/rejectedsoftware/ddox) is installed and
on the PATH. Then, run:

```console
> build-docs
```

Finally, open 'docs/index.html' in your browser.

Programmer's Notepad 2 Project Files
------------------------------------

Project files for [Programmer's Notepad 2](http://www.pnotepad.org/) are included. Just open ```SDLang-D.ppg```.

DUB Package Files
-----------------

As of SDLang-D v0.8.2, SDLang-D is a [DUB](https://github.com/rejectedsoftware/dub) package and is available in the [DUB registry](http://registry.vibed.org/). The package name is ```sdlang-d```.

All you have to do to use SDLang-D in your DUB-based project is include the following in your project's ```package.json``` file:
```json
{
	...
	"dependencies": {
		"sdlang-d": "==0.9.0"
	}
}
```
