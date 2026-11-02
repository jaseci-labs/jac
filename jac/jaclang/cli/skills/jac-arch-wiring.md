---
name: jac-arch-wiring
description: Declare a directory's module graph in archwire.jac with graph import wires and edge rules. Use when adopting archwire.jac, adding or removing an import under one, fixing E1144/E1146/E1147/E2090/E2091/E2094/E2097/E2098/E2099/E2100, or running jac arch init, sync and graph.
---

An `archwire.jac` is the only place an import between the modules below it exists. It holds `graph import [scope] { ... }` blocks of **wires** and **rules**:

```
graph import {
    edge CoreFlows: core.* --> cli.* | core.* | web.*;

    core.timefmt ++> [
        core.docs.sync { now_iso },
        web.main | web.status { now_iso },
    ]
}

graph import core {
    github ++> scoring_service { RepoMeta, head_sha }
    loader --> boot.Boot.start { load_plugins }
}
```

- `P ++> C { names }` **injects** `import from P { names }` into `C` (`P ++> C;` for `import P;`). `C` may continue into a class, function or method (`mod.Class.method`): the import lands at the top of that body.
- `P --> C { names }` **declares** an import `C` writes in place because it must run there: inside an `if`/`try`/loop/`with` block, or after other statements. It is checked, never injected.
- `edge Name: pattern --> pattern [{ names }]` is a rule that restricts what may flow where.
- Inside `graph import core.docs { ... }` both sides of every wire and rule are relative to the header.

To add an import, add a `++>` wire (or a name to an existing one) in archwire.jac; never write the import in the module. To drop one, delete the name from the wire. Then run `jac fmt` on archwire.jac: it re-renders the one canonical layout (wires in the block of the deepest package holding both ends, one statement per provider, sorted).

The rules every module under the file follows:

- A written import of a module below the archwire.jac at the top of a module or function body is an error (`E1144` at module level, `E2094` in a function); the message says whether to delete it (a `++>` wire already injects it) or which wire to add. `jac fmt --lintfix` deletes the injected ones.
- A written import that runs where it is written needs a `-->` wire, and a `-->` wire needs that import (`E1147`).
- A wired name the consumer never reads is `E1146` at the wire. Names are not re-exported; list public names in `__all__`.
- Wiring that names no module is `E2097`; a rule pattern matching nothing is `E2098`.
- Rules are mandatory between top-level packages: a wire from `core` into `web` needs a rule such as `edge Core: core.* --> web.*;` (`E2099` names the rule to add). Inside one top-level package rules are optional. A provider a rule names flows only where a rule admits (`E2090`), and a payload rule admits only the names it lists (`E2091`). A rule on the bare `*` pattern is `E2100`; `any` is not a pattern (`E0098`).
- `E1144`, `E1146`, `E2090`, `E2091`, `E2094` and `E2099` ignore inline `# jac:ignore`; changing a boundary is an edit to archwire.jac.
- `graph import` is legal only in `archwire.jac` (`E2088`), and archwire.jac holds nothing else: no statements, docstrings or comments (`E2089`).

Consequences worth knowing:

- Having an archwire.jac closes its directory down to the next `archwire.jac` or `jac.toml`. Code that must keep written imports (templates copied into other projects file by file) is its own project with a `jac.toml`.
- Names are relative to the archwire.jac's directory; generated imports use the real import name derived from where the file sits.
- Wires connect modules under the archwire.jac only; stdlib, pip, npm and asset imports stay in the module file. A rule may still funnel an external provider: `edge LlmFunnel: jaclang.byllm.* --> core.ai;`.
- `.test.jac` annexes import freely.

Adopt with `jac arch init [dir] --strip`, which also writes a rule per top-level package that feeds another; `jac arch sync [--prune]` is a one-time catch-up, not a workflow (it widens the rule named after a source package for new edges and deletes the written import of a pruned `-->` wire); inspect with `jac arch graph`. Full reference: `jac guide reference/wiring`.
