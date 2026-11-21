---
description: The graph spaces block of archwire.jac, which declares a project's spaces, their hosts and modules, its apps and its profiles.
keywords: graph spaces, spaces, space, app, profile, serve, module pattern
grammar: graph_spaces, space_decl, app_decl, module_pattern, name_list
---
# The archwire's spaces

`graph spaces { ... }` in a project's `archwire.jac` says where the project's code runs: which
modules form each space, the host each space runs on, and which spaces each app runs or serves.
Nothing in a module's own source says any of it.

`archwire.jac` sits at the project's root, beside `jac.toml`. Its other sections are
`graph layers`, which groups the project's modules into the layers every archwire declares
([Layers](../language/modules-layers.md)), and `graph import`, which declares which modules import
which and what each wire carries: see [Wiring modules](../language/modules-wiring.md)
(`jac docs language/modules-wiring`). A `graph spaces` block anywhere else is E2088.

## Syntax

```ebnf
graph_spaces ::= "graph" "spaces" NAME? "{" (STRING (space_decl | app_decl) | space_decl | app_decl)* "}"

space_decl ::= "space" NAME ":" (KEYWORD | NAME) "{" (("entry" wire_module_path | module_pattern ("|" module_pattern)*) ";")* "}"

app_decl ::= "app" NAME "{" (NAME "has" NAME ("." NAME)* ("," NAME ("." NAME)*)* ";" | ("run" | "serve") name_list)* "}"

module_pattern ::= "*" | wire_module_path ("." "*")?
```

`spaces`, `space`, `app`, `run` and `serve` are words only inside this block. They
are not reserved: a program may still name a function `app` or a variable `space`.
In a space, `entry` is the entry clause only when a module path follows it: `entry;`
and `entry | ui;` list a module named `entry`, as any other name is listed.

