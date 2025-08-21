# Chapter 11: Advanced Object Spatial Operations

Now that you understand basic walkers and abilities, let's explore advanced patterns that make Object-Spatial Programming truly powerful. This chapter covers sophisticated filtering, visit control, and traversal patterns using familiar social network examples.

!!! topic "Advanced Graph Operations Philosophy"
    Complex graph operations become intuitive when you move computation to data. Instead of loading entire datasets, walkers intelligently navigate only the relevant portions of your graph, making sophisticated queries both efficient and expressive.

## Advanced Filtering

Advanced filtering allows you to create sophisticated queries that combine multiple criteria, making complex graph searches simple and readable.

!!! topic "Multi-Criteria Graph Queries"
    Advanced filtering combines relationship traversal, node properties, and complex conditions to find exactly the data you need.

### Property-Based Filtering

!!! example "Finding Specific People"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        class Person:
            def __init__(self, name: str, age: int, city: str):
                self.name = name
                self.age = age
                self.city = city
                self.friendships = []

        class FriendsWith:
            def __init__(self, person1: Person, person2: Person, since: str, closeness: int):
                self.person1 = person1
                self.person2 = person2
                self.since = since
                self.closeness = closeness
                person1.friendships.append(self)
                person2.friendships.append(self)

        # Create a social network
        alice = Person("Alice", 25, "NYC")
        bob = Person("Bob", 30, "SF")
        charlie = Person("Charlie", 22, "NYC")
        diana = Person("Diana", 28, "LA")

        # Create friendships
        friendship1 = FriendsWith(alice, bob, "2020", 8)
        friendship2 = FriendsWith(alice, charlie, "2021", 9)
        friendship3 = FriendsWith(bob, diana, "2019", 6)

        all_people = [alice, bob, charlie, diana]

        # Find all young people in NYC (age < 25)
        young_nyc = [p for p in all_people if p.age < 25 and p.city == "NYC"]
        print("Young people in NYC:")
        for person in young_nyc:
            print(f"  {person.name}, age {person.age}")

        # Find Alice's close friends (closeness >= 8)
        close_friends = []
        for friendship in alice.friendships:
            if friendship.closeness >= 8:
                friend = friendship.person2 if friendship.person1 == alice else friendship.person1
                close_friends.append(friend)

        print(f"\nAlice's close friends:")
        for friend in close_friends:
            print(f"  {friend.name}")

        # Find all friendships that started before 2021
        all_friendships = [friendship1, friendship2, friendship3]
        old_friendships = [f for f in all_friendships if f.since < "2021"]
        print(f"\nOld friendships: {len(old_friendships)} found")
        ```

### Complex Relationship Filtering

!!! example "Multi-Hop Filtering"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        # Extended family network
        john = Person("John", 45, "NYC")
        emma = Person("Emma", 43, "NYC")
        alice = Person("Alice", 20, "SF")
        bob = Person("Bob", 18, "NYC")

        # Family relationships
        family_relationships = [
            FriendsWith(john, emma, "1995", 10),  # Married
            FriendsWith(john, alice, "2004", 10),  # Parent
            FriendsWith(emma, alice, "2004", 10),  # Parent
            FriendsWith(john, bob, "2006", 10),    # Parent
            FriendsWith(emma, bob, "2006", 10)     # Parent
        ]

        all_people = [john, emma, alice, bob]

        # Find John's family members under 25
        john_connections = []
        for friendship in john.friendships:
            if friendship.closeness == 10:
                connected_person = friendship.person2 if friendship.person1 == john else friendship.person1
                john_connections.append(connected_person)

        young_family = [p for p in john_connections if p.age < 25]
        print("John's young family members:")
        for person in young_family:
            print(f"  {person.name}, age {person.age}")

        # Find all people in NYC connected to John
        nyc_connections = [p for p in john_connections if p.city == "NYC"]
        print(f"\nJohn's NYC connections:");
        for person in nyc_connections {
            print(f"  {person.name}");
        }

        # Find friends of friends (simplified)
        friends_of_friends = []
        for direct_friend in john_connections:
            for friendship in direct_friend.friendships:
                indirect_friend = friendship.person2 if friendship.person1 == direct_friend else friendship.person1
                if indirect_friend != john and indirect_friend not in john_connections:
                    friends_of_friends.append(indirect_friend)

        print(f"\nFriend of friends: {len(set(f.name for f in friends_of_friends))} found")
        for person in set(friends_of_friends):
            print(f"  {person.name}")
        ```

