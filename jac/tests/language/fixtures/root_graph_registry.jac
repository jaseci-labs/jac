"""Test fixture for Root graph registry CRUD operations."""

node Person {
    has name: str;
}

node City {
    has name: str;
}

edge LivesIn {
    has since: int;
}

edge Knows {}

with entry {
    # --- CREATE ---
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    sf = City(name="San Francisco");

    root ++> alice;
    root ++> bob;
    alice +>: LivesIn(since=2020) :+> sf;
    alice +>: Knows() :+> bob;

    # Check type_registry has all entries
    tr = root.type_registry;
    print("ROOT_IN_REGISTRY:", "Root" in tr.values());
    print("PERSON_COUNT:", list(tr.values()).count("Person"));
    print("CITY_COUNT:", list(tr.values()).count("City"));
    print("LIVESIN_COUNT:", list(tr.values()).count("LivesIn"));
    print("KNOWS_COUNT:", list(tr.values()).count("Knows"));
    print("GENERIC_EDGE_COUNT:", list(tr.values()).count("GenericEdge"));

    # Check edge_index has correct adjacency
    root_neighbors = root.get_neighbors(root.__jac__.id);
    print("ROOT_OUTGOING:", len(root_neighbors));

    alice_neighbors = root.get_neighbors(alice.__jac__.id);
    print("ALICE_OUTGOING:", len(alice_neighbors));

    # --- READ ---
    alice_type = root.get_type_name(alice.__jac__.id);
    sf_type = root.get_type_name(sf.__jac__.id);
    print("ALICE_TYPE:", alice_type);
    print("SF_TYPE:", sf_type);

    # --- DELETE edge (disconnect alice --> bob, removes Knows edge) ---
    initial_registry_size = len(root.type_registry);
    alice del --> bob;
    print("REGISTRY_SHRUNK:", len(root.type_registry) < initial_registry_size);

    # Verify Knows edge removed from edge_index
    alice_neighbors_after = root.get_neighbors(alice.__jac__.id);
    print("ALICE_OUTGOING_AFTER_DEL:", len(alice_neighbors_after));

    # --- DELETE node ---
    bob_id = bob.__jac__.id;
    root del --> bob;
    del [bob];
    print("BOB_UNREGISTERED:", root.get_type_name(bob_id) is None);

    print("DONE");
}
