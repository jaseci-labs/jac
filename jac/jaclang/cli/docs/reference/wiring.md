# Project Wiring (arch.jac)

A project's architecture is the graph of which modules feed which. Jac lets you write that graph down once, in a file named `arch.jac` beside `jac.toml`, and then makes the file do two jobs: it **is** the import mechanism for the modules it names, and it is the rulebook that every import in the project is checked against.

The file holds `impl import` blocks. A block lists **wires** and **rules**:

```jac
impl import {
    edge CoreInternal: core.* --> core.*;
    edge AppOverCore: core.* --> web.* | cli.*;
    edge LlmFunnel: jaclang.byllm.* --> core.ai;
}

impl import core {
    ai --> core.scoring_service { optional_review }
    github --> core.scoring_service { RepoMeta, head_sha, repo_meta }
    timefmt --> core.docs.sync | core.social_graph { now_iso }
    install --> web.main { ensure_install, install_sh }
}
```

The picture reads the way the typed graph does: modules are the nodes, imports are the edges, and the names crossing an edge are its payload. Values flow from the provider on the left to the consumer on the right.

---

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

The consumer never writes the import. At compile time the wire is woven into the consumer as annex source, exactly as a `.impl.jac` file is, so every existing import diagnostic works unchanged and points at the wire: a name the provider does not export is `W1101` on the payload item, a wired name the consumer never uses is `W2003` on it. A wire that claims a flow which does not exist is therefore visible, and the file stays faithful to the code.

Three constraints keep wires readable:

- **A wire has one provider.** Patterns (`core.*`, `any`) belong to rules. A payload wire cannot list several providers, because the payload says what crosses from one module.
- **Wires connect project modules only.** A provider must resolve to a Jac or Python module under the project root. Standard-library, installed, npm and asset imports stay in the module file; they are that module's external surface, and `jac.toml` already governs them through `[dependencies]`.
- **A consumer is named in full.** It is the head module the import lands in, so `.impl.jac` files and `.test.jac` files are never consumers. An `.impl.jac` file counts as its head. A `.test.jac` runs inside its head's namespace, so it may import freely without wires, but an import that duplicates a wire is still redundant there and is removed like any other.

## Sealing

The file follows one rule: **whatever arch.jac names, arch.jac is the whole truth about.** A module is *sealed* once the file names it anywhere: as a wire's provider, as a wire's consumer, or by matching a rule's source or target pattern (`any` is a widening, not a name, and seals nothing). A sealed module is governed in both directions.

**As a consumer**, every module-level import it writes that resolves to a project module must match a wire on the whole binding: provider, form (`import`, `import from`, `include`, `type`, `comptime`), name and alias.

- A written import a wire already provides is `W3053` (`remove-wired-import`), and `jac fmt --lintfix` deletes it.
- A written import no wire provides is `E1144`, and the message carries the exact wire to add.
- A project-module import inside a function body is `E2094`. A wire is module-level, so a nested import is a dependency the file cannot show; a module that needs a lazy import stays unnamed.

**As a provider**, it admits imports only where a rule says. If no rule names it as a source, it flows nowhere: any import of it, written or wired, is `E2090` with the rule to add. This is why a file of wires needs rules, and why `jac arch init` writes them.

A module the file never names is open in both directions and behaves exactly as it did before the file existed. That is the opt-in, and it is by region rather than by side: naming a module means describing it completely, so a subsystem is migrated with its wires and its rules together. `jac arch init` does that for the whole project, and `jac arch init <package>` for one package and everything it imports from. A package rule such as `core.*` names every module beneath it, and there is no exemption from it: a package that a test builds on its own is copied out together with the `jac.toml` and `arch.jac` that own its imports, and the module the test drops in gets a wire of its own.

Imports in test annexes are exempt. A test runs inside its head module's namespace, and its dependencies are its own business; a test import that duplicates a wire is still reported as redundant.

## Closing the project

Sealing reaches only what the file names. To seal modules it has never heard of, including packages not yet written, set the default in `jac.toml`:

```toml
[arch]
closed = ["*"]              # or a ratchet: ["core.*", "web.*"]
```

A module matching a pattern is sealed whether or not arch.jac names it, and the setting applies even before arch.jac exists, so a fresh package under a closed root fails to check until it is wired and ruled. `closed = ["*"]` is the last step of a migration: after `jac arch init --strip` it costs nothing on the modules already wired and closes the door on new ones.

`E1144`, `E2090`, `E2091` and `E2094` ignore inline `# jac:ignore` comments. Loosening a boundary is an edit to arch.jac or to `[arch] closed`, so it is visible in review; `[check] suppress` in jac.toml still applies.

## Rules

A rule is an edge declaration over module patterns:

