---
name: jac-node-edge-patterns
description: Shaping the graph - the entities-and-relationships side of Object-Spatial Programming (OSP) in Jac. Defining nodes and edges, connecting, deleting, nested traversal filters by type/field/edge attributes, multi-hop reads, assign comprehensions for bulk updates. Load when modeling graph-persistent data or writing graph queries / OSP code. Pair with `jac-walker-patterns` (traversal logic over the graph).
---

Nodes are graph-persistent entities; edges are connections (plain or typed `edge` archetypes with `has` fields). Connect with arrow operators; read with list-comprehension references.

```jac
node Person {
    has name: str;
    has age: int = 0;
    has verified: bool = False;
}

edge Follows {
    has since: int = 2024;
}

with entry {
    alice = Person(name="alice", age=34);
    bob   = Person(name="bob", age=19);
    carol = Person(name="carol", age=42);

    root ++> alice;                                    # untyped connection
    alice +>:Follows(since=2020):+> bob;               # typed connection with has fields
    alice +>:Follows(since=2023):+> carol;

    all_out     = [alice -->];                         # every outgoing node
    via_follows = [alice ->:Follows:->];               # filter by edge type (single-arrow form)
    old_links   = [alice ->:Follows:since < 2022:->];  # edge-attribute predicate
    adults      = [alice -->[?:Person, age > 30]];     # node type + field predicate (nested)
    named_bob   = [alice -->[?name == "bob"]];         # node-field predicate

    print([n.name for n in via_follows]);              # ['bob', 'carol']

    [alice -->[?:Person]](=verified=True);             # assign comprehension: bulk update
}
```

## Reading and updating the graph

- Direction variants: `[n -->]` outgoing, `[n <--]` incoming, `[n <-->]` either direction. Typed: `[n ->:E:->]` and `[n <-:E:<-]`. **There is no typed bidirectional form** - `[n <->:E:<->]` is a parse error; combine the two directed reads instead.
- **Filters nest inside the reference** - the idiomatic form puts `[?...]` right after the arrow it filters: `[root-->[?:Profile]]`, with a field predicate `[root-->[?:Day, date == today]]`, after a typed edge `[me<-:Follow:<-[?:Profile]]`. Chaining outside the brackets - `[root-->][?:Profile]` - is equivalent (same nodes, same type narrowing), but nesting also composes per hop in multi-hop reads.
- Multi-hop chains in one reference: `[a ->:Friend:-> ->:Friend:->]` = friends-of-friends; filter each hop by nesting: `[r-->[?:Profile]-->[?:Tweet]]` = the tweets under r's profiles.
- `[edge n -->]` returns the *edge objects* instead of destination nodes - the way to read edge `has` fields, not just a deletion idiom: `[e.since for e in [edge alice ->:Follows:->]]`.
- Assign comprehensions bulk-update fields without a loop: `people(=verified=True)`; chainable after filters `[root -->[?:Person]](=done=True)`; multiple assignments `items(=status="done", count=0)`.
- Visualize: `print(printgraph(root));` - `printgraph` *returns* a Graphviz DOT string (it does not print by itself).

## Pitfalls

- Use `node` / `edge` for graph-persistent archetypes. Use `obj` for plain in-memory data that doesn't live on the graph.
- **`++>` returns a LIST, not the node.** `new = here ++> Todo(text=t);` makes `new` a list - `new[0]` is the Todo. `report new;` or `new.text` right after creation are the classic bugs; index first.
- `<++>` creates edges in BOTH directions - easy to double-count traversals. `<++` is just `++>` written from the other end (same single edge).
- Typed edge creation uses `+>:E(args):+>` - `+` on BOTH sides of the colons.
- Edge-type filter uses **single** arrows: `[src ->:E:->]`. The double-arrow form `[src -->:E:-->]` is a parse error.
- **Edge abilities are a silent no-op.** A `can x with SomeWalker entry` inside an `edge` compiles cleanly and never fires (documented Known Limitation). Modeling toll/cost/logging behavior on the edge gives zero effect with no error - put the logic in the walker's node abilities and read edge data via `[edge ...]`.
- **Edge-typed traversal returns `Unknown`-typed nodes - add `[?:NodeType]` to recover the type.** `[src ->:E:->]` doesn't tell the type checker which node type the edge points to. Direct attribute access then only *warns* (W1051) and `jac check` still passes - but passing such a node to a typed function parameter fails `E1053`, and the untyped access is a latent bug. Nest the destination node type to narrow (chaining `[...][?:NodeType]` narrows identically):

```
# FRAGILE - conn is Unknown; conn.username warns W1051, and `show(conn)` fails E1053
for conn in [p ->:Connected:->] { print(conn.username); }

# CORRECT - nest [?:NodeType] to narrow
for conn in [p ->:Connected:->[?:UserProfile]] { print(conn.username); }
```

- **Deleting edges:** the `del -->` disconnect operator is **untyped-only**. To delete a specific typed edge, query it with `[edge ...]` (single arrows) and iterate-del. `a del-->:E: b;` is a parse error; `del [a ->:E:-> b];` passes `jac check` but fails at run time (E5043) - neither deletes a typed edge.

```
# Untyped disconnect
a del --> b;

# Typed deletion - iterate edge objects and del each
for e in [edge a ->:E:-> b] { del e; }

# Delete a node - cascades to ALL its edges (in and out).
# Capture jid(n) BEFORE the del if you need to report what was removed.
gone = jid(node_var);
del node_var;
```

- A node needs `root` attachment (or a path from root) to be reachable later. A freshly constructed `Person(name="x")` with no incoming edge is unreachable from `[root -->]` reads - the node exists in memory but no walker or list-read can find it. Always attach: `root ++> person;`.
- **`jac run` persists graph state** in the cwd's `.jac/` directory. Re-running a script duplicates its nodes, and changing archetype definitions between runs yields `NodeAnchor ... is not a valid reference!` errors. Reset with `jac clean --all` (requires a jac.toml; for a bare script directory, `rm -rf .jac/`).
- Per-user vs shared data on a server: the commons graph hangs off `root.shared` - see `jac-sv-multi-user`.

Related guides: `jac-walker-patterns` (traversal), `jac-testing` (per-test root isolation), `jac-debugging` (NodeAnchor/stale-cache triage).
