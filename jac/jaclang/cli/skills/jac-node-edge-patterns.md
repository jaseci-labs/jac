---
name: jac-node-edge-patterns
description: Shaping the graph - the entities-and-relationships side of Object-Spatial Programming (OSP) in Jac. Defining nodes and edges, connecting them, and reading subsets by type or field. Load when modeling graph-persistent data, writing graph queries, or writing any OSP code. Pair with `jac-walker-patterns` (traversal logic over the graph).
---

Nodes are graph-persistent entities; edges are connections (plain or typed `edge` archetypes with `has` fields). Connect with arrow operators; read with list-comprehension references.

```jac
node Person {
    has name: str;
}

edge Follows {
    has since: int = 2024;
}

with entry {
    alice = Person(name="alice");
    bob   = Person(name="bob");
    carol = Person(name="carol");

    root ++> alice;                              # untyped connection
    alice +>:Follows(since=2020):+> bob;           # typed connection with has fields
    alice +>:Follows(since=2023):+> carol;

    all_out     = [alice -->];                     # every outgoing node
    via_follows = [alice ->:Follows:->];           # filter by edge type (single-arrow form)
    typed_nodes = [root -->][?:Person];          # filter by node type
    named_bob   = [alice -->][?name == "bob"];     # node-field predicate

    print([n.name for n in all_out]);
    print([n.name for n in via_follows]);
    print([n.name for n in typed_nodes]);
    print([n.name for n in named_bob]);
}
```

## Pitfalls

- Use `node` / `edge` for graph-persistent archetypes. Use `obj` for plain in-memory data that doesn't live on the graph.
- `<++>` creates edges in BOTH directions - easy to double-count traversals. `<++` is just `++>` written from the other end (same single edge).
- Typed edge creation uses `+>:E(args):+>` - `+` on BOTH sides of the colons.
- Edge-type filter uses **single** arrows: `[src ->:E:->]`. The double-arrow form `[src -->:E:-->]` is a parse error.
- **Edge-typed traversal returns `Unknown`-typed nodes - chain `[?:NodeType]` to recover the type.** `[src ->:E:->]` doesn't tell the type checker which node type the edge points to. Direct attribute access then only *warns* (W1051) and `jac check` still passes - but passing such a node to a typed function parameter fails `E1053`, and the untyped access is a latent bug. Append the destination node type to narrow:

```
# FRAGILE - conn is Unknown; conn.username warns W1051, and `show(conn)` fails E1053
for conn in [p ->:Connected:->] { print(conn.username); }

# CORRECT - chain [?:NodeType] to narrow
for conn in [p ->:Connected:->][?:UserProfile] { print(conn.username); }
```

- **Deleting edges:** the `del -->` disconnect operator is **untyped-only**. To delete a specific typed edge, query it with `[edge ...]` (single arrows) and iterate-del. `a del-->:E: b;` is a parse error; `del [a ->:E:-> b];` passes `jac check` but fails at run time (E5043) - neither deletes a typed edge.

```
# Untyped disconnect
a del --> b;

# Typed deletion - iterate edge objects and del each
for e in [edge a ->:E:-> b] { del e; }

# Delete a node (and all its edges)
del node_var;
```

- A node needs `root` attachment (or a path from root) to be reachable later. A freshly constructed `Person(name="x")` with no incoming edge is unreachable from `[root -->]` reads - the node exists in memory but no walker or list-read can find it. Always attach: `root ++> person;`.
