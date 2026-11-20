---
description: jac check, what it takes (a program, a project, an app, a space), what it checks, the format of a diagnostic, the order errors are reported in, and checking a project's apps and spaces.
keywords: diagnostic, diagnostics, type-check, error format
---
# check

`jac check` finds a program's errors without building it. It runs everything a build checks, and two things a build does not: the main module's `test` blocks and the lint rules the project selects.

```sh
jac check main.jac
```

A program with no errors prints nothing (on a terminal, `✓ Checked main.jac in 0.21s`) and exits with status 0. Otherwise every error is printed to stderr and the status is 1. A warning is printed and fails nothing: a program with warnings and no errors still exits with status 0.

```jac
# expect: E1001, E1110
def label(n: int) -> str {
    return "total: " + n;
}

with entry {
    count: int = "seven";
    print(label(count));
}
```

```text
main.jac:3:12: error[E1110]: '+' is not supported between str and int
 3 |     return "total: " + n;
   |            ^^^^^^^^^^^^^

main.jac:7:18: error[E1001]: expected int, found str
 7 |     count: int = "seven";
   |                  ^^^^^^^

2 errors
`jac docs E1110` explains an error by its code.
```

## Forms and options

```sh
jac check [<program>] [<option>...]
jac check [<app>...] [--profile <profile>]
jac check [<app>] --space <space> [<option>...]
```

