"""A space's graph, kept: `Store` is the interface of the plugin that holds its
rows, and this module the runtime above it, which owns node identity,
what of the graph is in memory, and when a call's writes commit. `grant` says
who else may touch a node.

- **The graph is brought as a walk reaches it.** A program starts with its
  roots. A node comes with its fields, and its edges when they are first
  read or changed (the runtime asks, rt_reach): the nodes at their other
  ends come with them, each with its own edges still to come. So a program
  holds what its calls reached, however much is kept.
- **One call is one transaction.** After each, what changed is found by
  encoding what is in memory and comparing it with what was read, so no
  write barrier sits on a hot path.
- **Several programs may share a store.** Each row has a version, which a
  write expects to be the one it read: a write that finds another raises
  StoreConflict, and the call is run again on what the other wrote
  (`kept_call`). Each call starts by taking in what the others wrote since
  the last."""

import json;

enum AccessLevel {
    NO_ACCESS = 0,
    READ = 1,
    CONNECT = 2,
    WRITE = 3,
}

"""One node or edge as a store keeps it, by its id (its `jid`, which the runtime
gives it as it is made and the store gives back to what it loads): `src`,
`dst` and `ord` only for an edge, `ord` the order edges were made in, which
loading makes them in again, so each node's edges keep their order.
`version` counts the times it was written: 0 for a row no store has yet."""
obj Row {
    has id: str,
        kind: str,
        type_name: str,
        data: str,
        src: str = "",
        dst: str = "",
        ord: int = 0,
        version: int = 0;
}

"""What a store has had written since a mark (Store.since): the rows written,
as they are now, and the ids of the rows taken out."""
obj Changed {
    has rows: list[Row] = [],
        gone: list[str] = [];
}

"""What one commit writes, all of it or none (Store.write): the rows to keep,
each at the version it was read at; the rows to take out, likewise; the
roots first given to users, by user; the shared root, when it is first set;
and the shape each type's rows are now written in."""
obj Writing {
    has rows: list[Row] = [],
        gone: list[Row] = [],
        roots: dict[str, str] = {},
        shared: str = "",
        shapes: dict[str, str] = {};
}

"""A write a store refuses because what it would change is no longer what was
read: another user of the store wrote or took out the rows `ids` first, or
gave a user their root first."""
obj:pub StoreConflict(Exception) {
    has ids: list[str] = [];

    def __str__ -> str {
        return f"the store's rows changed under this call: {', '.join(self.ids[:3])}"
            + (f" and {len(self.ids) - 3} more" if len(self.ids) > 3 else "");
    }
}

"""What holds a space's rows: the interface of the `store` abstraction's
plugins. One is made with its settings and does nothing until it is
opened."""
obj Store {
    """Make ready to hold rows: open the file, reach the service. DataError
    for data it holds that it can't be opened with."""
    def open abst;

    """What its data is called, where an app says what is wrong with what
    it kept: a file's path, a table's address."""
    def kept_as -> str abst;

    """How many rows it holds of each type, by the type's name: what a
    program is held against as it starts."""
    def types -> dict[str, int] abst;

    """The shape each type's rows were last written in (Writing.shapes)."""
    def shapes -> dict[str, str] abst;

    """Every row of the type `type_name`: asked only for a type whose shape
    the program has changed, to see that what is kept still fits."""
    def of_type(type_name: str) -> list[Row] abst;

    """The rows of `ids`, those it holds, in any order."""
    def rows(ids: list[str]) -> list[Row] abst;

    """Every edge at the node `id`, out of it and into it, in the order they
    were made."""
    def edges(id: str) -> list[Row] abst;

    """Where its writes are counted to: a number each write raises."""
    def mark -> int abst;

    """What was written after `mark`, by any user of the store; None when it
    no longer knows that far back, and what a program holds of it is to be
    read again."""
    def since(mark: int) -> Changed | None abst;

    """Keep what `w` writes, all of it or none, and give the mark it made.
    StoreConflict when a row is not at the version `w` has it at, or a user
    already has a root."""
    def write(w: Writing) -> int abst;

    """Every row it holds, each without its data: its id, its kind, an
    edge's two ends, and its version. What a sweep reads (stdjac.graph's
    `sweep`), a row at a time."""
    def every -> Iterator[Row] abst;

    """The id of the root of the user `user`, or "" before they have one."""
    def root_of(user: str) -> str abst;

    """Every user's root: never the shared one."""
    def roots -> list[str] abst;

    """The id of the space's one shared root, or "" before it has one. It is
    no user's: no user ID names it."""
    def shared_root -> str abst;
}

"""Data an app kept that it can't start with: the file at `path` ("" for a
store that keeps no file of its own to name), and what is wrong with it, as
what follows the file's name in a sentence ("is laid out as a newer jac
writes it"). It is the state of someone's data, not a fault of the program:
what starts an app says it, in words, and stops (stdjac.app)."""
obj:pub DataError(Exception) {
    has path: str,
        problem: str;

    def __str__ -> str {
        return f"{self.path} {self.problem}" if self.path != "" else self.problem;
    }
}

