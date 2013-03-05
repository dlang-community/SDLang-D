# SDLang-D

An [SDL (Simple Declarative Language)](http://sdl.ikayzo.org/display/SDL/Language+Guide) library for [D](http://dlang.org).

SDL is similar to JSON, XML or YAML, except it's:
* Less verbose than JSON and XML.
* [Type](http://sdl.ikayzo.org/display/SDL/Language+Guide#LanguageGuide-literals)-aware.
* Easier to learn and read than YAML.

This is what SDL looks like (some of these examples, and more, are from [the SDL site](http://sdl.ikayzo.org/display/SDL/Language+Guide)):
```
first "Joe"
last "Coder"

numbers 12 53 2 635
names "Sally" "Frank N. Stein"
pets chihuahua="small" dalmation="hyper" mastiff="big"

mixed 34.7f "Tim" somedate=2010/08/14
```

```
folder "myFiles" color="yellow" protection=on {
    folder "my images" {
        file "myHouse.jpg" color=true date=2005/11/05
        file "myCar.jpg" color=false date=2002/01/05
    }
    folder "my documents" {
        document "resume.pdf"
    }
}
```

Tags are of this form:
```
[tag name] [values] [attributes] [children]
```

Tag and attribute names can optionally include a namespace prefix (ie, ```namespace:name```). All parts are optional, the only exception being that an anonymous (ie, no name) tag must have at least one value.

## How to use SDLang-D

The only external requirement is [DMD](http://dlang.org) v2.061 or newer.

Obtain SDLang-D:
```console
> git clone https://github.com/Abscissa/SDLang-D.git
> cd SDLang-D
> git checkout v0.8.1
```

example.d (Note: [API](http://semitwist.com/sdlang-d-api) to be greatly improved):
```d
import std.stdio;
import sdlang;

int main()
{
    Tag root;
    
    try
    {
        // Or:
        // root = parseFile("myFile.sdl");
        root = parseSource(`
            welcome "Hello world"

            // Uncomment this for an error:
            // badSuffix 12Q

            myNamespace:person name="Joe Coder" {
                age 36
            }
        `);
    }
    catch(SDLangException e)
    {
        // Messages will be of the form:
        // myFile.sdl(5:28): Error: Invalid integer suffix.
        stderr.writeln(e.msg);
        return 1;
    }
    
    // Value is a std.variant.Algebraic
    Value welcome = root.tags[""]["welcome"].values[0];
    assert(welcome.type == typeid(string));
    writeln(welcome);
    
    Tag person = root.tags["myNamespace"]["person"];
    writeln("Name: ", person.attributes[""]["name"].value);
    
    int age = person.tags[""]["age"].values[0].get!int();
    writeln("Age: ", age);
    
    return 0;
}
```

Compile and run:
```console
> rdmd --build-only -I{path to sdlang}/src example.d
> example
Hello world
Name: Joe Coder
Age: 36
```

The type ```Value``` is defined as such:
```d
/++
SDL's datatypes map to D's datatypes as described below.
Most are straightforward, but take special note of the date/time-related types.

Boolean:                       bool
Null:                          typeof(null)
Unicode Character:             dchar
Double-Quote Unicode String:   string
Raw Backtick Unicode String:   string
Integer (32 bits signed):      int
Long Integer (64 bits signed): long
Float (32 bits signed):        float
Double Float (64 bits signed): double
Decimal (128+ bits signed):    real
Binary (standard Base64):      ubyte[]
Time Span:                     Duration

Date (with no time at all):           Date
Date Time (no timezone):              DateTimeFrac
Date Time (with a known timezone):    SysTime
Date Time (with an unknown timezone): DateTimeFracUnknownZone
+/
alias Algebraic!(
    bool,
    string, dchar,
    int, long,
    float, double, real,
    Date, DateTimeFrac, SysTime, DateTimeFracUnknownZone, Duration,
    ubyte[],
    typeof(null),
) Value;
```

## API Reference

See [API Reference](http://semitwist.com/sdlang-d-api)

## Changelog

See [Changelog](https://raw.github.com/Abscissa/SDLang-D/master/CHANGELOG.txt)

## Differences from original Java implementation

* API is completely redesigned for D.
* License is zlib/libpng, not LGPL. (No source from the Java or Ruby implementations was used or looked at.)
* Anonymous tags are named ```""``` (ie, empty string) not ```"content"```. Not sure yet whether or not this will change in the future.
* Dates with unknown or invalid time zones use a special type indicating "unknown time zone" (```DateTimeFracUnknownZone```) instead of assuming GMT.

## Included tools

### Lex or Parse an SDL file

```console
> build
> bin/sdlang lex sample.sdl
(...output...)
> bin/sdlang parse sample.sdl
(...output...)
```

### Unittests

```console
> build-unittests
> bin/sdlang-unittest
(...output...)
```

### Build API Reference

Make sure [ddox](https://github.com/rejectedsoftware/ddox) is installed and
on the PATH. Then, run:

```console
> build-docs
```

Finally, open 'docs/index.html' in your browser.

### Project/Package Files

Project files for [Programmer's Notepad 2](http://www.pnotepad.org/) are included. Just open ```SDLang-D.ppg```.

Starting with the upcoming SDLang-D v0.8.2, SDLang-D is a [DUB](https://github.com/rejectedsoftware/dub) package and can therefore be used with DUB. The package name is ```sdlang-d```.

## TODO

In no order:

* Major improvements to API for Tags.
* Ability to write SDL output, not just read it.
* Convert SDL documents to XML and JSON
* Improve API reference.
