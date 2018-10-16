# zxspectrum_be

This project is a ZX Spectrum interface to Andy Key's 'be' data analysis tool. The idea is that this project can be included into a project as a submodule, although how to use it or get the best from it is all a bit up in the air at the moment.

An [article](http://www.derekfountain.org/spectrum_ffdc.php) describing the idea is on my personal website.

What I currently have here:

* early drafts of Tcl scripts which will parse Z88DK/C code and pull out enums and structs and convert them to BE definition files. These aren't great; the code needs to be laid out just so for them to work. On the other hand, manually updating BE definition files each time a C type is changed is an even greater pain.
* an early draft of a Tcl script which will pull out all statically declared variables from C code and throw them into a BE definition file as best it can. This is even ropier than the structure extractor scripts, but it does work, just about.
* a BE definition file describing all the types in _stdint.h_, as they pertain to Z88DK/C for the Spectrum. Useful for including into a project's main BE definitions file.
* a BE definition file describing all the types and structures in the Z88DK SP1 library, useful for including into the BE definitions file for a project which uses SP1. I wrote this by hand and have little clue how most of it works. It proved to be helpful in researching SP1, but needs a lot of work to make it useful for real world debugging.

Andy's BE page, including documentation and downloads, is [here](http://www.nyangau.org/be/be.htm).

My _Wonky One Key_ game, which is the only example of the use of this BE code, is [here](https://github.com/derekfountain/zxwonkyonekey) on GitHub. Start with the _makefile_ in this project to understand how the scripts create BE definitions. Then look at the _wonkyonekey.berc_ file to get an idea of how to write a BE definitions file for a Spectrum game project.
