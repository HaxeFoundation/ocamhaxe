# ocamhaxe

OCaml distribution for Haxe compilation

Installing OCaml is not very easy on a Windows system and vary depending on what you have already installed on your computer.

This is AI-based installer. Just checkout the repo and ask it to follow the instructions stored in this file.

# Instructions

- read the KNOWLEDGE.md file if it exists. it might be outdated so be aware.
- locate the haxe git checkout on this computer
- verify that vscode is installed
- download the latest release of OPAM and put it as opam.exe in the haxe/opam directory
- start the opam init, use the localy installed cygwin if asked or install a new one
- once init finish, add the directory where opam store its binaries to the system PATH
- check that ocamlopt is available from the windows commandline
- install the opam dependencies required by haxe. give progress info to the user. solve the errors if any
- build haxe from the Makefile.win. solve the errors if any
- check that it builds from VSCode as well
- congratulate the user when you're done. use a lot of emojis.
- as you run, store any knowledge you learn in KNOWLEDGE.md that can help future users to install more quickly
- do not store any machine specific path or identifier in KNOWLEDGE.md, just general problems solving
- in the end, give a quick summary of what was changed on the machine, in particular the changed env vars