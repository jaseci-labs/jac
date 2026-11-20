---
description: Every jac command: what it does, its forms, its options and examples.
---
# Commands

What `jac help <command>` prints for each command, in the order `jac help` lists them. This page is printed by `jac help --markdown`, from the same table.

## How a command line is read

Every command reads its arguments the same way, from the table this page is printed from, so what a command's help lists is what the command takes.

- An argument that begins with `-` and a letter, or with `--` and a letter, is an option. One the command does not have is an error, answered with the nearest it has or with the command that has it.
- An option that takes a value takes the next argument, whatever it is. One spelled with `--` also takes it after `=`: `--target=wasm32-wasi`.
- Options and names come in any order.
- `--` ends the options. What follows is names, or, for `run` and `dev`, the arguments of what is run.
- Anything else is a name: `-`, `-5` and `-->` among them.

## Learn

### `jac docs`

Print the documentation: a page, or what defines a word.

```sh
jac docs [--json]
jac docs section <heading> [--json]
jac docs <page | word> [--json]
jac docs search <text> [-n <count>] [--json]
jac docs [<page | word>] --serve [--listen <address>]
jac docs --path
jac docs --check
```

| Option | What it does |
|---|---|
| `--json` | Print the answer as data |
| `--path` | Print the directory the pages are in, for grep |
| `--check` | List what of jac the pages leave out, and what in them leads nowhere |
| `-n <count>` | How many pages a search shows (default: 10) |
| `--serve` | Serve the pages to a browser, opened at the page or the word given |
| `--listen <address>` | Where --serve serves them (default: 127.0.0.1:8091) |

Alone, prints the map: every section, and under its heading its pages, each by its path and title. `docs section <heading>` prints a section's pages, each with what it covers. The pages are Markdown, for this version of jac, and need no network.

A word is answered with what defines it: a page by its path (language/walkers) or the last part of it (walkers), a diagnostic code (E1307), a keyword or operator, a builtin, a module, a jac.toml key, an environment variable, a command, or a rule of the grammar.

Several words are one name (`jac docs flow for`), and an operator is a word like any other, quoted where the shell would read it: `jac docs '-->'`. A word that names nothing is an error, with the nearest that does; `docs search` finds the pages that mention a text. A word that names several things is answered with the first, after a note of the others.

`--serve` serves the same pages to a browser and prints their address: each page as it reads, the map beside it, and one box that searches the pages and answers a word.

| Example | What it does |
|---|---|
| `jac docs` | The map of the pages |
| `jac docs section basics` | A section's pages, each with what it covers |
| `jac docs start/primer` | The language in one page |
| `jac docs visit` | The page that defines a keyword |
| `jac docs E1307` | What an error means, and the fix |
| `jac docs search edge filter` | Pages that mention a text |
| `jac docs --serve` | The pages, in a browser |

Its guide: [toolchain/docs](../toolchain/docs.md) (`jac docs toolchain/docs`).

### `jac skills`

Print playbooks for common tasks, or install them.

```sh
jac skills [--json]
jac skills <name> [--json]
jac skills install [<name>...] [--to <dir>]
```

| Option | What it does |
|---|---|
| `--json` | Print the answer as data |
| `--to <dir>` | Where install writes (default: .agents/skills in the directory it is run in) |

A skill is a playbook for a task, written for an agent: when to use it, the steps, the commands and what a correct result looks like. Alone, lists them.

`skills install` copies skills, each a directory holding a SKILL.md, to where an agent loads them from: every skill, or those named.

| Example | What it does |
|---|---|
| `jac skills` | The skills, each with what it is for |
| `jac skills writing-jac` | One skill |
| `jac skills install` | Every skill, into .agents/skills |

Its guide: [toolchain/docs](../toolchain/docs.md) (`jac docs toolchain/docs`).

## Build and run

### `jac build`

Compile a program, or a project's apps.

```sh
jac build [<program>...] -o <out> [<option>...]
jac build [<app>...] [--profile <profile>]
```

