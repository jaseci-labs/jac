edge Follow {}
edge CloseFriend(Follow) {}
node Person { has name: str; }
node VIPPerson(Person) { has tier: str = "gold"; }

with entry {
    # Build graph
    p1 = Person(name="Alice");
    p2 = VIPPerson(name="Bob");
    root +>: Follow :+> p1;
    root +>: CloseFriend :+> p2;

    # Test 1: Without stubs (should work regardless)
    print("=== WITHOUT STUBS ===");
    result1 = [root->:Follow:->];
    print(f"Follow filter: {len(result1)} nodes (expected: 2)");
    for n in result1 { print(f"  - {n.name}"); }

    # Convert to stubs
    root_anch = root.__jac__;
    orig_edges = list(root_anch.edges);
    stub_edges = [e.make_stub() for e in orig_edges];
    root_anch.edges = stub_edges;

    # Test 2: With stubs - this is where inheritance matters
    print("\n=== WITH STUBS (INHERITANCE TEST) ===");
    result2 = [root->:Follow:->];
    print(f"Follow filter: {len(result2)} nodes (expected: 2)");
    for n in result2 { print(f"  - {n.name}"); }

    if len(result2) == 2 {
        print("\n✓ INHERITANCE WORKING: CloseFriend edges match Follow filter!");
    } else {
        print("\n✗ INHERITANCE BROKEN: CloseFriend edges NOT matching Follow filter!");
    }
}
