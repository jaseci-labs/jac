---
description: The principle Jac is built on, that a program's source says what it means and never how that is carried out, the distinction between a library and a plugin that follows from it, which file says what, and the abstractions a project chooses a plugin for today.
keywords: principles, plugin, abstraction, mechanism
---
# Principles

Jac raises abstraction to the language. A program says what it means, and how that is carried out
is decided outside its source. This page states that principle, the distinction between a library
and a plugin that follows from it, and what a project chooses today.

## Source says what, never how

A module names an abstraction and leaves its mechanism unsaid:

| A module says | Which means | And does not say |
|---|---|---|
| `root ++> Note(text="hi");` | This caller's graph holds a note, kept between runs of a served app | Which database keeps it ([root](root.md)) |
| `greet("jac")`, `greet` a function of another space | A call | Whether it leaves the process, or what carries it ([Crossings](../apps/crossings.md)) |
| `def:protect` | Only a signed-in caller may call this | How a caller is known ([Access tags](access.md)) |
| `def triage(m: str) -> Ticket by llm();` | A model gives a `Ticket` | Which model ([By and sem](by-and-sem.md)) |
| `has count: int = 0;` in a component | State the page shows | Which UI library holds it ([Components and JSX](../apps/components.md)) |

So a mechanism changes and no module changes with it. This component is the same source under
React, Preact and Solid, and which of them its state becomes is one line of `jac.toml`:

<!-- example: not checked: a component is a module of a browser space, with JSX -->
```jac
def Counter -> JsxElement {
    has count: int = 0;

    return <button onClick={lambda { count = count + 1; }}>{count}</button>;
}
```

```toml
[spaces.site.ui]
plugin = "solid"    # or "react", or "preact"
```

When changing how something is done would mean editing a module, an abstraction is missing or
leaking. That is a defect of the language or of its library, not a cost of the change.

## A library and a plugin

Code that is not a program's own reaches it in one of two ways, and the two are kept apart:

| | Library | Plugin |
|---|---|---|
| What it is | Code a program calls | The mechanism behind one abstraction |
| Named by | A module, with `import` | The project, in `jac.toml` |
| Its interface is | Its author's | The abstraction's: every plugin of an abstraction has the same one |
| Replacing it | Edits the modules that import it | Edits `jac.toml`, and no module |
| What a program means | Depends on it | Does not: under every plugin of an abstraction a program means the same |

- **A library adds something a program can say.** `json`, a package from PyPI or npm, a module of
  the project's own: code imports it and calls it.
- **A plugin adds nothing a program can say.** It carries out what the program says already: where
  `root` is kept, which library a component's state becomes, which model answers.
- **A plugin is never imported.** A module that named one would name a mechanism, which is what
  the principle rules out.
- **Abstractions are the language's and its standard library's.** A plugin fills one of theirs, and
  a library does not declare one.
- **What a project cannot swap is what its modules import.** Everything it names in `jac.toml` it
  can.

## Which file says what

| Where | What it says |
|---|---|
| A module | What the program means, and the libraries it imports |
| `archwire.jac` | What changes what code means or may do: which modules form each space, the host each runs on, the spaces each app runs ([The archwire's spaces](../apps/archwire.md)) |
| `jac.toml` | What carries the abstractions out and how each is set, and the packages the project takes ([jac.toml](../reference/jac-toml.md)) |
| The environment a program runs in | What differs from one deployment to the next ([Building apps](../apps/building.md#deployment-values)) |

## Where jac is today

A project chooses, in `jac.toml`, what carries each of these out ([Plugins](../apps/plugins.md)):

| Abstraction | What source says | The plugins jac ships |
|---|---|---|
| `store` | `root`, `++>` | `sqlite` |
| `auth` | `:protect`, a page's `sign_in()` | `accounts` |
| `transport` | A call to another space | `http` |
| `llm` | `by llm()` | `anthropic` |
| `jobs`, `schedule`, `limits` | `@job`, `@schedule`, `@limit` | `process_jobs`, `loop_schedule`, `memory_limits` |
| `ui` | A component's `has`, its effects, its JSX | `react`, `preact`, `solid`, `react_native`, `none` |
| `bundler` | Nothing: a JavaScript space is bundled as it is built | `vite`, `expo` |

For all but the last two, the place a program runs may pick among the plugins it was built with.
`ui` and `bundler` are settled as a space is built
([UI plugins and bundlers](../apps/ui-bindings.md)).

A library is a module of the project, a module of [the standard library](../library/index.md),
a Jac package the project declares in `jac.toml`'s `[packages]`, or a package of Python's,
npm's, C's or Rust's ([Packages](../toolchain/packages.md)).
