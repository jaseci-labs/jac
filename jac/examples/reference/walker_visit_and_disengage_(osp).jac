"""Walker visit and disengage (OSP): Graph traversal control with visit and disengage statements."""

node Person {
    has name: str;
}

edge Friend {}

edge Colleague {
    has strength: int;
}

# ========================================
# BASIC VISIT STATEMENTS
# ========================================

# Simple visit to outgoing edges
walker BasicVisitor {
    can start with `root entry {
        print("BasicVisitor: visiting outgoing edges");
        visit [-->];
    }

    can visit_person with Person entry {
        print(f"BasicVisitor: at {here.name}");
    }
}

# ========================================
# VISIT WITH ELSE CLAUSE
# ========================================

# Visit with else handles no edges case
walker VisitWithElse {
    can start with `root entry {
        print("VisitWithElse: visiting with else clause");
        visit [-->] else {
            print("VisitWithElse: no outgoing edges from root");
        }
    }

    can visit_person with Person entry {
        print(f"VisitWithElse: at {here.name}");
        visit [-->] else {
            print(f"VisitWithElse: leaf node - {here.name}");
        }
    }
}

# ========================================
# DIRECT NODE VISIT
# ========================================

# Visit specific node directly
walker DirectVisit {
    has target: Person;

    can start with `root entry {
        print(f"DirectVisit: going directly to target");
        visit self.target;
    }

    can at_target with Person entry {
        print(f"DirectVisit: arrived at {here.name}");
    }
}

# ========================================
# TYPED EDGE VISIT
# ========================================

# Visit only specific edge types
walker TypedVisit {
    can start with Person entry {
        print(f"TypedVisit: at {here.name}, visiting Friend edges only");
        visit [->:Friend:->];
    }

    can visit_friend with Person entry {
        print(f"TypedVisit: visited friend {here.name}");
    }
}

# ========================================
# FILTERED VISIT WITH EDGE ATTRIBUTES
# ========================================

# Visit edges filtered by attributes
walker FilteredVisit {
    can start with Person entry {
        print(f"FilteredVisit: visiting strong colleagues from {here.name}");
        visit [->:Colleague:strength>5:->];
    }

    can visit_colleague with Person entry {
        print(f"FilteredVisit: visited colleague {here.name}");
    }
}

# ========================================
# BASIC DISENGAGE
# ========================================

# Disengage terminates walker immediately
walker BasicDisengage {
    can start with `root entry {
        print("BasicDisengage: starting traversal");
        visit [-->];
    }

    can visit_person with Person entry {
        print(f"BasicDisengage: at {here.name}");
        if here.name == "Bob" {
            print("BasicDisengage: found Bob, disengaging");
            disengage;
        }
        print(f"BasicDisengage: continuing from {here.name}");
        visit [-->];
    }
}

# ========================================
# CONDITIONAL DISENGAGE
# ========================================

# Disengage based on walker state
walker ConditionalDisengage {
    has max_visits: int = 2,
        visit_count: int = 0;

    can start with `root entry {
        print("ConditionalDisengage: starting");
        visit [-->];
    }

    can count_visits with Person entry {
        self.visit_count += 1;
        print(f"ConditionalDisengage: visit {self.visit_count} at {here.name}");
        if self.visit_count >= self.max_visits {
            print("ConditionalDisengage: max visits reached, disengaging");
            disengage;
        }
        visit [-->];
    }
}

# ========================================
# SEARCH WITH DISENGAGE
# ========================================

# Search for target and disengage when found
walker SearchWalker {
    has target_name: str,
        found: bool = False;

    can search with `root entry {
        print(f"SearchWalker: searching for {self.target_name}");
        visit [-->];
    }

    can check with Person entry {
        print(f"SearchWalker: checking {here.name}");
        if here.name == self.target_name {
            print(f"SearchWalker: found {here.name}!");
            self.found = True;
            disengage;
        }
        visit [-->];
    }
}

# ========================================
# MULTIPLE VISIT PATTERNS
# ========================================

# Walker with multiple visit strategies
walker MultiVisit {
    has visit_phase: int = 1;

    can start with `root entry {
        print("MultiVisit: phase 1 - visit all outgoing");
        visit [-->];
    }

    can phase_one with Person entry {
        if self.visit_phase == 1 {
            print(f"MultiVisit: phase 1 at {here.name}");
            self.visit_phase = 2;
            visit [-->];
        }
    }

    can phase_two with Person entry {
        if self.visit_phase == 2 {
            print(f"MultiVisit: phase 2 at {here.name}");
        }
    }
}

# ========================================
# DISENGAGE STOPS CODE AFTER IT
# ========================================

# Demonstrate that disengage stops execution immediately
walker ImmediateStop {
    can self_destruct with `root entry {
        print("ImmediateStop: before disengage");
        disengage;
        print("ImmediateStop: after disengage (never printed)");
    }
}

# ========================================
# COMBINED VISIT AND DISENGAGE
# ========================================

# Complex traversal with both visit and disengage
walker ComplexTraversal {
    has depth: int = 0,
        max_depth: int = 2,
        nodes_visited: list[str] = [];

    can start with `root entry {
        print("ComplexTraversal: starting from root");
        visit [-->];
    }

    can traverse with Person entry {
        self.depth += 1;
        self.nodes_visited.append(here.name);
        print(f"ComplexTraversal: depth {self.depth} at {here.name}");

        if self.depth >= self.max_depth {
            print(f"ComplexTraversal: max depth reached, disengaging");
            disengage;
        }

        visit [-->] else {
            print(f"ComplexTraversal: leaf node at {here.name}");
        }
    }
}

# ========================================
# GRAPH SETUP AND WALKER EXECUTION
# ========================================

# Build graph structure
glob alice = Person(name="Alice"),
     bob = Person(name="Bob"),
     charlie = Person(name="Charlie"),
     diana = Person(name="Diana"),
     eve = Person(name="Eve");

# Create graph connections
with entry {
    root ++> alice;
    alice ++> bob;
    alice ++> charlie;
    bob ++> diana;
    charlie ++> eve;

    # Add typed edges
    alice +>: Friend :+> bob;
    alice +>: Colleague(strength=7) :+> charlie;
    alice +>: Colleague(strength=3) :+> diana;

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

    print("\n=== Basic Disengage ===");
    root spawn BasicDisengage();

    print("\n=== Conditional Disengage ===");
    root spawn ConditionalDisengage();

    print("\n=== Search Walker ===");
}

glob w = root spawn SearchWalker(target_name="Charlie");

with entry {
    print(f"Found: {w.found}");

    print("\n=== Multi Visit ===");
    root spawn MultiVisit();

    print("\n=== Immediate Stop ===");
    root spawn ImmediateStop();

    print("\n=== Complex Traversal ===");
}

glob ct = root spawn ComplexTraversal();

with entry {
    print(f"Nodes visited: {ct.nodes_visited}");
}