"""What a codec raises for a row of a type it has none of: a node or an edge
type the data was kept with that the program no longer has."""
obj:pub UnknownType(Exception) {
    has name: str;

    def __str__ -> str {
        return f"an unknown type: {self.name}";
    }
}

"""How the graph's nodes and edges become rows and back. `make_node` and
`connect` raise UnknownType for a type the program has none of, and
CodecError for data that doesn't fit the type it has."""
obj Codec {
    def node_type(n: Node) -> str abst;
    def node_data(n: Node) -> dict[str, any] abst;
    def make_node(type_name: str, data: dict[str, any]) -> Node abst;

    """Give node `n` the fields `data` holds: what another user of the store
    wrote of it, or what it was before a call that is run again."""
    def fill_node(n: Node, data: dict[str, any]) abst;

    def edge_type(e: any) -> str abst;
    def edge_data(e: any) -> dict[str, any] abst;
    def connect(type_name: str, a: Node, b: Node, data: dict[str, any]) abst;
    def fill_edge(e: any, data: dict[str, any]) abst;

    """See that `data` fits the type named `type_name`: CodecError where it
    does not."""
    def fits(type_name: str, data: dict[str, any]) abst;

    """The shape of the type named `type_name`, as text: its fields and
    their types. Rows written in one shape fit a program whose type has
    it."""
    def shape(type_name: str) -> str abst;

    """Whether the program has a type of that name to keep."""
    def keeps(type_name: str) -> bool abst;
}

"""A node type the store keeps, by its module-qualified name: whether a node
is one, its fields as JSON's values, and one restored from them."""
obj NodeType {
    has name: str,
        shape: str,
        holds: Callable[[Node], bool],
        data: Callable[[Node], dict[str, any]],
        make: Callable[[dict[str, any]], Node],
        fill: Callable[[Node, dict[str, any]], None];
}

"""An edge type the store keeps, likewise: and an edge of it, restored, between
two nodes."""
obj EdgeType {
    has name: str,
        shape: str,
        holds: Callable[[any], bool],
        data: Callable[[any], dict[str, any]],
        connect: Callable[[Node, Node, dict[str, any]], None],
        fill: Callable[[any, dict[str, any]], None],
        fits: Callable[[dict[str, any]], None];
}

glob _node_types: list[NodeType] = [],
     _edge_types: list[EdgeType] = [];

"""Keep nodes of type N, named `name`: what the compiler calls, where N's
module starts, for each node type of a program that keeps a graph. Its
fields go through stdjac's codec, so a type with no JSON form is refused at
compile time."""
def:pub keep_node[N](name: str) -> bool {
    _node_types.append(
        NodeType(
            name=name,
            shape=shape_of[N](),
            holds=lambda (n: Node) -> bool { return type(n) is N; },
            data=lambda (n: Node) -> dict[str, any] {
                d: dict[str, any] = encode_object[N](n as N);
                return d;
            },
            make=lambda (d: dict[str, any]) -> Node { return decode_object[N](d); },
            fill=lambda (n: Node, d: dict[str, any]) { fill_object[N](n as N, d) },
        ),
    );
    return True;
}

"""Keep edges of type E, named `name`, as keep_node keeps nodes."""
def:pub keep_edge[E](name: str) -> bool {
    _edge_types.append(
        EdgeType(
            name=name,
            shape=shape_of[E](),
            holds=lambda (e: any) -> bool { return type(e) is E; },
            data=lambda (e: any) -> dict[str, any] {
                d: dict[str, any] = encode_object[E](e as E);
                return d;
            },
            connect=lambda (a: Node, b: Node, d: dict[str, any]) {
                made = decode_object[E](d);
                a +>:made:+> b;
            },
            fill=lambda (e: any, d: dict[str, any]) { fill_object[E](e as E, d) },
            fits=lambda (d: dict[str, any]) { checked = decode_object[E](d); },
        ),
    );
    return True;
}

