# Jac Quickstart

This document will give you a quick start on Object-Spatial Programming(OSP), the core feature of Jac.
For a short overview of the language syntax, refer to the [Syntax Quick Reference](./syntax_quick_reference.md).
If using byLLM in Python, refer to its [documentation](./jac-byllm/python_integration.md).

## Python Superset

Jac is a drop-in replacement for Python and supersets Python, much like Typescript supersets Javascript or C++ supersets C. It extends Python's semantics while maintaining full interoperability with the Python ecosystem.
Anything you can build with Python, you can build in Jac, and often more efficiently.

<!-- small syntax teaser, idk if there is a more iconic python library-->
<div class="code-block">
```jac

def example(){
    number = 1+2;
    print(f"Calculated {number}");
    if number < 4 {
        print("Small number");
    }
}

# jac's equivalent of main

with entry {
    print("Hello world!");
    example();
}

```
</div>

<!-- distilled from jason's blog: https://www.mars.ninja/blog/2025/10/26/four-things-object-spatial-programming/, using Kimi-K2 thinking -->
## Graphs and OSP
One of the core features of Jac is its ability to represent graphs natively in the type system. This enables Object-Spatial Programming (OSP), a paradigm where computation moves through spatially connected objects rather than calling methods on isolated ones.

### Why This Matters for OOP Programmers

If you've worked with graphs in traditional OOP, you've likely faced this pattern: create a `Node` class with a `List<Node> connections`, manually manage adjacency lists, and write recursive functions that risk stack overflow. OSP eliminates this boilerplate by making graph structures a first-class citizen.

**The key difference is the shift from "bring data to computation" (calling methods) to "send computation to data" (traversing graphs).** When your problem domain involves relationships such as social networks, dependency trees, and knowledge graphs. OSP models these naturally rather than forcing them into nested collections.

For example, finding all "friends of friends who aren't direct friends" in OOP requires nested loops and manual filtering. In OSP, you write `[alice ->:Friend:-> ->:Friend:->]` and the language handles the traversal.

---

### Object Spatial Model

In OSP, objects are not isolated. They exist in space with explicit relationships. Critically, **nodes and edges are full-featured classes** that inherit all OOP capabilities (methods, inheritance, polymorphism) and add spatial semantics.

**Nodes: Spatial Classes**

Start by defining nodes as you would regular classes. At this stage, they behave exactly like OOP objects, no graph concepts needed yet:

<div class="code-block">
```jac
node Person {
    has name: str;
    has age: int;

    def greet -> str {
        return f"Hello, I'm {self.name}!";
    }

    def celebrate_birthday {
        self.age += 1;
        print(f"{self.name} is now {self.age}!");
    }
}

with entry {
    alice = Person(name="Alice", age=25);
    bob = Person(name="Bob", age=30);
    print(alice.greet());  # Standard method call
}
```

</div>

The output behavior is standard for OOP: "Hello, I'm Alice! Alice is now 26!"
The graph capability is dormant until you connect nodes.

**Spatial Operators: Making Connections**

This is where OSP diverges. Instead of managing a `list` property, you use **spatial operators** to create first-class relationships that the type system understands:

<div class="code-block run-dot">
```jac

node Person {
    has name: str;
    has age: int;
}

with entry {
    alice = Person(name="Alice", age=25);
    bob = Person(name="Bob", age=30);
    root ++> alice;
    alice ++> bob;      # Alice → Bob (forward relationship)
    alice <++ bob;      # Bob → Alice (backward)
    alice <++> bob;     # Alice ↔ Bob (bidirectional)
}

# You now have a graph structure where relationships exist

# independently of any object's internal state

```
</div>

Behind the scenes, Jac maintains adjacency information, allowing queries like `[alice -->]` to return connected nodes without you writing traversal logic.

**Typed Edges: First-Class Relationships**

The real breakthrough: **relationships are classes**. Unlike OOP where you'd store relationship data as strings in a dictionary, edges have methods, properties, and type safety:

<div class="code-block run-dot">
```jac
node Person {
    has name: str;
    has age: int;
}

edge Friend {
    has since: int;
    has strength: int = 5;

    def is_strong -> bool {
        return self.strength >= 7;
    }
}

with entry {
    alice = Person(name="Alice", age=25);
    bob = Person(name="Bob", age=30);

    root ++> alice
    alice +>:Friend(since=2015, strength=9):+> bob;

    # Query all Friend relationships from alice
    friends = [alice ->:Friend:->];
    print(f"Alice has {len(friends)} friend(s)");

    # The result is a list of Person nodes, not data structures you have to unpack
}
```

</div>

This creates a graph edge that "knows" it's a friendship and can answer questions about itself. Visualizing `alice ->:Friend:->` returns the actual `bob` node, ready for method calls.

