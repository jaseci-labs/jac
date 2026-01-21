# Part III: Object-Spatial Programming (OSP)

> **Related Sections:**
>
> - [Graph Operators](foundation.md#67-graph-operators-osp) - Connection and edge reference syntax
> - [Pipe Operators](foundation.md#68-pipe-operators) - Spawn traversal modes
> - [Data Spatial Queries](#17-data-spatial-queries) - Filtering and querying
> - [Typed Context Blocks](#18-typed-context-blocks) - Type-based dispatch

## 11. Introduction to OSP

### 11.1 What is OSP?

Object-Spatial Programming models data as graphs and computation as mobile agents (walkers) that traverse the graph. Instead of calling functions on objects, walkers visit nodes and perform operations based on location.

### 11.2 Why OSP?

- **Natural graph modeling**: Social networks, knowledge graphs, state machines
- **AI agent architecture**: Walkers are natural representations of AI agents
- **Separation of concerns**: Data (nodes/edges) separate from behavior (walkers)
- **Spatial context**: `here`, `visitor` provide natural context

### 11.3 Core Concepts

| Concept | Description | Keyword |
|---------|-------------|---------|
| **Node** | Graph vertex holding data | `node` |
| **Edge** | Connection between nodes | `edge` |
| **Walker** | Mobile agent that traverses | `walker` |
| **Root** | Entry point to graph | `root` |
| **Here** | Walker's current location | `here` |
| **Visitor** | Reference to visiting walker | `visitor` |

### 11.4 Complete Example

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

## 12. Nodes

Nodes are the vertices of your graph -- they hold data and can have abilities that execute when walkers visit them. Think of nodes as "smart objects" that know when they're being visited and can react accordingly. Unlike regular objects, nodes can be connected via edges and participate in graph traversals.

### 12.1 Node Declaration

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

### 12.2 Node Entry/Exit Abilities

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

### 12.3 Node Inheritance

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

## 13. Edges

Edges are first-class connections between nodes. Unlike simple object references, edges can carry their own data (like relationship strength or timestamps) and have their own types. This lets you model rich relationships -- "Alice *knows* Bob *since 2020*" becomes natural to express. Use typed edges when the relationship itself has meaningful attributes.

### 13.1 Edge Declaration

```jac
edge Friend {
    has since: int;
    has strength: float = 1.0;
}

edge Follows { }  # Edge with no data

edge Weighted {
    has weight: float;

    can get_normalized(max_weight: float) -> float {
        return self.weight / max_weight;
    }
}
```

### 13.2 Edge Entry/Exit

Walkers can trigger abilities on edges during traversal:

```jac
edge Road {
    has distance: float;

    can on_traverse with Traveler entry {
        visitor.total_distance += self.distance;
    }
}
```

### 13.3 Directed vs Undirected

Edge direction is determined by connection operators:

```jac
a ++> b;          # Directed: a → b
a <++> b;         # Undirected: a ↔ b (creates edges both ways)
```

---

## 14. Walkers

Walkers are mobile agents that traverse the graph, executing abilities at each node they visit. Unlike functions that you call, walkers *go to* data. They maintain state throughout their journey, making them ideal for tasks like collecting information across a graph, implementing AI agents that navigate knowledge structures, or processing pipelines where context accumulates. Spawn a walker with `root spawn MyWalker()` to begin traversal.

### 14.1 Walker Declaration

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

### 14.2 Walker State

Walkers maintain state throughout their traversal:

```jac
walker Counter {
    has count: int = 0;

    can count_nodes with entry {
        self.count += 1;
        visit [-->];
    }
}

with entry {
    walker_instance = Counter();
    root spawn walker_instance;
    print(f"Counted {walker_instance.count} nodes");
}
```

### 14.3 The `visit` Statement

The `visit` statement tells the walker where to go next. It doesn't immediately move -- it queues nodes for the next step of traversal. This queue-based approach lets you control breadth-first vs depth-first traversal and handle cases where there's nowhere to go (using the `else` clause).

**Basic Syntax:**

```jac
visit [-->];                    # Visit all outgoing nodes
visit [<--];                    # Visit all incoming nodes
visit [<-->];                   # Visit both directions
```

**With Type Filters:**

```jac
visit [-->(`?Person)];          # Visit Person nodes only
visit [->:Friend:->];           # Visit via Friend edges only
visit [->:Friend:since>2020:->]; # Via Friend edges with condition
```

**With Else Clause:**

```jac
visit [-->] else {              # Fallback if no nodes to visit
    print("No outgoing edges");
}
```

**Direct Node Visit:**

```jac
visit target_node;              # Visit a specific node directly
visit self.target;              # Visit node stored in walker field
```

**Grammar:** `visit (COLON expression COLON)? expression (else_stmt | SEMI)`

The optional `COLON expression COLON` syntax (e.g., `visit :limit: [-->]`) may be used for limiting visits, but verify with current implementation.

### 14.4 The `report` Statement

Send data back without stopping:

```jac
walker DataCollector {
    can collect with DataNode entry {
        report here.value;  # Continues execution
        visit [-->];
    }
}

with entry {
    result = root spawn DataCollector();
    all_values = result.reports;  # List of reported values
}
```

### 14.5 The `disengage` Statement

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

### 14.6 Spawning Walkers

```jac
# Basic spawn
result = root spawn MyWalker();

# Spawn with parameters
result = root spawn MyWalker(param=value);

# Access results
print(result.returns);  # Return value
print(result.reports);  # All reported values

# Alternative syntax
result = MyWalker() spawn root;

# Multi-target spawn (concurrent)
results = MyWalker() spawn [node1, node2, node3];
```

### 14.7 Walker Inheritance

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

### 14.8 Special References

These keywords have special meaning in specific contexts:

| Reference | Valid Context | Description | See Also |
|-----------|---------------|-------------|----------|
| `self` | Any method/ability | Current instance (walker, node, object) | [Part II: Functions](functions-objects.md#9-object-oriented-programming) |
| `here` | Walker ability | Current node the walker is visiting | [Section 14.1](#141-walker-declaration) |
| `visitor` | Node ability | The walker that triggered this ability | [Section 12.2](#122-node-entryexit-abilities) |
| `root` | Anywhere | Root node of the current graph | [Section 15](#15-graph-construction) |
| `super` | Subclass method | Parent class reference | [Part II](functions-objects.md#92-inheritance) |
| `init` | Object body | Constructor method name | [Part II](functions-objects.md#91-objects-classes) |
| `postinit` | Object body | Post-constructor hook | [Part I](foundation.md#52-instance-variables-has) |
| `props` | JSX context | Component props reference | [Part IV: Full-Stack](full-stack.md#21-client-side-development-jsx) |

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

## 15. Graph Construction

### 15.1 Creating Nodes

```jac
# Create and assign
alice = Person(name="Alice", age=30);
bob = Person(name="Bob", age=25);

# Inline creation in connection
root ++> Person(name="Charlie", age=35);
```

### 15.2 Creating Edges

```jac
# Untyped (generic edge)
alice ++> bob;

# Typed edge
alice +>: Friend(since=2020) :+> bob;

# Bidirectional typed
alice <+: Colleague(department="Engineering") :+> bob;
```

### 15.3 Chained Construction

```jac
# Build chains in one expression
root ++> a ++> b ++> c ++> d;

# With typed edges
root +>: Start :+> a +>: Next :+> b +>: Next :+> c +>: End :+> d;
```

### 15.4 Deleting Nodes and Edges

```jac
# Delete node
del node;

# Delete specific edge
alice del --> bob;

# Delete typed edge
alice del ->:Friend:-> bob;
```

### 15.5 Built-in Graph Functions

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
with entry {
    id = jid(alice);
    grant(secret_node, bob);
    save(alice);
    commit();
    printgraph(root);
}
```

---

## 16. Graph Traversal

### 16.1 Basic Traversal

Walker traversal is queue-based (BFS-like by default):

```jac
walker BFSWalker {
    can traverse with entry {
        print(f"Visiting: {here}");
        visit [-->];  # Queue all outgoing for later visits
    }
}
```

### 16.2 Filtered Traversal

```jac
walker FilteredWalker {
    can traverse with entry {
        # By node type
        visit [-->(`?Person)];

        # By attribute condition
        visit [--> (age > 25)];

        # By edge type
        visit [->:Friend:->];

        # Combined
        visit [->:Friend:since > 2020:->(`?Person)];
    }
}
```

### 16.3 Entry and Exit Events

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

## 17. Data Spatial Queries

### 17.1 Edge Reference Syntax

```jac
# Basic forms
[-->]                          # All outgoing nodes
[<--]                          # All incoming nodes
[<-->]                         # Both directions

# Typed forms
[->:EdgeType:->]              # Outgoing via EdgeType
[<-:EdgeType:<-]              # Incoming via EdgeType
[<-:EdgeType:->]              # Bidirectional via EdgeType

# With conditions
[->:Edge:attr > value:->]     # Filter by edge attribute
[->:Edge:a > 1, b < 5:->]     # Multiple conditions

# Node type filter
[-->(`?NodeType)]             # Filter result nodes by type

# Get edges vs nodes
[edge -->]                     # Get edge objects
[node -->]                     # Get node objects (explicit)
```

### 17.2 Attribute Filtering

```jac
# Filter by node attributes (after traversal)
adults = [-->](?age >= 18);
active_users = [-->](?status == "active", verified == True);

# Filter by edge attributes (during traversal)
recent_friends = [->:Friend:since > 2020:->];
strong_connections = [->:Link:weight > 0.8:->];
```

### 17.3 Complex Queries

```jac
# Chained traversal (multi-hop)
friends_of_friends = [here ->:Friend:-> ->:Friend:->];

# Mixed edge types
path = [here ->:Friend:-> ->:Colleague:->];

# Combined with filters
target = [->:Friend:since < 2020:->(`?Person)](?age > 30);
```

---

## 18. Typed Context Blocks

### 18.1 What are Typed Context Blocks?

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

### 18.2 Tuple-Based Dispatch

```jac
walker Processor {
    can process with (Node1, Node2) entry {
        # Handle when visiting involves both types
    }
}
```

### 18.3 Context Blocks in Nodes

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

### 18.4 Complex Typed Context Example

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