"""The codec of the types kept (keep_node, keep_edge)."""
obj StoreCodec(Codec) {
    def node_type(n: Node) -> str {
        if isinstance(n, Root) {
            return "Root";
        }
        for t in _node_types {
            if t.holds(n) {
                return t.name;
            }
        }
        return "Node";
    }

    def node_data(n: Node) -> dict[str, any] {
        for t in _node_types {
            if t.holds(n) {
                return t.data(n);
            }
        }
        return {};
    }

    def make_node(type_name: str, data: dict[str, any]) -> Node {
        if type_name == "Root" {
            return Root();
        }
        for t in _node_types {
            if t.name == type_name {
                return t.make(data);
            }
        }
        raise UnknownType(name=type_name);
    }

    def fill_node(n: Node, data: dict[str, any]) {
        for t in _node_types {
            if t.holds(n) {
                t.fill(n, data);
                return;
            }
        }
    }

    def fill_edge(e: any, data: dict[str, any]) {
        for u in _edge_types {
            if u.holds(e) {
                u.fill(e, data);
                return;
            }
        }
    }

    def fits(type_name: str, data: dict[str, any]) {
        for t in _node_types {
            if t.name == type_name {
                t.make(data);
                return;
            }
        }
        for u in _edge_types {
            if u.name == type_name {
                u.fits(data);
                return;
            }
        }
    }

    def shape(type_name: str) -> str {
        for t in _node_types {
            if t.name == type_name {
                return t.shape;
            }
        }
        for u in _edge_types {
            if u.name == type_name {
                return u.shape;
            }
        }
        return "";
    }

    def keeps(type_name: str) -> bool {
        if type_name in ["Root", "Node", ""] {
            return True;
        }
        for t in _node_types {
            if t.name == type_name {
                return True;
            }
        }
        for u in _edge_types {
            if u.name == type_name {
                return True;
            }
        }
        return False;
    }

    def edge_type(e: any) -> str {
        for t in _edge_types {
            if t.holds(e) {
                return t.name;
            }
        }
        return "";
    }

    def edge_data(e: any) -> dict[str, any] {
        for t in _edge_types {
            if t.holds(e) {
                return t.data(e);
            }
        }
        return {};
    }

    def connect(type_name: str, a: Node, b: Node, data: dict[str, any]) {
        if type_name == "" {
            a ++> b;
            return;
        }
        for t in _edge_types {
            if t.name == type_name {
                t.connect(a, b, data);
                return;
            }
        }
        raise UnknownType(name=type_name);
    }
}

glob _store: dyn Store | None = None,
     _codec: dyn Codec | None = None,
     _grants: dict[str, int] = {},
     # Each user's root that is here, by its id, and by the user's name.
     _roots: dict[str, Root] = {},
     _user_roots: dict[str, Root] = {},
     # The roots made here that the store has not yet: each user's, by the
     # user's name, and the shared one's id.
     _new_roots: dict[str, str] = {},
     _new_shared: list[str] = [],
     # The kept nodes and edges that are here, by id.
     _nodes: dict[str, Node] = {},
     _edges: dict[str, any] = {},
     # Each of them as the store has it: its data, and the version read.
     _kept: dict[str, str] = {},
     _versions: dict[str, int] = {},
     # Each kept edge's two ends, by its id.
     _ends: dict[str, tuple[str, str]] = {},
     # The kept edges at each node whose edges are all here, by the node's id.
     _edges_at: dict[str, list[str]] = {},
     # The nodes whose edges are being brought: a walk that brings one asks
     # for no other's on the way.
     _bringing: dict[str, bool] = {},
     # The nodes taken out by name (remove): no id finds them after.
     _removed: dict[str, bool] = {},
     # Where the store's writes were counted to when this program last took
     # them in.
     _mark: list[int] = [0],
     # The shape the store has each type's rows in, and those to write.
     _shapes: dict[str, str] = {},
     _new_shapes: dict[str, str] = {},
     # The root the program starts with: every caller's where no store is
     # open.
     _home: Root = root;

"""How many times a call is run before the conflict a store raises is the
call's own failure."""
glob TRIES: int = 4;

"""`stdjac.graph.grant`: who else may touch `n`."""
def:pub grant(n: Node, level: AccessLevel = AccessLevel.READ) {
    _grants[jid(n)] = level.value;
}

"""The store and the codec of a graph that is kept."""
def keeper -> tuple[dyn Store, dyn Codec] {
    s = _store;
    c = _codec;
    if s is None or c is None {
        raise RuntimeError("this program keeps no graph");
    }
    return (s, c);
}

"""A kept row the program can't make again: a DataError that names where it
is kept."""
def unmade(r: Row, why: str) -> DataError {
    (s, _c) = keeper();
    what = "node" if r.kind == "n" else "edge";
    return DataError(path=s.kept_as(), problem=f"holds a {r.type_name} {what}, {r.id}, {why}");
}

"""The node row `r`, made a node here: with its fields and its id, its edges
still where they are kept (rt_await_edges)."""
def take_node(r: Row) -> Node {
    (_s, c) = keeper();
    data: dict[str, any] = json.loads(r.data);
    n: Node | None = None;
    try {
        n = c.make_node(r.type_name, data);
    } except UnknownType {
        raise unmade(r, "whose type this program no longer has");
    } except CodecError as e {
        raise unmade(r, f"which no longer fits its type ({e})");
    }
    if not rt_jid_restore(n, r.id) {
        raise unmade(r, "which no jid names");
    }
    _nodes[r.id] = n;
    _kept[r.id] = r.data;
    _versions[r.id] = r.version;
    if "__grant" in data {
        _grants[r.id] = int(data["__grant"]);
    }
    rt_await_edges(n);
    return n;
}

"""Bring the nodes `ids` names that are not here."""
def bring_nodes(ids: list[str]) {
    (s, _c) = keeper();
    need: list[str] = [];
    for i in ids {
        if i not in _nodes and i not in need {
            need.append(i);
        }
    }
    if len(need) == 0 {
        return;
    }
    for r in s.rows(need) {
        if r.kind == "n" and r.id not in _nodes {
            take_node(r);
        }
    }
}