**Querying with Edge References: Declarative Traversal**

Use bracket syntax to query the graph without loops:

```jac
# All outgoing connections (any type)
all_out = [alice -->];

# Only Friend edges
type_out = [alice ->:Friend:->];

# Friend edges filtered by property
filtered = [alice ->:Friend:since < 2018:->];

# Each query returns a list of connected nodes, ready to use
```

Think of `[alice ->:Friend:->]` as a declarative path specification: "From alice, follow outgoing Friend edges to their targets." The runtime handles the graph traversal.

**Operator Reference**

| Operator | Direction | Example | Result |
|----------|-----------|---------|--------|
| `++>` | Forward | `alice ++> bob;` | Creates alice → bob |
| `<++` | Backward | `alice <++ bob;` | Creates bob → alice |
| `<++>` | Both ways | `alice <++> bob;` | Creates alice ↔ bob |
| `[node -->]` | Outgoing query | Any type | Returns list of nodes |
| `[node ->:Type:->]` | Typed query | Specific edge type | Returns filtered nodes |
| `[node ->:Type:prop > 5:->]` | Filtered query | Property-based | Returns filtered nodes |

**Full OOP Support with Inheritance**

Nodes and edges support all OOP features: inheritance, polymorphism, interfaces:

```jac
node Entity {
    has id: str;
    has created: str;
}

node Person(Entity) {
    has email: str;
    def notify(msg: str) {
        print(f"To {self.email}: {msg}");
    }
}

# Person inherits from Entity, gets id/created fields
# plus its own email field and notify method
```

---

### Walkers: Mechanism for Mobile Computation

**Walkers are autonomous agents** represented by classes that can travel through your graph. Instead of calling methods on objects and bringing data to your function, you spawn a walker that visits nodes where the data lives.

**Basic Walker: Visiting Nodes**

<div class="code-block run-dot">
```jac
node Person {
    has name: str;
    has age: int;
}

walker Greeter {
    has greeting_count: int = 0;

    can start with `root entry {
        print("Starting journey!");
        visit [-->];  # Begin traversal from root's outgoing edges
    }

    can greet with Person entry {
        print(f"Hello, {here.name}!");  # 'here' is current node
        self.greeting_count += 1;
        visit [-->];  # Continue to next node's connections
    }
}

with entry {
    alice = Person(name="Alice");
    bob = Person(name="Bob");

    root ++> alice ++> bob;
    root spawn Greeter();  # Launch walker, it navigates autonomously
}

