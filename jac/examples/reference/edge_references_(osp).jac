"""Edge references (OSP): Edge reference expressions for graph queries."""

# ===== Node and Edge Definitions =====
node Person {
    has name: str;
}

edge Friend {
    has since: int = 2020;
}

edge Colleague {
    has years: int = 0;
}

# ===== Walker Demonstrating Edge References =====
walker EdgeRefWalker {
    can demonstrate with `root entry {
        print("=== 1. Basic Edge References ===\n");

        # Build simple graph
        alice = Person(name="Alice");
        bob = Person(name="Bob");
        charlie = Person(name="Charlie");

        root ++> alice;
        alice +>: Friend(since=2015) :+> bob;
        alice +>: Colleague(years=3) :+> charlie;

        # Basic outgoing edge reference [-->]
        print("From root:");
        out_from_root = [-->];
        print(f"  [-->] found {len(out_from_root)} outgoing nodes");
        for n in out_from_root {
            print(f"    - {n.name}");
        }

        # Move to Alice to demonstrate more
        visit [-->];
    }

    can show_refs with Person entry {
        if here.name == "Alice" {
            print(f"\n=== 2. Edge References from {here.name} ===\n");
            # Outgoing [-->]
            outgoing = [-->];
            print(f"Outgoing [-->]: {len(outgoing)} nodes");
            for n in outgoing {
                print(f"  - {n.name}");
            }
            # Incoming [<--]
            incoming = [<--];
            print(f"\nIncoming [<--]: {len(incoming)} nodes");
            # Bidirectional [<-->]
            both = [<-->];
            print(f"\nBidirectional [<-->]: {len(both)} nodes");
            print("\n=== 3. Typed Edge References ===\n");
            # Typed outgoing [->:Type:->]
            friends = [->:Friend:->];
            print(f"Friend edges [->:Friend:->]: {len(friends)} nodes");
            for n in friends {
                print(f"  - {n.name}");
            }
            colleagues = [->:Colleague:->];
            print(f"Colleague edges [->:Colleague:->]: {len(colleagues)} nodes");
            for n in colleagues {
                print(f"  - {n.name}");
            }
            print("\n=== 4. Filtered Edge References ===\n");
            # Filter on edge attributes
            old_friends = [->:Friend:since<2018:->];
            print(f"Friends since before 2018: {len(old_friends)} nodes");
            experienced_colleagues = [->:Colleague:years>2:->];
            print(f"Colleagues with years > 2: {len(experienced_colleagues)} nodes");
            # Multiple filter conditions
            specific = [->:Colleague:years>=1,years<=5:->];
            print(f"Colleagues with 1-5 years: {len(specific)} nodes");
            print("\n=== 5. Edge and Node Keywords ===\n");
            # Get edge objects [edge -->]
            edge_objs = [edge -->];
            print(f"[edge -->]: Retrieved {len(edge_objs)} edge objects");
            # Get node objects [node -->] (explicit)
            node_objs = [node -->];
            print(f"[node -->]: Retrieved {len(node_objs)} node objects");
            print("\n=== 6. Chained Edge References ===\n");
            # Chained edge references - multiple hops in one expression
            # Syntax: [node ->:Type1:-> ->:Type2:->]
            # This traverses Type1 edges, then Type2 edges from those nodes

            # Build deeper graph for chaining demo
            david = Person(name="David");
            # Get bob from outgoing Friend edges
            bob_list = [here->:Friend:->];
            if bob_list {
                bob_list[0] +>: Friend(since=2018) :+> david;
            }
            # Two-hop chain: Friend -> Friend
            two_hop = [here->:Friend:->->:Friend:->];
            print(
                f"[here ->:Friend:-> ->:Friend:->]: {len(two_hop)} nodes (2 hops via Friend)"
            );
            # Mixed type chain: Friend -> Colleague
            # This goes through Friend edges, then Colleague edges from those nodes
            mixed = [here->:Friend:->->:Colleague:->];
            print(
                f"[here ->:Friend:-> ->:Colleague:->]: {len(mixed)} nodes (Friend then Colleague)"
            );
            # Can chain many hops
            print("Can chain multiple: [node ->:T1:-> ->:T2:-> ->:T3:->]");
            print("\n=== 7. Edge References in Different Contexts ===\n");
            # In assignment
            targets = [-->];
            print(f"Assignment: targets = [-->] → {len(targets)} nodes");
            # In if condition
            if [-->] {
                print("Conditional: if [-->] → edges exist!");
            }
            # In for loop
            print("For loop:");
            for person in [-->] {
                print(f"  Iterating: {person.name}");
            }
            # In visit statement (most common)
            print("\nVisit statement: visit [->:Friend:->]");  # visit [->:Friend:->];  # Would visit friends
        }

        disengage;
    }
}

# ===== Summary Walker =====
walker Summary {
    can show with `root entry {
        print("\n" + "=" * 50);
        print("EDGE REFERENCE SYNTAX SUMMARY");
        print("=" * 50);

        print("\n** Basic Forms **");
        print("  [-->]           All outgoing edges");
        print("  [<--]           All incoming edges");
        print("  [<-->]          Bidirectional (both ways)");

        print("\n** Typed Forms **");
        print("  [->:Type:->]    Outgoing of specific type");
        print("  [<-:Type:<-]    Incoming of specific type");
        print("  [<-:Type:->]    Bidirectional of specific type");

        print("\n** Filtered Forms **");
        print("  [->:Type:attr > val:->]       Filter on edge attribute");
        print("  [->:Type:a > x, b < y:->]     Multiple conditions");

        print("\n** Special Forms **");
        print("  [edge -->]                    Get edge objects");
        print("  [node -->]                    Get node objects (explicit)");
        print("  [node ->:T1:-> ->:T2:->]      Chained (multi-hop)");

        print("\n** Common Usage **");
        print("  visit [-->];                  Visit all outgoing");
        print("  for n in [-->] { ... }        Iterate over nodes");
        print("  if [-->] { ... }              Check if edges exist");
        print("  targets = [->:Type:->];       Store in variable");

        print("\n" + "=" * 50);
    }
}

# ===== Execution =====
with entry {
    print("=== Object Spatial References Demo ===\n");
    root spawn EdgeRefWalker();
    root spawn Summary();
    print("\n✓ Edge reference variations demonstrated!");
}
