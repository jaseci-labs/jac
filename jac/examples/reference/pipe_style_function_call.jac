"""Pipe-style function call: Pipe-style function invocation."""

# ===== Part 1: Node and Walker Setup =====
node Task {
    has name: str,
        priority: int = 0;
}

walker SimpleWalker {
    has visited_names: list = [];

    can start with `root entry {
        print(f"SimpleWalker: Starting at root");
        visit [-->];
    }

    can process with Task entry {
        self.visited_names.append(here.name);
        print(f"  Processing: {here.name} (priority {here.priority})");
        visit [-->];
    }
}

# ===== Part 2: Basic spawn Keyword =====
walker BasicSpawn {
    can start with `root entry {
        print("BasicSpawn: started at root");
        visit [-->];
    }

    can handle_task with Task entry {
        print(f"  BasicSpawn at: {here.name}");
        visit [-->];
    }
}

# ===== Part 3: Depth-First Spatial Call (:>) =====
walker DepthFirst {
    has depth: int = 0;

    can start with `root entry {
        print("DepthFirst: root");
        visit [-->];
    }

    can process with Task entry {
        self.depth += 1;
        print(f"  Depth-first [{self.depth}]: {here.name}");
        visit [-->];
    }
}

# ===== Part 4: Breadth-First Spatial Call (|>) =====
walker BreadthFirst {
    has order: list = [];

    can start with `root entry {
        print("BreadthFirst: root");
        visit [-->];
    }

    can process with Task entry {
        self.order.append(here.name);
        print(f"  Breadth-first: {here.name}");
        visit [-->];
    }
}

# ===== Part 5: Walker Return Values =====
walker DataCollector {
    has collected: list = [],
        sum: int = 0;

    can start with `root entry {
        visit [-->];
    }

    can collect with Task entry {
        self.collected.append(here.name);
        self.sum += here.priority;
        visit [-->];
    }
}

# ===== Part 6: Walker Spawned from Nodes =====
walker NodeSpawner {
    can start with `root entry {
        visit [-->];
    }

    can process with Task entry {
        print(f"  At {here.name}");
        if here.name == "Task2" {
            print("    Spawning SubWalker from Task2");
            # Spawn another walker from current node
            here spawn SubWalker();
        }
        visit [-->];
    }
}

walker SubWalker {
    can start with Task entry {
        print(f"    SubWalker started at: {here.name}");
        visit [-->];
    }

    can handle with Task entry {
        print(f"      SubWalker processing: {here.name}");
        visit [-->];
    }
}

# ===== Part 7: Walker Construction and Spawn Patterns =====
walker ConstructedWalker {
    has label: str,
        max_visits: int = 5,
        visits: int = 0;

    can start with `root entry {
        print(f"ConstructedWalker '{self.label}' starting");
        visit [-->];
    }

    can process with Task entry {
        self.visits += 1;
        print(f"  [{self.label}] Visit {self.visits}: {here.name}");

        if self.visits >= self.max_visits {
            print(f"  [{self.label}] Max visits reached");
            disengage;
        }

        visit [-->];
    }
}

# ===== Part 8: Multiple Walkers on Same Graph =====
walker Counter {
    has total: int = 0;

    can start with `root entry {
        visit [-->];
    }

    can count_task with Task entry {
        self.total += 1;
        visit [-->];
    }
}

walker Analyzer {
    has high_priority: int = 0,
        low_priority: int = 0;

    can start with `root entry {
        visit [-->];
    }

    can analyze with Task entry {
        if here.priority > 5 {
            self.high_priority += 1;
        } else {
            self.low_priority += 1;
        }
        visit [-->];
    }
}

# ===== Part 9: Walker Spawn Syntax Variations =====
walker SyntaxDemo {
    can start with `root entry {
        print("SyntaxDemo: Demonstrating all spawn syntaxes");
    }
}

# ===== Execution and Tests =====
with entry {
    print("=== 1. Building Test Graph ===");
}

# Build tree structure:
#     root
#      |
#    Task1 (p=10)
#    /   \
# Task2  Task3 (p=3)
#  (p=5)   |
#          Task4 (p=8)
glob task1 = Task(name="Task1", priority=10),
     task2 = Task(name="Task2", priority=5),
     task3 = Task(name="Task3", priority=3),
     task4 = Task(name="Task4", priority=8);

with entry {
    root ++> task1;
    task1 ++> task2;
    task1 ++> task3;
    task3 ++> task4;

    print("Graph: root -> Task1 -> Task2");
    print("                 \\-> Task3 -> Task4\n");

    print("=== 2. Basic spawn Keyword ===");
    # Most common form: node spawn Walker()
    root spawn BasicSpawn();

    print("\n=== 3. Depth-First Spatial Call (:>) ===");
    # Depth-first traversal: goes deep before wide
    # Expected: Task1, Task2, Task3, Task4
    root spawn :> DepthFirst;

    print("\n=== 4. Breadth-First Spatial Call (|>) ===");
}

# Breadth-first traversal: goes level by level
# Expected: Task1, Task2, Task3, Task4
glob walker_bf = root spawn |> BreadthFirst;

with entry {
    print(f"  Order visited: {walker_bf.order}");

    print("\n=== 5. Walker Return Values ===");
}

# Walker instance is returned, can access state
glob collector = root spawn DataCollector();

with entry {
    print(f"  Collected: {collector.collected}");
    print(f"  Sum of priorities: {collector.sum}");

    print("\n=== 6. Walker Spawned from Nodes ===");
    # Walkers can spawn other walkers from any node
    root spawn NodeSpawner();

    print("\n=== 7. Walker Construction with Arguments ===");
}

# Create walker with initial state
glob w1 = root spawn ConstructedWalker(
         label="Alpha", max_visits=2
     );

with entry {
    print(f"  Walker visited {w1.visits} tasks");

    print("\n=== 8. Multiple Walkers on Same Graph ===");
}

# Different walkers can analyze same graph structure
glob counter = root spawn Counter(),
     analyzer = root spawn Analyzer();

with entry {
    print(f"  Counter: {counter.total} tasks");
    print(
        f"  Analyzer: {analyzer.high_priority} high, {analyzer.low_priority} low priority"
    );

    print("\n=== 9. Spawn Syntax Variations ===");
    # Variation 1: Basic spawn
    root spawn SyntaxDemo();

    # Variation 2: Depth-first spawn
    root spawn :> SyntaxDemo;

    # Variation 3: Breadth-first spawn
    root spawn |> SyntaxDemo;

    # Variation 4: Walker-first syntax (less common)
    SyntaxDemo() spawn root;
}

# Variation 5: With constructed walker
glob demo = SyntaxDemo();

with entry {
    root spawn demo;

    print("\n=== 10. Traversal Strategy Comparison ===");
}

# Build a deeper tree to see difference
glob a = Task(name="A", priority=1),
     b = Task(name="B", priority=2),
     c = Task(name="C", priority=3),
     d = Task(name="D", priority=4),
     e = Task(name="E", priority=5);

with entry {
    root ++> a;
    a ++> b;
    a ++> c;
    b ++> d;
    b ++> e;

    print("New graph: root -> A -> B -> D");
    print("                    \\   \\-> E");
    print("                     \\-> C\n");

    print("  Depth-first (:>):");
}

glob df = root spawn :> SimpleWalker;

with entry {
    print(f"    Visited: {df.visited_names}");

    print("\n  Breadth-first (|>):");
}

glob bf = root spawn |> SimpleWalker;

with entry {
    print(f"    Visited: {bf.visited_names}");

    print("\n✓ Object spatial calls demonstrated!");
}