"""The edge row `r`, made an edge here between its two ends, which are here:
the last of its source's edges out, until the source's are put in order."""
def take_edge(r: Row) -> any {
    (_s, c) = keeper();
    a = _nodes[r.src];
    b = _nodes[r.dst];
    try {
        c.connect(r.type_name, a, b, json.loads(r.data));
    } except UnknownType {
        raise unmade(r, "whose type this program no longer has");
    } except CodecError as e {
        raise unmade(r, f"which no longer fits its type ({e})");
    }
    held = rt_edges_held(a, False);
    e = held[len(held) - 1];
    rt_jid_restore(e, r.id);
    _edges[r.id] = e;
    _kept[r.id] = r.data;
    _versions[r.id] = r.version;
    _ends[r.id] = (r.src, r.dst);
    return e;
}

"""Forget the kept row `id`: it is no longer here, or no longer kept."""
def forget(id: str) {
    if id in _kept {
        del _kept[id];
    }
    if id in _versions {
        del _versions[id];
    }
    if id in _grants {
        del _grants[id];
    }
    if id in _ends {
        del _ends[id];
    }
    if id in _edges {
        del _edges[id];
    }
    if id in _edges_at {
        del _edges_at[id];
    }
    if id in _nodes {
        rt_edges_here(_nodes[id]);
        del _nodes[id];
    }
    if id in _roots {
        del _roots[id];
    }
}

"""The ids of the edges at node `n` as they are here: out of it and into it,
each once."""
def edges_here(n: Node) -> list[str] {
    out: list[str] = [];
    for into in [False, True] {
        for e in rt_edges_held(n, into) {
            eid = jid(e);
            if eid not in out {
                out.append(eid);
            }
        }
    }
    return out;
}

"""Bring node `n`'s edges, as the store has them now: each one that is not
here made, with the node at its other end; each kept one that is here and
the store no longer has taken out; and its edges out and in put in the order
they were made, those made here since after them."""
def bring_edges(n: Node) {
    nid = jid(n);
    if not rt_awaits_edges(n) or nid in _bringing {
        return;
    }
    (s, _c) = keeper();
    _bringing[nid] = True;
    try {
        rows = s.edges(nid);
        ends: list[str] = [];
        for r in rows {
            ends.append(r.src);
            ends.append(r.dst);
        }
        bring_nodes(ends);
        listed: dict[str, bool] = {};
        kept: list[str] = [];
        for r in rows {
            if r.src not in _nodes or r.dst not in _nodes {
                # (An edge whose other end the store no longer has.)
                continue;
            }
            listed[r.id] = True;
            kept.append(r.id);
            if r.id not in _edges {
                take_edge(r);
            }
        }
        for eid in edges_here(n) {
            if eid in _edges and eid not in listed {
                rt_drop_held_edge(_edges[eid]);
                forget(eid);
            }
        }
        for into in [False, True] {
            held = rt_edges_held(n, into);
            by_id: dict[str, any] = {};
            for e in held {
                by_id[jid(e)] = e;
            }
            ordered: list[any] = [];
            for r in rows {
                if r.id in by_id and (r.dst if into else r.src) == nid {
                    ordered.append(by_id[r.id]);
                }
            }
            for e in held {
                if jid(e) not in listed {
                    ordered.append(e);
                }
            }
            rt_edges_order(n, into, ordered);
        }
        _edges_at[nid] = kept;
        rt_edges_here(n);
    } finally {
        del _bringing[nid];
    }
}

"""What the runtime asks before it reads or changes the edges of a node whose
edges are still where they are kept (rt_reach)."""
def reach(n: Node) {
    in_turn(lambda { bring_edges(n) });
}

"""The node the store keeps as `id`, here: None for an id it has no node of."""
def node_kept(id: str) -> Node | None {
    if id == "" {
        return None;
    }
    if id not in _nodes {
        bring_nodes([id]);
    }
    return _nodes.get(id, None);
}

"""The node or edge named `name`, if it's in the graph: one that is here, one
the store keeps, or one made since the last commit that a node here leads
to."""
def:pub jobj(name: str) -> any {
    if name in _removed {
        return None;
    }
    if name in _nodes {
        return _nodes[name];
    }
    if name in _edges {
        return _edges[name];
    }
    found: list[any] = [];
    in_turn(lambda { found.append(find_kept(name)) });
    if found[0] is not None {
        return found[0];
    }
    seen: dict[str, bool] = {};
    todo: list[Node] = [root.shared, _home];
    for held in _nodes.values() {
        todo.append(held);
    }
    for r in _roots.values() {
        todo.append(r);
    }
    i = 0;
    while i < len(todo) {
        n = todo[i];
        i += 1;
        nid = jid(n);
        if nid in seen {
            continue;
        }
        seen[nid] = True;
        if nid == name {
            return n;
        }
        for e in rt_edges_held(n, False) {
            if jid(e) == name {
                return e;
            }
            todo.append(rt_edge_dst(e));
        }
    }
    return None;
}

