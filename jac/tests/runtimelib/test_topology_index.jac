"""Unit tests for the TopologyIndex data structure."""

import from uuid { uuid4, UUID }
import from jaclang.runtimelib.topology_index { TopologyIndex }

# ── Encoding ─────────────────────────────────────────────────────────
test "encode decode round trip" {
    idx = TopologyIndex();
    root_id = uuid4();
    n1 = uuid4();
    n2 = uuid4();
    idx.add_node(root_id, "Root");
    idx.add_node(n1, "NodeA");
    idx.add_node(n2, "NodeB");
    idx.add_edge(root_id, n1, "EdgeX");
    idx.add_edge(n1, n2, "EdgeY");

    decoded = TopologyIndex.decode(idx.encode());

    assert decoded.type_table == ["Root", "NodeA", "NodeB", "EdgeX", "EdgeY"];
    assert len(decoded.node_table) == 3;
    assert len(decoded.adj_list) == 2;
}

test "cross root preserved through encoding" {
    idx = TopologyIndex();
    foreign_root = uuid4();
    n1 = uuid4();
    idx.add_node(uuid4(), "Root");
    idx.add_node(n1, "NodeA", owner_root=foreign_root);

    decoded = TopologyIndex.decode(idx.encode());
    assert decoded.node_table[1][2] == foreign_root;
}

test "large graph under 1MB" {
    idx = TopologyIndex();
    node_ids = [uuid4() for _ in range(10000)];
    types = ["TypeA", "TypeB", "TypeC", "TypeD", "TypeE"];
    for (i, nid) in enumerate(node_ids) {
        idx.add_node(nid, types[i % len(types)]);
    }
    for i in range(50000) {
        idx.add_edge(node_ids[i % 10000], node_ids[(i * 7 + 3) % 10000], "Edge");
    }
    data = idx.encode();
    assert len(data) < 1000000;
    decoded = TopologyIndex.decode(data);
    assert len(decoded.node_table) == 10000;
    assert len(decoded.adj_list) == 50000;
}

test "unknown version returns empty index" {
    decoded = TopologyIndex.decode(bytes.fromhex("99000000000000000000"));
    assert len(decoded) == 0;
}

# ── Mutation ─────────────────────────────────────────────────────────
test "add node idempotent" {
    idx = TopologyIndex();
    nid = uuid4();
    assert idx.add_node(nid, "A") == idx.add_node(nid, "A");
    assert len(idx.node_table) == 1;
}

test "remove node removes its edges" {
    idx = TopologyIndex();
    n1 = uuid4();
    n2 = uuid4();
    n3 = uuid4();
    idx.add_node(n1, "A");
    idx.add_node(n2, "B");
    idx.add_node(n3, "C");
    idx.add_edge(n1, n2, "E");
    idx.add_edge(n2, n3, "E");
    idx.add_edge(n1, n3, "E");
    idx.remove_node(n2);
    assert len(idx.adj_list) == 1;
}

test "remove edge by type" {
    idx = TopologyIndex();
    n1 = uuid4();
    n2 = uuid4();
    idx.add_node(n1, "A");
    idx.add_node(n2, "B");
    idx.add_edge(n1, n2, "EdgeX");
    idx.add_edge(n1, n2, "EdgeY");
    idx.remove_edge(n1, n2, "EdgeX");
    assert len(idx.adj_list) == 1;
    assert idx.type_table[idx.adj_list[0][1]] == "EdgeY";
}

# ── Query ────────────────────────────────────────────────────────────
def build_fan_graph -> tuple[TopologyIndex, UUID, list[UUID], list[UUID]] {
    idx = TopologyIndex();
    r = uuid4();
    idx.add_node(r, "Root");
    a_ids: list[UUID] = [];
    b_ids: list[UUID] = [];
    for i in range(100) {
        nid = uuid4();
        if i < 10 {
            idx.add_node(nid, "NodeA");
            a_ids.append(nid);
        } else {
            idx.add_node(nid, "NodeB");
            b_ids.append(nid);
        }
        idx.add_edge(r, nid, "EdgeX");
    }
    return (idx, r, a_ids, b_ids);
}

