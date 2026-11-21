---
description: What makes a directory a project (jac.toml and archwire.jac), how its files are laid out (impl and test annexes, variants), the .jac/ and dist/ directories jac writes, and what jac shows while it works, on a terminal and off one.
keywords: project, project root, .jac, dist, status line, progress, color
---
# Projects

A project is a directory of Jac modules with a `jac.toml` at its top. The directory holding `jac.toml` is the project's root: where jac reads the project's settings, where imports stop climbing, where tests are found from, and where jac keeps what it makes for the project.

```text
shop/
    jac.toml
    main.jac
    cart.jac
    impl/
        cart.impl.jac
    test/
        cart.test.jac
```

```toml
[project]
name = "shop"

[test]
directories = ["."]
```

```sh
cd shop
jac check main.jac
jac build main.jac -o shop
jac test
jac fmt .
```

## The project's root

For a program, the root is the nearest directory at or above the main module's that holds a `jac.toml`, wherever jac is run from. `jac build app/main.jac -o x` and `cd app && jac build main.jac -o x` read the same `jac.toml`. A main module with no `jac.toml` above it is a project of its own directory, with no settings.

The root decides:

| What | How |
|---|---|
| Settings | `jac.toml` is read from the root: the memory profile, lint rules, test directories, `fmt`'s exclusions, Python packages ([jac.toml](../reference/jac-toml.md)) |
| Imports | `import x` looks for `x.jac` beside the importing file, then in each directory above it up to the root ([Modules](../language/modules.md#how-a-module-is-found)) |
| Lint rules | The rules `jac.toml` selects judge the modules under the root ([Lint rules](lint.md#which-files-the-rules-judge)) |
| What jac makes | It goes in `.jac/` at the root (below) |

`jac test` with no paths finds the root from the current directory instead, and `jac fmt` from each directory it is given: the nearest directory at or above it with a `jac.toml`.

`jac.toml` may be as short as one line, or empty. jac reads only the tables it knows and ignores the rest, so the same file can hold settings for other tools.

## archwire.jac

`archwire.jac` is the project's wiring, in Jac:

- its `graph layers` block groups the project's modules into layers, and every module is in one ([Layers](../language/modules-layers.md));
- its `graph import` blocks declare which modules import what from which, and which layers may feed which ([Import wiring](../language/modules-wiring.md));
- its `graph spaces` block declares the project's spaces (where code runs: native, CPython, Node, a browser), its apps and its profiles ([Archwire](../apps/archwire.md)).

An `archwire.jac` governs the modules in its directory and below, up to the root. The commands that work on spaces and apps (`jac build`, `jac run` and `jac check` with an app's name or `--space`, `jac emit-js`, `jac emit-py`) run from the directory that holds it, and refuse to run anywhere else:

```text
jac: `jac emit-py` writes a space of the project in this directory, and there is no archwire.jac here
```

A project of one program needs no `archwire.jac`.

## How the files are laid out

A module is one `.jac` file and the annexes beside it, which are part of the module and are found by their names ([Modules](../language/modules.md#annexes)).

### Impl annexes

An impl annex holds the bodies of what its module declares. For `cart.jac` the compiler looks in three places, and loads each that exists:

1. `impl/cart.impl.jac`
2. `cart.impl.jac` beside the module
3. `cart.impl/cart.impl.jac`

and, in each, any parts `cart.<part>.impl.jac`. `impl/` is the convention: the lint rule `impls-in-annex` reports an annex beside its module, and `jac fmt --fix` moves it ([Lint rules](lint.md#layout-policies), [Impl blocks](../language/impl.md)).

### Test annexes

A test annex holds `test` blocks for its module: `cart.test.jac` beside `cart.jac`, or `test/cart.test.jac`. `jac test` and `jac check` load it with the module; a build does not ([test](test.md)).

### Variants

A module may have a file for each platform it differs on, `fs.linux.jac`, `fs.darwin.jac`, `fs.windows.jac` beside `fs.jac`; a build uses the one for its target ([Modules](../language/modules.md#how-a-module-is-found)).

`jac fmt`, `jac test` and a directory search leave out files and directories whose names start with `.`.

## What jac writes

| Where | What | Written by |
|---|---|---|
| `.jac/build/` | One record for each output a build or check made, of what it read ([The build cache](cache.md#when-a-build-has-nothing-to-do)); each app's build directory; `logs/`, what each program an app's build ran printed | `build`, `check`, `run`, `emit-js`, `emit-py` |
| `.jac/test/<platform>/` | The test runners, at their modules' paths, each with its `.build.log` and `.log` | `test` |
| `.jac/venv/` | The project's Python virtual environment | `install` |
| `.jac/data/<app>/` | An app's graph, accounts and jobs, when it runs on this machine | the app ([Apps](../apps/data.md)) |
| `jac.lock` | What each ecosystem's resolver pinned for `jac.toml`: Python distributions, and each npm tree's lock ([Packages](packages.md)) | `install`, `npm`, `absorb` |
| `eco/<tree>/package.json`, `package-lock.json`, `node_modules/`, `.jac/` | An npm tree as its tools read it, written from `jac.toml` and `jac.lock`, its installed packages, and its spaces as compiled | `install`, `npm`, `build` |
| `dist/` | Each app's artifact | `build` with no main module ([Building apps](../apps/building.md)) |
| `-o <out>` | The program, wherever `-o` names | `build` |

`.jac/`, `dist/` and what jac writes under `eco/` are made again by the commands that wrote them, so they do not belong in version control. `jac.lock` does. The compiled code itself is not in the project: it is in the [build cache](cache.md), shared by every project.

```text
.jac/
dist/
```

That is a `.gitignore` for a project.

## What jac shows while it works

A build, a check or an app's build that takes more than a moment says what it is doing, on stderr. What it shows depends on whether stderr is a terminal.

**On a terminal** there is one status line, redrawn in place: the output being made, the step it is at, and, for a step it waits on, how long that has taken so far.

```text
⠧ main: compiling units · 21/59  0.2s
```

The steps of a program's build are `loading modules`, `resolving names`, `checking types`, `checking ownership`, `generating code`, `preparing units`, `compiling units · <done>/<all>` and `linking`; an app's build adds its own (`building the program`, `bundling site with vite · transforming 4300 modules`, `assembling the artifact`). The line is cut with `…` to the terminal's width, so it never wraps. Its width is counted in the terminal's columns: a wide character (`漢`) takes two, a combining mark or a control character none, and a line is never cut in the middle of a character. Diagnostics, and the output of the tools a build runs, are written above it as they arrive.

When the work is done, the status line is replaced by the outcome:

| Outcome | Printed by |
|---|---|
| `✓ Built main in 1.94s` | A build that made its output |
| `✓ main is up to date` | A build that had nothing to do ([The build cache](cache.md)) |
| `✓ Checked main.jac in 0.21s` | A check with no errors |
| `✓ Wrote out-py in 0.41s` | `emit-js`, `emit-py` |
| `✗ web was not built` | An app whose build failed |

Durations read as `0.35s` under ten seconds, `12.4s` under a minute, `2m 05s` under an hour, and `1h 02m` beyond.

**Anywhere else** (a pipe, a file, CI), there is no status line and no outcome. A build or check that succeeds prints nothing at all, and one that fails prints its diagnostics alone, uncolored. jac still says, on a line of its own, when it fetches something or waits for another build:

```text
jac: fetching <what> for linux-x86_64
jac: waiting for the crates another build is compiling
```

The exit status says whether the command worked, in both cases.

### Tools a build runs

A build runs other programs: Clang and rustc for C and Rust modules, the bundler of a browser space, another jac for each program of an app. Their output is passed through, according to what it is:

- What a tool warns of or reports as an error is shown as the tool wrote it.
- What a tool only narrates (Vite's `transforming...`, the crates rustc is compiling) becomes the status line's detail, and is shown in full only if the tool fails.
- A tool's own colors and redrawing are taken out, and tabs become four spaces.
- A tool that cannot be started is reported (`cannot run`), with exit status 127.

Each program an app's build runs also leaves its output in `.jac/build/logs/`.

### Color

On a terminal, diagnostics and the status line are colored. The usual variables change that:

| Variable | Effect |
|---|---|
| `NO_COLOR` | Set to anything but the empty string: no color, wherever the output goes. It wins over the two below |
| `FORCE_COLOR`, `CLICOLOR_FORCE` | Set to anything but the empty string or `0`: color even where the output is not a terminal (a CI log that shows colors) |
| `TERM=dumb` | No status line and no outcome line, as when the output is not a terminal, and no color unless `FORCE_COLOR` or `CLICOLOR_FORCE` asks for it |

The status line's marks (`✓`, the spinner, `·`, `…`) need a UTF-8 locale, read from `LC_ALL`, `LC_CTYPE` or `LANG`. Without one the line uses ASCII (`|/-\`, ` - `, `...`) and the outcome has no mark.

On Windows, jac does not yet ask what the console is, so it writes there as it does to a file: no status line and no color.

### JAC_PROGRESS_TO

`JAC_PROGRESS_TO=<file>` sends the steps to a file instead: jac appends one line for each step, `<step>` or `<step> · <detail>`, draws nothing, and writes nothing to stderr but diagnostics. It is how one jac shows the steps of another it runs (an app's build shows each program's build as `<outer step> · <inner step>`), and how an editor or a script can follow a build. The variable stays in the environment of the programs jac runs (`jac node`'s, a build step's), so a tool that reports its steps reports them to the same file.

```sh
JAC_PROGRESS_TO=steps.log jac build main.jac -o main
cat steps.log
```

```text
loading modules
resolving names
checking types
checking ownership
generating code
preparing units
compiling units
compiling units · 0/59
compiling units · 22/59
compiling units · 54/59
linking
```

A build with nothing to do writes no steps.

## What goes wrong

| Message | Cause |
|---|---|
| `jac: jac.toml: Expected ']' at the end of a table declaration (at line 1, column 9)` | `jac.toml` is not valid TOML |
| `... there is no archwire.jac here` | A command for spaces or apps run outside the directory that holds `archwire.jac` |
| `the archwire has no space 'web'` | A space the archwire does not declare |
| A setting seems to be ignored | It is in a `jac.toml` that is not the project's root's: jac reads only the nearest one at or above the main module |