"""What the store keeps as `name`, brought here: a node, or an edge with the
nodes at its ends; None for a name it keeps nothing as."""
def find_kept(name: str) -> any {
    s = _store;
    if s is None {
        return None;
    }
    for r in s.rows([name]) {
        if r.kind == "n" {
            return _nodes[r.id] if r.id in _nodes else take_node(r);
        }
        bring_nodes([r.src, r.dst]);
        if r.src in _nodes and r.dst in _nodes {
            return _edges[r.id] if r.id in _edges else take_edge(r);
        }
    }
    return None;
}

"""Takes `n` out of the graph, with its edges: none of them is found by its id
any more."""
def:pub remove(n: Node) {
    for e in [edge n -->] + [edge n <--] {
        _removed[jid(e)] = True;
    }
    _removed[jid(n)] = True;
    rt_detach_node(id(n));
}

"""Every caller's root in this space."""
def:pub allroots -> list[Root] {
    in_turn(bring_roots);
    return list(_roots.values());
}

"""Bring every user's root the store keeps."""
def bring_roots {
    s = _store;
    if s is None {
        return;
    }
    ids = s.roots();
    bring_nodes(ids);
    for i in ids {
        if i in _nodes and i not in _roots {
            _roots[i] = _nodes[i] as Root;
        }
    }
}

"""What `counts` (how many rows of each type) reads as: "9 Tweet and 3
Channel"."""
def counted(counts: dict[str, int]) -> str {
    parts = [f"{n} {name}" for (name, n) in counts.items()];
    return parts[0] if len(parts) == 1 else ", ".join(parts[:-1]) + " and " + parts[-1];
}

"""Opens the graph: its shared root, with the rest to come as it is reached.
What is kept is held against the program first: rows of a type the program
no longer has, and rows that no longer fit the type it has, are DataError,
all of them said at once. A type whose rows were written in the shape the
program has is known to fit, and none of its rows is read."""
def:pub graph_open(store: dyn Store, codec: dyn Codec) {
    store.open();
    _store = store;
    _codec = codec;
    gone: dict[str, int] = {};
    unfit: dict[str, int] = {};
    why: dict[str, str] = {};
    was = store.shapes();
    for (name, count) in store.types().items() {
        if not codec.keeps(name) {
            gone[name] = count;
            continue;
        }
        shape = codec.shape(name);
        if shape == "" {
            continue;
        }
        _shapes[name] = was.get(name, "");
        if _shapes[name] == shape {
            continue;
        }
        # Kept in another shape, or before shapes were: each row is read once,
        # to see that it still fits.
        for r in store.of_type(name) {
            try {
                codec.fits(name, json.loads(r.data));
            } except CodecError as e {
                unfit[name] = unfit.get(name, 0) + 1;
                if name not in why {
                    why[name] = str(e);
                }
            }
        }
        if name not in unfit {
            _new_shapes[name] = shape;
        }
    }
    if len(gone) > 0 or len(unfit) > 0 {
        said: list[str] = [];
        if len(gone) > 0 {
            whose = "whose type" if len(gone) == 1 else "whose types";
            said.append(f"holds {counted(gone)} {whose} this program no longer has");
        }
        for (name, count) in unfit.items() {
            said.append(f"holds {count} {name} that no longer fit the type ({why[name]})");
        }
        raise DataError(path="", problem="; and ".join(said));
    }
    _mark[0] = store.mark();
    shared = node_kept(store.shared_root());
    if shared is not None {
        rt_set_shared_root(shared as Root);
    } else {
        _new_shared.append(jid(root.shared));
    }
    rt_reach_with(reach);
}

"""The root `user` starts at, made the first time."""
def:pub root_for(user: str) -> Root {
    if _store is None {
        return _home;
    }
    if user not in _user_roots {
        in_turn(lambda { find_root(user) });
    }
    return _user_roots[user];
}

"""`user`'s root, from the store or made now: kept in _user_roots."""
def find_root(user: str) {
    s = _store;
    if s is None or user in _user_roots {
        return;
    }
    kept = node_kept(s.root_of(user));
    if kept is not None {
        _roots[jid(kept)] = kept as Root;
        _user_roots[user] = kept as Root;
        return;
    }
    r = Root();
    _new_roots[user] = jid(r);
    _roots[jid(r)] = r;
    _user_roots[user] = r;
}

"""Whose graph `root` means for the call this thread answers: `user`'s. With
no caller it is no one's: `root` raises there, `root.shared` and `allroots()`
are what the call has, and a walker it spawns on `root` starts at the shared
one. It is the thread's own, and that of each thread the call
starts, so the calls a server answers at once each have their caller's.
A call starts on what the store's other users have written by now."""
def:pub enter_caller(user: str) {
    if _store is not None {
        in_turn(take_in);
    }
    if user == "" {
        rt_caller_enter(root.shared, True, "");
    } else {
        rt_caller_enter(root_for(user), False, user);
    }
}

"""Who the call being answered is for: its caller's name, "" for no one.
What a crossing this process carries itself passes on (stdjac.remote's
in-process spaces)."""
def:pub current_caller -> str {
    return rt_caller_name();
}

"""What gives each use of the store its turn, in a program whose calls run
on threads (stdjac.server's lock, set as it starts serving): given the work,
it runs it when no other thread is at the store. None where nothing runs
beside it."""
glob _turn: Callable[[Callable[[], None]], None] | None = None;

