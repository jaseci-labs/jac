# Object-Spatial Programming (OSP)

Object-Spatial Programming is Jac's unique paradigm for working with graph-based data structures. It treats computation as **mobile agents (walkers)** that traverse a **graph of data (nodes and edges)**.

## The OSP Philosophy

| Traditional Programming | Object-Spatial Programming |
|------------------------|---------------------------|
| Bring data to code | Send code to data |
| Functions process data | Walkers visit nodes |
| Objects contain methods | Nodes have abilities that trigger on visits |
| Linear control flow | Graph-based traversal |

---

## Nodes

Nodes are data containers that form the vertices of your graph.

### Basic Node Definition

```jac
node Person {
    has name: str;
    has age: int = 0;
}

with entry {
    # Create a node
    alice = Person(name="Alice", age=30);
    print(alice.name);  # Alice
}
```

### Node Abilities

Nodes can have abilities that trigger when walkers visit them.

```jac
node Greeter {
    has message: str = "Hello!";

    # Triggers when ANY walker enters
    can greet with entry {
        print(self.message);
    }

    # Triggers only for specific walker type
    can special_greet with VIPWalker entry {
        print(f"VIP: {self.message}");
    }
}
```

---

## Edges

Edges represent connections between nodes. They can be typed and hold data.

### Basic Edge Definition

```jac
edge Knows {
    has since: int = 2024;
}

edge WorksWith;  # Empty edge (just a connection type)
```

### Connection Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `++>` | Connect with generic edge | `a ++> b` |
| `+>:EdgeType:+>` | Connect with typed edge | `a +>:Knows:+> b` |
| `-->` | Traverse forward | `[-->]` |
| `<--` | Traverse backward | `[<--]` |
| `<-->` | Traverse both directions | `[<-->]` |

### Connecting Nodes

```jac
node Person {
    has name: str;
}

edge Knows {
    has years: int = 1;
}

with entry {
    # Create nodes connected to root
    alice = root ++> Person(name="Alice");
    bob = root ++> Person(name="Bob");

    # Connect nodes with typed edge
    alice[0] +>:Knows(years=5):+> bob[0];
}
```

---

## Walkers

Walkers are mobile agents that traverse the graph, carrying state and executing abilities.

### Basic Walker Definition

```jac
walker Greeter {
    has greeting: str = "Hello";
    has visited_count: int = 0;

    can greet with Person entry {
        print(f"{self.greeting}, {here.name}!");
        self.visited_count += 1;
        visit [-->];  # Continue to connected nodes
    }
}
```

### Spawning Walkers

```jac
with entry {
    root ++> Person(name="Alice");
    root ++> Person(name="Bob");

    # Spawn walker at root
    walker_instance = Greeter() spawn root;

    # Access walker state after traversal
    print(f"Visited {walker_instance.visited_count} nodes");
}
```

### Walker Abilities

```jac
walker Explorer {
    has path: list[str] = [];

    # Trigger on root node
    can start with `root entry {
        print("Starting exploration");
        visit [-->];
    }

    # Trigger on Person nodes
    can explore with Person entry {
        self.path.append(here.name);
        visit [-->];
    }

    # Trigger when leaving any node
    can log with exit {
        print("Leaving a node");
    }
}
```

---

## Reference Keywords

| Keyword | Context | Meaning |
|---------|---------|---------|
| `self` | Walker/Node | The current walker or node instance |
| `here` | Walker ability | The current node being visited |
| `visitor` | Node ability | The walker currently visiting |

### Using Reference Keywords

```jac
node Room {
    has name: str;

    can welcome with Visitor entry {
        # 'visitor' refers to the walker
        print(f"Welcome {visitor.name} to {self.name}");
    }
}

