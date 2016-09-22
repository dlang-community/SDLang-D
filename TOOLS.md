Included tools and scripts
==========================

Lex or Parse an SDL file
------------------------

Using [DUB](http://code.dlang.org/download):

```console
> dub build
> bin/sdlang lex sample.sdl
(...output...)
> bin/sdlang parse sample.sdl
(...output...)
> bin/sdlang to-sdl sample.sdl
(...output...)
```

Unittests
---------

Using [DUB](http://code.dlang.org/download):

```console
> dub test
or
> dub test --config=unittest-buitin
```

The first one runs the tests via [unit-threaded](https://github.com/atilaneves/unit-threaded). The second uses D's built-in test runner.

Build API Reference
-------------------

Make sure [ddox](https://github.com/rejectedsoftware/ddox) is installed and
on the PATH.

Also, at the moment, SDLang-D's dependencies will need to be in specific sister directories to SDLang-D, instead of where DUB installs them:

```console
> cd ..
> git clone https://github.com/Abscissa/libInputVisitor.git libInputVisitor
> git clone https://github.com/s-ludwig/taggedalgebraic.git taggedalgebraic
> cd sdlang-d
```

Then, run:

```console
> build-docs
```

Finally, open 'docs/index.html' in your browser.

DUB Package Files
-----------------

SDLang-D is a [DUB](http://code.dlang.org/getting_started) package and is available in the [DUB package registry](http://code.dlang.org/). The package name is [```sdlang-d```](http://code.dlang.org/packages/sdlang-d).
