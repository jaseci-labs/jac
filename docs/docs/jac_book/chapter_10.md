# Chapter 10: Advanced Object Spatial Operations
---
Now that you understand basic walkers and abilities, let's explore advanced patterns that make Object-Spatial Programming truly powerful. This chapter covers sophisticated filtering, visit control, and traversal patterns using familiar social network examples.


> Complex graph operations become intuitive when you move computation to data. Instead of loading entire datasets, walkers intelligently navigate only the relevant portions of your graph, making sophisticated queries both efficient and expressive.

## Advanced Filtering
---
In earlier chapters, we explored how to navigate and filter nodes based on type and attributes, as well as how to filter edges by type and metadata. These foundational operations enable us to traverse structured graphs intelligently. In this section, we’ll take those concepts further by applying them to a real-world-inspired scenario: a social graph that models people and their relationships.


### Usecase: Advanced Filtering in Social Networks

### Modeling Relationships with Attributes
We define a simple `Person` node type, representing individuals in a network:

```jac
node Person {
    has name: str;
    has age: int;
    has city: str;
}
```
And a custom edge type `FriendsWith`, representing social or family ties. This edge includes:
- `since`: the year the relationship began
- `closeness`: an integer score (1–10) to reflect relationship strength

```jac
edge FriendsWith {
    has since: str;
    has closeness: int;  # 1–10 scale
}
```
These edge attributes allow us to represent not just connections, but contextual strength and history—a key part of reasoning over real-world graphs.

### Building the Graph
We construct a small family network, establishing strong (`closeness = 10`) `FriendsWith` edges between parents and children:

```jac
with entry {
    # Create extended family network
    john = root ++> Person(name="John", age=45, city="NYC");
    emma = root ++> Person(name="Emma", age=43, city="NYC");
    alice = root ++> Person(name="Alice", age=20, city="SF");
    bob = root ++> Person(name="Bob", age=18, city="NYC");

    # Family relationships
    john +>:FriendsWith(since="1995", closeness=10):+> emma;
    [john[0], emma[0]] +>:FriendsWith(since="2004", closeness=10):+> alice;
    [john[0], emma[0]] +>:FriendsWith(since="2006", closeness=10):+> bob;
```

### Query 1: Filtering by Edge and Node Attributes
Let’s find all of John’s close family members under the age of 25. We’ll filter for:

- `FriendsWith` **edges with** `closeness == 10`
- `Person` **nodes where** `age < 25`

```jac
    young_family = [john[0]->:FriendsWith:closeness == 10:->(`?Person)](?age < 25);
    print("John's young family members:");
    for person in young_family {
        print(f"  {person.name}, age {person.age}");
    }
```
This combines edge filtering and post-traversal node filtering to answer a nuanced question: *Which people closely connected to John are young?*

### Query 2: Location-Based Filtering
Next, we want to find all people connected to John who currently live in **New York City**. This time, we don’t care about edge closeness—we’re only filtering the **target nodes**:

```jac
    nyc_connections = [john[0]->:FriendsWith:->(`?Person)](?city == "NYC");
    print(f"John's NYC connections:");
    for person in nyc_connections {
        print(f"  {person.name}");
    }
```
This is a great example of layered filtering, where edge traversal is followed by node-level projection.

### Query 3: Friends of Friends
Finally, we can go one step further and perform a 2-hop traversal, discovering John’s extended social network:

```jac
    friends_of_friends = [john[0]->:FriendsWith:->->:FriendsWith:->(`?Person)];
    print(f"Friend of friends: {len(friends_of_friends)} found");
    for person in friends_of_friends {
        print(f"  {person.name}");
    }
}
```
This query:
- Starts at John
- Follows one FriendsWith edge
- Then follows another from the intermediate person
- Collects any resulting people
This is equivalent to saying: “Show me who my friends are connected to,” and lays the foundation for building more advanced features like social distance estimation, recommendation systems, or community clustering.

### Putting It All Together
Here’s the complete code for our advanced filtering example:

```jac
node Person {
    has name: str;
    has age: int;
    has city: str;
}

edge FriendsWith {
    has since: str;
    has closeness: int; # 1-10 scale
}