```
</div>

What happens: `Greeter` spawns at `root`, executes `start` ability, then `visit [-->` sends it to `alice`. The `greet` ability triggers (because `alice` is a `Person`), prints, increments counter, then `visit [-->]` moves it to `bob`. This continues until no unvisited nodes remain.

**Walker Structure: State + Abilities**

```jac
walker DataCollector {
    has counter: int = 0;          # Walker state, persists across visits
    has visited_names: list = [];  # Accumulates data during traversal

    can collect with NodeType entry {  # Executes when visiting NodeType
        self.visited_names.append(here.name);
        self.counter += 1;
        visit [-->];  # Default: depth-first traversal
    }
}
```

Think of walkers as lightweight threads that carry their own state and navigate via graph edges rather than function calls.

**Special References: Context in Abilities**

Inside walker abilities, these references are always available:

| Reference | Meaning | Example |
|-----------|---------|---------|
| `self` | Walker instance | `self.counter += 1` |
| `here` | Current node being visited | `print(here.name)` |
| `root` | Global root node | `root spawn MyWalker()` |

`here` is the game-changer: it gives you the actual node object, so you can call its methods and access its properties as if you were inside a method call, while being inside a traversal instead.

**Navigation Patterns: Controlling the Journey**

```jac
walker Explorer {
    can explore with Person entry {
        # Visit all outgoing connections (depth-first)
        visit [-->];

        # Visit only Friend edges
        visit [->:Friend:->];

        # Friend edges with strength > 5
        visit [->:Friend:strength > 5:->];
    }
}
```

Each `visit` statement creates a branching point: the walker visits all matching nodes in sequence, maintaining its state.

**Search Pattern: Finding a Specific Node**

```jac
walker FindPerson {
    has target: str;
    has found: bool = False;

    can search with Person entry {
        if here.name == self.target {
            self.found = True;
            disengage;  # Stop immediately, don't visit further
        }
        visit [-->];  # Keep searching if not found
    }
}
```

`disengage` is the walker's "return early" mechanism. Unlike a function returning, it halts the walker's entire traversal, even if midway through visiting nodes.

---

### Abilities: Event-Driven Interaction Model

Abilities define **what happens when walkers and nodes meet**. They automatically execute based on type matching, creating an event-driven system instead of explicit method calls.

**Walker Abilities: When Walkers Visit Nodes**

From the walker's perspective, you define what to do at each node type:

```jac
walker Tourist {
    can meet_person with Person entry {
        print(f"Met {here.name}, age {here.age}");
        visit [-->];
    }

    can visit_city with City entry {
        print(f"Visiting {here.name}, pop {here.population}");
        visit [-->];
    }
}
```

When `Tourist` visits a `Person`, only `meet_person` executes. When it visits a `City`, only `visit_city` executes. This is **automatic type-based dispatch**, no if-statements checking types.

**Node Abilities: When Nodes Receive Visitors**

Nodes can also define abilities triggered by specific walker types:

```jac
node Person {
    has name: str;

    can receive_greeting with Greeter entry {
        print(f"{self.name} acknowledges greeting");
    }
}
```

Now when a `Greeter` walker visits, the node responds. This separates concerns: the walker handles traversal logic, the node handles domain logic.

**Bidirectional Execution: The OSP Revolution**

Here's what makes OSP unique: **both node AND walker abilities execute** when they match:

```jac
node Person {
    can greet_visitor with Visitor entry {
        print(f"{self.name} says: Welcome!");  # Executes first
    }
}

walker Visitor {
    can meet_person with Person entry {
        print(f"Visitor says: Hello, {here.name}!");  # Executes second
        visit [-->];
    }
}
```

Execution order: **node ability first**, then walker ability. This bidirectional interaction contract means you can:

- Nodes validate/prepare state before walker acts
- Walkers implement generic algorithms that any node can customize
- Achieve double-dispatch polymorphism without visitor pattern boilerplate

In traditional OOP, you'd need the Visitor Pattern with its awkward `accept(Visitor v)` methods. OSP abilities give you the same power declaratively.

---

### Navigation: Controlling Traversal and Collecting Results

**Visit Strategies: Sophisticated Pathfinding**

```jac
# Visit immediate neighbors
visit [-->];

# Visit only via Friend edges
visit [->:Friend:->];

# Visit via Friend edges from before 2020
visit [->:Friend:since < 2020:->];

# Multi-hop: friends of friends
visit [here ->:Friend:-> ->:Friend:->];
```

Each pattern specifies a path expression: "from current node, follow these edges, then from those nodes, follow these edges." The runtime materializes all matching paths.

**Result Collection: `report` vs `return`**

Unlike functions that `return` once, walkers use `report` to stream multiple values while continuing traversal:

```jac
walker AgeCollector {
    has ages: list = [];

    can collect with Person entry {
        self.ages.append(here.age);  # Accumulate in walker state
        visit [-->];
    }
}

# After execution: walker.ages contains [25, 30, 28]
```

`report` is for streaming during traversal; accumulator fields are for collecting at the end.

**Control Flow: Stopping Early with `disengage`**

```jac
walker FindFirstMatch {
    can search with Person entry {
        if here.name == self.target {
            report here;  # Send back the node
            disengage;    # Stop traversing immediately
        }
        visit [-->];
    }
}
```

`disengage` halts the walker, similar to breaking out of a nested loop, but works across the entire graph traversal.

**Complete Example: Dependency Resolution**

```jac
node Task {
    has title: str;
    has status: str = "pending";
}

edge DependsOn {}

walker TaskAnalyzer {
    has ready_tasks: list = [];

    can analyze with Task entry {
        if here.status != "pending": return;

        # Get all dependencies
        deps = [here ->:DependsOn:->];

        # Check if all complete
        all_done = all(dep.status == "complete" for dep in deps);

        if all_done {
            self.ready_tasks.append(here.title);
        }

        visit [-->];  # Continue to next task
    }
}

# Usage: spawn analyzer, then check analyzer.ready_tasks
```

This walker traverses the entire task graph, identifies completed dependencies, and collects tasks ready to execute, without explicit recursion or stack management.

**Traversal Control Summary**

| Mechanism | Purpose | Stops Walker? |
|-----------|---------|---------------|
| `visit [pattern];` | Navigate to new nodes | No |
| `report value;` | Stream result back | No |
| `disengage;` | Stop immediately | Yes |
| `return;` | Exit current ability | No |

---

## Next Steps

Jac contains many more features!

**Want to start building?** We have a [Syntax Quick Reference](./syntax_quick_reference.md) to make it easier to write jac.

**Working on Agentic AI?** [byLLM](./jac-byllm/with_llm.md) provides an interface to greatly simplify prompt engineering workflows.

**Scaling up to a production application?** [jac-scale](../jac-scale/README.md) provides Scale-Native tooling to seamlessly deploy OSP to the cloud.

<!-- eventually, the onelang -->
