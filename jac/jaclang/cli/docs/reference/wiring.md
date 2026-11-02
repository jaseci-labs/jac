# Project Wiring (archwire.jac)

A project's architecture is the graph of which modules feed which. Jac lets you write that graph down in a file named `archwire.jac`, and for the directory it sits in the file is the **only** place an import between its modules exists: it generates those imports, and it is the rulebook they are checked against.

The file holds `graph import` blocks of **wires** and **rules**:

```jac
graph import {
    edge AppOverCore: core.* --> cli.* | web.*;
    edge CoreInternal: core.* --> core.*;
    edge LlmFunnel: jaclang.byllm.* --> core.ai;

    core.install ++> web.main { ensure_install, install_sh }
    core.timefmt ++> [
        core.docs.sync { now_iso },
        web.main | web.status { now_iso, since },
    ]
}

graph import core {
    ai ++> knowledge_service { classify_ask }
    knowledge.repo ++> [
        knowledge_service { ReleaseLine, ensure_repo, read_status },
        docs.sync { ReleaseLine },
    ]
}
```

Modules are the nodes, imports are the edges, and the names crossing an edge are its payload. Values flow from the provider on the left to the consumer on the right.

---

## Where archwire.jac lives

An `archwire.jac` governs the modules in its directory and below it, down to the next `archwire.jac` or `jac.toml`: the nearest one above a module is the one that wires it, the way the nearest `jac.toml` configures it. A project can keep one file at its root, or give a package its own file inside the package, so the wiring ships with the package and travels with any subtree that is copied elsewhere.

Having the file is the whole switch. A directory with an `archwire.jac` is a **closed boundary**; a directory without one is ordinary code. There is no partial mode and nothing to configure in `jac.toml`.

Module names in an `archwire.jac` are relative to its directory: in `app/archwire.jac`, `core.docs` is `app/core/docs.jac`. The generated import uses the module's real import name, derived from the packages above the directory (up to the outermost one with an `__init__`), so a package's `archwire.jac` names `cli.errmap` while the import it generates reads `import from mypkg.cli.errmap`. A boundary copied to another location generates the imports that are right there.

## Wires

A wire is an import with its consumer attached. `++>` **injects** the import: the consumer never writes it, and at compile time it is woven into the consumer as annex source, exactly as a `.impl.jac` file is, so every import diagnostic points at the wire.

| Wire in `archwire.jac` | Generated in the consumer |
|---|---|
| `P ++> C;` | `import P;` |
| `P as p ++> C;` | `import P as p;` |
| `P ++> C { a, b as c }` | `import from P { a, b as c }` |
| `type P ++> C { T }` | `import type from P { T }` |
| `comptime P ++> C { x }` | `comptime import from P { x }` |
| `include P ++> C;` | `include P;` |
| `P ++> C1 \| C2 { a }` | the same import in both `C1` and `C2` |
| `P ++> [C1 { a }, C2 { b }]` | each target gets its own import from `P` |
| `P ++> C.f { a }` | `import from P { a }` at the top of the body of `f` in `C` |

A consumer path may continue past the module into a class, function or method: `core.jobs.Runner.start` names `start` in class `Runner` of `core.jobs`, whether its body is written inline or in an `.impl.jac` annex. The longest prefix that is a module is the module; the rest walks its declarations. Such a wire lands its import at the top of that body, so a dependency that must stay lazy (to break an import cycle, or to keep a heavy provider off the start-up path) is still declared in the file. A wire target names each consumer module once; give a second scope in the same module its own target.

### Imports that run where they are written

An injected import lands at the top of its body. An import that must run somewhere else, inside an `if`, `try`, loop or `with` block, or after other statements (an early return, a guard), stays written in place, because moving it would change when it runs: an optional dependency caught by `except ImportError` would fail before the `try`, and a cycle-breaking import would run too early. An `include` in an `.impl.jac` annex is positional too: an include is textual, the annex merges after the module's own body, and moving the include to the head would put its declarations ahead of names it follows. Such an import is declared with `-->`, which checks the import and never injects it:

```jac
graph import {
    runtime.builtin --> runtime.archetype.Archetype.__init_subclass__ { _jac_region_instrument }
}
```

