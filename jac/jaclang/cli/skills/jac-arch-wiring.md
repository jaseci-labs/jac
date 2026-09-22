---
name: jac-arch-wiring
description: Declare a project's module graph in arch.jac with impl import wires and edge rules. Use when adopting arch.jac, fixing E1144/E2090/E2091/W3053, or running jac arch init, sync and graph.
---

`arch.jac` beside `jac.toml` holds `impl import [scope] { ... }` blocks. A **wire** `provider --> consumer { names }` (or `provider --> consumer;`) generates that import into the consumer at compile time; a **rule** `edge Name: pattern --> pattern [{ names }]` says what may flow where.

```
impl import {
    edge CoreInternal: core.* --> core.*;
    edge AppOverCore: core.* --> web.* | cli.*;
}

impl import core {
    github --> core.scoring_service { RepoMeta, head_sha }
    timefmt --> core.docs.sync | core.social_graph { now_iso }
}
```

Rules that always hold:

- **Coverage is per consumer.** A module wired by any wire must have every project-module import it writes match a wire, item by item: matched is `W3053` (autofixed by `jac fmt --lintfix`), unmatched is `E1144` with the wire to add. Uncovered modules are untouched.
- **Wires are project-internal.** stdlib, pip, npm and asset imports stay in the module file. A rule may still name such a provider (`edge LlmFunnel: jaclang.byllm.* --> core.ai;`).
- **Rules constrain on mention.** A provider matched by any rule's source may only flow where some rule admits it (`E2090`); a payload rule admits only the names it lists (`E2091`). Rules apply to every module, covered or not.
- **Scoped block:** inside `impl import core.docs { ... }` the left side is relative to the header, the right side is always absolute.
- `impl import` is legal only in `arch.jac` (`E2088`), and `arch.jac` holds nothing else (`E2089`).

Adopt with `jac arch init --strip`, extend with `jac arch sync`, inspect with `jac arch graph`. Full reference: `jac guide reference/wiring`.