```jac
impl import {
    edge WebInternal: web.* --> web.*;
    edge Public: core.docs.* --> web.* | cli.* { docs_status, doc_tree, doc_page }
}
```

A rule names the modules its patterns match, which seals them, and it admits flows from its sources to its targets. A sealed provider flows only where some rule admits it, so `edge CoreInternal: core.* --> core.*;` alone means `core` modules may be imported by `core` modules and by nobody else, and it also seals every `web` module the moment a second rule names `web.*`. Rules apply project-wide, to written imports and wires alike.

- A flow no rule admits is `E2090`.
- A rule with a payload admits only the names it lists, and a payload always narrows: if any admitting rule carries a payload, every crossing name must appear in one of those payloads, or it is `E2091`. A module-form import (`import P;`) cannot be admitted by a payload rule, since the names it carries are not visible.
- A rule may name an external provider. `edge LlmFunnel: jaclang.byllm.* --> core.ai;` declares that all model-client access goes through one module, without a single wire. External providers are constrained only when a rule names them; sealing is for project modules.
- A pattern that matches no project module is `W2083`; external source patterns are exempt, since they are meant to match modules outside the project.

Patterns are a dotted module (`core.docs.graph`), a package glob (`core.*`, which also matches the package's own `__init__`), a quoted npm name, or `any`. Every rule is named, because the name carries the diagnostics that cite it.

## Scoped blocks

`impl import <package> { ... }` sets a scope. Inside it the **left side is relative to the header**, so the block reads as the export surface of that package; the **right side is always absolute**, and a sibling consumer is spelled in full, the way an `impl` body reaches a sibling through `self` rather than a bare name. A bare `*` in a rule inside a scoped block means the whole scoped package.

```jac
impl import core.docs {
    edge Public: * --> web.* | cli.* { docs_status, doc_tree, doc_page, llms_txt }
    graph --> web.main { docs_status, doc_tree, doc_page, llms_txt }
    graph --> core.docs.sync { DocsHub, DocVersion, place_page }
}
```

The unscoped block stays for layer rules and anything cross-cutting. Several blocks in one file union, so a block per subsystem is the natural grouping.

## What the file may hold

`impl import` is legal only in the `arch.jac` beside `jac.toml` (`E2088` elsewhere), and that file holds `impl import` blocks and nothing else (`E2089`). The file is itself checked when you check the project:

| Code | Fires when |
|---|---|
| `E1140` | a scope header names nothing under the project root |
| `E1141` | a wire's provider is not a project module |
| `E1142` | a wire's consumer is not a Jac module under the root, or is a package with no `__init__` |
| `E1143` | a wire connects a module to itself |
| `E2092` | two rules share a name |
| `E2093` | `arch.jac` has syntax errors, so a sealed module's wiring may be incomplete |
| `E2094` | a sealed module imports a project module inside a function body |
| `W3052` | a wire repeats an earlier one (`remove-duplicate-wire`, autofixed by `jac fmt --lintfix`) |

Syntax has its own codes, `E0086` through `E0096`, each naming the shape that was expected: a directed `-->`, one provider per wire, consumers named in full, `as` only on the module form, no duplicate payload names, `include` without a payload, named rules, a dotted scope, and `*` standing alone.

## Caching

A module's cache key folds in only its own wire slice plus the rule set, so editing one wire rebuilds one module, and a project without `arch.jac` keeps the keys it had.

## The `jac arch` command

| Command | Effect |
|---|---|
| `jac arch init` | Write `arch.jac` from every project-module import, one block per leaf package, plus one `edge <Pkg>Flows` rule per package stating where its modules flow today. `--strip` then removes those imports from the modules, which is the same fix `jac fmt --lintfix` applies. `--force` overwrites an existing file. |
| `jac arch init <package>` | Wire one package and everything it imports from, transitively, and merge the wires and rules into an existing `arch.jac`. This is how a large tree adopts one subsystem at a time. |
| `jac arch sync` | Add a wire for every import a sealed module writes that `arch.jac` does not declare, into the block whose scope matches, and a rule for every provider that has none. `--strip` removes the now-redundant imports. |
| `jac arch graph` | Render the wiring as mermaid (default) or `--format json`; `-o <file>` writes it. |

Modules that `[check] exclude` lists are not wired, since they are not checked. Modules that `[check.lint] exclude` lists are wired but never stripped, so a hand-written import may sit beside the wire that provides it. Such an import is bound once: the generated copy is dropped as the module is parsed, so the two never produce a duplicate declaration on any backend. `jac arch init --strip` is the adoption path: nobody hand-writes hundreds of wires. Run it once, read the file it wrote as a catalog of packages, then add the rules that state how the project is layered.
