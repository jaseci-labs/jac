"""Unit tests for the SAM TopologyIndex data structure."""

import from uuid { uuid4, UUID }
import from jaclang.runtimelib.topology_index { TopologyIndex }

# ── Basic SAM operations ─────────────────────────────────────────────
test "add edge and query by node type" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    idx.add_edge(r, n1, ["NodeA"], "EdgeX", ["Root"]);
    result = idx.query_targets(r, node_type="NodeA");
    assert result == {n1};
}

test "add edge and query by edge type" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    idx.add_edge(r, n1, ["NodeA"], "EdgeX", ["Root"]);
    result = idx.query_targets(r, edge_type="EdgeX");
    assert result == {n1};
}

test "combined node + edge type query" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    n2 = uuid4();
    idx.add_edge(r, n1, ["NodeA"], "EdgeX", ["Root"]);
    idx.add_edge(r, n2, ["NodeA"], "EdgeY", ["Root"]);
    result = idx.query_targets(r, node_type="NodeA", edge_type="EdgeX");
    assert result == {n1};
}

test "nonexistent type returns empty" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    idx.add_edge(r, n1, ["NodeA"], "EdgeX", ["Root"]);
    assert idx.query_targets(r, node_type="NodeB") == set();
    assert idx.query_targets(r, edge_type="EdgeZ") == set();
}

test "remove edge clears target from all columns" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    idx.add_edge(r, n1, ["NodeA", "Base"], "EdgeX", ["Root"]);
    assert idx.query_targets(r, node_type="Base") == {n1};
    idx.remove_edge(r, n1);
    assert idx.query_targets(r, node_type="NodeA") == set();
    assert idx.query_targets(r, node_type="Base") == set();
    assert idx.query_targets(r, edge_type="EdgeX") == set();
}

test "remove node drops all references" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    n2 = uuid4();
    idx.add_edge(r, n1, ["A"], "E", ["Root"]);
    idx.add_edge(r, n2, ["B"], "E", ["Root"]);
    idx.add_edge(n1, n2, ["B"], "E", ["A"]);
    idx.remove_node(n1);
    assert idx.query_targets(r, node_type="A") == set();
    assert idx.query_targets(r, node_type="B") == {n2};
}

# ── MRO / Inheritance ────────────────────────────────────────────────
test "mro fan-out indexes parent type" {
    idx = TopologyIndex();
    r = uuid4();
    p1 = uuid4();
    p2 = uuid4();
    c1 = uuid4();
    idx.add_edge(r, p1, ["PostNode", "BaseContent"], "E", ["Root"]);
    idx.add_edge(r, p2, ["PostNode", "BaseContent"], "E", ["Root"]);
    idx.add_edge(r, c1, ["CommentNode", "BaseContent"], "E", ["Root"]);

    assert idx.query_targets(r, node_type="PostNode") == {p1,p2};
    assert idx.query_targets(r, node_type="CommentNode") == {c1};
    assert idx.query_targets(r, node_type="BaseContent") == {p1,p2,c1};
}

test "mro fan-out large graph" {
    idx = TopologyIndex();
    r = uuid4();
    post_ids: list[UUID] = [];
    comment_ids: list[UUID] = [];
    other_ids: list[UUID] = [];
    for i in range(100) {
        nid = uuid4();
        if i < 30 {
            idx.add_edge(r, nid, ["PostNode", "BaseContent"], "EdgeX", ["Root"]);
            post_ids.append(nid);
        } elif i < 50 {
            idx.add_edge(r, nid, ["CommentNode", "BaseContent"], "EdgeX", ["Root"]);
            comment_ids.append(nid);
        } else {
            idx.add_edge(r, nid, ["OtherNode"], "EdgeX", ["Root"]);
            other_ids.append(nid);
        }
    }
    base_result = idx.query_targets(r, node_type="BaseContent");
    assert len(base_result) == 50;
    assert base_result == set(post_ids) | set(comment_ids);
    assert len(base_result & set(other_ids)) == 0;
}

