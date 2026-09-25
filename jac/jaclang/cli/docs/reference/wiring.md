# Project Wiring (arch.jac)

A project's architecture is the graph of which modules feed which. Jac lets you write that graph down in a file named `arch.jac`, and the file does two jobs for the directory it sits in: it **is** the import mechanism for the modules below it, and it is the rulebook their imports are checked against.

The file holds `graph import` blocks. A block lists **wires** and **rules**:

```jac
graph import {
    edge CoreInternal: core.* --> core.*;
    edge AppOverCore: core.* --> web.* | cli.*;
    edge LlmFunnel: jaclang.byllm.* --> core.ai;
}

graph import core {
    ai --> core.scoring_service { optional_review }
    github --> core.scoring_service { RepoMeta, head_sha, repo_meta }
    timefmt --> core.docs.sync | core.social_graph { now_iso }
    install --> web.main { ensure_install, install_sh }
}
```

The picture reads the way the typed graph does: modules are the nodes, imports are the edges, and the names crossing an edge are its payload. Values flow from the provider on the left to the consumer on the right.

---

## Where arch.jac lives

An `arch.jac` governs the modules in its directory and below it, down to the next `arch.jac` or `jac.toml`: the nearest one above a module is the one that wires it, the way the nearest `jac.toml` configures it. A project can keep one file at its root, or give a package its own file inside the package, so the wiring ships with the package and travels with any subtree that is copied elsewhere.

Having the file is the whole switch. A directory with an `arch.jac` is a **closed boundary**; a directory without one is ordinary code. There is no partial mode and nothing to configure in `jac.toml`. Code that must keep its written imports, such as component templates copied into other projects one file at a time, is a project of its own with its own `jac.toml`.

Module names in an `arch.jac` are relative to its directory: in `app/arch.jac`, `core.docs` is `app/core/docs.jac`. The generated import is written with the module's real import name, which the file derives from the packages above its directory (up to the outermost one with an `__init__`, passing through namespace directories on the way), so a package's `arch.jac` names `cli.errmap` while the import it generates reads `import from mypkg.cli.errmap`. The name is derived where the file sits, so a boundary copied to another location generates the imports that are right there.

## Wires

A wire is one import statement with its consumer attached:

| Wire in `arch.jac` | Generated in the consumer |
|---|---|
| `P --> C;` | `import P;` |
| `P as p --> C;` | `import P as p;` |
| `P --> C { a, b as c }` | `import from P { a, b as c }` |
| `type P --> C { T }` | `import type from P { T }` |
| `comptime P --> C { x }` | `comptime import from P { x }` |
| `include P --> C;` | `include P;` |
| `P --> C1 \| C2 { a }` | the same import in both `C1` and `C2` |
| `P --> C.f { a }` | `import from P { a }` at the top of the body of `f` in `C` |

The consumer never writes the import. At compile time the wire is woven into the consumer as annex source, exactly as a `.impl.jac` file is, so every existing import diagnostic works unchanged and points at the wire: a name the provider does not export is `W1101` on the payload item, a wired name the consumer never uses is `W2003` on it. A wire that claims a flow which does not exist is therefore visible, and the file stays faithful to the code.

Three constraints keep wires readable:

- **A wire has one provider.** Patterns (`core.*`) belong to rules. A payload wire cannot list several providers, because the payload says what crosses from one module.
- **Wires connect modules under the arch.jac.** A provider must resolve to a Jac or Python module below it. Standard-library, installed, npm and asset imports stay in the module file; they are that module's external surface, and `jac.toml` already governs them through `[dependencies]`.
- **A consumer is named in full.** It is the head module the import lands in, so `.impl.jac` files and `.test.jac` files are never consumers. An `.impl.jac` file counts as its head. A `.test.jac` runs inside its head's namespace, so it may import freely without wires, but an import that duplicates a wire is still redundant there and is removed like any other.

A consumer path may continue past the module into a class, function or method: `core.jobs.Runner.start` names `start` in class `Runner` of `core.jobs`, whether its body is written inline or in an `.impl.jac` annex. The longest prefix that is a module is the module; the rest walks its declarations. Such a wire lands its import at the top of that body instead of at module level, so a dependency that must stay lazy (to break an import cycle, or to keep a heavy provider off the start-up path) is still declared in the file. A wire names each consumer module once; give a second scope in the same module its own wire.

An import of a name the runtime resolves outside the boundary is never a wired import, even when a file below it shares the name: a standard-library module (`types`, `math`), a module of the bundled native standard library, a module importing its own names, and, in server code, a bare name that only matches a sibling file (`prometheus_client` next to a same-named module is the installed package, since a server module reaches only the search path). Client and native code do resolve siblings, so there a bare sibling name is wired like any other.

## Closed boundaries

Every module under an `arch.jac` takes its imports of the modules below it from wires, matched on the whole binding: provider, form (`import`, `import from`, `include`, `type`, `comptime`), name and alias.

- A written import a wire already provides is `W3053` (`remove-wired-import`), and `jac fmt --lintfix` deletes it.
- A written import no wire provides is `E1144`, and the message carries the exact wire to add.
- An import inside a function body must match a wire whose consumer names that function (`E2094` otherwise, with the scoped wire to add). An import in the body proper is removed by `jac fmt --lintfix` like a module-level one; an import nested in an `if` or `try` stays written, since moving it to the top of the function would change when it runs, and the wire declares it.

A new module under the directory is governed from the moment it exists, so a fresh package fails to check until its imports are wired. `jac arch sync` adds the missing wires.

