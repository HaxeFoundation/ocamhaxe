# KNOWLEDGE

Accumulated knowledge for installing OCaml and building Haxe on Windows.
General problem-solving only — no machine-specific paths or identifiers.

## 1. Locating things

- The Haxe checkout is a clone of `https://github.com/haxefoundation/haxe`. Identify it by
  `Makefile.win` + `haxe.opam` plus a matching `git remote -v`.
  Beware: a **Haxe binary distribution** directory (the one usually on `PATH`, e.g. via
  `%HAXEPATH%`) looks similar but has no `.git` — check for it.
- The Haxe checkout's `.gitignore` already contains `/opam`, which confirms `haxe/opam/` is
  the intended drop location for `opam.exe` and keeps it out of git.

## 2. Which OCaml version

Do **not** assume an old version — this changes over time. Read it from the checkout:

- `haxe.opam` -> `depends:` currently has `"ocaml" {>= "5.0"}` (required by `domainslib`
  for multicore support).
- `.github/workflows/main.yml` -> `env: OCAML_VERSION:` is the exact version CI pins.
  Prefer that exact version; it is the best-tested one.

The CI workflow is generally the single best reference for how to build Haxe on Windows.
Read `.github/workflows/main.yml` and `.github/actions/setup-ocaml-windows/action.yml`
before improvising.

## 3. Getting OPAM

- Latest release + asset list via the GitHub API:
  `https://api.github.com/repos/ocaml/opam/releases/latest`
- The Windows asset is named `opam-<version>-x86_64-windows.exe`. Download and rename to
  `opam.exe`. It is a single self-contained binary — no installer needed.

## 4. opam init on Windows

Useful non-interactive flags (several warn "experimental" — harmless):

- `--bare` — set up the root and fetch the repository *without* building a compiler.
  **Do a bare init first**: it is fast and surfaces cygwin/toolchain problems before you
  commit to a 10+ minute compiler build.
- `-y`, plus env `OPAMYES=1` / `OPAMCONFIRMLEVEL=unsafe-yes` for full non-interactivity.
- `--cygwin-local-install --cygwin-location=<cygwin root>` — reuse an existing cygwin.
- `--cygwin-internal-install` — let opam install and manage its own private cygwin.
- `--no-setup` — don't let opam modify shell profiles (use when you set `PATH` yourself).
- `--no-git-location` — don't prompt for a git binary; a Windows-native git on `PATH` is fine.

Because these commands are long-running and prompt-prone, run them detached with stdout and
stderr redirected to log files rather than interactively.

### Recovering from an interrupted init

If `opam init` is interrupted partway through the repository download, the root is left in a
state where opam insists **"Opam was already initialised"** while no packages are actually
available. Detect it inside the opam root (`%LOCALAPPDATA%\opam` by default):

- `repo/default.new` exists (partial download), and/or `repo/default/packages` is missing;
- a zero-byte `repo/lock` is left behind.

Fix: confirm no `opam.exe` process is running, delete the stale `repo/lock` and
`repo/default.new`, then re-run init adding `--reinit`. A healthy repo has several thousand
directories under `repo/default/packages`.

## 5. Cygwin requirements

- What matters for building OCaml is the **mingw-w64 cross compiler**, not the cygwin-native
  one: `mingw64-x86_64-gcc-core` and `mingw64-x86_64-gcc-g++`. The absence of
  `<cygwin>/bin/gcc.exe` is **not** a problem and is a misleading thing to check.
  List installed cygwin packages with `cygcheck -c -d`.
- Also required: `make`, `patch`, `diffutils`, `unzip`, `tar`, `xz`, `rsync`.
- `curl` and `git` inside cygwin are **not** required — opam downloads fine without them and
  can use a Windows-native git.
- Haxe's depexts additionally need `mingw64-x86_64-pcre2` and `mingw64-x86_64-zlib`.
- With a **local** (external) cygwin, opam cannot install missing cygwin packages for you;
  add them yourself with cygwin's `setup-x86_64.exe`. With an **internal** cygwin, opam
  handles it. If the existing cygwin lacks the mingw toolchain, an internal install is the
  lower-friction route.
- A correctly configured mingw switch installs these marker packages:
  `host-system-mingw`, `conf-mingw-w64-gcc-x86_64`, `ocaml-env-mingw64`, `flexdll`,
  `mingw-w64-shims`. Confirm with `ocamlopt -config`: expect `system: mingw64`,
  `architecture: amd64`, `c_compiler: x86_64-w64-mingw32-gcc`.

## 6. Putting opam's binaries on PATH

- The directory is `opam var bin --switch <switch>`, i.e. `<opam root>\<switch>\bin`.
  Since the opam root normally lives under the user profile, **user** `PATH` is the right
  scope and needs no elevation.
- **Pitfall:** the user `Path` registry value (`HKCU:\Environment`) is usually
  `REG_EXPAND_SZ` (`ExpandString`) and contains entries like `%USERPROFILE%\...`.
  Writing it back as a plain string silently breaks those entries. Preserve the value kind,
  and read it with `DoNotExpandEnvironmentNames` so you don't bake in expanded paths.
- Broadcast `WM_SETTINGCHANGE` afterwards so already-running apps pick the change up.
- To verify like a *freshly opened* shell, rebuild `PATH` from the Machine + User registry
  values rather than trusting the current process environment, which is stale.

## 7. Installing Haxe's dependencies

- `OPAMEXTERNALSOLVER=builtin-mccs+glpk` — the default resolver may otherwise pull in
  **32-bit** libraries.
