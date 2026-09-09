---
name: jac-node-edge-patterns
description: Model transient or persistent graphs with typed nodes, edges, queries, and deletion. Use when building graph relationships or filtering topology.
---

Nodes represent graph entities, either transient or persistent; edges are connections (plain or typed `edge` archetypes with `has` fields). Connect with arrow operators; read with list-comprehension references.

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
- **Reference semantics: deduplicated, ordered, eager.** One reference returns each destination once (parallel edges and diamond paths collapse); results come back in edge-creation order unless an ordering term asks otherwise (see below); and the reference is evaluated where it appears - nodes attached after the line are not in its result. A traversal read *on the spot* (`len([a-->])`, `if [a-->]`) answers from the query without materialising the neighbourhood, which changes the cost, not the result.
- **Order and bound inside the reference, not after it.** An ordering term is a bare field name (ascending) or its negation (descending), written in the same comma list as the predicates, in the position that says which side it reads: the hop slot names the edge, the filter bracket names the node. Ordering terms come after every predicate on that hop, and only the final hop of a chain may carry one.

```
[chan ->:Posted:-sent:-> [?:Msg]]           # by the carrying edge's field, descending
[chan ->:Posted:-> [?:Msg, -at]]            # by the node's field, descending
[chan ->:Posted:-> [?:Msg, at > 3, -at]]    # filter, then order
[chan ->:Posted:-> [?:Msg, -at]][:50]       # ordering + bound resolve in one query
```

  Ordering by an *edge* field has no other spelling: the reference returns nodes, so no key over the result can name the edge that carried them. `sorted(<reference>, key=lambda (m: Msg) { -m.at; })` is equivalent for a node field and is folded into the same query, so existing sorts keep working and get faster; a key that computes something (`-(m.at + m.boost)`) cannot fold and sorts in object space.

- **Keyset pagination needs a composite key.** Ordering on a timestamp alone drops or repeats rows when two share it, so page on a tuple: `[chan ->:Posted:-> [?:Msg, (at, seq) < (cur.at, cur.seq)]]`. Left of the operator is field names, right is ordinary scope; both sides must be tuples of the same arity.
- **Edge types are values, but the hop's type slot takes a bare name only.** `t = Coin; visit [->:t:->];` works (dynamic dispatch via a dict of edge types); inline expressions like `[->:table[ev]:->]` are a parse error - assign to a variable first.
- `[edge n -->]` returns the *edge objects* instead of destination nodes - the way to read edge `has` fields, not just a deletion idiom: `[e.since for e in [edge alice ->:Follows:->]]`. Edge references are **not** deduplicated by endpoint: two parallel edges to the same node are two edges, so `len([edge n -->])` and `len([n -->])` legitimately differ.
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

- **Deleting edges:** the `del -->` disconnect operator is **untyped-only**, and `a del-->:E: b;` is a parse error. For a typed edge, `del` the `[edge ...]` query directly: `del` on any expression that is not a name, an attribute, or a subscript destroys exactly the graph objects the expression yields.

```
# Untyped disconnect
a del --> b;

# Typed deletion - del the edge query itself
del [edge a ->:E:-> b];

# Delete a node - cascades to ALL its edges (in and out).
# Capture jid(n) BEFORE the del if you need to report what was removed.
gone = jid(node_var);
del node_var;

# del on a container entry destroys the node it holds, then removes the entry.
del index["alice"];
# Rebind to drop a reference without destroying the node.
index["alice"] = None;
```

- `[root -->]` reads nodes connected from the current root; it cannot find an unconnected node merely because the node exists. Attach nodes where your query or traversal starts. A transient node can also be used directly as a query source or walker spawn location; root attachment is not required for in-memory graph work.
- **Invalid anchors after a change:** check the reference, selected app/store, and schema migration state. Follow `jac-debugging` and `jac-sv-persistence`; do not infer that an anchor error requires deleting project data.
- Per-user vs shared data on a server: the commons graph hangs off `root.shared` - see `jac-sv-multi-user`.

Related guides: `jac-walker-patterns` (traversal), `jac-testing` (per-test root isolation), `jac-debugging` (NodeAnchor/stale-cache triage).
