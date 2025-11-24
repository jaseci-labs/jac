"""Connect expressions (OSP): Graph edge creation and connection operators."""

# ===== Node and Edge Definitions =====
node Person {
    has name: str;
    has age: int = 0;
}

node City {
    has name: str;
}

edge LivesIn {
    has years: int = 0;
}

edge Friend {
    has since: int = 2020;
}

edge Colleague {
    has department: str;
}

# ===== Test Walker =====
walker GraphBuilder {
    can build with `root entry {
        print("=== 1. Untyped Connect Operators ===");
        # Forward (++>), Backward (<++), Bidirectional (<++>)
        alice = Person(name="Alice", age=30);
        bob = Person(name="Bob", age=25);
        charlie = Person(name="Charlie", age=28);

        alice ++> bob;  # Forward: alice -> bob
        print(f"Forward: {alice.name} ++> {bob.name}");

        bob <++ charlie;  # Backward: charlie -> bob
        print(f"Backward: {bob.name} <++ {charlie.name} (edge from Charlie to Bob)");

        alice <++> charlie;  # Bidirectional: alice <-> charlie
        print(f"Bidirectional: {alice.name} <++> {charlie.name} (both directions)");

        print("\n=== 2. Typed Connect Operators ===");
        # Forward (+>:Type:+>), Backward (<+:Type:<+), Bidirectional (<+:Type:+>)
        diana = Person(name="Diana", age=32);
        eve = Person(name="Eve", age=27);
        frank = Person(name="Frank", age=29);
        nyc = City(name="New York");
        london = City(name="London");

        diana +>:LivesIn:+> nyc;  # Typed forward
        print(f"Typed forward: {diana.name} +>:LivesIn:+> {nyc.name}");

        eve <+:LivesIn:<+ london;  # Typed backward: london -> eve
        print(f"Typed backward: {eve.name} <+:LivesIn:<+ {london.name} (edge from London to Eve)");

        diana <+:Friend:+> eve;  # Typed bidirectional
        print(f"Typed bidirectional: {diana.name} <+:Friend:+> {eve.name}");

        print("\n=== 3. Edge Attribute Initialization ===");
        # Initialize edge attributes during connect (all directions)
        grace = Person(name="Grace", age=26);
        henry = Person(name="Henry", age=31);
        iris = Person(name="Iris", age=24);

        grace +>: Friend(since=2015) :+> henry;  # Forward with attributes
        print(f"Forward with attrs: {grace.name} +>: Friend(since=2015) :+> {henry.name}");

        henry <+: Friend(since=2018) :<+ iris;  # Backward with attributes
        print(f"Backward with attrs: {henry.name} <+: Friend(since=2018) :<+ {iris.name}");

        grace <+: Colleague(department="Engineering") :+> iris;  # Bidirectional with attributes
        print(f"Bidirectional with attrs: {grace.name} <+: Colleague(department='Engineering') :+> {iris.name}");

        print("\n=== 4. Chained Connections ===");
        # Multiple connects in one expression
        jack = Person(name="Jack", age=35);
        kate = Person(name="Kate", age=29);
        liam = Person(name="Liam", age=30);
        mike = Person(name="Mike", age=33);

        jack ++> kate ++> liam ++> mike;  # Chain of connections
        print(f"Chain: {jack.name} ++> {kate.name} ++> {liam.name} ++> {mike.name}");

        print("\n=== 5. Inline Node Creation ===");
        # Create nodes inline within connect expression
        nina = Person(name="Nina", age=28);

        nina ++> Person(name="InlineNode1", age=35);  # Untyped with inline
        nina +>:Friend:+> Person(name="InlineNode2", age=40);  # Typed with inline
        nina +>: Friend(since=2010) :+> Person(name="InlineNode3", age=45);  # With attributes
        print("Connected to 3 inline-created nodes (untyped, typed, with attrs)");

        print("\n=== 6. Connect to Multiple Targets ===");
        # One node connecting to multiple targets
        oscar = Person(name="Oscar", age=27);
        paula = Person(name="Paula", age=26);
        quinn = Person(name="Quinn", age=24);

        oscar ++> paula;
        oscar ++> quinn;
        oscar +>:Friend:+> Person(name="Rita", age=30);
        print(f"Connected {oscar.name} to 3 different targets");

        print("\n=== 7. Disconnect Operator ===");
        # Grammar: disconnect_op: KW_DELETE edge_op_ref
        # Syntax: node del [-->] target
        print("Disconnect syntax: node del [-->] target (deletes edges from node to target)");

        print("\n=== 8. Connect in Expressions ===");
        # Connect expressions return values and can be used in larger expressions
        steve = Person(name="Steve", age=45);
        tina = Person(name="Tina", age=42);

        steve ++> tina;
        print(f"Connect used in expression: {steve.name} ++> {tina.name}");

        print("\n✓ All connect expression features demonstrated!");
        disengage;
    }
}

# ===== Edge Traversal Demonstration =====
walker EdgeTraverser {
    can traverse_root with `root entry {
        print("\n=== Edge Traversal with Visit ===");

        # Build a small graph demonstrating typed edges
        a = Person(name="A", age=25);
        b = Person(name="B", age=30);
        c = Person(name="C", age=35);

        root ++> a;
        a +>: Friend(since=2010) :+> b;
        a +>: Colleague(department="Sales") :+> c;
        b +>: Friend(since=2015) :+> c;

        print("Graph: root->A, A-Friend->B, A-Colleague->C, B-Friend->C");
        print("Visiting all outgoing edges from root:");
        visit [-->];
    }

    can traverse_person with Person entry {
        print(f"  Visited: {here.name}, age={here.age}");
    }
}

# ===== Execution =====
with entry {
    root spawn GraphBuilder();
    root spawn EdgeTraverser();
}