# ── Chain resolution ─────────────────────────────────────────────────
test "resolve chain single hop" {
    idx = TopologyIndex();
    r = uuid4();
    a_ids: list[UUID] = [];
    for i in range(100) {
        nid = uuid4();
        if i < 10 {
            idx.add_edge(r, nid, ["NodeA"], "EdgeX", ["Root"]);
            a_ids.append(nid);
        } else {
            idx.add_edge(r, nid, ["NodeB"], "EdgeX", ["Root"]);
        }
    }
    assert idx.resolve_chain({r}, [("EdgeX", "NodeA", 2)]) == set(a_ids);
}

test "resolve chain multi hop" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    b = uuid4();
    c = uuid4();
    idx.add_edge(r, a, ["A"], "E1", ["Root"]);
    idx.add_edge(a, b, ["B"], "E2", ["A"]);
    idx.add_edge(b, c, ["C"], "E3", ["B"]);
    assert idx.resolve_chain({r}, [("E1", "A", 2), ("E2", "B", 2), ("E3", "C", 2)]) == {c};
}

test "resolve chain inheritance" {
    idx = TopologyIndex();
    r = uuid4();
    p = uuid4();
    c = uuid4();
    o = uuid4();
    idx.add_edge(r, p, ["PostNode", "BaseContent"], "E", ["Root"]);
    idx.add_edge(r, c, ["CommentNode", "BaseContent"], "E", ["Root"]);
    idx.add_edge(r, o, ["OtherNode"], "E", ["Root"]);
    assert idx.resolve_chain({r}, [("E", "BaseContent", 2)]) == {p,c};
}

# ── Reverse (IN) queries ────────────────────────────────────────────
test "query sources returns incoming neighbours" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    b = uuid4();
    idx.add_edge(r, a, ["A"], "E", ["Root"]);
    idx.add_edge(b, a, ["A"], "E", ["B"]);
    sources = idx.query_sources(a);
    assert sources == {r,b};
}

test "query sources by node type" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    b = uuid4();
    idx.add_edge(r, a, ["A"], "E", ["Root"]);
    idx.add_edge(b, a, ["A"], "E", ["B"]);
    assert idx.query_sources(a, node_type="Root") == {r};
    assert idx.query_sources(a, node_type="B") == {b};
}

test "resolve chain IN direction" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    b = uuid4();
    idx.add_edge(r, a, ["A"], "E", ["Root"]);
    idx.add_edge(r, b, ["B"], "E", ["Root"]);
    # From a, go IN → should find r
    assert idx.resolve_chain({a}, [(None, None, 1)]) == {r};
    # From a, go IN with edge type E → should find r
    assert idx.resolve_chain({a}, [("E", None, 1)]) == {r};
}

test "remove edge clears reverse entries" {
    idx = TopologyIndex();
    r = uuid4();
    a = uuid4();
    idx.add_edge(r, a, ["A"], "E", ["Root"]);
    assert idx.query_sources(a) == {r};
    idx.remove_edge(r, a);
    assert idx.query_sources(a) == set();
}

# ── Serialization ────────────────────────────────────────────────────
test "encode decode round trip" {
    idx = TopologyIndex();
    r = uuid4();
    n1 = uuid4();
    idx.add_edge(r, n1, ["PostNode", "BaseContent"], "EdgeX", ["Root"]);

    decoded = TopologyIndex.decode(idx.encode());
    assert decoded.query_targets(r, node_type="BaseContent") == {n1};
    assert decoded.query_targets(r, node_type="PostNode") == {n1};
    assert decoded.query_targets(r, edge_type="EdgeX") == {n1};
    assert decoded.query_sources(n1, node_type="Root") == {r};
}

test "cross root ids" {
    idx = TopologyIndex();
    foreign = uuid4();
    n1 = uuid4();
    n2 = uuid4();
    idx.node_owners[str(n2)] = foreign;
    cross = idx.get_cross_root_ids({n1,n2});
    assert cross[foreign] == {n2};
    assert n1 not in cross.get(foreign, set());
}
