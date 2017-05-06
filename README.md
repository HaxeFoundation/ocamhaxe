# ocamhaxe

OCaml distribution for Haxe compilation

If you have download this as a distribution, simply run `config.bat` to have it setup on your system.

If you have cloned the repository, you need to run the Build script in /build to rebuild the ocamhaxe distribution.

### About

There are two distinct scripts:

- `haxe/Build.hx` will build an ocamhaxe repo from scratch, that can be zip'ed and distributed to users as-it. It should contain everything needed to compile & run haxe and its libraries, without any additional requirement 

- `haxe/Config.hx` will setup the computer (env vars etc.) on the client computer that has downloaded the ocamhaxe distribution. It is triggered by `config.bat` so runs from the toplevel directory. 

- both are precompiled using hxcpp so they can get run on a system even if no haxe is available.

- both are referencing `haxe/config.json` which contains cygwin tools / opam libs to install etc. mostly used for the build process or to check in Config if the cygwin already installed on the computer have all the necessary tools/libs