## Visit Patterns

Visit patterns control how walkers traverse your graph. The most powerful feature is indexed visiting using `:0:`, `:1:`, etc., which controls the order of traversal.

!!! topic "Controlling Walker Navigation"
    Visit patterns let you control exactly how walkers move through your graph - whether breadth-first, depth-first, or custom ordering based on your needs.

### Breadth-First vs Depth-First Traversal

!!! example "BFS vs DFS Walker Behavior"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        from collections import deque

        class Person:
            def __init__(self, name: str):
                self.name = name
                self.level = 0
                self.children = []

        class FamilyTraverser:
            def bfs_traversal(self, start_person: Person):
                queue = deque([start_person])
                visited = set()

                while queue:
                    person = queue.popleft()
                    if person in visited:
                        continue

                    visited.add(person)
                    print(f"BFS visiting: {person.name} (level {person.level})")

                    for child in person.children:
                        if child not in visited:
                            child.level = person.level + 1
                            queue.append(child)

            def dfs_traversal(self, person: Person, visited=None):
                if visited is None:
                    visited = set()

                if person in visited:
                    return

                visited.add(person)
                print(f"DFS visiting: {person.name} (level {person.level})")

                for child in person.children:
                    if child not in visited:
                        child.level = person.level + 1
                        self.dfs_traversal(child, visited)

        # Create family tree
        grandpa = Person("Grandpa")
        dad = Person("Dad")
        mom = Person("Mom")
        child1 = Person("Alice")
        child2 = Person("Bob")
        grandchild = Person("Charlie")

        # Create relationships
        grandpa.children = [dad, mom]
        dad.children = [child1]
        mom.children = [child2]
        child1.children = [grandchild]

        traverser = FamilyTraverser()

        print("=== Breadth-First Search ===")
        traverser.bfs_traversal(grandpa)

        # Reset levels
        all_people = [grandpa, dad, mom, child1, child2, grandchild]
        for person in all_people:
            person.level = 0

        print("\n=== Depth-First Search ===")
        traverser.dfs_traversal(grandpa)
        ```

### Priority-Based Visiting

!!! example "Custom Visit Ordering"
    === "Jac"
        <div class="code-block">
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
        </div>
    === "Python"
        ```python
        class Person:
            def __init__(self, name: str, priority: int):
                self.name = name
                self.priority = priority
                self.connections = []

        class ConnectedTo:
            def __init__(self, person1: Person, person2: Person, strength: int):
                self.strength = strength
                person1.connections.append(person2)

        class PriorityWalker:
            def __init__(self):
                self.visited = set()

            def visit_by_priority(self, person: Person):
                if person in self.visited:
                    return

                self.visited.add(person)
                print(f"Visiting: {person.name} (priority: {person.priority})")

                if person.connections:
                    # Sort by priority (highest first)
                    connections = sorted(
                        [p for p in person.connections if p not in self.visited],
                        key=lambda p: p.priority,
                        reverse=True
                    )

                    print(f"  Found {len(connections)} connections")
                    for conn in connections:
                        print(f"    {conn.name} (priority: {conn.priority})")

                    # Visit highest priority first
                    for conn in connections:
                        self.visit_by_priority(conn)

        # Create network with different priorities
        center = Person("Center", 5)
        high_priority = Person("VIP", 10)
        medium_priority = Person("Regular", 5)
        low_priority = Person("Basic", 1)

        # Create connections
        ConnectedTo(center, high_priority, 8)
        ConnectedTo(center, medium_priority, 5)
        ConnectedTo(center, low_priority, 3)

        print("=== Priority-Based Traversal ===")
        walker = PriorityWalker()
        walker.visit_by_priority(center)
        ```

## Best Practices

!!! summary "Advanced Operation Guidelines"
    - **Plan traversal depth**: Use depth limits to prevent infinite loops
    - **Cache expensive calculations**: Store results in walker state
    - **Use early returns**: Skip unnecessary processing with guards
    - **Implement backtracking**: Remove items from paths when backtracking
    - **Optimize filters**: Apply most selective filters first
    - **Consider performance**: Use indexed visits for better control over traversal order

## Key Takeaways

!!! summary "What We've Learned"
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