The two must agree both ways: a written import that runs where it is written needs a `-->` wire naming it (`E2094`, `E1144`), and a `-->` wire needs that written import (`E1147`).

Three constraints keep wires readable:

- **A wire has one provider.** Patterns (`core.*`) belong to rules. A payload says what crosses from one module.
- **Wires connect modules under the archwire.jac.** A provider must resolve to a Jac or Python module below it. Standard-library, installed, npm and asset imports stay in the module file; they are that module's external surface, and `jac.toml` already governs them through `[dependencies]`.
- **A consumer is named in full.** It is the head module the import lands in, so `.impl.jac` files are never consumers; an `.impl.jac` file counts as its head. A `.test.jac` annex runs inside its head's namespace and may import freely without wires.

An import of a name the runtime resolves outside the boundary is never a wired import, even when a file below it shares the name: a standard-library module (`types`, `math`), a module of the bundled native standard library, a module importing its own names, and, in server code, a bare name that only matches a sibling file (`prometheus_client` next to a same-named module is the installed package). Client and native code do resolve siblings, so there a bare sibling name is wired like any other.

## Closed boundaries

Under an `archwire.jac`, an import of a module below it is never written at the top of a module or function body: it is a wire. Imports are matched on the whole binding: provider, form (`import`, `import from`, `include`, `type`, `comptime`), name and alias.

- A written import is `E1144` (at module level) or `E2094` (inside a function), and the message says what to do: delete it when a `++>` wire already injects it, or add the wire it names and then delete it. `jac fmt --lintfix` deletes written imports a `++>` wire injects.
- A wired name its consumer never reads is `E1146`, reported at the wire. A wire is the import itself, so an unused name is a false fact. Names are not re-exported: other modules import a name from the module that defines it. A name the module lists in `__all__` is its declared public surface and counts as used.
- An unaliased module wire (`P ++> C;`) loads `P` for its effect and is never reported as unused.

A new module under the directory is governed from the moment it exists, so a fresh package fails to check until its imports are wired.

Modules compiled by the bootstrap compiler (the jac0 seed set of the jaclang package itself) follow the same rule: jac0 reads `archwire.jac` and weaves the same imports the full compiler does.

`E1144`, `E1146`, `E2090`, `E2091`, `E2094` and `E2099` ignore inline `# jac:ignore` comments. Changing a boundary is an edit to archwire.jac, so it is visible in review; `[check] suppress` in jac.toml still applies.

## Rules

Wires declare which imports exist; rules restrict them. A rule only checks, so it is written with `-->`:

```jac
graph import {
    edge Public: core.docs.* --> cli.* | web.* { doc_page, doc_tree, docs_status }
    edge WebInternal: web.* --> web.*;
}
```

Rules are mandatory between top-level packages. A wire or written import from one top-level package into another (`core` into `web`, say) must be admitted by a rule, or it is `E2099`, and the message carries the rule to add. Every dependency between packages is then a stated decision, reviewed as an edit to archwire.jac. Plumbing inside one top-level package needs no rule.

A rule speaks about the top-level packages its targets name. Once a rule names a provider as its source and targets a package, the provider flows into that package only where some rule admits it. So `edge CoreInternal: core.* --> core.*;` governs the imports inside `core`, and `edge Docs: core.docs.* --> core.sync;` would then confine `core.docs` to `core.sync` within `core`, while `edge Core: core.* --> web.*;` says nothing about `core`'s own modules. A rule naming a provider outside the boundary governs every flow from it. Rules apply to every wire and every written import.

- A wire between top-level packages that no rule governs is `E2099`.
- A flow that rules govern but none admits is `E2090`.
- A rule with a payload admits only the names it lists, and a payload always narrows: if any admitting rule carries a payload, every crossing name must appear in one of those payloads, or it is `E2091`. A module-form import (`import P;`) cannot be admitted by a payload rule, since the names it carries are not visible.
- A rule may name an external provider. `edge LlmFunnel: jaclang.byllm.* --> core.ai;` declares that all model-client access goes through one module, without a single wire.
- A pattern that matches no module is `E2098`; external source patterns are exempt, since they are meant to match modules outside the boundary.
- A rule on the bare `*` pattern, as a source or a target, is `E2100`: it admits everything and states no architecture.