Imports in test annexes are exempt. A test runs inside its head module's namespace, and its dependencies are its own business; a test import that duplicates a wire is still reported as redundant.

Modules compiled by the bootstrap compiler (the jac0 seed set of the jaclang package itself) run before wiring exists, so they keep their written imports; arch.jac still declares them and the check still applies, but `jac fmt --lintfix` does not remove them.

`E1144`, `E2090`, `E2091` and `E2094` ignore inline `# jac:ignore` comments. Changing a boundary is an edit to arch.jac, so it is visible in review; `[check] suppress` in jac.toml still applies.

## Rules

Wires declare which imports exist; rules restrict them. A rule is an edge declaration over module patterns:

```jac
graph import {
    edge WebInternal: web.* --> web.*;
    edge Public: core.docs.* --> web.* | cli.* { docs_status, doc_tree, doc_page }
}
```

A provider that no rule names flows anywhere inside the boundary. A provider a rule names as a source flows only where some rule admits it, so `edge CoreInternal: core.* --> core.*;` alone means `core` modules may be imported by `core` modules and by nobody else under this arch.jac. Rules apply to written imports and wires alike.

- A flow no rule admits is `E2090`.
- A rule with a payload admits only the names it lists, and a payload always narrows: if any admitting rule carries a payload, every crossing name must appear in one of those payloads, or it is `E2091`. A module-form import (`import P;`) cannot be admitted by a payload rule, since the names it carries are not visible.
- A rule may name an external provider. `edge LlmFunnel: jaclang.byllm.* --> core.ai;` declares that all model-client access goes through one module, without a single wire.
- A pattern that matches no module is `W2083`; external source patterns are exempt, since they are meant to match modules outside the boundary.

Patterns are a dotted module (`core.docs.graph`), a package glob (`core.*`, which also matches the package's own `__init__`), `*` for every module under the arch.jac, or a quoted npm name. A rule's targets are always modules under its arch.jac: importers outside the directory answer to their own arch.jac, so `any` is not a pattern (`E0097`). Every rule is named, because the name carries the diagnostics that cite it.

## Scoped blocks

`graph import <package> { ... }` sets a scope. Inside it the **left side is relative to the header**, so the block reads as the export surface of that package; the **right side is always absolute**, and a sibling consumer is spelled in full, the way an `impl` body reaches a sibling through `self` rather than a bare name. A bare `*` in a rule inside a scoped block means the whole scoped package.

```jac
graph import core.docs {
    edge Public: * --> web.* | cli.* { docs_status, doc_tree, doc_page, llms_txt }
    graph --> web.main { docs_status, doc_tree, doc_page, llms_txt }
    graph --> core.docs.sync { DocsHub, DocVersion, place_page }
}
```

The unscoped block stays for layer rules and anything cross-cutting. Several blocks in one file union, so a block per subsystem is the natural grouping.

## What the file may hold

`graph import` is legal only in a file named `arch.jac` (`E2088` elsewhere), and that file holds `graph import` blocks and nothing else (`E2089`). The file is itself checked when you check the project. Wiring that names no existing module is inert rather than an error, so a distribution that leaves some modules out still compiles; the name is reported so a misspelling does not go unnoticed:

| Code | Fires when |
|---|---|
| `W2084` | a scope header or a wire's consumer names no module under the arch.jac, so it is inert |
| `E1141` | a wire's provider is not a module under the arch.jac, and one of its consumers exists |
| `E1142` | a wire's consumer is a package with no `__init__`, a non-Jac module, or a scope its module does not declare |
| `E1143` | a wire connects a module to itself |
| `E2092` | two rules share a name |
| `E2093` | `arch.jac` has syntax errors, so a module's wiring may be incomplete |
| `E2094` | a module imports a module under the arch.jac inside a function body that no scoped wire declares |
| `W3052` | a wire repeats an earlier one (`remove-duplicate-wire`, autofixed by `jac fmt --lintfix`) |

Syntax has its own codes, `E0086` through `E0098`, each naming the shape that was expected: a directed `-->`, one provider per wire, consumers named in full, `as` only on the module form, no duplicate payload names, `include` without a payload, named rules, a dotted scope, `*` standing alone, no `any` in a rule, and the `graph import` header.

## Caching

A module's cache key folds in only its own wire slice plus the rule set, so editing one wire rebuilds one module, and a project without `arch.jac` keeps the keys it had.

## The `jac arch` command

| Command | Effect |
|---|---|
| `jac arch init [dir]` | Seal `dir` (or the project root): write its `arch.jac` from every import between the modules below it, one block per leaf package. `--strip` then removes those imports from the modules, which is the same fix `jac fmt --lintfix` applies. `--force` overwrites an existing file. |
| `jac arch sync [dir]` | For the `arch.jac` in `dir`, or every `arch.jac` in the project: add a wire for every import a module writes that `arch.jac` does not declare, into the block whose scope matches. `--strip` removes the now-redundant imports. |
| `jac arch graph [dir]` | Render the wiring as mermaid (default) or `--format json`; `-o <file>` writes it. |

To seal part of a tree first, run `jac arch init` in that directory; it gets its own `arch.jac`, and the rest of the tree is untouched until you seal it too.

Modules that `[check.lint] exclude` lists are wired but never stripped, so a hand-written import may sit beside the wire that provides it. Such an import is bound once: the generated copy is dropped as the module is parsed, so the two never produce a duplicate declaration on any backend. `jac arch init --strip` is the adoption path: nobody hand-writes hundreds of wires. Run it once, read the file it wrote as a catalog of packages, then add the rules that state how the project is layered.
