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
    decoded = TopologyIndex.decode(b"\x99\x00\x00\x00\x00\x00\x00\x00\x00");
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