"""The store's users take turns through `turn` from here."""
def:pub store_in_turn(turn: Callable[[Callable[[], None]], None]) {
    _turn = turn;
}

"""Run `work`, which uses the store, in its turn."""
def in_turn(work: Callable[[], None]) {
    turn = _turn;
    if turn is None {
        work();
    } else {
        turn(work);
    }
}

"""Run `work`, a call's own work for `user`, and keep what it changed.

It runs on what the store's other users wrote before it started. When what
it would write was written under it (StoreConflict), what it changed here is
put back as it was and it runs again, on what the other wrote: up to TRIES
times, after which the conflict is the call's own failure. So `work` may run
more than once, and what it does outside the graph is done each time."""
def:pub kept_call(user: str, work: Callable[[], any]) -> any {
    if _store is None {
        enter_caller(user);
        return work();
    }
    tried = 0;
    while True {
        enter_caller(user);
        out = work();
        try {
            commit();
            return out;
        } except StoreConflict as e {
            tried += 1;
            in_turn(lambda { put_back(e) });
            if tried >= TRIES {
                raise;
            }
        }
    }
}

"""`stdjac.graph.commit`: write what changed in the graph since it was last
written, now. A server writes it when each call returns; a call that runs
long, or a stream, calls this where what it has made so far should be kept
whatever happens next. In a program that keeps no graph it does nothing.
StoreConflict when another user of the store wrote what this would: what a
server answers by running the call again (kept_call)."""
def:pub commit {
    if _store is None or _codec is None {
        return;
    }
    in_turn(write_changes);
}

"""`stdjac.graph.sweep`: take out of what is kept every node and edge that no
root leads to, and say how many rows went.

A write takes out what it can tell is cut off: a node with no edge into it,
and what only it led to. Nodes that lead to each other and are cut off
together it cannot tell from nodes another walk still reaches, and they keep
their rows until a sweep. A sweep reads the id of everything kept, so its
cost grows with the store, where a write's does not: it is for a quiet hour,
from a scheduled function or by hand. In a program that keeps no graph it
does nothing. StoreConflict when another user of the store wrote one of the
rows meanwhile: nothing is taken out, and the sweep is for another time."""
def:pub sweep -> int {
    if _store is None or _codec is None {
        return 0;
    }
    commit();
    went: list[int] = [];
    in_turn(lambda { went.append(sweep_kept()) });
    return went[0];
}

"""Take out the kept rows no root leads to: how many."""
def sweep_kept -> int {
    (s, _c) = keeper();
    nodes: dict[str, int] = {};
    edges: dict[str, int] = {};
    ends: dict[str, tuple[str, str]] = {};
    leads: dict[str, list[str]] = {};
    for r in s.every() {
        if r.kind == "n" {
            nodes[r.id] = r.version;
            continue;
        }
        edges[r.id] = r.version;
        ends[r.id] = (r.src, r.dst);
        if r.src not in leads {
            leads[r.src] = [];
        }
        leads[r.src].append(r.id);
    }
    reached: dict[str, bool] = {};
    todo: list[str] = [s.shared_root()] + s.roots();
    while len(todo) > 0 {
        nid = todo.pop();
        if nid in reached or nid not in nodes {
            continue;
        }
        reached[nid] = True;
        for eid in leads.get(nid, []) {
            if ends[eid][1] in nodes {
                reached[eid] = True;
                todo.append(ends[eid][1]);
            }
        }
    }
    w = Writing();
    for (eid, version) in edges.items() {
        if eid not in reached {
            (from_id, to_id) = ends[eid];
            w.gone.append(
                Row(
                    id=eid, kind="e", type_name="", data="", src=from_id, dst=to_id, version=version
                ),
            );
        }
    }
    for (nid, version) in nodes.items() {
        if nid not in reached {
            w.gone.append(Row(id=nid, kind="n", type_name="", data="", version=version));
        }
    }
    if len(w.gone) == 0 {
        return 0;
    }
    mark = s.write(w);
    # What went may be here: it is here no longer.
    for r in w.gone {
        if r.kind == "e" and r.id in _edges {
            rt_drop_held_edge(_edges[r.id]);
            for at in _edges_at.values() {
                if r.id in at {
                    at.remove(r.id);
                }
            }
            forget(r.id);
        }
    }
    for r in w.gone {
        if r.kind == "n" and r.id in _nodes {
            n = _nodes[r.id];
            for into in [False, True] {
                for e in rt_edges_held(n, into) {
                    rt_drop_held_edge(e);
                }
            }
            forget(r.id);
        }
    }
    if mark == _mark[0] + 1 {
        _mark[0] = mark;
    }
    return len(w.gone);
}

"""Node `n` as a row holds it."""
def node_text(n: Node, nid: str) -> str {
    (_s, c) = keeper();
    data = c.node_data(n);
    if nid in _grants {
        data["__grant"] = _grants[nid];
    }
    return json.dumps(data);
}

