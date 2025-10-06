# Visit Statements

node Person {
    has name: str;
}

# Basic visit statement
walker BasicVisitor {
    can start with `root entry {
        print("visiting outgoing");
        visit [-->];
    }

    can visit_person with Person entry {
        print(f"at {here.name}");
    }
}

# Visit with else clause
walker VisitWithElse {
    can start with `root entry {
        print("visiting with else");
        visit [-->] else {
            print("no outgoing edges");
        }
    }

    can visit_person with Person entry {
        print(f"at {here.name}");
        visit [-->] else {
            print("leaf node");
        }
    }
}

# Visit specific node expression
walker DirectVisit {
    has target: Person;

    can start with `root entry {
        print("direct visit to target");
        visit self.target;
    }

    can at_target with Person entry {
        print(f"arrived at {here.name}");
        disengage;
    }
}

# Visit with typed edge filter
edge Friend {}

walker TypedVisit {
    can start with Person entry {
        print(f"at {here.name}, visiting Friend edges");
        visit [->:Friend:->];
    }
}

# Visit with edge attribute filter
edge Colleague {
    has strength: int;
}

walker FilteredVisit {
    can start with Person entry {
        print(f"visiting strong colleagues from {here.name}");
        visit [->:Colleague:strength > 5:->];
    }
}

# Multiple visit statements
walker MultiVisit {
    can start with `root entry {
        print("first visit");
        visit [-->];
    }

    can continue_visit with Person entry {
        print(f"at {here.name}");
        print("second visit");
        visit [-->];
    }
}

with entry {
    # Build graph
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    charlie = Person(name="Charlie");

    root ++> alice;
    alice ++> bob;
    alice ++> charlie;
    alice +>:Friend:+> bob;
    alice +>:Colleague(strength=7):+> charlie;

    print("=== Basic Visit ===");
    root spawn BasicVisitor();

    print("\n=== Visit with Else ===");
    root spawn VisitWithElse();

    print("\n=== Direct Visit ===");
    root spawn DirectVisit(target=charlie);

    print("\n=== Typed Visit ===");
    alice spawn TypedVisit();

    print("\n=== Filtered Visit ===");
    alice spawn FilteredVisit();

    print("\n=== Multi Visit ===");
    root spawn MultiVisit();
}