| Option | What it does |
|---|---|
| `-o <out>` | The file to write |
| `--release` | Inline more across modules: faster code, from a build that takes longer |
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--cpu <processor>` | Compile for a processor newer than the platform's baseline: a level of the architecture (x86-64-v2, x86-64-v3, x86-64-v4) or native; the program runs only on processors that have what it has |
| `--lib` | Build a C-ABI shared library of the main module's :pub functions and globals |
| `--c-archive` | Write the program's C modules as a static library; the program isn't built |
| `--gui` | Build a Windows program of the GUI subsystem, which starts without a console |
| `--monitor` | Have a program using Python fire sys.monitoring's events, for profilers and coverage |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--emit-ir <file>` | Also write the program's LLVM IR |
| `--verify-reuse` | Compile every module, and check each one an earlier build made against what its sources make now |
| `--rt <dir>` | The runtime to build against (default: the rt/ beside jac) |
| `--profile <profile>` | Build the apps as the archwire's profile of that name arranges them |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

A program is a file, known by its extension: a Jac program's main module (.jac), a C or C++ program (.c, .cc, .cpp), a Rust one (.rs) or a Python one (.py), each file built alone with its language's standard library. Or it is a directory, known by the first of these manifests it holds: an archwire.jac that declares spaces (a project's apps), jac.toml (a Jac project, whose program is its main.jac), Cargo.toml (a Rust package), cmodule.toml (a C module whose sources define main). With none named, it is the directory you are in.

A program is built into one executable, which needs nothing installed where it runs; a Python program into the directory -o names, holding the program, the CPython it runs on and its standard library, and a launcher of the program's name. The options but -o and --release are a Jac program's.

Several Jac programs are built into one executable that holds each of them and runs the one its first argument names: a program is named by its file, a main.jac by its directory.

In a project whose archwire.jac declares spaces, a name with no extension or path in it is an app's: the apps named, or every app, are each built into dist/, and where each one is is printed.

A build compiles each module on its own and keeps what it compiles in a cache (JAC_CACHE_DIR, else jac/ in your cache directory), so an edit recompiles only what it touched, and a build with nothing changed does nothing.

| Example | What it does |
|---|---|
| `jac build hello.jac -o hello` | A program for this machine |
| `jac build hello.c -o hello` | A C program of one file |
| `jac build adder -o adder --release` | The Rust package in adder/ |
| `jac build hello.jac -o hello.wasm --target wasm32-wasi` | The same program for WASI |
| `jac build count.jac sort.jac -o tools` | Two programs in one executable: `tools count` runs the first |
| `jac build` | Every app of the project in this directory |
| `jac build web --profile fleet` | One app, under a profile |

Its guide: [toolchain/build](../toolchain/build.md) (`jac docs toolchain/build`).

### `jac run`

Build a program, or one of a project's apps, and run it.

```sh
jac run [<program>] [<option>...] [-- <argument>...]
jac run <app> [--fresh] [--profile <profile>] [-- <argument>...]
```

| Option | What it does |
|---|---|
| `-o <out>` | Where to build the program (default: in its project's .jac/build/) |
| `--release` | Inline more across modules: faster code, from a build that takes longer |
| `--cpu <processor>` | Compile for a processor newer than the platform's baseline: a level of the architecture (x86-64-v2, x86-64-v3, x86-64-v4) or native; the program runs only on processors that have what it has |
| `--gui` | Build a Windows program of the GUI subsystem, which starts without a console |
| `--monitor` | Have a program using Python fire sys.monitoring's events, for profilers and coverage |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--rt <dir>` | The runtime to build against (default: the rt/ beside jac) |
| `--fresh` | Start the app with no data: what it kept in .jac/data/<app> is set aside, in a directory beside it named for the moment |
| `--profile <profile>` | Build the app as the archwire's profile of that name arranges it |
| `-- <argument>...` | What follows is the app's own command line |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

A program is named as `jac build` names one, and built as it builds one; then it runs, and jac exits with its status.

An app is run from its project's root. It is built as `jac build <app>` builds it, then runs in jac's place: a signal sent to `jac run` is sent to the app, and the status it ends with is the app's.

A phone app (one that runs a hermes space) is installed on the Android phone or emulator that is connected, an emulator started when none is, and started there; a space it reaches at this machine's own address is reached from the phone as this machine's port.

| Example | What it does |
|---|---|
| `jac run hello.rs` | Build and run a Rust program of one file |
| `jac run -- input.txt` | Run the program in this directory, with an argument |
| `jac run web` | Build the app `web` and serve it |
| `jac run cli -- docs status` | Pass the app its arguments |

Its guide: [apps/building](../apps/building.md) (`jac docs apps/building`).

### `jac dev`

Work on an app: rebuild and restart it as you edit.

```sh
jac dev <app> [<option>...] [-- <argument>...]
```

| Option | What it does |
|---|---|
| `--listen <address>` | Where the app is while it is worked on (default: 127.0.0.1:8000) |
| `--fresh` | Start the app with no data, as `jac run --fresh` does |
| `--profile <profile>` | Build the app as the archwire's profile of that name arranges it |
| `-- <argument>...` | What follows is the app's own command line |

Run from a project's root. The app is built and started, and from then on a change to a file of the project builds again what the change reaches. The app's program is started again only when what it is made from changed; a build that fails says why and leaves what is running as it is.

An app's page is served by its bundler's dev server instead of a bundle, when the bundler has one, so a page edit is one compile, which the open page then shows by itself. The page is at `--listen`, and what it asks of the app goes on to the app's program.

| Example | What it does |
|---|---|
| `jac dev web` | Work on the app `web` |
| `jac dev web --listen 127.0.0.1:9000` | Work on it with its page at another address |

Its guide: [apps/building](../apps/building.md) (`jac docs apps/building`).

### `jac check`

Check a program, or a project's apps, for errors without building.

```sh
jac check [<program>] [<option>...]
jac check [<app>...] [--profile <profile>]
jac check [<app>] --space <space> [<option>...]
```

| Option | What it does |
|---|---|
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--memory <profile>` | The memory profile: managed, rc or nogc (default: jac.toml's [memory] profile, else managed) |
| `--lib` | Check it as the shared library `build --lib` makes |
| `--rt <dir>` | The runtime to build against (default: the rt/ beside jac) |
| `--space <space>` | Check one space's program on its host: an app's program of it where an app is named, else the space alone, as emit-js and emit-py load it |
| `--profile <profile>` | Check the apps as the archwire's profile of that name arranges them |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Runs everything a build checks (syntax, names, types, ownership, the memory profile's contract) and reports every error it finds, the tests of the modules it checks among them. Exits with status 1 when there are any.

It takes what `jac build` takes. A program is a Jac program's main module, or a directory, known by the first of these manifests it holds: an archwire.jac that declares spaces (a project's apps), jac.toml (a Jac project, whose program is its main.jac). With none named, it is the directory you are in.

In a project whose archwire.jac declares spaces, a name with no extension or path in it is an app's. The apps named, or every app and every space no app holds, are each checked as their build makes them: every program an app is, on its host, all at once. --space checks one of them. --target, --memory, --lib and --rt are options of one program's check: a main module's, or a space's.

| Example | What it does |
|---|---|
| `jac check main.jac` |  |
| `jac check` | The project in this directory: its apps, or its main.jac |
| `jac check web` | The app web: each program it is |
| `jac check web --space site` | The app web's program of site |
| `jac check --space site` | The space site alone, on its host |

Its guide: [toolchain/check](../toolchain/check.md) (`jac docs toolchain/check`).

### `jac test`

Build and run tests.

```sh
jac test [<path>...] [<option>...]
jac test <file.jac> -o <runner> [<option>...]
```

| Option | What it does |
|---|---|
| `-k <text>` | Run only the tests whose names contain <text>; a module with none isn't built |
| `-j <jobs>` | Build and run this many modules at once, each told it has this many processors (default: one for each core) |
| `-o <runner>` | Build the one module's test runner, and don't run it |
| `--target <platform>` | Build for another platform: macos-aarch64, macos-x86_64, linux-aarch64, linux-x86_64, windows-x86_64, wasm32-wasi |
| `--rt <dir>` | The runtime to build against (default: the rt/ beside jac) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Runs the tests of every module under the paths given, or under jac.toml's [test] directories. Each module's tests are built into one runner, in the project's .jac/test/, and the runners are built and run in parallel.

Exits with status 1 when a test fails or a runner doesn't build, and 5 when there are no tests.

| Example | What it does |
|---|---|
| `jac test` | Every test in the project |
| `jac test tests/chess -k castling` | Some tests of one directory |

Its guide: [toolchain/test](../toolchain/test.md) (`jac docs toolchain/test`).

### `jac fmt`

Format Jac source.

```sh
jac fmt [--check] [--fix] <path>...
```

| Option | What it does |
|---|---|
| `--check` | Change nothing: list the files that would change, and exit with status 1 if any would |
| `--fix` | First rewrite what has a fix: each old spelling the language rejects, and each lint rule the file's project selects in jac.toml's [check.lint] |

Rewrites the .jac files the paths name in jac's one layout. A directory means every .jac file under it, but those its jac.toml's [fmt] exclude patterns name.

With --fix, a module and its annexes are fixed together, and nothing is written unless every file it would write parses.

| Example | What it does |
|---|---|
| `jac fmt src` |  |
| `jac fmt --check .` | For CI |
| `jac fmt --fix .` | Move a project to the one spelling |

Its guide: [toolchain/fmt](../toolchain/fmt.md) (`jac docs toolchain/fmt`).

### `jac port`

Translate source in another language into Jac.

```sh
jac port [--check] [-o <out>] [<option>...] <path>...
jac port --mapping <language>
```

| Option | What it does |
|---|---|
| `--check` | Write nothing: report what would port and what is refused, and exit with status 1 if anything is |
| `-o <out>` | Where to write: a .jac file for one source, else a directory (default: beside each source) |
| `--mapping <language>` | Print what port makes of each construct of a language: c, c++, rust, python or javascript |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Translates each source file into a Jac module that behaves as the file does, or refuses it and says why. A file is known by its extension, and a directory means every source under it that port translates. Each language is read by its own compiler, and the Jac is written in jac's one layout, with the source's comments.

A file ports whole or not at all: every construct port refuses is reported (E4001, E4005), nothing is written for that file, and the exit status is 1. The source is never changed, and an output that is already there is refused (E4003).

| Example | What it does |
|---|---|
| `jac port tools/gen.py` | Writes tools/gen.jac |
| `jac port --check src` | What of a directory would port |
| `jac port --mapping python` |  |

Its guide: [toolchain/port](../toolchain/port.md) (`jac docs toolchain/port`).

### `jac precommit`

Fix, format and check what is staged for a commit.

```sh
jac precommit [--all] [--verify] [<path>...]
jac precommit --install [--force]
```

| Option | What it does |
|---|---|
| `--all` | The whole project, where no path is given, in place of the staged files |
| `--verify, -v` | Change nothing: fail when a file is not as `jac fmt --fix` leaves it, or doesn't check |
| `--install` | Install git's pre-commit hook, which runs `jac precommit --verify`, and a commit-msg hook that refuses a commit naming an AI as its author |
| `--force` | With --install, replace a hook jac did not install, keeping it as a .bak file |

Runs `jac fmt --fix` on the .jac files staged for a commit (a module with its annexes), then checks each module as `jac check` does, under the rules its project's jac.toml selects in [check.lint].

A module is checked as a program of its own, so one that is no program is fixed and not checked: a file that is another target's variant, and one that jac.toml's `[check] exclude` names. `jac check <main> --target <platform>` checks a variant in the program it is part of.

A file of a project whose archwire.jac declares spaces is checked in its project, whose apps are its programs: `jac check` runs there once, however many of its files are staged.

Exits with status 1 when a check fails, when --verify finds a file to fix, or when it rewrote a staged file, which is then to stage again.

| Example | What it does |
|---|---|
| `jac precommit` | Fix and check the staged files |
| `jac precommit --all --verify` | For CI |
| `jac precommit --install` | Once in a clone |

Its guide: [toolchain/lint](../toolchain/lint.md) (`jac docs toolchain/lint`).

## Packages

### `jac install`

Install the project's packages, of every ecosystem.

```sh
jac install [--frozen]
jac install --pypi <package>...
jac install --npm <package>... [--tree <tree>]
```

| Option | What it does |
|---|---|
| `--pypi <package>...` | Add these packages to jac.toml's [dependencies.pypi], and install them |
| `--npm <package>...` | Add these packages to an npm tree of jac.toml, [npm.<tree>], and install them |
| `--tree <tree>` | The npm tree --npm adds to, made if jac.toml has none of the name; a project's only tree needs no naming |
| `--frozen` | Install exactly what jac.lock pins, and fail if it doesn't cover jac.toml |

Installs what jac.toml lists and records in jac.lock exactly what was installed. A package jac.toml declares by a repository ([packages]) is fetched into eco/jac/<name>. jac.lock pins every package installed there, whoever installed it, and a package declared by its version that is not there stops the install. What the project's libraries and plugins need of PyPI and npm is installed with the project's own. PyPI packages ([dependencies.pypi]) go into the project's virtual environment (.jac/venv), on jac's CPython. Each npm tree ([npm.<tree>], which is that tree's package.json) is installed by jac's npm in eco/<tree>, where jac writes its package.json and package-lock.json from jac.toml and jac.lock.

Where jac.toml has an [android] table, what a phone app's Android build is made with is fetched into jac's cache, once the table accepts the Android SDK's licenses (`licenses = "accepted"`): the SDK unless ANDROID_HOME names one, a JDK unless JAVA_HOME names one, and an emulator where the table says `emulator = true`. Each is a pinned release, checked against its digest.

| Example | What it does |
|---|---|
| `jac install` | What jac.toml lists |
| `jac install --pypi numpy` | Add a PyPI package |
| `jac install --npm lodash --tree web` | Add an npm package |

Its guide: [toolchain/packages](../toolchain/packages.md) (`jac docs toolchain/packages`).

### `jac remove`

Remove packages from the project.

```sh
jac remove --pypi <package>...
jac remove --npm <package>... [--tree <tree>]
```

| Option | What it does |
|---|---|
| `--pypi <package>...` | Take these packages out of jac.toml's [dependencies.pypi] and the environment |
| `--npm <package>...` | Take these packages out of an npm tree of jac.toml and its installed packages |
| `--tree <tree>` | The npm tree, where jac.toml has several |

Its guide: [toolchain/packages](../toolchain/packages.md) (`jac docs toolchain/packages`).

### `jac absorb`

Take another tool's manifest into jac.toml.

```sh
jac absorb [<directory>] [--tree <tree>]
```

| Option | What it does |
|---|---|
| `--tree <tree>` | The name of the npm tree it becomes; a directory's own name without it |

Takes the package.json in a directory, and the package-lock.json beside it, into jac.toml and jac.lock as an npm tree, and moves them and their node_modules to eco/<tree>, where jac writes them from then on.

In a directory with no package.json, takes every Cargo.toml (with its Cargo.lock) and cmodule.toml under it into the jac.toml of the project each is in, as a table named by its directory: jac writes them where they stood from then on.

| Example | What it does |
|---|---|
| `jac absorb --tree web` | The project's own package.json |
| `jac absorb crates` | Every crate and C module under crates/ |

Its guide: [toolchain/packages](../toolchain/packages.md) (`jac docs toolchain/packages`).

### `jac packages`

Print the project's Jac packages, and what is missing.

```sh
jac packages [--json]
```

| Option | What it does |
|---|---|
| `--json` | Print one JSON document, which a package manager reads, and no text |

Prints the Jac packages of the project as the compiler finds them: each one's name, version and kind (and what a plugin fills), where its copy is and what installed it, every package that asks for it and for what, and whether it is found, missing or wrong. Then the version of each abstraction's interface in this jac, which is what a plugin's interface_ver has to be, and every problem with its place in a jac.toml.

It reads and changes nothing: it fetches no package, writes no lock and hashes no file. Exits with status 1 when a package is missing or a check fails, and 0 when the project's packages are all as jac.toml asks.

| Example | What it does |
|---|---|
| `jac packages` | What the project uses, and what is missing |
| `jac packages --json` | The same, for a program to read |

Its guide: [toolchain/packages](../toolchain/packages.md) (`jac docs toolchain/packages`).

### `jac npm`, `jac npx`

Run npm, or npx, on jac's Node.

```sh
jac npm [<npm argument>...]
jac npx [<npx argument>...]
```

The npm that Node ships, with its own command line. In a project it runs in an npm tree of jac.toml (eco/<tree>: the one it is run in, or the project's only one), and what it writes to the tree's package.json and package-lock.json is taken into jac.toml and jac.lock as it ends.

Its arguments, --help among them, are that program's own: `jac npm --help` is its help.

| Example | What it does |
|---|---|
| `jac npm ls` |  |

Its guide: [interop/npm](../interop/npm.md) (`jac docs interop/npm`).

## Runtimes and toolchains

### `jac python`

Run jac's CPython.

```sh
jac python [<python argument>...]
```

CPython 3.15, with its own command line. In a project with a virtual environment (.jac/venv), it is that environment's Python.

Its arguments, --help among them, are that program's own: `jac python --help` is its help.

| Example | What it does |
|---|---|
| `jac python -c 'import sys; print(sys.version)'` |  |

Its guide: [interop/python](../interop/python.md) (`jac docs interop/python`).

### `jac node`

Run jac's Node.

```sh
jac node [<node argument>...]
```

Node, with its own command line.

Its arguments, --help among them, are that program's own: `jac node --help` is its help.

| Example | What it does |
|---|---|
| `jac node server.mjs` |  |

Its guide: [interop/npm](../interop/npm.md) (`jac docs interop/npm`).

### `jac cc`, `jac c++`, `jac clang`, `jac clang++`, `jac ar`, `jac ranlib`, `jac dlltool`, `jac lib`, `jac ld.lld`, `jac ld64.lld`, `jac lld-link`, `jac wasm-ld`, `jac objcopy`

Compile and link C and C++ with jac's Clang and LLD.

```sh
jac cc|c++ [-target <triple>] <clang argument>...
jac clang|clang++|ar|ranlib|dlltool|lib <argument>...
jac ld.lld|ld64.lld|lld-link|wasm-ld <argument>...
jac objcopy --strip-debug|--discard-all|--strip-all <file>
```

The C toolchain jac builds programs with, under its tools' own command lines. cc and c++ compile for any platform jac builds for (-target), with that platform's C library and headers.

Its arguments, --help among them, are that program's own: `jac cc --help` is its help.

| Example | What it does |
|---|---|
| `jac cc -O2 hello.c -o hello` |  |
| `jac cc -target aarch64-linux-gnu hello.c -o hello` |  |

Its guide: [interop/c-and-cpp](../interop/c-and-cpp.md) (`jac docs interop/c-and-cpp`).

### `jac cargo`, `jac rustc`, `jac rustdoc`

Build Rust with jac's Rust toolchain.

```sh
jac cargo|rustc|rustdoc [<argument>...]
```

The Rust toolchain jac carries, built against jac's own LLVM and linking every target through `jac cc`. A target's standard library is fetched the first time a build names it.

In a project whose crates are tables of jac.toml, `jac cargo` writes their Cargo.toml and Cargo.lock first, and jac.toml and jac.lock take what cargo changed as it ends.

Its arguments, --help among them, are that program's own: `jac cargo --help` is its help.

| Example | What it does |
|---|---|
| `jac cargo build --release` |  |

Its guide: [interop/rust](../interop/rust.md) (`jac docs interop/rust`).

## Inspect

### `jac lsp`

Serve an editor over the Language Server Protocol.

```sh
jac lsp
```

An editor starts it and speaks the Language Server Protocol to it. It checks the programs the open files belong to as they are edited, with what is unsaved, and answers the editor from what the checks found.

| Example | What it does |
|---|---|
| `jac lsp` | What an editor is configured to run |

Its guide: [toolchain/lsp](../toolchain/lsp.md) (`jac docs toolchain/lsp`).

### `jac query`

Ask what the language server answers, from the command line.

```sh
jac query <what> <file>[:<line>[:<column>]]
```

<what> is one of definition, declaration, implementation, type, references, hover, symbols, completion, signature, diagnostics and arch. The file is checked as the language server checks it, in the program it belongs to, and the answer is printed: places as <file>:<line>:<column>-<line>:<column>, one to a line.

`arch` prints, as JSON, the architecture picture the file is in, as `jac arch --json` does: a module's file gives its module, the line of a layer in archwire.jac that layer, and anywhere else there the project.

| Example | What it does |
|---|---|
| `jac query definition main.jac:12:9` | Where what is at 12:9 is defined |
| `jac query references core/clock.jac:3:5` | Every use of it in its program |
| `jac query symbols main.jac` | The file's outline |
| `jac query arch core/clock.jac` | What the module takes and gives |

Its guide: [toolchain/lsp](../toolchain/lsp.md) (`jac docs toolchain/lsp`).

### `jac browse`

Drive a browser: open a page, read it, act on it.

```sh
jac browse open <url> [--no-sandbox] [--chrome <path>]
jac browse open <url> --cdp <address>
jac browse back | forward | reload | close [--all]
jac browse snapshot [-i]
jac browse click | dblclick | hover | focus <element>
jac browse check | uncheck | scrollintoview <element>
jac browse fill | type <element> <text>
jac browse select <element> <option>...
jac browse upload <element> <file>...
jac browse press | keydown | keyup <key>
jac browse scroll <up | down | left | right> [<pixels>]
jac browse mouse move <x> <y> | wheel <dy> [<dx>]
jac browse mouse down | up [<button>]
jac browse get title | url | text [<element>] | html [<element>]
jac browse get value | box <element> | count <selector>
jac browse get attr <element> <name>
jac browse is visible | enabled | checked <element>
jac browse eval <javascript>
jac browse wait <element> | <milliseconds> | --text <text>
jac browse wait --url <pattern> | --load <state> | --fn <javascript>
jac browse console | errors [--clear]
jac browse network requests [--filter <text>] [--clear]
jac browse cookies [set <name> <value> | clear]
jac browse storage <local | session> [<key> | clear]
jac browse storage <local | session> set <key> <value>
jac browse state save | load <file>
jac browse tab [new [<url>] | <number> | close [<number>]]
jac browse frame <element> | main
jac browse dialog [accept [<text>] | dismiss]
jac browse set viewport <width> <height>
jac browse screenshot [<file>] [--full]
jac browse pdf <file>
jac browse session list
jac browse serve [--no-sandbox] [--chrome <path> | --cdp <address>]
```

| Option | What it does |
|---|---|
| `--session <name>` | The session a command is for (default: JAC_BROWSE_SESSION, else default) |
| `--timeout <seconds>` | How long a command waits for what it needs (default: 10, and 30 for a page to load) |
| `--chrome <path>` | Start this browser, a Chrome or Chromium, in place of the one jac fetches |
| `--cdp <address>` | Attach to a browser that is running, by its debugger's address |
| `--no-sandbox` | Start the browser without its sandbox |
| `-i` | snapshot: only what can be acted on, with its refs |
| `--full` | screenshot: the whole page, not only the window |
| `--clear` | console, errors, network requests: forget what was kept |
| `--all` | close: every session |
| `--text <text>` | wait: until the page's text holds this |
| `--url <address>` | wait: until the page's address matches this pattern; cookies set: the site the cookie is for |
| `--load <state>` | wait: until the page has reached load, domcontentloaded or networkidle |
| `--fn <javascript>` | wait: until this expression is true |
| `--filter <text>` | network requests: only those whose address holds this |
| `--domain <domain>` | cookies set: the site the cookie is for |
| `--path <path>` | cookies set: the path the cookie is sent for |
| `--expires <seconds>` | cookies set: when the cookie ends, in seconds since 1970 |
| `--samesite <mode>` | cookies set: Strict, Lax or None |
| `--secure` | cookies set: sent only over HTTPS |
| `--httponly` | cookies set: kept from the page's scripts |

A session is a browser a background process holds: `open` starts one, the commands after it act on its page, and `close` ends it. The browser is Chrome's headless shell, which jac fetches the first time and keeps beside its build cache; nothing is installed.

`snapshot` prints the page as its accessibility outline, each thing that can be acted on with a ref (`[ref=e3]`). An <element> is a ref of the last snapshot, written `@e3`, or a CSS selector. A command that acts on an element waits until it is visible, enabled, still, and not covered, then sends the browser real input.

| Example | What it does |
|---|---|
| `jac browse open localhost:8000` | Start a session at a page |
| `jac browse snapshot -i` | What can be acted on, with refs |
| `jac browse click @e5` | Click an element by its ref |
| `jac browse fill '#email' ann@example.com` | Fill a field |
| `jac browse wait --text Welcome` | Wait for text to appear |
| `jac browse screenshot page.png` | Save what the window shows |
| `jac browse close` | End the session |

Its guide: [toolchain/browse](../toolchain/browse.md) (`jac docs toolchain/browse`).

### `jac arch`

Draw a project's architecture from its archwire.jac.

```sh
jac arch [<layer> | <module>] [--mermaid | --json | --text]
jac arch [<layer> | <module>] --svg <file> | --png <file>
jac arch --view spaces [--profile <profile>] [<output>]
```

| Option | What it does |
|---|---|
| `--view <view>` | layers (the default), or spaces: the spaces on their hosts, the apps that run and serve them, and the crossings between them |
| `--profile <profile>` | The spaces view as the archwire's profile of that name arranges it |
| `--mermaid` | Print the picture as a Mermaid flowchart |
| `--json` | Print the picture's content: its boxes, its arrows, the names each wire carries and where it is written |
| `--text` | Print the picture on the terminal |
| `--svg <file>` | Write the picture as an SVG |
| `--png <file>` | Write the picture as a PNG, drawn by the browser `jac browse` drives |
| `--listen <address>` | Where the viewer is served (default: 127.0.0.1:8090) |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Run from inside a project. The picture is drawn from archwire.jac and from nothing else: its layers are the boxes, its wires the arrows, each labelled with the edge rule that admits it.

With no output option, the picture is served as a page that follows the project as it is edited: its address is printed, and a click on a layer, a module or an arrow opens it. An output option prints one picture and exits, and refuses a project whose wiring has errors: it prints them and writes nothing.

Every module archwire.jac names is read, whether or not a program loads it, and every target's wires are checked, so what is drawn holds for the whole project.

| Example | What it does |
|---|---|
| `jac arch` | Serve the project's picture |
| `jac arch --text` | Print it on the terminal |
| `jac arch backends --text` | One layer, opened |
| `jac arch compiler.gen --json` | One module: what it takes and gives |
| `jac arch --mermaid` | A flowchart for a README or a pull request |
| `jac arch --view spaces --svg spaces.svg` | The spaces, as a file |

Its guide: [toolchain/arch](../toolchain/arch.md) (`jac docs toolchain/arch`).

### `jac parse`

Check that files parse, or print their syntax trees.

```sh
jac parse [--tree] <file.jac | @list>...
```

| Option | What it does |
|---|---|
| `--tree` | Print each file's syntax tree |
| `@<list>` | A file naming the files to parse, one to a line |

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`jac docs toolchain/inspect`).

### `jac grammar`

Print the grammar a parser implements.

```sh
jac grammar <parser.jac> [--page] [-o <file>]
```

| Option | What it does |
|---|---|
| `-o <file>` | Write it to a file |
| `--page` | Print it as the documentation's page of it (docs/reference/grammar.md) |

Reads the grammar out of a parser's source (jac's own is compiler/parsing/parser.jac), as compiler/parsing/jac.spec records it.

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`jac docs toolchain/inspect`).

### `jac emit-js`, `jac emit-py`

Write a space's JavaScript, or its Python code.

```sh
jac emit-js <space> -o <dir> [--app <app> [--profile <profile>]]
jac emit-py <space> -o <dir> [--app <app> [--profile <profile>]]
```

| Option | What it does |
|---|---|
| `-o <dir>` | The directory to write |
| `--app <app>` | The space as that app's program of it, with its plan |
| `--profile <profile>` | The app under that profile |
| `--diagnostics <form>` | How diagnostics are written on stderr: human (the default), or json, one record a line |

Run from a project's root: the modules of one space of its archwire, checked and written as an app's build would write them. emit-js is for a space on a JavaScript host (browser, node, hermes), emit-py for one on cpython.

Its guide: [toolchain/inspect](../toolchain/inspect.md) (`jac docs toolchain/inspect`).

## About jac

### `jac help`

List the commands, or say what one takes.

```sh
jac help [<command>]
jac help --markdown
```

| Option | What it does |
|---|---|
| `--markdown` | Print every command's help as one Markdown page (docs/reference/commands.md) |

`jac <command> --help` says the same of a command as `jac help <command>`.

### `jac version`

Name the release jac is installed from.

```sh
jac version
```

Prints the release's version, the platform it runs on and the commit it was built from; `jac --version` and `jac -V` do the same. A jac built from source says so.