"""The ids of the roots: the shared one's, and each user's that is here."""
def root_ids -> dict[str, bool] {
    out: dict[str, bool] = {jid(root.shared): True};
    for i in _roots {
        out[i] = True;
    }
    return out;
}

"""What changed since the last commit, written.

- **What is taken out:** a kept edge that is no longer at a node whose edges
  are all here, and a kept node that has no edge into it and is no root,
  with its edges out, and so on down from it. (A cycle of nodes cut off
  whole keeps its rows: nothing here can tell it from one another walk
  still reaches.)
- **What is written:** each node here, and each node and edge made since
  that one of them leads to, whose row is not what the store has."""
def write_changes {
    (s, c) = keeper();
    w = Writing();
    roots = root_ids();
    # The kept edges that have gone from where they were.
    gone: dict[str, bool] = {};
    asked: list[str] = [i for i in _removed if i in _nodes];
    for (nid, were) in _edges_at.items() {
        now = edges_here(_nodes[nid]);
        for eid in were {
            if eid not in now and eid not in gone {
                gone[eid] = True;
                asked.append(_ends[eid][1]);
            }
        }
    }
    # The nodes they led to, when nothing else leads to them, and what those
    # led to.
    doomed: dict[str, bool] = {};
    i = 0;
    while i < len(asked) {
        nid = asked[i];
        i += 1;
        if nid in doomed or nid in roots or nid not in _nodes {
            continue;
        }
        n = _nodes[nid];
        bring_edges(n);
        if len(rt_edges_held(n, True)) > 0 {
            continue;
        }
        doomed[nid] = True;
        for e in rt_edges_held(n, False) {
            eid = jid(e);
            if eid in _edges {
                gone[eid] = True;
            }
            asked.append(jid(rt_edge_dst(e)));
            rt_drop_held_edge(e);
        }
    }
    # What is here now, from every node that is kept or a root.
    seen: dict[str, bool] = {};
    fresh_nodes: dict[str, Node] = {};
    fresh_edges: dict[str, any] = {};
    todo: list[Node] = [root.shared];
    for users in _roots.values() {
        todo.append(users);
    }
    for (nid, n) in _nodes.items() {
        if nid not in doomed {
            todo.append(n);
        }
    }
    i = 0;
    while i < len(todo) {
        n = todo[i];
        i += 1;
        nid = jid(n);
        if nid in seen {
            continue;
        }
        seen[nid] = True;
        text = node_text(n, nid);
        if _kept.get(nid) != text {
            kind = c.node_type(n);
            w.rows.append(
                Row(id=nid, kind="n", type_name=kind, data=text, version=_versions.get(nid, 0))
            );
            fresh_nodes[nid] = n;
            note_shape(w, kind);
        }
        for e in rt_edges_held(n, False) {
            eid = jid(e);
            dst = rt_edge_dst(e);
            etext = json.dumps(c.edge_data(e));
            if _kept.get(eid) != etext {
                kind = c.edge_type(e);
                w.rows.append(
                    Row(
                        id=eid,
                        kind="e",
                        type_name=kind,
                        data=etext,
                        src=nid,
                        dst=jid(dst),
                        ord=-1,
                        version=_versions.get(eid, 0),
                    ),
                );
                fresh_edges[eid] = e;
                note_shape(w, kind);
            }
            todo.append(dst);
        }
    }
    for eid in gone {
        (from_id, to_id) = _ends[eid];
        w.gone.append(
            Row(
                id=eid,
                kind="e",
                type_name="",
                data="",
                src=from_id,
                dst=to_id,
                version=_versions[eid],
            ),
        );
    }
    for nid in doomed {
        w.gone.append(Row(id=nid, kind="n", type_name="", data="", version=_versions[nid]));
    }
    for (user, rid) in _new_roots.items() {
        w.roots[user] = rid;
    }
    if len(_new_shared) > 0 {
        w.shared = _new_shared[0];
    }
    for (name, shape) in _new_shapes.items() {
        w.shapes[name] = shape;
    }
    if len(w.rows) + len(w.gone) + len(w.roots) + len(w.shapes) == 0 and w.shared == "" {
        return;
    }
    mark = s.write(w);
    # It is kept: what is here is what the store has.
    for r in w.rows {
        _kept[r.id] = r.data;
        _versions[r.id] = r.version + 1;
        if r.kind == "e" {
            _ends[r.id] = (r.src, r.dst);
            _edges[r.id] = fresh_edges[r.id];
        } else {
            _nodes[r.id] = fresh_nodes[r.id];
        }
    }
    for r in w.gone {
        forget(r.id);
    }
    for (name, shape) in w.shapes.items() {
        _shapes[name] = shape;
    }
    _new_shapes.clear();
    _new_roots.clear();
    _new_shared.clear();
    _removed.clear();
    # A node made here has all its edges here; and each node whose edges are
    # all here has these of them kept now.
    for nid in fresh_nodes {
        if nid not in _edges_at and not rt_awaits_edges(_nodes[nid]) {
            _edges_at[nid] = [];
        }
    }
    for nid in list(_edges_at.keys()) {
        _edges_at[nid] = [eid for eid in edges_here(_nodes[nid]) if eid in _edges];
    }
    if mark == _mark[0] + 1 {
        _mark[0] = mark;
    }
}