with entry {
    # Create extended family network
    john = root ++> Person(name="John", age=45, city="NYC");
    emma = root ++> Person(name="Emma", age=43, city="NYC");
    alice = root ++> Person(name="Alice", age=20, city="SF");
    bob = root ++> Person(name="Bob", age=18, city="NYC");

    # Family relationships
    john +>:FriendsWith(since="1995", closeness=10):+> emma;  # Married
    [john[0], emma[0]] +>:FriendsWith(since="2004", closeness=10):+> alice;  # Parents
    [john[0], emma[0]] +>:FriendsWith(since="2006", closeness=10):+> bob;    # Parents

    # Find John's family members under 25
    young_family = [john[0]->:FriendsWith:closeness == 10:->(`?Person)](?age < 25);
    print("John's young family members:");
    for person in young_family {
        print(f"  {person.name}, age {person.age}");
    }

    # Find all people in NYC connected to John
    nyc_connections = [john[0]->:FriendsWith:->(`?Person)](?city == "NYC");
    print(f"John's NYC connections:");
    for person in nyc_connections {
        print(f"  {person.name}");
    }

    # Find friends of friends (2-hop connections)
    friends_of_friends = [john[0]->:FriendsWith:->->:FriendsWith:->(`?Person)];
    print(f"Friend of friends: {len(friends_of_friends)} found");
    for person in friends_of_friends {
        print(f"  {person.name}");
    }
}
```
<br />

```terminal
$ jac run foaf.jac

John's young family members:
  Alice, age 20
  Bob, age 18
John's NYC connections:
  Emma
  Bob
Friend of friends: 2 found
  Alice
  Bob

```

## Traversal Strategies: BFS and DFS with Walkers
---
In previous sections, we focused on how to filter nodes and edges during traversal. Now, we turn our attention to how the graph is actually traversed—that is, the order in which nodes are visited.

Two classic traversal strategies are:

- Breadth-First Search (BFS): visits all immediate neighbors before going deeper.
- Depth-First Search (DFS): dives deep along one path before backtracking.

In Jac, we can control traversal behavior explicitly through walker design, particularly by modifying how the `visit` command consumes nodes.

Let’s walk through an example that compares BFS and DFS in a family tree graph.

### The Graph: A Family Tree

We define a simple `Person` node with a `name` and a `level` attribute. The level indicates how far the node is from the root node in terms of generations.

```jac
node Person {
    has name: str;
    has level: int = 0;
}

edge ParentOf {}
```
We then construct a simple family tree with `ParentOf` edges connecting generations.

### BFS: Level-by-Level Traversal
In our `BFSWalker`, the traversal is performed using default queue semantics. This means that all neighbors at the current level are visited before any of their children:

```jac
walker BFSWalker {
    can traverse with Person entry {
        print(f"BFS visiting: {here.name} (level {here.level})");

        children = [->:ParentOf:->(`?Person)];
        for child in children {
            child.level = here.level + 1;
        }
        visit children;  # Queue-based order (breadth-first)
    }
}
```

### DFS: Deep Dive Traversal
In contrast, the `DFSWalker` uses the `:0:` modifier in the `visit` statement, which causes the walker to treat the visit list as a stack, resulting in depth-first behavior:

```jac
walker DFSWalker {
    can traverse with Person entry {
        print(f"DFS visiting: {here.name} (level {here.level})");

        children = [->:ParentOf:->(`?Person)];
        for child in children {
            child.level = here.level + 1;
        }
        visit :0: children;  # Stack-based order (depth-first)
    }
}
```

### Running the Walkers
We create a simple family tree and spawn both walkers to see how they traverse the graph:
```jac
with entry {
    # Create family tree
    grandpa = root ++> Person(name="Grandpa");
    dad = root ++> Person(name="Dad");
    mom = root ++> Person(name="Mom");
    child1 = root ++> Person(name="Alice");
    child2 = root ++> Person(name="Bob");
    grandchild = root ++> Person(name="Charlie");

    # Create relationships
    grandpa +>:ParentOf:+> dad;
    grandpa +>:ParentOf:+> mom;
    dad +>:ParentOf:+> child1;
    mom +>:ParentOf:+> child2;
    child1 +>:ParentOf:+> grandchild;

    print("=== Breadth-First Search ===");
    grandpa[0] spawn BFSWalker();

    # Reset levels
    all_people = [root-->(`?Person)];
    for person in all_people {
        person.level = 0;
    }

    print("=== Depth-First Search ===");
    grandpa[0] spawn DFSWalker();
}
```

```terminal
$ jac run family_tree.jac
=== Breadth-First Search ===
BFS visiting: Grandpa (level 0)
BFS visiting: Dad (level 1)
BFS visiting: Mom (level 1)
BFS visiting: Alice (level 2)
BFS visiting: Bob (level 2)
BFS visiting: Charlie (level 3)
=== Depth-First Search ===
DFS visiting: Grandpa (level 0)
DFS visiting: Dad (level 1)
DFS visiting: Alice (level 2)
DFS visiting: Charlie (level 3)
DFS visiting: Mom (level 1)
DFS visiting: Bob (level 2)
```

## Visit Patterns
---
Visit patterns control how walkers traverse your graph. The most powerful feature is indexed visiting using `:0:`, `:1:`, etc., which controls the order of traversal.


Visit patterns let you control exactly how walkers move through your graph - whether breadth-first, depth-first, or custom ordering based on your needs.

### Breadth-First vs Depth-First Traversal

```jac
node Person {
    has name: str;
    has level: int = 0;
}

edge ParentOf {}

walker BFSWalker {
    can traverse with Person entry {
        print(f"BFS visiting: {here.name} (level {here.level})");

        # Visit children - default queue behavior (breadth-first)
        children = [->:ParentOf:->(`?Person)];
        for child in children {
            child.level = here.level + 1;
        }
        visit children;
    }
}

walker DFSWalker {
    can traverse with Person entry {
        print(f"DFS visiting: {here.name} (level {here.level})");

        # Visit children with :0: (stack behavior for depth-first)
        children = [->:ParentOf:->(`?Person)];
        for child in children {
            child.level = here.level + 1;
        }
        visit :0: children;
    }
}

with entry {
    # Create family tree
    grandpa = root ++> Person(name="Grandpa");
    dad = root ++> Person(name="Dad");
    mom = root ++> Person(name="Mom");
    child1 = root ++> Person(name="Alice");
    child2 = root ++> Person(name="Bob");
    grandchild = root ++> Person(name="Charlie");

    # Create relationships
    grandpa +>:ParentOf:+> dad;
    grandpa +>:ParentOf:+> mom;
    dad +>:ParentOf:+> child1;
    mom +>:ParentOf:+> child2;
    child1 +>:ParentOf:+> grandchild;

    print("=== Breadth-First Search ===");
    grandpa[0] spawn BFSWalker();

    # Reset levels
    all_people = [root-->(`?Person)];
    for person in all_people {
        person.level = 0;
    }

    print("=== Depth-First Search ===");
    grandpa[0] spawn DFSWalker();
}
```


### Priority-Based Visiting

```jac
node Person {
    has name: str;
    has priority: int;
}

edge ConnectedTo {
    has strength: int;
}

walker PriorityWalker {
    can visit_by_priority with Person entry {
        print(f"Visiting: {here.name} (priority: {here.priority})");

        # Get all connections
        connections = [->:ConnectedTo:->(`?Person)];

        if connections {
            print(f"  Found {len(connections)} connections");
            for conn in connections {
                print(f"    {conn.name} (priority: {conn.priority})");
            }

            # Visit highest priority first using :0:
            visit :0: connections;
        }
    }
}

