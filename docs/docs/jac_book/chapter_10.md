# Chapter 10: Advanced Object Spatial Operations
---
Now that you understand basic walkers and abilities, let's explore advanced patterns that make Object-Spatial Programming truly powerful. This chapter covers sophisticated filtering, visit control, and traversal patterns using familiar social network examples.


> Complex graph operations become intuitive when you move computation to data. Instead of loading entire datasets, walkers intelligently navigate only the relevant portions of your graph, making sophisticated queries both efficient and expressive.

## Advanced Filtering
---
Advanced filtering allows you to create sophisticated queries that combine multiple criteria, making complex graph searches simple and readable.



### Property-Based Filtering

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
    # Create a social network
    alice = root ++> Person(name="Alice", age=25, city="NYC");
    bob = root ++> Person(name="Bob", age=30, city="SF");
    charlie = root ++> Person(name="Charlie", age=22, city="NYC");
    diana = root ++> Person(name="Diana", age=28, city="LA");

    # Create friendships
    alice +>:FriendsWith(since="2020", closeness=8):+> bob;
    alice +>:FriendsWith(since="2021", closeness=9):+> charlie;
    bob +>:FriendsWith(since="2019", closeness=6):+> diana;

    # Find all young people in NYC (age < 25)
    nyc = [root-->(`?Person)](?city == "NYC");
    print("People in NYC:");
    for person in nyc {
        print(f"  {person.name}, age {person.age}");
    }
    young_nyc = nyc(?age < 25);
    print("Young people in NYC:");
    for person in young_nyc {
        print(f"  {person.name}, age {person.age}");
    }

    # Find Alice's close friends (closeness >= 8)
    close_friends = [alice->:FriendsWith:closeness >= 8:->(`?Person)];
    print(f"Alice's close friends:");
    for friend in close_friends {
        print(f"  {friend.name}");
    }

    # Find all friendships that started before 2021
    old_friendships = [root->:FriendsWith:since < "2021":->];
    print(f"Old friendships: {len(old_friendships)} found");
}
```


### Complex Relationship Filtering

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

    print("\n=== Depth-First Search ===");
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