A complete block, below the `graph layers` block its archwire declares:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space site: browser { entry web; pages.* | ui.*; }
    space api: native { core.orders | core.stock; }
    space reports: cpython { reports.*; }
    space cli: native { entry cli; }

    app web { run api, reports; serve site; }
    app cli { run cli; }
}
```

`jac fmt archwire.jac` lays a space or an app that fits on one line out on one line.

A space and an app may each have a docstring before it, one line of at most 120 characters
(E2209): it is what [`jac arch`](../toolchain/arch.md) writes in that box of the spaces view.

<!-- example: not checked: a graph spaces block is valid only in a file named archwire.jac, beside the modules it places -->
```jac
graph spaces {
    """The site's pages."""
    space site: browser { entry web; pages.*; }

    """Everything the public site is."""
    app web { serve site; }
}
```

## Spaces

`space <name>: <host> { ... }` declares a space. Its body holds:

| Line | Meaning |
|---|---|
| `entry <module>;` | The module the space's program starts at. At most one (E1270). |
| `<pattern> \| <pattern> ...;` | Modules the space holds |

A space's name appears in URLs (`/__jac/call/<space>/...`), in environment variables
(`JAC_REMOTE_<SPACE>`) and in `jac.toml` (`[spaces.<space>]`), so keep it a plain lowercase word.

### Hosts

The host is one of six words. Any other is E1226.

| Host | The space's code becomes | Runs in |
|---|---|---|
| `native` | Machine code, through LLVM | The app's own process |
| `browser` | ES modules, bundled | A browser tab, or a desktop app's window |
| `wasm` | A WebAssembly module | A page of a browser space |
| `node` | ES modules | Node: its own process, or embedded in a native app's |
| `hermes` | A Hermes bundle | A phone app, on React Native's engine |
| `cpython` | CPython code objects | CPython: its own process, or embedded in a native app's |

[Hosts](hosts.md) says what each one reaches and refuses (`jac docs host`).

### Patterns: which modules a space holds

A pattern is a module's dotted name from the archwire's directory (`core.orders` is
`core/orders.jac`) or a package's name followed by `.*`:

| Pattern | Holds |
|---|---|
| `core.orders` | That module |
| `core.*` | Every module below `core/`, at any depth |

A module is in at most one space. When several patterns match it, the most specific wins:

1. The space that names it as its `entry`, or by its exact name.
2. Otherwise the space with the longest `.*` pattern: `core.site.*` over `core.*`.

Two spaces writing the same pattern is E1275.

The production also allows a bare `*`. That form is for a layer in `graph layers`; in a space it
names no module.

### Modules no space holds

A module that matches no space's pattern is **unplaced**. It is compiled into every program that
imports it, and a call to it is an ordinary call, never a crossing. This is where shared types and
pure logic go: the `obj` a server function returns and a page reads is declared in an unplaced
module that both wire in.

Because an unplaced module has no space to be served from, a `:pub` or `:protect` function or
walker in one is E1211.

### What a space's program starts from

Every space's program starts from its `entry`, when it has one, and from each module its patterns
name exactly. By host, it also starts from:

| Host | Also a root |
|---|---|
| `native` | Each module directly in the directory of a `pkg.*` pattern |
| `browser` | Each of the project's page modules that the space holds ([Pages](pages.md)) |
| `wasm` | Nothing more: its module is the first one its patterns name |

Everything those modules import comes with them. A module nothing reaches is not built.

An `entry` decides what the program does when it starts:

- **A native, node or cpython space with an `entry`** makes its app a program that runs: the
  entry module's `with entry` block is its main code, and the program ends when that code does.
- **An app whose spaces have no `entry`** serves: its program listens for calls of its spaces'
  functions and walkers ([Serving a space](server.md)).
- **A hermes space's `entry`** is the module whose `app` function is the phone app's root
  component.
- **A browser space's `entry`** is optional. It is where the space's style sheets are imported, and
  its `app` function, when it has one, wraps every page ([Pages](pages.md)).

### A space whose entry is in a subdirectory

`entry` takes a dotted name as a pattern does: `entry tool.show;` is `tool/show.jac`. The same
names and `pkg.*` patterns say which modules a layer of `graph layers` holds, and which module a
wire of `graph import` joins. A to-do project with its server in `todos.jac`, its pages under
`pages/`, a command-line client in `tool/show.jac`, and the type `Item` in `model.jac`, which no
space holds:

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer shared { model; }
    layer service { todos; }
    layer pages { pages.*; }
    layer tool { tool.*; }
}

graph spaces {
    space api: native { todos; }
    space site: browser { pages.*; }
    space cli: native { entry tool.show; }

    app api { run api; serve site; }
    app cli { run cli; }
}

graph import {
    edge Shared: shared --> service | pages | tool;
    edge Calls: service --> pages | tool;

    model ++> todos | pages.index | tool.show { Item }
    todos ++> pages.index { add_item, list_items, mark_done }
    todos ++> tool.show { list_items }
}
```

The layer `tool` holds every module below `tool/`, and a rule that names it admits wires to any of
them; each wire names the module it feeds, `tool.show`. `jac build` makes
`dist/cli-<platform>`, which runs `tool/show.jac`'s `with entry` and calls `list_items` on the
server at the URL `[apps.cli.remote]` gives.

### Variants of a module by host

A module may have a file for one host or one `ui` plugin beside its plain file, as it may for an
operating system: `font.hermes.jac` beside `font.jac`, `screen.solid.jac` beside `screen.jac`. A
space's program loads the variant for its `ui` plugin if there is one, else the one for its host,
else the plain file.

## Apps

`app <name> { ... }` declares a program to build. Its body holds:

| Line | Meaning |
|---|---|
| `run <space>, ...;` | The spaces whose code runs in the app's process |
| `serve <space>, ...;` | The `browser` and `wasm` spaces the app hands to browsers |

What an app is follows from the hosts of the spaces it runs:

| The app runs | It builds to |
|---|---|
| Native spaces, with or without served pages | One native program, `dist/<app>-<platform>`, or a directory of that name when it carries pages, CPython or Node |
| Native spaces and one `cpython` and/or one `node` space | The same, with CPython or Node embedded and those spaces run in its process |
| One `node` or one `cpython` space alone | `dist/<app>/`: the space's modules, the interpreter and a launcher |
| A `browser` space | A desktop app: the space in a window of its own ([Hosts](hosts.md)) |
| One `hermes` space | `dist/<app>/`: the phone app's Hermes bundles |

Rules an app must keep:

| Rule | Code |
|---|---|
| Every space it names is declared | E1273 |
| It serves only `browser` and `wasm` spaces, and runs the others | E1272 |
| An app's name is declared once in its block, and a space's once | E0077 |
| A space that calls another space is only in an app when the space it calls is in one too | E1276 |
| Every space the app reaches and does not run has a URL in `jac.toml` | E1212 |

The last two are about **reach**. An app reaches a space when a module of one of its own spaces is
wired to a module of that space. It need not run every space it reaches: a command-line app calls a
server it does not contain. [Crossings](crossings.md) says how such a call travels and where the
URL is given.

Combinations the build does not make yet are refused with E5090: two `cpython` spaces, or two
`node` spaces, in one native app's process, and a `wasm` or `hermes` space in `run` beside native
spaces (a web app lists its `wasm` space under `serve`). So is an app that runs no space: what it
serves needs a program to serve it, so `app web { serve site; }` is refused as
`an app 'web' that serves site and runs no space`.

## Profiles

A second `graph spaces` block with a name is a **profile**: another way to group the same spaces
into apps.

<!-- example: not checked: an archwire is one file of a project -->
```jac
graph layers {
    layer all { *; }
}

graph spaces {
    space orders: native { core.orders; }
    space stock: native { core.stock; }

    app shop { run orders, stock; }
}

graph spaces split {
    app front { run orders; }
    app back { run stock; }
}
```

- The unnamed block holds every space and the default apps.
- A profile holds only apps. A space, or anything else, in one is E1271.
- Under a profile, the apps are the default block's with the profile's added, and a profile's app
  replaces the default one of the same name.

```sh
jac build                      # shop
jac build --profile split      # shop, front and back
jac build front --profile split
jac run back --profile split
```

Under `split`, `orders` and `stock` are in different programs, so the call from one to the other
is a request between them, and `front` needs `stock`'s URL:

```toml
[apps.front.remote]
stock = "http://127.0.0.1:8001"
```

A profile the archwire does not declare is E1274, which lists the ones it has.

One artifact may hold an app as several profiles arrange it, and be whichever its user chooses
where it runs: `profiles` in `jac.toml`'s `[apps.<app>]` lists them, `default` naming the unnamed
block ([Building apps](building.md#several-arrangements-in-one-artifact)).

## What is not in the archwire

What carries a space's work out is not architecture, and no line of the archwire says it: where a
space keeps its graph, what says who a caller is, what carries a call between two spaces. Each is
a [plugin](plugins.md) the project binds in `jac.toml` (`jac docs plugins`), and changing one
changes no module and no line here.

## A line reserved for what is not built yet

| Line | Would choose | Code |
|---|---|---|
| `<space> has fs.read, net;` in an app | What an embedded wasm space may use | E1263 |

## What goes wrong

| Code | Cause |
|---|---|
| E0115 | Something other than a space or an app in the block |
| E0116 | Something other than `entry` or patterns in a space |
| E0117 | Something other than `run`, `serve` or `<space> has` in an app |
| E2093 | The archwire has a syntax error; reported with the error itself |
| E1226 | A host that is not one of the six |
| E1270 | A second `entry` in a space |
| E1271 | A space in a profile |
| E1272 | An app serving a space that is not `browser` or `wasm` |
| E1273 | An app naming a space that is not declared |
| E1274 | `--profile` naming a profile that is not declared |
| E1275 | The same pattern in two spaces |
| E2098 | A space's pattern or its `entry` naming no module of the project |
| E1276 | A space in an app calls a space that no app of that grouping runs or serves |
| E0077 | A space or an app declared twice |

`jac docs E1276` prints any of them with its message.