- Prepend `<cygwin>\bin` and `<cygwin>\usr\x86_64-w64-mingw32\bin` to `PATH` for the build
  (needed by `luv`, see aantron/luv issue #162).
- Install via a local pin rather than by hand:
  `opam pin add haxe . --no-action` then `opam install haxe --deps-only`.
  Note the pin is a *git* pin, so it tracks committed state of the current branch.
- `conf-neko` merely runs `neko -version`, so any Neko on `PATH` satisfies it — no headers
  or libraries required.

### mbedtls is a hidden dependency

`mbedtls` is **not** listed in `haxe.opam`'s `depends:`, but Haxe's eval target links against
it (`libs/.../mbedtls_stubs.c`, `std/eval/_std/mbedtls/*`). CI installs a prebuilt mingw64
build from the `Simn/mingw64-mbedtls` GitHub releases:

- asset: `mingw64-<arch>-mbedtls-<version>-1-noarch.tar.xz`
- the tarball is laid out as `usr/x86_64-w64-mingw32/sys-root/mingw/{bin,lib,include}`,
  i.e. exactly the cygwin mingw sysroot, so extract it at the cygwin root with
  cygwin's own tar: `tar -C / -xf <file>` (cygwin `tar` needs `xz` installed for `.tar.xz`).

## 8. Building

    opam exec -- make -f Makefile.win ARCH=64 haxe

- Run it under `opam exec` so the switch environment is applied, with the cygwin and mingw
  directories prepended to `PATH`.
- Use **cygwin's** `make`; the Makefile relies on a POSIX shell plus `awk`/`grep`/`sed`/`date`
  and calls `git`, so a Windows-native git on `PATH` is enough.
- `ARCH` defaults to 32 in `Makefile.win`; it only affects the Neko archive name used for
  packaging, but pass `ARCH=64` for correctness.
- The build emits many OCaml `Warning 6 [labels-omitted]` and C warnings from
  `mbedtls_stubs.c`. These are **expected noise**, not failures.
- The default target is `all: haxe tools`, where `tools` builds haxelib from the
  `extra/haxelib_src` **git submodule**. If that submodule was never initialised
  (`git submodule status` shows a leading `-`), the `tools` target cannot build; use the
  `haxe` target alone to get just the compiler, or initialise the submodule first.

### Runtime DLLs

The built `haxe.exe` dynamically links five mingw DLLs: `libmbedtls`, `libmbedcrypto`,
`libmbedx509`, `libpcre2-8-0`, `zlib1`. Find them with
`cygcheck <path>\haxe.exe`. To run the compiler outside the cygwin environment either put
`<cygwin>\usr\x86_64-w64-mingw32\sys-root\mingw\bin` on `PATH`, or copy those DLLs next to
`haxe.exe` (which is what the Makefile's `package_win` target does).

Watch out for a false positive here: if an existing Haxe *distribution* is already on `PATH`,
it ships DLLs with these same names, so a freshly built `haxe.exe` may appear to work while
actually loading the older distribution's copies. Prefer the DLLs you just built against.

### Smoke test

Verify more than `haxe -version` — exercise the native libraries:
set `HAXE_STD_PATH` to the checkout's `std`, then compile and run a small program using a
regexp (pcre2) and `haxe.crypto.Crc32` (zlib) with `--interp` (eval).

## 9. Building from VS Code

The checkout ships `.vscode/tasks.json`. Its **default build task** (Ctrl+Shift+B) on Windows is

    opam exec -- make ADD_REVISION=1 -f Makefile.win -s -j haxe

- **Critical:** this invokes `opam` itself, so the directory containing `opam.exe` must be on
  `PATH`. Adding only the *switch bin* directory (step 6) is **not** sufficient — that gives
  you `ocamlopt`/`dune` but not `opam`. Add both.
- Cygwin's `bin` must also be on `PATH` so the task finds `make` and `sh`.
- `ADD_REVISION=1` appends the git short SHA to the version, so a successful task shows
  `haxe -version` as `<version>+<sha>`. That is a good way to confirm the task really rebuilt
  rather than no-opped.
- **VS Code caches environment variables at launch.** After changing `PATH`, restart VS Code
  (fully quit — reloading the window is not enough) or the task keeps failing with
  `The term 'opam' is not recognized ... CommandNotFoundException`, even though `opam` works
  fine in a newly opened shell outside VS Code.
- **Better than relying on the global `PATH`:** because `opam.exe` lives inside the checkout,
  add it to the workspace terminal environment in `.vscode/settings.json`:

      "terminal.integrated.env.windows": {
          "PATH": "${workspaceFolder};${workspaceFolder}/opam;${env:PATH}"
      }

  This is portable (no machine-specific path), and it takes effect for newly spawned task
  terminals without needing a full VS Code restart. The switch's own `bin` does not need to
  be added, because `opam exec --` injects it.
- To test the task without clicking through the UI, run the exact command string from
  `tasks.json` in a shell whose `PATH` you rebuilt from the Machine + User registry values —
  that reproduces what a freshly started VS Code sees. Note `.vscode/settings.json` also
  prepends `${workspaceFolder}` to the terminal `PATH`.
- Beware when scripting such a test: passing a `PATH` assignment through nested shell
  invocations easily loses its quoting, and each `;`-separated segment then gets parsed as a
  command. Set the environment in the parent process and let the child inherit it instead.

### OCaml extension sandbox

`.vscode/settings.json` pins the OCaml Platform extension to a sandbox:

    "ocaml.sandbox": { "kind": "opam", "switch": "default" }

If your switch is not literally named `default` (e.g. you created it named after the OCaml
version), the extension will not find it and IDE features (merlin, go-to-definition) break —
though the *build task* is unaffected, since it uses `opam exec` against the current switch.
Either name the switch `default` at creation time, or update this setting to the switch name.

`.vscode` is listed in the Haxe repo's `.gitignore`, so local edits there won't dirty the
checkout.
