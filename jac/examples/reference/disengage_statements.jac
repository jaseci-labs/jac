# Disengage Statements

node Person {
    has name: str;
}

# Basic disengage
walker BasicDisengage {
    can start with `root entry {
        print("starting");
        visit [-->];
    }

    can visit_person with Person entry {
        print(f"at {here.name}");
        if here.name == "Bob" {
            print("found Bob, disengaging");
            disengage;
        }
        visit [-->];
    }
}

# Disengage vs continue traversal
walker ConditionalDisengage {
    has max_visits: int = 2;
    has visit_count: int = 0;

    can start with `root entry {
        visit [-->];
    }

    can count_visits with Person entry {
        self.visit_count += 1;
        print(f"visit {self.visit_count}: {here.name}");
        if self.visit_count >= self.max_visits {
            print("max visits reached, disengaging");
            disengage;
        }
        visit [-->];
    }
}

# Disengage in walker ability
walker SearchWalker {
    has target_name: str;
    has found: bool = False;

    can search with `root entry {
        visit [-->];
    }

    can check with Person entry {
        print(f"checking {here.name}");
        if here.name == self.target_name {
            print(f"found {here.name}!");
            self.found = True;
            disengage;
        }
        visit [-->];
    }
}

with entry {
    # Build graph
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    charlie = Person(name="Charlie");
    diana = Person(name="Diana");

    root ++> alice;
    alice ++> bob;
    alice ++> charlie;
    bob ++> diana;

    print("=== Basic Disengage ===");
    root spawn BasicDisengage();

    print("\n=== Conditional Disengage ===");
    root spawn ConditionalDisengage();

    print("\n=== Search Walker ===");
    w = root spawn SearchWalker(target_name="Charlie");
    print(f"found: {w.found}");
}