with entry {
    # Create network with different priorities
    center = root ++> Person(name="Center", priority=5);
    high_priority = root ++> Person(name="VIP", priority=10);
    medium_priority = root ++> Person(name="Regular", priority=5);
    low_priority = root ++> Person(name="Basic", priority=1);

    # Create connections
    center +>:ConnectedTo(strength=8):+> high_priority;
    center +>:ConnectedTo(strength=5):+> medium_priority;
    center +>:ConnectedTo(strength=3):+> low_priority;

    print("=== Priority-Based Traversal ===");
    center[0] spawn PriorityWalker();
}
```


## Best Practices
---

- **Plan traversal depth**: Use depth limits to prevent infinite loops
- **Cache expensive calculations**: Store results in walker state
- **Use early returns**: Skip unnecessary processing with guards
- **Implement backtracking**: Remove items from paths when backtracking
- **Optimize filters**: Apply most selective filters first
- **Consider performance**: Use indexed visits for better control over traversal order

## Key Takeaways
---
**Advanced Filtering:**

- **Multi-criteria queries**: Combine node properties, edge attributes, and relationships
- **Complex conditions**: Use logical operators and nested filters
- **Property-based selection**: Filter based on node and edge properties
- **Relationship filtering**: Navigate specific types of connections

**Visit Patterns:**

- **Traversal control**: Direct how walkers move through the graph
- **Breadth vs depth**: Choose appropriate traversal strategy
- **Priority-based visiting**: Use indexed visits for custom ordering
- **Performance optimization**: Control traversal for better efficiency

**Advanced Techniques:**

- **Smart visiting patterns**: Enable conditional and multi-path exploration
- **Complex traversals**: Make advanced algorithms like recommendations simple
- **Walker state management**: Enable backtracking and path discovery
- **Performance considerations**: Optimize for large graph structures

**Practical Applications:**

- **Social network analysis**: Find friends of friends and connection patterns
- **Recommendation systems**: Discover related items through graph traversal
- **Path finding**: Navigate through complex relationship networks
- **Data analysis**: Extract insights from connected information

!!! tip "Try It Yourself"
    Master advanced operations by building:
    - A recommendation engine using friend-of-friend patterns
    - A family tree analyzer with complex relationship queries
    - A social network explorer with priority-based traversal
    - A pathfinding system using breadth-first search

    Remember: Advanced operations enable sophisticated graph algorithms with simple, readable code!

---

*You've mastered advanced graph operations! Next, let's discover how walkers automatically become API endpoints.*