"""The rows of type `kind` are written in the shape the program has it in
from this write on, when the store has them in another."""
def note_shape(w: Writing, kind: str) {
    (_s, c) = keeper();
    shape = c.shape(kind);
    if shape != "" and _shapes.get(kind, "") != shape {
        w.shapes[kind] = shape;
    }
}

"""Take in what the store's other users wrote since this program last did:
each row that is here given what was written of it, each that was taken out
taken out here, and each new edge at a node whose edges are all here made
here. Where the store no longer knows that far back, everything here is read
again."""
def take_in {
    (s, c) = keeper();
    mark = s.mark();
    if mark == _mark[0] {
        return;
    }
    got = s.since(_mark[0]);
    since = Changed();
    if got is not None {
        since = got;
    } else {
        held = list(_nodes.keys()) + list(_edges.keys());
        rows = s.rows(held);
        still = {r.id: True for r in rows};
        since = Changed(rows=rows, gone=[i for i in held if i not in still]);
        # (And which edges each node has is asked again as it is reached.)
        for (nid, n) in _nodes.items() {
            if nid in _edges_at {
                del _edges_at[nid];
                rt_await_edges(n);
            }
        }
    }
    for i in since.gone {
        if i in _edges {
            rt_drop_held_edge(_edges[i]);
            for (nid, at) in _edges_at.items() {
                if i in at {
                    at.remove(i);
                }
            }
            forget(i);
        }
    }
    for i in since.gone {
        if i in _nodes {
            n = _nodes[i];
            for into in [False, True] {
                for e in rt_edges_held(n, into) {
                    eid = jid(e);
                    rt_drop_held_edge(e);
                    forget(eid);
                }
            }
            forget(i);
        }
    }
    for r in since.rows {
        if r.kind == "n" {
            if r.id in _nodes and r.version != _versions[r.id] {
                if r.data != _kept[r.id] {
                    data: dict[str, any] = json.loads(r.data);
                    c.fill_node(_nodes[r.id], data);
                    if "__grant" in data {
                        _grants[r.id] = int(data["__grant"]);
                    } elif r.id in _grants {
                        del _grants[r.id];
                    }
                    _kept[r.id] = r.data;
                }
                _versions[r.id] = r.version;
            }
            continue;
        }
        if r.id in _edges {
            if r.version != _versions[r.id] {
                if r.data != _kept[r.id] {
                    c.fill_edge(_edges[r.id], json.loads(r.data));
                    _kept[r.id] = r.data;
                }
                _versions[r.id] = r.version;
            }
            continue;
        }
        if r.src in _edges_at or r.dst in _edges_at {
            bring_nodes([r.src, r.dst]);
            if r.src in _nodes and r.dst in _nodes {
                take_edge(r);
                for end in [r.src, r.dst] {
                    if end in _edges_at and r.id not in _edges_at[end] {
                        _edges_at[end].append(r.id);
                    }
                }
            }
        }
    }
    _mark[0] = mark;
    adopt_shared();
}

"""The shared root is the one the store has, when another program gave it one
before this program's own was written."""
def adopt_shared {
    s = _store;
    if s is None or len(_new_shared) == 0 {
        return;
    }
    kept = node_kept(s.shared_root());
    if kept is not None {
        _new_shared.clear();
        rt_set_shared_root(kept as Root);
    }
}

"""Put what is here back as the store had it when it was read, after a write
the store refused (`e`): each kept node and edge given the fields it was
read with, each edge made since taken out, and each node that lost a kept
edge left to bring its edges again. A root made here for a user who has one
by now is let go: the call runs again from theirs."""
def put_back(e: StoreConflict) {
    (s, c) = keeper();
    for (nid, n) in _nodes.items() {
        if node_text(n, nid) != _kept[nid] {
            data: dict[str, any] = json.loads(_kept[nid]);
            c.fill_node(n, data);
            if "__grant" in data {
                _grants[nid] = int(data["__grant"]);
            } elif nid in _grants {
                del _grants[nid];
            }
        }
    }
    for (eid, link) in _edges.items() {
        if json.dumps(c.edge_data(link)) != _kept[eid] {
            c.fill_edge(link, json.loads(_kept[eid]));
        }
    }
    for (nid, n) in list(_nodes.items()) {
        for into in [False, True] {
            for link in rt_edges_held(n, into) {
                if jid(link) not in _edges {
                    rt_drop_held_edge(link);
                }
            }
        }
        if nid in _edges_at {
            now = edges_here(n);
            for eid in _edges_at[nid] {
                if eid not in now {
                    del _edges_at[nid];
                    rt_await_edges(n);
                    break;
                }
            }
        }
    }
    _removed.clear();
    for (user, rid) in list(_new_roots.items()) {
        if s.root_of(user) != "" {
            del _new_roots[user];
            del _user_roots[user];
            if rid in _roots {
                del _roots[rid];
            }
        }
    }
    adopt_shared();
}
