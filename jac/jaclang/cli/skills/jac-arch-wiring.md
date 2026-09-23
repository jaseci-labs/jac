---
name: jac-arch-wiring
description: Declare a project's module graph in arch.jac with impl import wires and edge rules. Use when adopting arch.jac, fixing E1144/E2090/E2091/E2094/W3053, setting [arch] closed, or running jac arch init, sync and graph.
---

`arch.jac` beside `jac.toml` holds `impl import [scope] { ... }` blocks. A **wire** `provider --> consumer { names }` (or `provider --> consumer;`) generates that import into the consumer at compile time; a **rule** `edge Name: pattern --> pattern [{ names }]` says what may flow where.

```
impl import {
    edge CoreFlows: core.* --> core.* | web.* | cli.*;
    edge WebFlows:  web.* --> web.*;
}

impl import core {
    github  --> core.scoring_service { RepoMeta, head_sha }
    timefmt --> core.docs.sync | core.social_graph { now_iso }
}
```

The one rule: **whatever arch.jac names, arch.jac is the whole truth about.** A module is *sealed* once the file names it anywhere: as a wire's provider or consumer, or by matching a rule's source or target pattern (`any` does not count). A sealed module:

- must have every project-module import it writes match a wire, item by item: matched is `W3053` (autofixed by `jac fmt --lintfix`), unmatched is `E1144` with the wire to add;
- admits imports from itself only where a rule says: if no rule names it as a provider it flows nowhere (`E2090`), and a payload rule admits only the names it lists (`E2091`);
- may not import a project module inside a function body (`E2094`); a module that needs a lazy import stays unnamed.

Everything else stays open. `[arch] closed = ["*"]` in `jac.toml` (or a pattern list) seals modules the file never names, and applies even before arch.jac exists. `E1144`, `E2090`, `E2091` and `E2094` ignore inline `# jac:ignore`; loosening a boundary is an edit to arch.jac or jac.toml.

Consequences worth knowing:

- Every wire seals its provider, so a file of wires needs rules: `jac arch init` writes one `edge <Pkg>Flows` rule per package stating where it flows today, and `jac arch sync` adds a rule for any provider that has none.
- Rules and wires are adopted together, by region. `jac arch init <package>` wires one package and everything it imports from, merging into an existing arch.jac.
- Wires connect project modules only; stdlib, pip, npm and asset imports stay in the module file. A rule may still funnel an external provider: `edge LlmFunnel: jaclang.byllm.* --> core.ai;`.
- Inside `impl import core.docs { ... }` the left side is relative to the header, the right side is always absolute.
- `impl import` is legal only in `arch.jac` (`E2088`), and `arch.jac` holds nothing else (`E2089`).

Adopt with `jac arch init --strip`, grow with `jac arch init <package>` or `jac arch sync`, inspect with `jac arch graph`. Full reference: `jac guide reference/wiring`.
