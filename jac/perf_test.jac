import time;

edge Follow {}
edge CloseFriend(Follow) {}
edge BestFriend(CloseFriend) {}
node Person { has name: str; }

with entry {
    # Create many edges to test performance
    nodes = [];
    for i in range(100) {
        n = Person(name=f"Person{i}");
        nodes.append(n);
        if i % 3 == 0 {
            root +>: Follow :+> n;
        } elif i % 3 == 1 {
            root +>: CloseFriend :+> n;
        } else {
            root +>: BestFriend :+> n;
        }
    }

    # Convert to stubs
    root_anch = root.__jac__;
    orig_edges = list(root_anch.edges);
    stub_edges = [e.make_stub() for e in orig_edges];
    root_anch.edges = stub_edges;

    # Test performance
    start = time.time();
    result = [root->:Follow:->];
    elapsed = time.time() - start;

    print(f"Traversed {len(root_anch.edges)} stub edges");
    print(f"Found {len(result)} nodes matching Follow (including subclasses)");
    print(f"Time taken: {elapsed:.4f} seconds");

    # Verify correctness
    expected = 100;  # All edges should match due to inheritance
    if len(result) == expected {
        print("✓ Inheritance working correctly!");
    } else {
        print(f"✗ Expected {expected} nodes, got {len(result)}");
    }
}