Patterns are a dotted module (`core.docs.graph`), a package glob (`core.*`, which also matches the package's own `__init__`), or a quoted npm name. A rule's targets are always modules under its archwire.jac, so `any` is not a pattern (`E0098`). Every rule is named, because the name carries the diagnostics that cite it.

## Scoped blocks

`graph import <package> { ... }` sets a scope: **both sides** of its wires, and both sides of its rules, are relative to the header.

```jac
graph import core.docs {
    graph ++> [
        sync { DocsHub, DocVersion, place_page },
        views.page { doc_page },
    ]
}
```

A wire's block is where it is written; several blocks in one file union.

## One canonical layout

`jac fmt` renders an `archwire.jac` in exactly one form, so two files that declare the same facts are byte-identical and every diff is a change of fact:

- each wire sits in the block of the deepest package that contains both its provider and its consumer, with both ends written relative to that block, and blocks follow the package tree;
- every wire from one provider (with the same form and arrow) is one statement, using the list form once it has two or more targets; targets with the same payload share one fan-out with `|`;
- rules sit in the root block, sorted by name, ahead of its wires;
- everything else is sorted.

So the root block holds exactly the edges between top-level packages, and each deeper block holds the plumbing inside its package.

## What the file may hold

`graph import` is legal only in a file named `archwire.jac` (`E2088`), and that file holds `graph import` blocks and nothing else (`E2089`): no statements, docstrings or comments, since every line is a fact. The file is itself checked when you check the project:

| Code | Fires when |
|---|---|
| `E1141` | a wire's provider is not a module under the archwire.jac |
| `E1142` | a wire's consumer is a package with no `__init__`, a non-Jac module, or a scope its module does not declare |
| `E1143` | a wire connects a module to itself |
| `E2092` | two rules share a name |
| `E2093` | `archwire.jac` has syntax errors, so a module's wiring may be incomplete |
| `E2097` | a scope header or a wire's consumer names no module under the archwire.jac |
| `E2098` | a rule pattern matches no module |
| `E2100` | a rule's source or target is the bare `*` pattern |

Syntax has its own codes, `E0086` through `E0099`, each naming the shape that was expected: a directed `++>` or `-->`, one provider per wire, consumers named in full, `as` only on the module form, no duplicate payload names, `include` without a payload, named rules, a dotted scope, `*` standing alone, no `any` in a rule, and the `graph import` header.

## Wiring inside a package

In a project whose `[project] name` is a scoped package name (`acme/graphkit`, see [Packages](packages.md)), `archwire.jac` names the project's modules by their qualified names: `acme.graphkit.core ++> acme.graphkit.web.main { ... }`. The generated imports then load each module under the one name consumers use for it.

## Caching

A module's cache key folds in only its own wire slice plus the rule set, so editing one wire rebuilds one module, and a project without `archwire.jac` keeps the keys it had.

## The `jac arch` command

You change import relationships by editing `archwire.jac`. The `jac arch` command is for adopting the file and for one-time cleanups:

| Command | Effect |
|---|---|
| `jac arch init [dir]` | Seal `dir` (or the project root): write its `archwire.jac` from every import between the modules below it, with one rule per top-level package that feeds another (`edge Core: core.* --> cli.* \| web.*;`). `--strip` then removes the written imports the file now injects. `--force` overwrites an existing file. |
| `jac arch sync [dir]` | For the `archwire.jac` in `dir`, or every `archwire.jac` in the project: add a wire for every import a module writes that `archwire.jac` does not declare, and admit each new edge between top-level packages in the rule named after its source package, creating that rule if needed. Hand-written rules are never edited. `--prune` also removes the wired names no consumer uses, and the written import of a pruned `-->` wire. `--strip` removes the now-injected written imports. |
| `jac arch graph [dir]` | Render the wiring as mermaid (default) or `--format json`; `-o <file>` writes it. |

`jac arch init --strip` is the adoption path: run it once, then read the file it wrote. Its rules describe the layering the project has today; tighten them into the layering it should have.

`jac fmt --lintfix` removes a written import under a boundary that no wire provides and nothing reads (`W3054`); it is dead however it got there. A written import that is read stays, since it needs a wire, not a deletion.
