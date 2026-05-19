---
name: jac-walker-patterns
description: Writing walkers that traverse the graph - the core of Object-Spatial Programming (OSP) in Jac. Entry points, moving between nodes, collecting results, and stopping early. Load before creating, editing, or debugging any walker-based traversal or OSP code. Pair with `jac-node-edge-patterns` (the graph shape the walker moves through).
---

A walker is a mobile procedure that enters nodes and runs type-matched entry points. Walker state lives on the walker via `has`; traversal is driven by `visit`; results come back via `report`. Entry points can live on **both** sides - the walker reacts to nodes it enters, and nodes can react to arriving walkers.

```jac
node Item {
    has name: str;

    can greet with Finder entry {
        # node side: self = this node, visitor = the arriving walker
        print(f"{self.name} greeted by {visitor.target}");
    }
}

walker Finder {
    has target: str;
    has matches: list = [];

    can on_root with Root entry {
        visit [-->];
    }

    can on_item with Item entry {
        # walker side: self = walker, here = current node
        if here.name == self.target {
            self.matches.append(here);
            report here;                  # emit to result.reports
        }
        visit [-->];
    }
}

with entry {
    root ++> Item(name="foo");
    root ++> Item(name="bar");

    result = root spawn Finder(target="foo");
    print(result.matches);                # [Item(name='foo')]
}
```

## Pitfalls

- `Root` in type annotations, bare `root` as a value (canonical). `root()` still compiles for backward-compat but emits a deprecation warning - always write `root`, `root ++> node`, `[root -->]`.
- `disengage;` halts the walker immediately - queued visits are discarded. Use for search-style early exits.
- **`visit` is a statement, not a method.** `visit [-->]` queues every outgoing edge; `visit (node_expr)` queues one specific node. Variants: `[<--]` incoming, `[-->:EdgeType:]` typed. Do NOT write `self.visit(...)` - a walker has no `visit` attribute (fails E1030).
- Walkers don't `return` - they `report X;` (appears in `result.reports`) or `disengage;`.
- Every entry needs `with <NodeType> entry` - bare `can foo { ... }` is invalid.
- Entry points are **`can`**, NOT `def`. Plain helper methods can still be `def`, but bodies that fire on node arrival must be `can`.
- **Keyword pairs depend on which side you're writing.** Inside a *walker* entry (`can ... with NodeType entry` in a walker): `self` = the walker, `here` = the current node. Inside a *node* entry (`can ... with WalkerType entry` in a node): `self` = the node, `visitor` = the arriving walker. Mixing them is the #1 walker bug.
- **No generic `with node entry`.** `node` is a declaration keyword, NOT a type. `can foo with node entry { ... }` fails `jac check` with E2018 - the type must be a declared node archetype (or `Root`). Nodes without a matching entry body are simply passed through - no catch-all needed.