test "type filter narrows fanout" {
    (idx, r, a_ids, _) = build_fan_graph();
    assert idx.resolve_chain({r}, [("EdgeX", "NodeA", 2)]) == set(a_ids);
}

test "nonexistent type returns empty" {
    (idx, r, _, _) = build_fan_graph();
    assert idx.resolve_chain({r}, [("EdgeX", "NodeC", 2)]) == set();
}

test "deep chain" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    b = uuid4();
    c = uuid4();
    for (nid, t) in [(r, "Root"), (a, "A"), (b, "B"), (c, "C")] {
        idx.add_node(nid, t);
    }
    idx.add_edge(r, a, "E1");
    idx.add_edge(a, b, "E2");
    idx.add_edge(b, c, "E3");
    assert idx.resolve_chain({r}, [("E1", "A", 2), ("E2", "B", 2), ("E3", "C", 2)]) == {c};
}

test "multi hop selective" {
    idx = TopologyIndex();
    r = uuid4();
    idx.add_node(r, "Root");
    a_ids: list[UUID] = [];
    b_ids: list[UUID] = [];
    for i in range(100) {
        a = uuid4();
        idx.add_node(a, "NodeA");
        idx.add_edge(r, a, "E1");
        a_ids.append(a);
    }
    for i in range(5) {
        b = uuid4();
        idx.add_node(b, "NodeB");
        idx.add_edge(a_ids[i], b, "E2");
        b_ids.append(b);
    }
    assert idx.resolve_chain({r}, [("E1", "NodeA", 2), ("E2", "NodeB", 2)]) == set(
        b_ids
    );
}

test "cross root ids" {
    idx = TopologyIndex();
    foreign = uuid4();
    n1 = uuid4();
    n2 = uuid4();
    idx.add_node(uuid4(), "Root");
    idx.add_node(n1, "A");
    idx.add_node(n2, "B", owner_root=foreign);
    cross = idx.get_cross_root_ids({n1,n2});
    assert cross[foreign] == {n2};
    assert n1 not in cross.get(foreign, set());
}

# ── MRO fan-out ──────────────────────────────────────────────────────
test "subtype query returns instances of all descendants" {
    idx = TopologyIndex();
    r = uuid4();
    post = uuid4();
    article = uuid4();
    idx.add_node(r, "Root", ["Root"]);
    idx.add_node(post, "PostNode", ["PostNode", "BaseContent"]);
    idx.add_node(article, "ArticleNode", ["ArticleNode", "BaseContent"]);
    idx.add_edge(r, post, "Authored");
    idx.add_edge(r, article, "Authored");
    # Query by parent type — both subtypes match.
    assert idx.resolve_chain({r}, [(None, "BaseContent", 2)]) == {post,article};
    # Query by concrete subtype — only that subtype matches.
    assert idx.resolve_chain({r}, [(None, "PostNode", 2)]) == {post};
}

test "MRO fan-out survives encode decode" {
    idx = TopologyIndex();
    r = uuid4();
    post = uuid4();
    idx.add_node(r, "Root", ["Root"]);
    idx.add_node(post, "PostNode", ["PostNode", "BaseContent"]);
    idx.add_edge(r, post, "Authored");
    decoded = TopologyIndex.decode(idx.encode());
    assert decoded.resolve_chain({r}, [(None, "BaseContent", 2)]) == {post};
    assert decoded.resolve_chain({r}, [(None, "PostNode", 2)]) == {post};
}

# ── Multi-edge between same pair ─────────────────────────────────────
test "multi-edge between same pair preserves edge-type isolation" {
    # Two edges of different types between the same pair must not collide
    # in the lookup map: removing one edge type must leave the other
    # discoverable via both its e: column and the n: column.
    idx = TopologyIndex();
    a = uuid4();
    b = uuid4();
    idx.add_node(a, "A");
    idx.add_node(b, "B");
    idx.add_edge(a, b, "Follow");
    idx.add_edge(a, b, "Like");

    assert idx.resolve_chain({a}, [("Follow", None, 2)]) == {b};
    assert idx.resolve_chain({a}, [("Like", None, 2)]) == {b};
    # IN direction sees the same connectivity from b's bucket.
    assert idx.resolve_chain({b}, [("Follow", None, 1)]) == {a};
    assert idx.resolve_chain({b}, [("Like", None, 1)]) == {a};

    idx.remove_edge(a, b, "Like");
    # Like is gone; Follow remains.
    assert idx.resolve_chain({a}, [("Follow", None, 2)]) == {b};
    assert idx.resolve_chain({a}, [("Like", None, 2)]) == set();
    # n: column for B is still populated because Follow still connects (a, b).
    assert idx.resolve_chain({a}, [(None, "B", 2)]) == {b};
    # ANY direction still finds the connection.
    assert idx.resolve_chain({a}, [(None, None, 3)]) == {b};

    idx.remove_edge(a, b, "Follow");
    # Now everything is gone — n: column too.
    assert idx.resolve_chain({a}, [(None, "B", 2)]) == set();
}

