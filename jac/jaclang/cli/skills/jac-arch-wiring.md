---
name: jac-arch-wiring
description: Declare a directory's module graph in arch.jac with graph import wires and edge rules. Use when adopting arch.jac, fixing E1144/E2090/E2091/E2094/W3053/W2084, or running jac arch init, sync and graph.
---

An `arch.jac` holds `graph import [scope] { ... }` blocks. A **wire** `provider --> consumer { names }` (or `provider --> consumer;`) generates that import into the consumer at compile time; a **rule** `edge Name: pattern --> pattern [{ names }]` restricts what may flow where.

```
graph import {
    edge CoreFlows: core.* --> core.* | web.* | cli.*;
    edge WebFlows:  web.* --> web.*;
}

graph import core {
    github  --> core.scoring_service { RepoMeta, head_sha }
    timefmt --> core.docs.sync | core.social_graph { now_iso }
}
```

The one rule: **having an arch.jac closes its directory.** It governs every module below it, down to the next `arch.jac` or `jac.toml`. There is no open mode and nothing in `jac.toml`. Every module under it:

- must have every import of a module below the arch.jac match a wire, item by item: matched is `W3053` (autofixed by `jac fmt --lintfix`), unmatched is `E1144` with the wire to add;
- may import such a module inside a function body only through a scoped wire naming that function (`pkg.mod.Class.method`), or it is `E2094`.

Rules are optional restrictions. A provider no rule names flows anywhere under the arch.jac; one a rule names flows only where a rule admits (`E2090`), and a payload rule admits only the names it lists (`E2091`). Rule targets are modules under the arch.jac, so `any` is not a pattern (`E0097`). `E1144`, `E2090`, `E2091` and `E2094` ignore inline `# jac:ignore`; changing a boundary is an edit to arch.jac.

Consequences worth knowing:

- Names are relative to the arch.jac's directory; generated imports use the real import name derived from where the file sits, so a boundary copied elsewhere still weaves correctly.
- Wiring that names no existing module is inert and reported as `W2084`, not an error, so a distribution that leaves modules out still compiles.
- Code that must keep written imports (templates copied into other projects file by file) is its own project with a `jac.toml`.
- Wires connect modules under the arch.jac only; stdlib, pip, npm and asset imports stay in the module file. A rule may still funnel an external provider: `edge LlmFunnel: jaclang.byllm.* --> core.ai;`.
- Inside `graph import core.docs { ... }` the left side is relative to the header, the right side is always absolute.
- `graph import` is legal only in `arch.jac` (`E2088`), and `arch.jac` holds nothing else (`E2089`).

Seal a directory with `jac arch init [dir] --strip`, keep it current with `jac arch sync`, inspect with `jac arch graph`. Full reference: `jac guide reference/wiring`.
