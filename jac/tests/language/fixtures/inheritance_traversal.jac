"""Test that type-filtered traversals respect inheritance on STUBS.

The short-circuit optimization stores arch_cls as a frozenset[TypeRef]
representing the full MRO chain on stub anchors and checks membership.
This allows inheritance: a CloseFriend stub (arch_cls contains both
CloseFriend and Follow TypeRefs) is accepted when the filter asks for Follow.

This test converts edge anchors to stubs (simulating un-populated storage
state) and verifies that filtering by a *base* type still returns edges
whose concrete type is a *subclass* of that base.

Uses root (persistent) so that edges are registered in TieredMemory and
stubs can populate() when the type filter matches.
"""

import from jaclang.jac0core.constructs { clear_typeref_registry }

# Clear the TypeRef registry to prevent false-positive collisions from
# other test fixtures that may have registered types under __main__.
with entry {
    clear_typeref_registry();
}

# ── Base and derived edge types ──────────────────────────────────────────────
edge Follow {}
edge CloseFriend(Follow) {}
# ── Base and derived node types ──────────────────────────────────────────────
node Person {
    has name: str;
}
node VIPPerson(Person) {
    has tier: str = "gold";
}

# ── All logic in a single entry block to avoid glob-induced extra edges ──────
with entry {
    # Build graph:
    #   root --Follow------> p1(Person, "Alice")
    #   root --CloseFriend-> p2(VIPPerson, "Bob")
    p1 = Person(name="Alice");
    p2 = VIPPerson(name="Bob");
    root +>: Follow :+> p1;
    root +>: CloseFriend :+> p2;

    # Grab root anchor and verify edges.
    root_anch = root.__jac__;
    print("TOTAL_EDGES", len(root_anch.edges));
    assert len(root_anch.edges) == 2 , f"Expected 2 edges on root, got {len(root_anch.edges)}";

    # Save original edges and convert to stubs.
    orig_edges = list(root_anch.edges);

    # ── Test 1: Filter by base edge type Follow on stubs ─────────────────
    stub_edges_1 = [e.make_stub() for e in orig_edges];
    for s in stub_edges_1 {
        assert 'arch_cls' in s.__dict__ , "Stub must have arch_cls in __dict__";
    }
    root_anch.edges = stub_edges_1;

    follow_result = [root->:Follow:->];
    print("FOLLOW_EDGE_STUB_COUNT", len(follow_result));

    # Expected: 2 nodes (p1 via Follow, p2 via CloseFriend which IS-A Follow)
    assert len(follow_result) == 2 , f"Expected 2 nodes via Follow filter on stubs (CloseFriend IS-A Follow), got {len(follow_result)}";

    # ── Test 2: Filter by base node type Person on stubs ─────────────────
    stub_edges_2 = [e.make_stub() for e in orig_edges];
    root_anch.edges = stub_edges_2;

    person_result = [root-->(?:Person)];
    print("PERSON_NODE_STUB_COUNT", len(person_result));

    assert len(person_result) == 2 , f"Expected 2 nodes via Person filter on stubs (VIPPerson IS-A Person), got {len(person_result)}";

    # ── Test 3: Derived edge filter should still work correctly ───────────
    stub_edges_3 = [e.make_stub() for e in orig_edges];
    root_anch.edges = stub_edges_3;

    closefriend_result = [root->:CloseFriend:->];
    print("CLOSEFRIEND_EDGE_STUB_COUNT", len(closefriend_result));

    assert len(closefriend_result) == 1 , f"Expected 1 node via CloseFriend filter on stubs, got {len(closefriend_result)}";

    # ── Test 4: Derived node filter should still work correctly ───────────
    stub_edges_4 = [e.make_stub() for e in orig_edges];
    root_anch.edges = stub_edges_4;

    vip_result = [root-->(?:VIPPerson)];
    print("VIP_NODE_STUB_COUNT", len(vip_result));

    assert len(vip_result) == 1 , f"Expected 1 VIPPerson node via filter on stubs, got {len(vip_result)}";

    print("INHERITANCE_STUB_TESTS_PASSED");
}
