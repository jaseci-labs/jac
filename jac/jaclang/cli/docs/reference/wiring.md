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

## Coverage

A module is **covered** once it is the consumer of any wire. In a covered module, every module-level import that resolves to a project module must match a wire, item by item and on the whole binding: provider, form (`import`, `import from`, `include`, `type`, `comptime`), name and alias.

- A written import a wire already provides is `W3053` (`remove-wired-import`), and `jac fmt --lintfix` deletes it.
- A written import no wire provides is `E1144`, and the message carries the exact wire to add.

An uncovered module behaves exactly as it did before the file existed. That is the opt-in: cover a module by wiring something into it. A covered module depends on `arch.jac` for those imports, the way a head module depends on its `.impl.jac`, so a package that is meant to be copied out of the tree on its own, such as a fixture or a standalone native module, is better left uncovered. Imports nested inside function bodies are outside coverage, since they are control flow rather than architecture, and external imports are never touched.

## Rules

A rule is an edge declaration over module patterns:

```jac
impl import {
    edge WebInternal: web.* --> web.*;
    edge Public: core.docs.* --> web.* | cli.* { docs_status, doc_tree, doc_page }
}
```

A rule constrains a provider **on mention**: once any rule's source pattern matches a provider, that provider may flow only where some rule admits it. A provider no rule mentions is unconstrained, so `edge CoreInternal: core.* --> core.*;` alone does not fence `web`; add `edge WebInternal: web.* --> web.*;` to do that. Rules apply project-wide, to written imports and wires alike, whether or not the importing module is covered.

- A flow no rule admits is `E2090`.
- A rule with a payload admits only the names it lists, and a payload always narrows: if any admitting rule carries a payload, every crossing name must appear in one of those payloads, or it is `E2091`. A module-form import (`import P;`) cannot be admitted by a payload rule, since the names it carries are not visible.
- A rule may name an external provider. `edge LlmFunnel: jaclang.byllm.* --> core.ai;` declares that all LLM access goes through one module without a single wire.
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
| `E2093` | `arch.jac` has syntax errors, so a covered module's wiring may be incomplete |
| `W3052` | a wire repeats an earlier one (`remove-duplicate-wire`, autofixed by `jac fmt --lintfix`) |

Syntax has its own codes, `E0086` through `E0096`, each naming the shape that was expected: a directed `-->`, one provider per wire, consumers named in full, `as` only on the module form, no duplicate payload names, `include` without a payload, named rules, a dotted scope, and `*` standing alone.

## Caching

A module's cache key folds in only its own wire slice plus the rule set, so editing one wire rebuilds one module, and a project without `arch.jac` keeps the keys it had.

## The `jac arch` command

| Command | Effect |
|---|---|
| `jac arch init` | Write `arch.jac` from every project-module import, one block per leaf package. `--strip` then removes those imports from the modules, which is the same fix `jac fmt --lintfix` applies. `--force` overwrites an existing file. |
| `jac arch sync` | Add a wire for every import a covered module writes that `arch.jac` does not declare, into the block whose scope matches. `--strip` removes the now-redundant imports. |
| `jac arch graph` | Render the wiring as mermaid (default) or `--format json`; `-o <file>` writes it. |

Modules that `jac.toml` excludes from checking or linting are left alone by `init` and `sync`, since the lint autofix cannot strip their imports. `jac arch init --strip` is the adoption path: nobody hand-writes hundreds of wires. Run it once, read the file it wrote as a catalog of packages, then add the rules that state how the project is layered.
