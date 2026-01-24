# Your First Graph

Before building a full app, let's understand Jac's graph-based approach. This 5-minute tutorial introduces nodes, edges, and walkers.

---

## Why Graphs?

Most applications model relationships: users follow users, tasks belong to projects, messages form conversations. Jac makes these relationships first-class citizens through **graphs**.

A graph has:

- **Nodes** - data containers (like objects)
- **Edges** - connections between nodes
- **Walkers** - code that traverses the graph

---

## Step 1: Create a Node

Create `graph.jac`:

```jac
node Person {
    has name: str;
    has age: int;
}

with entry {
    alice = Person(name="Alice", age=30);
    print(f"Created: {alice.name}, age {alice.age}");
}
```

Run it:

```bash
jac run graph.jac
```

Output:

```
Created: Alice, age 30
```

**What's happening:**

| Part | Meaning |
|------|---------|
| `node Person` | Defines a node type (like a class) |
| `has name: str` | Declares an attribute with type |
| `Person(...)` | Creates a node instance |

---

## Step 2: Connect Nodes

Every Jac program has a `root` node - the starting point of your graph. Let's connect nodes to it:

```jac
node Person {
    has name: str;
}

with entry {
    # Create nodes connected to root
    root ++> Person(name="Alice");
    root ++> Person(name="Bob");
    root ++> Person(name="Charlie");

    print("Created 3 people connected to root");
}
```

The `++>` operator creates a node and connects it in one step:

```
    root
   / | \
  /  |  \
Alice Bob Charlie
```

---

## Step 3: Query the Graph

Use `[-->]` to get nodes connected to the current node:

```jac
node Person {
    has name: str;
}

with entry {
    # Create nodes
    root ++> Person(name="Alice");
    root ++> Person(name="Bob");
    root ++> Person(name="Charlie");

    # Query all connected Person nodes
    people = [-->](`?Person);

    print("People in the graph:");
    for person in people {
        print(f"  - {person.name}");
    }
}
```

Output:

```
People in the graph:
  - Alice
  - Bob
  - Charlie
```

**What's happening:**

| Part | Meaning |
|------|---------|
| `[-->]` | Get nodes connected via outgoing edges |
| `` `?Person `` | Filter: only Person nodes |

---

## Step 4: Build a Chain

Nodes can connect to other nodes, not just root:

```jac
node Message {
    has text: str;
}

with entry {
    # Build a chain: root -> msg1 -> msg2 -> msg3
    msg1 = root ++> Message(text="Hello");
    msg2 = msg1 ++> Message(text="How are you?");
    msg3 = msg2 ++> Message(text="Goodbye");

    # Access each message
    print(msg1.text);
    print(msg2.text);
    print(msg3.text);
}
```

Output:

```
Hello
How are you?
Goodbye
```

The graph now looks like:

```
root -> "Hello" -> "How are you?" -> "Goodbye"
```

---

## Step 5: Introduce Walkers

Manually traversing graphs gets tedious. **Walkers** automate this - they're code that walks through the graph:

```jac
node Person {
    has name: str;
}

walker Greeter {
    can greet with Person entry {
        print(f"Hello, {here.name}!");
        visit [-->];  # Continue to connected nodes
    }
}

with entry {
    # Create a chain of people
    p1 = root ++> Person(name="Alice");
    p2 = p1 ++> Person(name="Bob");
    p3 = p2 ++> Person(name="Charlie");

    # Start the walker at the first person
    p1 spawn Greeter();
}
```

Output:

```
Hello, Alice!
Hello, Bob!
Hello, Charlie!
```

**What's happening:**

| Part | Meaning |
|------|---------|
| `walker Greeter` | Defines a walker (mobile code) |
| `can greet with Person entry` | Runs when entering a Person node |
| `here` | The current node the walker is on |
| `visit [-->]` | Move to connected nodes |
| `p1 spawn Greeter()` | Start the walker at p1 |

---

## Key Concepts Summary

| Concept | Syntax | Purpose |
|---------|--------|---------|
| **Node** | `node Name { has attr: type; }` | Data container in the graph |
| **Root** | `root` | Every graph's starting point |
| **Connect** | `a ++> b` | Create edge from a to b |
| **Query** | `[-->]` | Get connected nodes |
| **Walker** | `walker Name { can ... }` | Code that traverses the graph |
| **Spawn** | `node spawn Walker()` | Start a walker at a node |
| **Visit** | `visit [-->]` | Move walker to connected nodes |

---

## Quick Reference: Graph Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `++>` | Create and connect node | `root ++> Person()` |
| `[-->]` | Get outgoing neighbors | `[-->](\`?Person)` |
| `[<--]` | Get incoming neighbors | `[<--](\`?Message)` |
| `spawn` | Start walker at node | `root spawn MyWalker()` |
| `visit` | Move walker to nodes | `visit [-->]` |

For more details, see [Graph Operations](../reference/language/graph-operations.md).

---

## Next Steps

Now you understand the basics of graph programming in Jac:

- **Ready to build?** → [Your First App](first-app.md) - Build a complete todo application
- **Want more theory?** → [Object-Spatial Programming](../tutorials/language/osp.md) - Deep dive into nodes, edges, and walkers
