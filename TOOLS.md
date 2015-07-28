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

Or, you can use [DUB](http://code.dlang.org/getting_started):

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

Or, you can use [DUB](http://code.dlang.org/getting_started):

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

DUB Package Files
-----------------

SDLang-D is a [DUB](http://code.dlang.org/getting_started) package and is available in the [DUB registry](http://registry.vibed.org/). The package name is ```sdlang-d```.