walker Visitor {
    has name: str;

    can explore with Room entry {
        # 'here' refers to the current node
        print(f"{self.name} entered {here.name}");
        visit [-->];
    }
}
```

---

## Graph Traversal

### Visit Patterns

```jac
walker Traverser {
    can traverse with entry {
        # Visit all forward connections
        visit [-->];

        # Visit all backward connections
        visit [<--];

        # Visit both directions
        visit [<-->];

        # Visit with else (no more nodes)
        visit [-->] else {
            print("End of path");
            disengage;
        }
    }
}
```

### Filtering Traversal

```jac
walker Finder {
    can find with entry {
        # Visit only Person nodes
        visit [-->(`?Person)];

        # Visit via specific edge type
        visit [-->:Knows:];

        # Combined filtering
        visit [-->:Knows:(`?Person)];
    }
}
```

### Disengage

The `disengage` keyword stops a walker's traversal.

```jac
walker SearchWalker {
    has target: str;
    has found: bool = False;

    can search with Person entry {
        if here.name == self.target {
            self.found = True;
            disengage;  # Stop traversing
        }
        visit [-->];
    }
}
```

---

## Complete Example

```jac
"""Social network example demonstrating OSP concepts."""

node Person {
    has name: str;
    has messages: list[str] = [];

    can receive with Messenger entry {
        self.messages.append(visitor.message);
        print(f"{self.name} received: {visitor.message}");
    }
}

edge Knows {
    has since: int = 2024;
}

walker Messenger {
    has message: str;
    has delivered_to: list[str] = [];

    can start with `root entry {
        visit [-->];
    }

    can deliver with Person entry {
        self.delivered_to.append(here.name);
        visit [-->:Knows:];  # Only traverse Knows edges
    }
}

with entry {
    # Build graph
    alice = root ++> Person(name="Alice");
    bob = root ++> Person(name="Bob");
    carol = root ++> Person(name="Carol");

    # Create relationships
    alice[0] +>:Knows(since=2020):+> bob[0];
    bob[0] +>:Knows(since=2022):+> carol[0];

    # Send message
    m = Messenger(message="Hello everyone!") spawn root;

    print(f"Delivered to: {m.delivered_to}");
}
```

---

## Common Patterns

### Tree Traversal

```jac
walker TreeWalker {
    has depth: int = 0;

    can walk with entry {
        print(f"{'  ' * self.depth}Node at depth {self.depth}");
        self.depth += 1;
        visit [-->];
        self.depth -= 1;
    }
}
```

### Data Collection

```jac
walker Collector {
    has data: list = [];

    can start with `root entry {
        visit [-->];
    }

    can collect with Person entry {
        self.data.append({"name": here.name});
        visit [-->];
    }
}

with entry {
    root ++> Person(name="Alice");
    root ++> Person(name="Bob");

    c = Collector() spawn root;
    print(c.data);  # [{"name": "Alice"}, {"name": "Bob"}]
}
```

### Conditional Visiting

```jac
walker AgeFilter {
    has min_age: int = 18;

    can start with `root entry {
        visit [-->];
    }

    can filter with Person entry {
        if here.age >= self.min_age {
            print(f"{here.name} is {here.age}");
        }
        visit [-->];
    }
}
```

---

## Learn More

| Topic | Resource |
|-------|----------|
| OSP Introduction | [Chapter 8: OSP Paradigm](../../jac_book/chapter_8.md) |
| Nodes & Edges Detail | [Chapter 9: Nodes and Edges](../../jac_book/chapter_9.md) |
| Walkers & Abilities | [Chapter 10: Walkers](../../jac_book/chapter_10.md) |
| Advanced Traversal | [Chapter 11: Advanced OSP](../../jac_book/chapter_11.md) |
| Formal Specification | [Data-Spatial Programming](../../learn/dspfoundation.md) |
| Nodes Reference | [Nodes & Edges Guide](../../learn/data_spatial/nodes_and_edges.md) |
| Walkers Reference | [Walkers Guide](../../learn/data_spatial/walkers.md) |
