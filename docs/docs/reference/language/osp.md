# Part III: Object-Spatial Programming (OSP)

**In this part:**

- [Introduction to OSP](#introduction-to-osp) - Concepts, motivation, core example
- [Nodes](#nodes) - Node declaration, entry/exit abilities
- [Edges](#edges) - Edge declaration, typed connections
- [Walkers](#walkers) - Walker declaration, visit, report, disengage
- [Graph Construction](#graph-construction) - Creating and connecting nodes
- [Graph Traversal](#graph-traversal) - Filtered traversal, entry/exit events
- [Data Spatial Queries](#data-spatial-queries) - Edge references, attribute filtering
- [Typed Context Blocks](#typed-context-blocks) - Type-based dispatch

---

> **Related Sections:**
>
> - [Graph Operators](foundation.md#7-graph-operators-osp) - Connection and edge reference syntax
> - [Pipe Operators](foundation.md#8-pipe-operators) - Spawn traversal modes

## Introduction to OSP

### 1 What is OSP?

Object-Spatial Programming models data as graphs and computation as mobile agents (walkers) that traverse the graph. Instead of calling functions on objects, walkers visit nodes and perform operations based on location.

### 2 Why OSP?

- **Natural graph modeling**: Social networks, knowledge graphs, state machines
- **AI agent architecture**: Walkers are natural representations of AI agents
- **Separation of concerns**: Data (nodes/edges) separate from behavior (walkers)
- **Spatial context**: `here`, `visitor` provide natural context

### 3 Core Concepts

| Concept | Description | Keyword |
|---------|-------------|---------|
| **Node** | Graph vertex holding data | `node` |
| **Edge** | Connection between nodes | `edge` |
| **Walker** | Mobile agent that traverses | `walker` |
| **Root** | Entry point to graph | `root` |
| **Here** | Walker's current location | `here` |
| **Visitor** | Reference to visiting walker | `visitor` |

### 4 Complete Example

```jac
node Person {
    has name: str;
    has age: int;
}

edge Knows {
    has since: int;
}

walker Greeter {
    can greet with `root entry {
        visit [-->];
    }

    can say_hello with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];
    }
}

with entry {
    # Build graph
    alice = Person(name="Alice", age=30);
    bob = Person(name="Bob", age=25);

    root ++> alice;
    alice +>: Knows(since=2020) :+> bob;

    # Spawn walker
    root spawn Greeter();
}
```

---

## Nodes

Nodes are the vertices of your graph -- they hold data and can have abilities that execute when walkers visit them. Think of nodes as "smart objects" that know when they're being visited and can react accordingly. Unlike regular objects, nodes can be connected via edges and participate in graph traversals.

### 1 Node Declaration

```jac
node Person {
    has name: str;
    has age: int = 0;

    can greet with Visitor entry {
        print(f"Hello from {self.name}");
    }
}

# Node with no data
node Waypoint { }
```

### 2 Node Entry/Exit Abilities

Abilities triggered when walkers enter or exit. The event clause syntax is:

```
can ability_name with [TypeExpression] (entry | exit) { ... }
```

Where `TypeExpression` is optional - if omitted, the ability triggers for ALL walkers.

```jac
node SecureRoom {
    has clearance_required: int;

    # Generic entry - triggers for ANY walker (no type filter)
    can on_enter with entry {
        print("Someone entered");
    }

    # Typed entry - triggers only for Inspector walkers
    can check_clearance with Inspector entry {
        if visitor.clearance < self.clearance_required {
            print("Access denied");
            disengage;
        }
    }

    # Type reference entry - using backtick for root
    can at_root with `root entry {
        print("At root node");
    }

    # Walker exiting
    can on_exit with Inspector exit {
        print("Inspector leaving");
    }

    # Multiple walker types (union)
    can process with Walker1 | Walker2 entry {
        print("Processing for Walker1 or Walker2");
    }
}
```

**Event Clause Forms:**

| Form | Triggers When |
|------|---------------|
| `with entry` | Any walker enters (no type filter) |
| `with TypeName entry` | Walker of TypeName enters |
| `` with `root entry `` | At root node entry |
| `with Type1 \| Type2 entry` | Walker of either type enters |
| `with exit` | Any walker exits |
| `with TypeName exit` | Walker of TypeName exits |

### 3 Node Inheritance

```jac
node Entity {
    has id: str;
    has created_at: str;
}

node User(Entity) {
    has username: str;
    has email: str;
}
```

---

## Edges

Edges are first-class connections between nodes. Unlike simple object references, edges can carry their own data (like relationship strength or timestamps) and have their own types. This lets you model rich relationships -- "Alice *knows* Bob *since 2020*" becomes natural to express. Use typed edges when the relationship itself has meaningful attributes.

### 1 Edge Declaration

```jac
edge Friend {
    has since: int;
    has strength: float = 1.0;
}

edge Follows { }  # Edge with no data

edge Weighted {
    has weight: float;

    def get_normalized(max_weight: float) -> float {
        return self.weight / max_weight;
    }
}
```

### 2 Edge Entry/Exit

Walkers can trigger abilities on edges during traversal:

```jac
edge Road {
    has distance: float;

    can on_traverse with Traveler entry {
        visitor.total_distance += self.distance;
    }
}
```

### 3 Directed vs Undirected

Edge direction is determined by connection operators:

```jac
node Item {}

with entry {
    a = Item();
    b = Item();

    a ++> b;          # Directed: a → b
    a <++> b;         # Undirected: a ↔ b (creates edges both ways)
}
```

---

## Walkers

Walkers are mobile agents that traverse the graph, executing abilities at each node they visit. Unlike functions that you call, walkers *go to* data. They maintain state throughout their journey, making them ideal for tasks like collecting information across a graph, implementing AI agents that navigate knowledge structures, or processing pipelines where context accumulates. Spawn a walker with `root spawn MyWalker()` to begin traversal.

### 1 Walker Declaration

```jac
walker Collector {
    has items: list = [];
    has max_items: int = 10;

    can start with `root entry {
        print("Starting collection");
        visit [-->];
    }

    can collect with DataNode entry {
        if len(self.items) < self.max_items {
            self.items.append(here.value);
        }
        visit [-->];
    }
}
```

### 2 Walker State

Walkers maintain state throughout their traversal:

```jac
node DataNode {
    has value: int;
}

walker Counter {
    has count: int = 0;

    can start with `root entry {
        self.count += 1;
        visit [-->];
    }

    can count_nodes with DataNode entry {
        self.count += 1;
        visit [-->];
    }
}

with entry {
    root ++> DataNode(value=1) ++> DataNode(value=2);
    walker_instance = Counter();
    root spawn walker_instance;
    print(f"Counted {walker_instance.count} nodes");  # Output: 3
}
```

> **Note:** Walker abilities must specify which node types they handle. Use `` `root `` for the root node and specific node types for others. A generic `with entry` only triggers at the spawn location.

### 3 The `visit` Statement

The `visit` statement tells the walker where to go next. It doesn't immediately move -- it queues nodes for the next step of traversal. This queue-based approach lets you control breadth-first vs depth-first traversal and handle cases where there's nowhere to go (using the `else` clause).

**Basic Syntax:**

```jac
node Item {}

walker Visitor {
    can go with Item entry {
        visit [-->];                    # Visit all outgoing nodes
        visit [<--];                    # Visit all incoming nodes
        visit [<-->];                   # Visit both directions
    }
}
```

**With Type Filters:**

```jac
node Person {}
edge Friend { has since: int = 2020; }

walker Visitor {
    can filter with Person entry {
        visit [-->(`?Person)];          # Visit Person nodes only
        visit [->:Friend:->];           # Visit via Friend edges only
        visit [->:Friend:since>2020:->]; # Via Friend edges with condition
    }
}
```

**With Else Clause:**

```jac
node Item {}

walker Visitor {
    can traverse with Item entry {
        visit [-->] else {              # Fallback if no nodes to visit
            print("No outgoing edges");
        }
    }
}
```

**Direct Node Visit:**

```jac
node Item {}

walker Visitor {
    has target: Item | None = None;

    can direct with Item entry {
        visit here;                     # Visit current node
        visit self.target;              # Visit node stored in walker field
    }
}
```

**Indexed Visit:**

```jac
node Item {}

walker Visitor {
    can indexed with Item entry {
        visit : 0 : [-->];              # Visit first outgoing node only
        visit : -1 : [-->];             # Visit last outgoing node only
        visit : 2 : [-->];              # Visit third node (0-indexed)
    }
}
```

Out-of-bounds indices result in no visit.

### 4 The `report` Statement

Send data back without stopping:

```jac
node DataNode {
    has value: int = 0;
}

walker DataCollector {
    can collect with DataNode entry {
        report here.value;  # Continues execution
        visit [-->];
    }
}

with entry {
    root ++> DataNode(value=1);
    result = root spawn DataCollector();
    all_values = result.reports;  # List of reported values
}
```

### 5 The `disengage` Statement

The `disengage` statement immediately terminates a walker's traversal. Use it when the walker has found what it was looking for (like a search hitting its target) or when a condition means further traversal would be pointless. It's the walker equivalent of `return` from a recursive function.

```jac
walker Searcher {
    has target: str;

    can search with Person entry {
        if here.name == self.target {
            report here;
            disengage;  # Stop traversal
        }
        visit [-->];
    }
}
```

### 6 Spawning Walkers

```jac
node Item { has value: int = 0; }

walker MyWalker {
    has param: int = 0;

    can visit with `root entry {
        visit [-->];
    }
    can collect with Item entry {
        report here.value;
    }
}

with entry {
    node1 = Item(value=1);
    node2 = Item(value=2);
    node3 = Item(value=3);
    root ++> node1 ++> node2 ++> node3;

    # Basic spawn
    result = root spawn MyWalker();

    # Spawn with parameters
    result = root spawn MyWalker(param=10);

    # Access results
    print(result.returns);  # Return value
    print(result.reports);  # All reported values
}
```

### 7 Walker Inheritance

```jac
walker BaseVisitor {
    can log with entry {
        print(f"Visiting: {here}");
    }
}

walker DetailedVisitor(BaseVisitor) {
    override can log with entry {
        print(f"Detailed visit to: {type(here).__name__}");
    }
}
```

### 8 Special References

These keywords have special meaning in specific contexts:

| Reference | Valid Context | Description | See Also |
|-----------|---------------|-------------|----------|
| `self` | Any method/ability | Current instance (walker, node, object) | [Part II: Functions](functions-objects.md#object-oriented-programming) |
| `here` | Walker ability | Current node the walker is visiting | [Walkers](#walkers) |
| `visitor` | Node ability | The walker that triggered this ability | [Nodes](#nodes) |
| `root` | Anywhere | Root node of the current graph | [Graph Construction](#graph-construction) |
| `super` | Subclass method | Parent class reference | [Part II](functions-objects.md#2-inheritance) |
| `init` | Object body | Constructor method name | [Part II](functions-objects.md#1-objects-classes) |
| `postinit` | Object body | Post-constructor hook | [Part I](foundation.md#2-instance-variables-has) |
| `props` | JSX context | Component props reference | [Part IV: Full-Stack](full-stack.md#client-side-development-jsx) |

**Usage examples:**

```jac
node SecureRoom {
    has required_level: int;

    # 'visitor' refers to the walker visiting this node
    # 'self' refers to this node instance
    can check with Inspector entry {
        if visitor.clearance >= self.required_level {
            print("Access granted to " + visitor.name);
        }
    }
}

walker Inspector {
    has clearance: int;
    has name: str;

    # 'here' refers to the current node being visited
    # 'self' refers to this walker instance
    can inspect with SecureRoom entry {
        print(f"{self.name} inspecting room at {here}");
        print(f"Room requires level {here.required_level}");
    }

    can start with `root entry {
        # 'root' is always the graph root
        print(f"Starting from root: {root}");
        visit [-->];
    }
}
```

**When each reference is valid:**

| Context | `self` | `here` | `visitor` | `root` |
|---------|--------|--------|-----------|--------|
| Walker ability | Walker instance | Current node | N/A | Graph root |
| Node ability | Node instance | N/A | Visiting walker | Graph root |
| Object method | Object instance | N/A | N/A | Graph root |
| Free code | N/A | N/A | N/A | Graph root |

---

## Graph Construction

### 1 Creating Nodes

```jac
node Person {
    has name: str;
    has age: int;
}

with entry {
    # Create and assign
    alice = Person(name="Alice", age=30);
    bob = Person(name="Bob", age=25);

    # Inline creation in connection
    root ++> Person(name="Charlie", age=35);
}
```

### 2 Creating Edges

```jac
node Person { has name: str; }
edge Friend { has since: int = 2020; }
edge Colleague { has department: str = ""; }

with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");

    # Untyped (generic edge)
    alice ++> bob;

    # Typed edge
    alice +>: Friend(since=2020) :+> bob;

    # Bidirectional typed
    alice <+: Colleague(department="Engineering") :+> bob;
}
```

### 3 Chained Construction

```jac
node Item {}
edge Start {}
edge Next {}
edge End {}

with entry {
    a = Item();
    b = Item();
    c = Item();
    d = Item();

    # Build chains in one expression
    root ++> a ++> b ++> c ++> d;

    # With typed edges
    root +>: Start :+> a +>: Next :+> b +>: Next :+> c +>: End :+> d;
}
```

### 4 Deleting Nodes and Edges

```jac
node Person { has name: str; }
edge Friend {}

with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    alice +>: Friend :+> bob;

    # Delete specific edge
    alice del --> bob;

    # Delete node
    del bob;
}
```

### 5 Built-in Graph Functions

| Function | Description |
|----------|-------------|
| `jid(node)` | Get unique Jac ID of object |
| `jobj(node)` | Get Jac object wrapper |
| `grant(node, user)` | Grant access permission |
| `revoke(node, user)` | Revoke access permission |
| `allroots()` | Get all root references |
| `save(node)` | Persist node to storage |
| `commit()` | Commit pending changes |
| `printgraph(root)` | Print graph for debugging |

```jac
node Person { has name: str; }

with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");
    secret_node = Person(name="Secret");

    id = jid(alice);
    save(alice);
    printgraph(root);
}
```

---

## Graph Traversal

### 1 Basic Traversal

Walker traversal is queue-based (BFS-like by default):

```jac
walker BFSWalker {
    can start with `root entry {
        print(f"Starting at: {here}");
        visit [-->];
    }

    can traverse with Person entry {
        print(f"Visiting: {here.name}");
        visit [-->];  # Queue all outgoing for later visits
    }
}
```

### 2 Filtered Traversal

```jac
node Person { has age: int = 0; }
edge Friend { has since: int = 2020; }

walker FilteredWalker {
    can start with `root entry {
        visit [-->];  # Start traversal from root
    }

    can traverse with Person entry {
        # By node type
        visit [-->(`?Person)];

        # By edge type
        visit [->:Friend:->];

        # Combined: Friend edges to Person nodes since 2020
        visit [->:Friend:since > 2020:->(`?Person)];
    }
}
```

### 3 Entry and Exit Events

```jac
node Room {
    can on_enter with Visitor entry {
        print("Entering room");
    }

    can on_exit with Visitor exit {
        print("Exiting room");
    }
}
```

---

## Data Spatial Queries

### 1 Edge Reference Syntax

```jac
node Person {}
edge EdgeType {}
edge Edge { has attr: int = 0; has a: int = 0; has b: int = 0; }
edge Friend {}

walker Traverser {
    can query with Person entry {
        # Basic forms
        outgoing = [-->];                     # All outgoing nodes
        incoming = [<--];                     # All incoming nodes
        both = [<-->];                        # Both directions

        # Typed forms
        via_type = [->:EdgeType:->];          # Outgoing via EdgeType

        # With conditions
        filtered = [->:Edge:attr > 0:->];     # Filter by edge attribute

        # Node type filter
        people = [-->(`?Person)];             # Filter result nodes by type

        # Get edges vs nodes
        edges = [edge -->];                   # Get edge objects
        friends = [edge ->:Friend:->];        # Typed edge objects
    }
}
```

Use `[edge -->]` when you need to access edge attributes or visit edges directly.

### 2 Attribute Filtering

```jac
node User {
    has age: int = 0;
    has status: str = "";
    has verified: bool = False;
}
edge Friend { has since: int = 2020; }
edge Link { has weight: float = 0.0; }

walker Filter {
    can query with User entry {
        # Filter by node attributes (after traversal)
        adults = [-->](?age >= 18);
        active = [-->](?status == "active");

        # Filter by edge attributes (during traversal)
        recent_friends = [->:Friend:since > 2020:->];
        strong_connections = [->:Link:weight > 0.8:->];
    }
}
```

### 3 Complex Queries

```jac
node Person { has age: int = 0; }
edge Friend { has since: int = 2020; }
edge Colleague {}

walker Querier {
    can complex with Person entry {
        # Chained traversal (multi-hop)
        friends_of_friends = [here ->:Friend:-> ->:Friend:->];

        # Mixed edge types
        path = [here ->:Friend:-> ->:Colleague:->];

        # Combined with filters
        target = [->:Friend:since < 2020:->(`?Person)](?age > 30);
    }
}
```

---

## Typed Context Blocks

### 1 What are Typed Context Blocks?

Handle different types with specialized code paths. The syntax uses `->Type{code}` with no space between the arrow and type name:

```jac
walker AnimalVisitor {
    can visit with Animal entry {
        # Typed context block for Dog (subtype of Animal)
        ->Dog{print(f"{here.name} is a {here.breed} dog");}

        # Typed context block for Cat (subtype of Animal)
        ->Cat{print(f"{here.name} says meow");}

        # Default case (any other Animal type)
        ->_{print(f"{here.name} is some animal");}
    }
}
```

**Syntax Notes:**

- No space between `->` and the type name: `->Dog{` not `-> Dog {`
- Opening brace immediately follows the type
- Code typically on same line with closing brace
- Use `->_` for default/catch-all case

### 2 Tuple-Based Dispatch

```jac
walker Processor {
    can process with (Node1, Node2) entry {
        # Handle when visiting involves both types
    }
}
```

### 3 Context Blocks in Nodes

Nodes reacting to different walker types:

```jac
node DataNode {
    has value: int;

    can handle with Walker entry {
        ->Reader{print(f"Read value: {self.value}");}

        ->Writer{
            self.value = visitor.new_value;
            print(f"Updated to: {self.value}");
        }
    }
}
```

### 4 Complex Typed Context Example

From the reference examples, showing inheritance-based dispatch:

```jac
walker ShoppingCart {
    can process_item with Product entry {
        print(f"Processing {type(here).__name__}...");

        # Each subtype gets its own block
        ->Book{print(f"  -> Book: '{here.title}' by {here.author}");}
        ->Magazine{print(f"  -> Magazine: '{here.title}' Issue #{here.issue}");}
        ->Electronics{print(f"  -> Electronics: {here.name}, warranty {here.warranty_years}yr");}

        self.total += here.price;
        visit [-->];
    }
}
```

---

## See Also

- [Walker Responses](walker-responses.md) - Patterns for handling `.reports` array
- [Graph Operations](graph-operations.md) - Quick reference for `++>`, `-->`, `del here`
- [Build a Todo App](../../tutorials/fullstack/todo-app.md) - Full-stack tutorial using OSP concepts
- [OSP Tutorial](../../tutorials/language/osp.md) - Hands-on tutorial with exercises
- [What Makes Jac Different](../../quick-guide/what-makes-jac-different.md) - Gentle introduction to Jac's core concepts
