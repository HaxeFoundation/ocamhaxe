# ocamhaxe

OCaml distribution for Haxe compilation

If you have download this as a distribution, simply run `config.bat` to have it setup on your system.

# Build

If you have cloned the repository, you need to run the Build script in /build to rebuild the ocamhaxe distribution. This requires Cygwin  + Dumpbin.exe windows utility (part of Visual Studio)

Required Cygwin packages are:
  - patch
  - unzip
  - mingw[64]-i686-gcc

Troubleshoot:

- In some cases there is an error about prims.c of ocaml not compiling. It seems to be related to newline endings (Makefile sed script outputs "name-of-prim\r\n" instead of "name-of-prim"), running through bash does not help. Not sure yet what to do about it.

### About

There are two distinct scripts:

- `haxe/Build.hx` will build an ocamhaxe repo from scratch, that can be zip'ed and distributed to users as-it. It should contain everything needed to compile & run haxe and its libraries, without any additional requirement 

- `haxe/Config.hx` will setup the computer (env vars etc.) on the client computer that has downloaded the ocamhaxe distribution. It is triggered by `config.bat` so runs from the toplevel directory. 

- both are precompiled using hxcpp so they can get run on a system even if no haxe is available.

- both are referencing `haxe/config.json` which contains cygwin tools / opam libs to install etc. mostly used for the build process or to check in Config if the cygwin already installed on the computer have all the necessary tools/libs
