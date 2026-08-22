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

edge Follows: Person --> Person {                  # typed endpoints: source --> target
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
    via_follows = [alice ->:Follows:->];               # typed edge -> inferred list[Person]
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
- Multi-hop chains in one reference: `[a ->:Friend:-> ->:Friend:->]` = friends-of-friends; filter each hop by nesting: `[r-->[?:Profile]-->[?:Tweet]]` = the tweets under r's profiles. **Every hop takes its own edge predicate AND node filter**, directions may reverse mid-chain, and predicates AND together: `[me ->:Follows:since > 2020:-> [?:Person, age >= 18] ->:Follows:->]` (adult post-2020 follows' follows), `[me <-:Follows:<- ->:Posted:->]` (my followers' posts), `[->:Follows:since >= 2019, since <= 2022:->]` (range on one hop). The anchor may also be a *list* of nodes: `[friends ->:Follows:->]`.
- **Reference semantics: deduplicated, ordered, eager.** One reference returns each destination once (parallel edges and diamond paths collapse); results come back in edge-creation order (the basis of deterministic traversal); and the reference is evaluated where it appears - nodes attached after the line are not in its result.
- **Edge types are values, but the hop's type slot takes a bare name only.** `t = Coin; visit [->:t:->];` works (dynamic dispatch via a dict of edge types); inline expressions like `[->:table[ev]:->]` are a parse error - assign to a variable first.
- `[edge n -->]` returns the *edge objects* instead of destination nodes - the way to read edge `has` fields, not just a deletion idiom: `[e.since for e in [edge alice ->:Follows:->]]`.
- Assign comprehensions bulk-update fields without a loop: `people(=verified=True)`; chainable after filters `[root -->[?:Person]](=done=True)`; multiple assignments `items(=status="done", count=0)`.
- Visualize: `print(printgraph(root));` - `printgraph` *returns* a Graphviz DOT string (it does not print by itself).

## Pitfalls

- Use `node` / `edge` for graph-persistent archetypes. Use `obj` for plain in-memory data that doesn't live on the graph.
- **`++>` mirrors its right-hand side.** `new = here ++> Todo(text=t);` makes `new` the Todo node (a single-node connect returns the node, not a list); `new.text` works directly. Connecting to a **list** (`here ++> [a, b]`) returns a list. The old `new[0]` unwrap is gone - drop it.
- `<++>` creates edges in BOTH directions - easy to double-count traversals. `<++` is just `++>` written from the other end (same single edge).
- Typed edge creation uses `+>:E(args):+>` - `+` on BOTH sides of the colons. **The colon-assign form `+>:E:field=val:+>` parses but silently drops the assignment** (the edge default-constructs; verified `since=2021` produced `since=0`). Always pass fields through the constructor parens.
- **Edge-field predicates need the edge type named.** The untyped-predicate form `[a ->::attr > 0:->]` parses but is duck-typed: it evaluates `attr` on EVERY out-edge, so a generic `++>` edge (or any edge type lacking the field) raises `'GenericEdge' object has no attribute ...` at run time. Write `[a ->:E:attr > 0:->]` - the type narrows before the predicate runs.
- Edge-type filter uses **single** arrows: `[src ->:E:->]`. The double-arrow form `[src -->:E:-->]` is a parse error.
- **Edge abilities fire only when the itinerary includes the edge itself.** A `can x with SomeWalker entry` inside an `edge` is a silent no-op under plain node visits (`visit [-->]` crosses edges without waking them) - but it DOES fire on `visit [edge -->]` or when spawning directly on an edge object, and the walker then continues to the edge's target node automatically (verified: toll edge decrements `visitor.budget` via `visit [edge -->]`, stays silent via `visit [-->]`). To put behavior on a relationship, visit the edges; to merely read edge data, `[edge ...]` in a node ability is enough.
- **An *untyped* edge's traversal returns `Unknown`-typed nodes - declare the edge's endpoints, or add `[?:NodeType]` to recover the type.** Over a bare `edge E {}`, `[src ->:E:->]` doesn't tell the type checker which node type the edge points to. Direct attribute access then only *warns* (W1051) and `jac check` still passes - but passing such a node to a typed function parameter fails `E1053`, and the untyped access is a latent bug. Two fixes, prefer the first:
  - **Declare endpoint types on the edge** - `edge E: Src --> Tgt {}` - so *every* `[src ->:E:->]` infers `Tgt` (and `[src <-:E:<-]` infers `Src`) with no per-read filter. A subtype edge inherits its base's endpoints; the clause is edge-only (`E2027` otherwise). This is the durable fix and it also makes the field read compile on the native backend.
  - **Nest `[?:NodeType]`** at the read site to narrow further (or for an intentionally-untyped edge). Chaining `[...][?:NodeType]` narrows identically.

```
# UNTYPED edge - conn is Unknown; conn.username warns W1051, and `show(conn)` fails E1053
edge Connected {}
for conn in [p ->:Connected:->] { print(conn.username); }

# FIX 1 (durable) - declare endpoints; every traversal over Connected now infers UserProfile
edge Connected: UserProfile --> UserProfile {}
for conn in [p ->:Connected:->] { print(conn.username); }

# FIX 2 - nest [?:NodeType] at the read site to narrow further
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