`check` takes what [`jac build`](build.md#what-a-program-is) takes, and reads it the same way:

| Named | What is checked |
|---|---|
| `main.jac` | The Jac program that main module starts |
| A directory whose `archwire.jac` declares spaces | The project: every app, and every space no app holds ([below](#checking-a-project)) |
| A directory with a `jac.toml` | The Jac project's `main.jac` |
| Nothing | The directory the command runs in, as above |
| A name with no extension or path in it, in a project whose `archwire.jac` declares spaces | That app: each program it is |

A program of another language is refused (E5090): its own compiler checks it when it is built.

| Option | What it does |
|---|---|
| `--target <platform>` | Check the program as a build for that platform would compile it ([build](build.md#--target-building-for-another-platform)) |
| `--memory <profile>` | The memory profile to check under: `managed`, `rc` or `nogc` (default: `jac.toml`'s `[memory] profile`, else `managed`). See [Memory](../language/memory.md) |
| `--lib` | Check it as the shared library `build --lib` makes |
| `--rt <dir>` | The runtime to check against (default: the `rt/` beside jac) |
| `--space <space>` | Check one space's program on its host: an app's program of it where an app is named, else the space alone |
| `--profile <profile>` | Check the apps as the archwire's profile of that name arranges them |
| `--diagnostics <form>` | How diagnostics are written on stderr: `human` (the default), or `json`, one record a line ([Diagnostics as JSON](#diagnostics-as-json)) |

`check` takes one program. It checks that main module and every module it imports; there is no need to name the others, and naming two is an error. `--target`, `--memory`, `--lib` and `--rt` are options of one program's check: a main module's, or a space's named with `--space`.

## What it checks

| Checked | Examples of what is reported |
|---|---|
| Syntax, of every file the program loads | A missing `;`, an unexpected token, a spelling the language rejects ([Lint rules](lint.md)) |
| That every import names a module | W1100 |
| Declarations | What a declaration itself gets wrong: an edge that names no endpoints (E2086) |
| Names and types | An unknown name (W2001), a value of the wrong type (E1001), an operator its operands do not support (E1110), a call's arguments |
| Ownership | A value used after it was moved (E1301), a borrow that outlives its owner |
| The memory profile's contract | Under `nogc`, or in modules `[memory] enforce` names: where the ownership contract is broken |
| The main module's `test` blocks | The same checks, in the tests the module holds and in its test annexes (`main.test.jac`, `test/main.test.jac`). Tests of imported modules are not checked; check those modules themselves |
| The lint rules the project selects | Each rule `jac.toml`'s `[check.lint]` selects, in the project's own modules ([Lint rules](lint.md)) |

`jac build` runs all of these but the last two.

## The format of a diagnostic

```text
<file>:<line>:<column>: error[<CODE>]: <message>
 <line> | <the source line>
        | <^ under the place, from where it starts to where it ends>
    <a note, when there is one>
```

- **Where**: the file as it was named or found, then line and column, each counting from 1, the column in characters. A diagnostic that belongs to no place in a file (a C module that failed to compile) has only `error[CODE]: message`.
- **The severity**: `error`, or `warning` for a warning, which is shown and fails nothing.
- **The code**: one condition, always the same code. Look one up with `jac docs <code>`; [Diagnostics](../reference/diagnostics/e00-1.md) lists them all. A diagnostic of another tool that jac ran has that tool's own code after the tool's name: `error[rustc E0308]`.
- **The source line**, marked with `^` from where the diagnostic's place starts to where it ends; a place that runs on to later lines is marked to the end of its first. A line longer than 120 columns is cut to 120 around the column.
- **Notes**, indented four spaces: where the code being checked came from, when the compiler made it from other code (a function specialized for compile-time arguments), and what the diagnostic is part of when a build of several programs reports it (`in app 'site'`, `in space 'web'`, `in module 'tests/cart.jac'`).
- **The count**, after the last diagnostic, when there is an error: `1 error` or `N errors`, then the warnings, `2 errors, 1 warning`.
- **Where to read more**: a last line naming the command that explains the first error's code, `` `jac docs E1110` explains an error by its code. `` ([docs and skills](docs.md)).

Diagnostics are sorted by file, then line, then column. When any of them takes more than one line they are set apart by an empty line. One mistake is reported once, even when the compiler meets it in several copies of the same code, and what follows from it is not reported again: with `x = undefined_name + 1;`, `x * 2` and `len(x)` later on are not errors of their own, and the check reports only W2001 for the unknown name.

On a terminal the location and message are bold, the code and the count are red, and the last line is dim. `NO_COLOR` turns color off, `FORCE_COLOR` or `CLICOLOR_FORCE` turns it on where there is no terminal ([Projects](projects.md#color)).

### Codes

A code is a letter and four digits. The first digits give the area:

| Codes | Area |
|---|---|
| `E00xx`, `E01xx` | Syntax |
| `E1xxx` | Types, ownership and regions, what code needs from where it runs |
| `E2xxx` | Declarations, modules and their wiring, impls |
| `E3xxx`, `W3xxx` | Lint rules and rejected spellings |
| `E5xxx` | Native code generation, C and Rust modules, and what a target cannot do |
| `Wxxxx` | Conditions the reference design only warns about |

A `W` code is the reference design's code for a condition the reference design only warns about. jac uses the reference design's code wherever the reference design reports the same condition, and where native code can give the program no meaning past the condition it refuses the program under the reference design's warning code: a `W` code is then shown as `error[W2001]`, counts as an error and fails the check. One is a warning in jac too: W0060, a string that documents nothing, is shown as `warning[W0060]` and fails nothing.

### Diagnostics as JSON

`--diagnostics json`, an option of `check`, `build`, `run` and `test`, writes each diagnostic as one line of JSON on stderr instead, with no count and no last line:

```sh
jac check wrong.jac --diagnostics json
```

```text
{"severity":"ERROR","kind":"DIAGNOSTIC","origin":"jac","code":"E1001","msg":"expected int, found str","args":["int","str"],"span":{"file":"wrong.jac","line":2,"col":18,"end_line":2,"end_col":25,"text":""},"labels":[],"children":[],"fixes":[],"expansion":[],"frames":[],"causes":[],"units":[],"facts":{},"result":null}
```

A record holds its `severity` (`ERROR`, `WARNING`, `INTERNAL` for a defect of jac itself), the `origin` whose diagnostic it is (`jac` for jac's own, else the tool's name) and its `code`, the message `msg` and the `args` that filled its template, its place `span` with where it ends, and the `units` it is part of (an app, a space, a module). The exit status is the same as without the option. A jac that another jac runs sends its records the same way, to the file `JAC_DIAGNOSTICS_TO` names ([Environment](../reference/environment.md)), and the one that ran it shows them as part of what it was building.

## The order errors are reported in

jac does not stop at the first error. It checks in phases; within a phase it recovers from each error and keeps going, then reports everything the phase found and stops. A later phase runs only when the ones before it found nothing.

| Phase | Reports |
|---|---|
| 1. Loading | Syntax errors in every file of the program, and imports that name no module |
| 2. Declarations | What declarations themselves get wrong, before any function body is checked |
| 3. Types and ownership | Names, types, calls, moves and borrows, the memory contract, all in one report |
| 4. Lint | The selected rules' findings |

So a file with a missing `;` and a type error shows only the missing `;` first:

```jac
# expect: E0002
def label(n: int) -> str {
    return "total: " + n
}

with entry {
    print(label(1));
}
```

```text
main.jac:4:1: error[E0002]: missing ';'
 4 | }
   | ^

1 error
`jac docs E0002` explains an error by its code.
```

The parser recovers from a syntax error and reads on, so every syntax error in every file is in the first report. Fix what is reported and run `check` again until it is quiet.

## Checking a project

In a project whose `archwire.jac` declares spaces, a program is not a main module: a space runs on a host (native code, CPython, Node, a browser), and an app is one or more spaces built together. Its apps are its programs, and `check` names them as `build` does:

```sh
jac check                       # the project here: every app, and every space no app holds
jac check site                  # the app site: each program it is
jac check site desk             # two apps
jac check site --profile fleet  # the app as that profile of the archwire arranges it
jac check site --space web      # the app site's program of the space web
jac check --space web           # the space web alone, on its host
```

- **An app** is checked as `jac build <app>` compiles it: the program of the spaces it runs, and its program of each space it serves or carries, each on its own host. They are checked at once, each in a process of its own, so a project's check takes about as long as its slowest program's.
- **A project** is every app, and every space that no app runs or serves, each checked the same way.
- **`--space <space>`** checks one program. With an app named, it is the app's program of that space, with the app's plan (which spaces it runs, where the others are). With none, it is the space alone, as `jac emit-js` and `emit-py` load it ([Inspect](inspect.md)). Either way the tests of its entry module are checked, and a cpython or node space is checked against what that host allows, so a program that compiles to native code can be refused there.

An app's check finds what a space's alone cannot: what the app's plan gets wrong, such as a space it reaches and neither runs nor has an address for (E1212).

A diagnostic of a project's check says what it is part of, and one mistake in a module that several programs hold is reported once, with the first of them:

```text
svc.jac:2:12: error[E1002]: cannot return int from a function declared to return str
 2 |     return 7;
   |            ^
    in app 'api'
```

A check that ends without reporting anything says where what it printed is kept. Two checks of one project at once do not meet: each keeps its own files while it runs. See [Building apps](../apps/building.md) for spaces, apps and profiles.

## What goes wrong

| Message | Cause |
|---|---|
| `error[E5151]: the directory '.' holds no manifest a program is known by` | Nothing was named, in a directory that is no project |
| `error[E5152]: the Jac project '.' has no main.jac, the program it is` | Nothing was named, in a Jac project with no `main.jac`: name its main module |
| `it takes one program, and was given 'a.jac' and 'b.jac'` | Two files. `check` each on its own |
| `nosuch.jac: no such file` | The main module does not exist |
| `` `jac check <app>` checks the apps of the project in this directory, and there is no archwire.jac here `` | A name with no extension, outside a project's root |
| `this project has no app 'nope': its apps are web, desk` | A name the archwire declares no app by |
| `--space names a space of the project in this directory, and there is no archwire.jac here` | `--space` outside a project's root |
| `the archwire has no space 'web'` | `--space` names a space the archwire does not declare |
| `--target is an option of one program's check, and this is a project's apps: name a space with --space` | An option of one program's check, where several programs are checked |
| ``it has no option '--app' (`jac emit-js` has it)`` | An app is named by its name alone: `jac check web` |
| `jac.toml: [check.lint] select is a list of strings` | A `[check.lint]` key of the wrong type ([jac.toml](../reference/jac-toml.md)) |
| `error[E3057]` at a line of `jac.toml` | `[check.lint]` names a rule that does not exist |
