"""The graph view walk must render what it can, not 500 on one bad edge, and
must render only what the caller may read.

`collect_node_connections` backs the /graph/data endpoint, the admin portal's
graph and the graph builtin. A node whose edge list cites an anchor that cannot
be loaded in this process (quarantined row, peer service's class in a shared
store, legacy corruption) must be skipped -- raising turns one dangling
reference into a blank graph for the whole app. A node the caller cannot read
must be left out too, along with the edge to it and whatever lies behind it:
the dump is a read, so it answers to the same permission test a walker's
traversal does.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from uuid { UUID, uuid4 }

import from jaclang.runtime.archetype { AccessLevel, EdgeAnchor, GenericEdge, Root }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.graph_utils { collect_node_connections }
import from jaclang.runtime.runtime { JacRuntime }


node Doc {
    has label: str = "";
}


"""An unpopulatable EdgeAnchor stub (its backing row is unreadable/gone)."""
def _dangling_edge_stub -> any {
    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = uuid4();
    return stub;
}


test "collect_node_connections skips an unresolvable edge instead of raising" {
    root_arch: any = Root();
    ranch: any = root_arch.__jac__;
    ranch.edges.append(_dangling_edge_stub());

    visited: set = set();
    connections: set = set();
    edge_ids: set = set();
    collect_node_connections(root_arch, visited, connections, edge_ids);

    assert root_arch in visited;
    assert len(connections) == 0;
}

test "collect_node_connections still returns the resolvable part of the graph" {
    root_arch: any = Root();
    other_arch: any = Root();
    ranch: any = root_arch.__jac__;

    e: any = EdgeAnchor(
        archetype=GenericEdge(),
        source=ranch,
        target=other_arch.__jac__,
        is_undirected=False
    );
    ranch.edges.append(e);
    ranch.edges.append(_dangling_edge_stub());

    visited: set = set();
    connections: set = set();
    edge_ids: set = set();
    collect_node_connections(root_arch, visited, connections, edge_ids);

    assert len(connections) == 1 , (
        f"the healthy edge must survive a dangling sibling entry, "
        f"got {len(connections)} connections"
    );
    assert other_arch in visited;
}


def _ctx(td: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=td, full_target_path=str(Path(td) / "graph_app.jac")
    );
}


def _mk_root(mem: any) -> any {
    anch: any = Root().__jac__;
    anch.persistent = True;
    setattr(anch, "root", anch.id);
    mem.put(anch);
    return anch;
}


"""A persistent Doc owned by `owner`, open to everyone at `public` if given."""
def _doc(mem: any, owner: any, label: str, public: any = None) -> any {
    d: any = Doc(label=label).__jac__;
    d.persistent = True;
    setattr(d, "root", owner.id);
    if public is not None {
        d.own_access().all = public;
    }
    mem.put(d);
    return d;
}


def _link(mem: any, src: any, dst: any) {
    e: any = EdgeAnchor(
        archetype=GenericEdge(), source=src, target=dst, is_undirected=False
    );
    e.persistent = True;
    src.edges.append(e);
    dst.edges.append(e);
    mem.put(e);
}


test "collect_node_connections leaves out what the caller cannot read" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx1 = _ctx(td);
        JacRuntime.exec_ctx = ctx1;
        alice_id: str;
        bob_id: str;
        try {
            alice = _mk_root(ctx1.mem);
            bob = _mk_root(ctx1.mem);
            hub = _doc(ctx1.mem, alice, "alice-hub");
            _link(ctx1.mem, alice, hub);
            _link(ctx1.mem, hub, _doc(ctx1.mem, alice, "alice-own"));
            _link(ctx1.mem, hub, _doc(ctx1.mem, bob, "bob-public", AccessLevel.READ));
            hidden = _doc(ctx1.mem, bob, "bob-private");
            _link(ctx1.mem, hub, hidden);
            _link(ctx1.mem, hidden, _doc(ctx1.mem, alice, "behind-bob-private"));
            _link(ctx1.mem, bob, hub);
            _link(ctx1.mem, bob, _doc(ctx1.mem, bob, "bob-note"));
            ctx1.mem.commit();
            alice_id = str(alice.id);
            bob_id = str(bob.id);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx1.close();
        }
        ctx2 = _ctx(td);
        JacRuntime.exec_ctx = ctx2;
        try {
            ctx2.set_user_root(alice_id);
            root_anchor: any = ctx2.mem.get(UUID(alice_id));
            assert root_anchor is not None;
            root_arch: any = root_anchor.archetype;
            visited: set = set();
            connections: set = set();
            edge_ids: set = set();
            collect_node_connections(root_arch, visited, connections, edge_ids);

            labels = sorted(
                [
                    n.label
                    for n in visited
                    if isinstance(n, Doc)
                ]
            );
            assert labels == ["alice-hub", "alice-own", "bob-public"] , (
                f"alice may read exactly these docs, got {labels}"
            );
            ends = {str(n.__jac__.id) for (_, s, t, _) in connections for n in (s, t)};
            assert bob_id not in ends , (
                "bob's root is not readable to alice, so the edge from it must "
                "not surface its id"
            );
            assert len(connections) == 3 , (
                f"root->hub, hub->alice-own, hub->bob-public; got {len(connections)}"
            );
        } finally {
            JacRuntime.exec_ctx = old;
            ctx2.close();
        }
    }
}
