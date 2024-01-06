# ocamhaxe

OCaml distribution for Haxe compilation

# Install

Download the [Latest Release](https://github.com/haxeFoundation/ocamhaxe/releases/latest) then simply run `config.bat` to have it setup on your system.

# Build

If you have cloned the repository, you need to run the `Build.exe` script in /build to rebuild the ocamhaxe distribution. This requires Cygwin 64 bits + Dumpbin.exe windows utility (part of Visual Studio)

Required Cygwin64 packages are:
  - wget
  - m4
  - patch
  - unzip
  - perl
  - perl-IPC-System-Simple
  - libpcre2-devel
  - mingw64-x86_64-gcc-core
  - mingw64-x86_64-zlib
  - mingw64-x86_64-pcre
  - mingw64-x86_64-pcre2
 
(or for 32 bits):
  - mingw[64]-i686-gcc-core
  - mingw[64]-i686-zlib
  - mingw[64]-i686-pcre

Troubleshoot:

- You need to run `Build.exe` from the command line (`cmd`) to watch for errors
  - If you have Haxe installed, you can also run `haxe --interp --main Build` from the `haxe` folder
- In some cases there is an error about `prims.c` not compiling when building the ocaml compiler. It requires having git for Cygwin installed (prevents windows newline issues). Also make sure that your system PATH has Cygwin at the highest priority to prevent clashes.
- If you get `Access Denied` when runnning `Build.exe`, checkout again the ocamhaxe repository using Git For Windows
- Download and unzip `mingw64-uv` `mingw64-mbedtls` to your Cygwin install folder, from the link provided in `haxe/config.json/mingwPackages`

### About

There are two distinct scripts:

- `haxe/Build.hx` will build an ocamhaxe repo from scratch, that can be zip'ed and distributed to users as-it. It should contain everything needed to compile & run haxe and its libraries, without any additional requirement 

- `haxe/Config.hx` will setup the computer (env vars etc.) on the client computer that has downloaded the ocamhaxe distribution. It is triggered by `config.bat` so runs from the toplevel directory. 

- both are precompiled using hxcpp so they can get run on a system even if no haxe is available.

- both are referencing `haxe/config.json` which contains cygwin tools / opam libs to install etc. mostly used for the build process or to check in Config if the cygwin already installed on the computer have all the necessary tools/libs
