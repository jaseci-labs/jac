---
description: What jac is, what one download contains, the platforms it runs on and builds for, and where to go next.
keywords: jac, release, platform
---
# What jac is

jac is a native-first implementation of the Jac language. Its compiler is written in Jac and compiles itself. It compiles a program, with jac's own runtime, into one native executable through LLVM; nothing has to be installed where that executable runs.

```sh
echo 'with entry { print("hello from jac"); }' > hello.jac
jac build hello.jac -o hello
./hello
```

```text
hello from jac
```

jac defines the Jac language it compiles. It is not jaseci's `jac` with another backend: some forms `jac` accepts are errors here (see [Lint rules](../toolchain/lint.md) for the spellings jac rejects). Read the language pages instead of assuming what `jac` or Python does.

## One command

Everything is a subcommand of `jac`. `jac` alone, or `jac help` (`--help`, `-h`), lists them; `jac help <command>` and `jac <command> --help` (or `-h`) say what one takes, with examples; `jac --version` (or `-V`, or `jac version`) names the release, the platform it runs on and the commit it was built from. A command that is another program's command line (`python`, `node`, `npm`, `cc`, `cargo`, ...) passes `--help` to that program, and an option after `--` belongs to the program being run (`jac run web -- --help`).

| Group | Commands | What they do |
|---|---|---|
| Learn | `docs`, `skills` | Print this documentation, and playbooks for common tasks |
| Build and run | `build`, `run`, `check`, `test`, `fmt` | Compile a program or a project's apps, run an app, check for errors, run tests, format source |
| Packages | `install`, `remove`, `npm`, `npx` | A project's Python packages, and npm on jac's Node |
| Runtimes and toolchains | `python`, `node`, `cc`, `c++`, `cargo`, `rustc`, ... | The CPython, Node, Clang and LLD, and Rust that jac carries |
| Inspect | `lsp`, `query`, `parse`, `grammar`, `emit-js`, `emit-py` | The language server and its answers, syntax trees, the grammar, and what a space compiles to |
| About jac | `help`, `version` | The commands, and the release |

[Commands](../reference/commands.md) has every command with its options.

## The documentation is in jac

`jac docs` prints these pages. Every release carries them, for its own version, and reading them needs no network:

```sh
jac docs                   # the map: every section and its pages
jac docs section basics    # a section's pages, each with what it covers
jac docs start/first-program
jac docs walker            # the page that defines a word
jac docs E1030             # what an error code means, and the fix
jac docs search edge filter
```

A word can be a page's name, a keyword or operator of the language, a builtin, a module, a diagnostic code, a command, a `jac.toml` key or an environment variable. `jac skills` lists playbooks for common tasks, written for agents. See [docs and skills](../toolchain/docs.md) (`jac docs toolchain/docs`).

A command given something it does not take says what was wrong, shows its usage, and names the nearest command or option when a word is mistyped. That goes to stderr with exit status 1; help is an answer, so it goes to stdout with status 0.

```sh
jac buld hello.jac
```

```text
jac: 'buld' is not a jac command (did you mean 'build'?)

Run `jac help` for the commands.
```

## What one download contains

A release is one archive, `jac-<version>-<platform>.tar.gz` (`.zip` for Windows). It needs no system compiler, SDK, Python, Node or Rust.

| In the archive | What it is |
|---|---|
| `bin/jac` | The one executable: the Jac compiler, and the tools below under their own command lines |
| `rt/` | The runtime, as Jac source: the builtins, the standard library, `stdjac`. Every program is compiled with it |
| `docs/` | This documentation and the skills, which `jac docs` and `jac skills` print |
| `lib/clang`, `lib/libc`, `lib/libcxx`, `lib/libunwind`, `lib/targets` | Clang's headers, and the C library headers and the C and C++ runtimes of every platform jac builds for |
| `lib/clibs` | The C libraries CPython's standard library and Node are built on, for this platform (another platform's are fetched the first time a build needs them) |
| `lib/cpython` | CPython 3.15: its standard library, and `bin/python3.15`, which is `bin/jac` under its Python name |
| `lib/node` | Node (`bin/node`, which is jac), npm, and what a program embedding Node links |
| `lib/rust` | The Rust toolchain: `rustc`, `rustdoc` and `cargo` (links to `bin/jac`) and the standard library |
| `lib/bin` | The names Rust's tools run jac's C compiler by, for every target |
| `VERSION` | The release's version and the commit it was built from |
| `README.md` | The repository's README, as of the release |

The tools are jac itself, not separate installs:

| Command | Runs |
|---|---|
| `jac python` | CPython 3.15, with its own command line |
| `jac node`, `jac npm`, `jac npx` | Node, and the npm it ships |
| `jac cc`, `jac c++`, `jac ar`, `jac ld.lld`, ... | Clang and LLD, compiling C and C++ for any platform jac builds for |
| `jac cargo`, `jac rustc`, `jac rustdoc` | The Rust toolchain, built against the same LLVM |

## Platforms

Releases run on:

| Platform | Notes |
|---|---|
| `linux-x86_64` | |
| `linux-aarch64` | |
| `macos-aarch64` | Apple Silicon. There is no Intel macOS release |
| `windows-x86_64` | A zip, built on Linux and not yet tested on Windows. The installer does not install it |

A jac on any of them builds programs for all of these, and for `macos-x86_64` and `wasm32-wasi` (WebAssembly), with `--target`. See [build](../toolchain/build.md).

## Where to go next

| To | Read | Or run |
|---|---|---|
| Install a release | [Install](install.md) | `jac docs start/install` |
| Write, check, build and run a program | [A first program](first-program.md) | `jac docs first-program` |
| Build programs, and cross-compile | [build](../toolchain/build.md) | `jac docs toolchain/build` |
| Find errors without building | [check](../toolchain/check.md) | `jac docs toolchain/check` |
| Run tests | [test](../toolchain/test.md) | `jac docs toolchain/test` |
| Set up a project | [Projects](../toolchain/projects.md) | `jac docs toolchain/projects` |
| Configure a project | [jac.toml](../reference/jac-toml.md) | `jac docs jac.toml` |
| Find a page, a word or an error code | [docs and skills](../toolchain/docs.md) | `jac docs toolchain/docs` |
