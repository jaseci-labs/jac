---
description: jac arch, a project's architecture drawn from its archwire.jac - the layers, one layer or module opened, the spaces under each profile; a page that follows the project as it is edited, and the picture as text, SVG, PNG, Mermaid and JSON.
keywords: arch, architecture, diagram, picture, viewer, mermaid, svg, png, architecture diagram
---
# arch

`jac arch` draws a project's architecture, and draws it from `archwire.jac` and nothing else.
Its [layers](../language/modules-layers.md) are the boxes. Its [wires](../language/modules-wiring.md)
are the arrows, each with the edge rule that admits it at that level of the layers beside it. Nothing in the picture is written
down a second time anywhere, so the picture cannot say something the code does not.

```sh
jac arch                  # serve the picture as a page
jac arch --text           # print it on the terminal
jac arch platform --text  # one layer, opened
```

Run it from anywhere inside a project. For the project of [Layers](../language/modules-layers.md),
`jac arch platform --text` prints:

```text
platform
What the program stands on.

          ┌─ time ────────────────────┐
          │ Clocks, and nothing else. │
          │                           │
          │ core.clock                │
          └───┬───────────┬───────────┘
              │ Time      │ Clock
              │           └───────────┐
              ▼                       │
┌─ machine ────────────────────────┐  │
│ The machine the program runs on. │  │
│                                  │  │
│ host · posix · shared · win      │  │
└────────────┬─────────────────────┘  │
             │ Machine                │
             └─────────────┐        ┌─┘
                           ▼        ▼
                ┌╌ screen ╌╌╌╌╌╌╌╌╌╌╌╌┐
                ╎ What the user sees. ╎
                ╎                     ╎
                ╎ app.view · main     ╎
                └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

## What is drawn

| In the picture | Where it comes from |
|---|---|
| A box | A layer, with its docstring and what it holds. Opened, a layer's boxes are the layers it holds, or its modules |
| A module's words | The first sentence of the module's own docstring |
| An arrow | The wires between the two boxes' modules, from the provider to the consumer |
| A dotted arrow, its head hollow in `--text` (`▽`) | An arrow whose every wire is [declared](../language/modules-wiring.md#declared-wires---) (`-->`): the consumer is a file in another language, whose own source writes the import. A solid arrow has a wire that is the import (`++>`). In `--json` the arrow's `declared` says which, and each wire's `how` |
| `a JavaScript module`, `a Python module`, `a Rust module`, `a C file`, `a C++ file`, `a C module`, `a Rust crate` in a module's box | The module is a file of the project in that language, a C module, or a crate |
| The words beside an arrow | The edge rule that admits those wires between those two boxes: a wire has [a rule at every level](../language/modules-layers.md#a-rule-at-every-level), and each picture shows its own level's |
| A dashed box | Something outside what is opened: another layer, or what the project imports from outside itself |
| A box across the picture's width | A layer that provides to nearly every other, or takes from nearly every other. It names them in place of an arrow to each |

- **What a project imports from outside itself** is drawn too, by where it comes from: the runtime
  and standard library, npm, Python, C libraries. These imports are written in the modules; the
  picture is read from them.
- **`--view spaces`** draws an app project's [spaces](../apps/archwire.md): each space with its
  host, its entry and how many modules run in it, each app with what it runs and serves, and an
  arrow between two spaces for the wires that cross between them. `--profile <name>` draws them as
  that profile arranges them.

## What it takes

```text
jac arch [<layer> | <module>] [--mermaid | --json | --text]
jac arch [<layer> | <module>] --svg <file> | --png <file>
jac arch --view spaces [--profile <profile>] [<output>]
```

| Argument | The picture |
|---|---|
| none | The project's layers |
| a layer's name | That layer, opened |
| a module's name, as wires write it (`core.clock`) | That module, with everything it takes from and gives to |
| `--view spaces` | The spaces, as the unnamed `graph spaces` block arranges them |
| `--profile <name>` | The spaces, as that profile does |

| Output | What is written |
|---|---|
| none | The picture is served as a page: see [The viewer](#the-viewer) |
| `--text` | The picture, on the terminal |
| `--svg <file>` | The same picture as an SVG. It is the same bytes each time for the same project |
| `--png <file>` | The SVG as the browser [`jac browse`](browse.md) drives draws it. The first use fetches that browser |
| `--mermaid` | A Mermaid flowchart, for a README, an issue or a pull request, where GitHub draws it |
| `--json` | What the picture is drawn from: each box and what it holds, each arrow with its wires, the names each carries, the rule that admits it at each level of the layers (`levels`), and its file and line |

The layout of `--text`, `--svg` and `--png` is jac's own, and all three are one layout. Mermaid
lays its flowchart out itself, so it looks different and says the same.

## The whole project is checked

A build checks the modules its program loads. `jac arch` reads **every** module `archwire.jac`
names, in a wire, a rule, a layer or a space, whether or not any program loads it, and every
target's files. So before it draws, it has held the whole project to the wiring's rules:

- a wired name its module never spells, on any target (E1146);
- an import of a project module written where a wire belongs (E1144);
- a module in no layer (E2201);
- an import from outside the project with no rule, where `jac.toml` asks one for each (E2211);
- an edge rule, or a part of one, that nothing uses (E2205, E2206, E2207), an import in a module's
  text included.

**An output option refuses a project whose wiring has errors.** It prints them, writes nothing and
exits with 1: a picture that leaves the terminal is of a project that checks. `--diagnostics json`
prints them as records.

## The viewer

With no output option, `jac arch` serves the picture and prints where:

```text
The architecture of shop is at http://127.0.0.1:8090/
```

- **A click on a layer or a module opens it.** The line above the picture says where it is, and
  each part of that line goes back.
- **The arrows are listed beside the picture.** A click on one, or on its line, shows its wires:
  the two modules with the wire's own arrow between them (`++>`, or `-->` where the consumer's
  source writes the import), the names that cross, the rules that admit them, from the outermost
  level in, and the line of `archwire.jac` that holds the wire.
- **Layers and Spaces** switch the view, and a project with profiles has a list of them.
- **The page follows the project.** It asks the server each second whether a file it read has
  changed, and the server reads the project again when one has.
- **A wiring error is drawn where it is.** The viewer does not refuse a project with errors: it
  draws the wire or the box in red and lists each error with its code and its place.
- **The page loads nothing from anywhere else.** Its code is a Jac program, compiled for the
  browser when jac is built, and it is served from the same address as the picture.

`--listen <address>` says where it serves (`127.0.0.1:8090` when not given; port 0 is any free
port). It serves until it is interrupted. It opens no browser: open the address in one, or have
[`jac browse`](browse.md) do it.

## For editors

- **`jac query arch <file>[:<line>]`** prints the JSON of the picture a document is in: a
  module's file gives its module, the line of a `layer` in `archwire.jac` that layer, and anywhere
  else in `archwire.jac` the project.
- **The language server** answers the request `jac/architecture` the same way, with the text
  the editor holds, saved or not. See [The language server](lsp.md#architecture).

## What the picture does not show

- **The order things run in.** A module that reads what another recorded depends on it, and
  imports nothing from it. Wires are who may name whom, and that is all the picture says.
- **Plans.** A box for something not built has no source to be drawn from.
- **Imports that files in another language write**: a space's `.py`, `.js` and `.ts` files. A
  wire's consumer is a Jac or C module.