# ── v1 → v2 migration ────────────────────────────────────────────────
test "v1 blob migrates to v2 on decode and warms up MRO via mutation" {
    # Construct a v1 blob by hand: 3 types, 2 nodes, 1 edge.
    import struct;

    root_id = uuid4();
    child_id = uuid4();
    self_root = UUID(int=0);

    blob = bytearray();
    # Header (v1): version=1, num_types=3, num_nodes=2, num_edges=1
    blob.extend(struct.pack("<BHHi", 1, 3, 2, 1));
    # TypeTable (v1: just name_len + name, no MRO chain)
    for name in [b"Root", b"NodeA", b"EdgeX"] {
        blob.append(len(name));
        blob.extend(name);
    }
    # NodeTable: (uuid, type_id, owner_root)
    blob.extend(root_id.bytes);
    blob.extend(struct.pack("<H", 0));
    blob.extend(self_root.bytes);
    blob.extend(child_id.bytes);
    blob.extend(struct.pack("<H", 1));
    blob.extend(self_root.bytes);
    # AdjList: (src_lid, edge_type_id, tgt_lid)
    blob.extend(struct.pack("<HHH", 0, 2, 1));

    idx = TopologyIndex.decode(bytes(blob));

    # All persisted data made it across.
    assert len(idx.adj_list) == 1;
    assert len(idx.node_table) == 2;
    assert idx.type_table == ["Root", "NodeA", "EdgeX"];
    # Migration installed stub MRO chains: each type is its own ancestor.
    assert idx.type_mro_ids == [[0], [1], [2]];

    # Concrete-type queries work immediately on the migrated index.
    assert idx.resolve_chain({root_id}, [(None, "NodeA", 2)]) == {child_id};
    assert idx.resolve_chain({root_id}, [("EdgeX", "NodeA", 2)]) == {child_id};

    # Adding a new node with a real MRO chain warms up subtype queries for
    # that type. The widen-the-check logic in _ensure_type lets the longer
    # chain replace the migration stub.
    new_child = uuid4();
    idx.add_node(new_child, "PostNode", ["PostNode", "BaseContent"]);
    idx.add_edge(root_id, new_child, "EdgeX");
    assert idx.resolve_chain({root_id}, [(None, "BaseContent", 2)]) == {new_child};
    assert idx.resolve_chain({root_id}, [(None, "PostNode", 2)]) == {new_child};

    # Re-encoding the migrated index produces a v2 blob that round-trips.
    re_decoded = TopologyIndex.decode(idx.encode());
    assert re_decoded.resolve_chain({root_id}, [(None, "BaseContent", 2)]) == {new_child};
}

# ── Compact-encoding fidelity ────────────────────────────────────────
test "encoded size beats naive bound" {
    # Same shape as the 1MB test, but tighten the budget. Per-edge target is
    # ~6 bytes plus a small node + type table overhead.
    idx = TopologyIndex();
    node_ids = [uuid4() for _ in range(1000)];
    for (i, nid) in enumerate(node_ids) {
        idx.add_node(nid, "T" + str(i % 5));
    }
    for i in range(5000) {
        idx.add_edge(node_ids[i % 1000], node_ids[(i * 7 + 3) % 1000], "Edge");
    }
    # 1000 nodes × 34B = 34000; 5000 edges × 6B = 30000; type table tiny.
    # Generous ceiling: 80KB.
    assert len(idx.encode()) < 80000;
}
