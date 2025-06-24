# Chapter 1: Introduction to Jac

Welcome to Jac, a revolutionary programming language that transforms how we think about computation and data relationships. This chapter introduces you to Jac's core concepts and shows why it represents a fundamental shift in programming paradigms.

!!! topic "What Makes Jac Different"
    Jac introduces Object-Spatial Programming (OSP), where computation moves to data rather than data moving to computation, enabling naturally distributed and scale-agnostic applications.

## What is Jac and Why It Exists

Jac emerged from the need to better handle interconnected, graph-like data structures that are common in modern applications - social networks, knowledge graphs, distributed systems, and AI workflows. Traditional programming languages treat relationships as secondary concerns, but Jac makes them first-class citizens.

### The Problem with Traditional Programming

In traditional programming, we model relationships awkwardly:

!!! example "Traditional Relationship Modeling"
    === "Python"
        ```python
        # Traditional approach - relationships are just lists
        class Person:
            def __init__(self, name):
                self.name = name
                self.friends = []  # Just a list reference

            def add_friend(self, friend):
                self.friends.append(friend)
                friend.friends.append(self)  # Manual bidirectional setup

            def find_mutual_friends(self, other):
                return [f for f in self.friends if f in other.friends]

        # Create people and relationships
        alice = Person("Alice")
        bob = Person("Bob")
        charlie = Person("Charlie")

        # Manually manage relationships
        alice.add_friend(bob)
        bob.add_friend(charlie)

        # Complex traversal logic
        mutual = alice.find_mutual_friends(charlie)
        print(f"Alice and Charlie mutual friends: {[f.name for f in mutual]}")
        ```
    === "Jac"
        <div class="code-block">
        ```jac
        # Jac approach - relationships are spatial connections
        node Person {
            has name: str;
        }

        edge FriendsWith;

        with entry {
            # Create people
            alice = root ++> Person(name="Alice");
            bob = root ++> Person(name="Bob");
            charlie = root ++> Person(name="Charlie");

            # Create relationships naturally
            alice +>:FriendsWith:+> bob +>:FriendsWith:+> charlie;

            # Find mutual friends through graph traversal
            mutual_friends = [alice->:FriendsWith:->(`?Person)](?name != "Alice") and [charlie->:FriendsWith:->(`?Person)](?name != "Charlie");

            print("Alice and Charlie's mutual friends:");
            for friend in mutual_friends {
                print(f"  {friend.name}");
            }
        }
        ```
        </div>

The Jac version is not only more concise but also naturally handles the spatial relationships between entities.

## Object-Spatial Programming Paradigm Overview

Object-Spatial Programming (OSP) is built on three fundamental concepts:

!!! topic "OSP Core Concepts"
    - **Nodes**: Stateful entities that hold data
    - **Edges**: Typed relationships between nodes
    - **Walkers**: Mobile computation that traverses the graph

### Nodes: Data with Location

Nodes are like enhanced objects that exist in a spatial graph:

!!! example "Node Definition"
    === "Jac"
        <div class="code-block">
        ```jac
        node User {
            has username: str;
            has email: str;
            has created_at: str;
        }

        node Post {
            has title: str;
            has content: str;
            has likes: int = 0;
        }

        with entry {
            # Create nodes in the graph
            user = root ++> User(
                username="alice",
                email="alice@example.com",
                created_at="2024-01-01"
            );

            post = user ++> Post(
                title="Hello Jac!",
                content="My first post in Jac"
            );

            print(f"User {user[0].username} created post: {post[0].title}");
        }
        ```
        </div>
    === "Python"
        ```python
        from datetime import datetime

        class User:
            def __init__(self, username, email, created_at):
                self.username = username
                self.email = email
                self.created_at = created_at
                self.posts = []  # Manual relationship management

        class Post:
            def __init__(self, title, content, likes=0):
                self.title = title
                self.content = content
                self.likes = likes
                self.author = None  # Manual back-reference

        # Create objects
        user = User("alice", "alice@example.com", "2024-01-01")
        post = Post("Hello Python!", "My first post in Python")

        # Manually manage relationships
        user.posts.append(post)
        post.author = user

        print(f"User {user.username} created post: {post.title}")
        ```

### Edges: First-Class Relationships

Edges represent typed connections between nodes:

!!! example "Edge Relationships"
    === "Jac"
        <div class="code-block">
        ```jac
        node Person {
            has name: str;
            has age: int;
        }

        edge FamilyRelation {
            has relationship_type: str;
        }

        with entry {
            # Create family members
            parent = root ++> Person(name="John", age=45);
            child1 = root ++> Person(name="Alice", age=20);
            child2 = root ++> Person(name="Bob", age=18);

            # Create family relationships
            parent +>:FamilyRelation(relationship_type="parent"):+> child1;
            parent +>:FamilyRelation(relationship_type="parent"):+> child2;
            child1 +>:FamilyRelation(relationship_type="sibling"):+> child2;

            # Query relationships
            children = [parent[0]->:FamilyRelation:relationship_type=="parent":->(`?Person)];

            print(f"{parent[0].name} has {len(children)} children:");
            for child in children {
                print(f"  - {child.name} (age {child.age})");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        class Person:
            def __init__(self, name, age):
                self.name = name
                self.age = age
                self.relationships = {}  # Manual relationship tracking

        class FamilyRelation:
            def __init__(self, from_person, to_person, relationship_type):
                self.from_person = from_person
                self.to_person = to_person
                self.relationship_type = relationship_type

        # Create family members
        parent = Person("John", 45)
        child1 = Person("Alice", 20)
        child2 = Person("Bob", 18)

        # Create relationships manually
        relations = [
            FamilyRelation(parent, child1, "parent"),
            FamilyRelation(parent, child2, "parent"),
            FamilyRelation(child1, child2, "sibling")
        ]

        # Query relationships manually
        children = [r.to_person for r in relations
                   if r.from_person == parent and r.relationship_type == "parent"]

        print(f"{parent.name} has {len(children)} children:")
        for child in children:
            print(f"  - {child.name} (age {child.age})")
        ```

### Walkers: Mobile Computation

Walkers are computational entities that move through the graph:

!!! example "Walker Traversal"
    === "Jac"
        <div class="code-block">
        ```jac
        node Person {
            has name: str;
            has visited: bool = False;
        }

        edge FriendsWith;

        walker GreetFriends {
            can greet with Person entry {
                if not here.visited {
                    here.visited = True;
                    print(f"Hello, {here.name}!");

                    # Visit all friends
                    visit [->:FriendsWith:->];
                }
            }
        }

        with entry {
            # Create friend network
            alice = root ++> Person(name="Alice");
            bob = root ++> Person(name="Bob");
            charlie = root ++> Person(name="Charlie");

            # Connect friends
            alice +>:FriendsWith:+> bob +>:FriendsWith:+> charlie;
            alice +>:FriendsWith:+> charlie;  # Alice also friends with Charlie

            # Spawn walker to greet everyone
            alice[0] spawn GreetFriends();
        }
        ```
        </div>
    === "Python"
        ```python
        class Person:
            def __init__(self, name):
                self.name = name
                self.visited = False
                self.friends = []

        class GreetFriends:
            def __init__(self):
                pass

            def greet_all(self, start_person, visited=None):
                if visited is None:
                    visited = set()

                if start_person in visited:
                    return

                visited.add(start_person)
                start_person.visited = True
                print(f"Hello, {start_person.name}!")

                # Visit all friends
                for friend in start_person.friends:
                    self.greet_all(friend, visited)

        # Create friend network
        alice = Person("Alice")
        bob = Person("Bob")
        charlie = Person("Charlie")

        # Connect friends manually
        alice.friends = [bob, charlie]
        bob.friends = [alice, charlie]
        charlie.friends = [alice, bob]

        # Start greeting process
        greeter = GreetFriends()
        greeter.greet_all(alice)
        ```

## Scale-Agnostic Programming Concept

One of Jac's most powerful features is scale-agnostic programming - code written for one user automatically scales to multiple users and distributed systems.

!!! topic "Write Once, Scale Anywhere"
    The same Jac code works whether you have 1 user or 1 million users, running on a single machine or distributed across the globe.

### Automatic Persistence

Every node connected to the root is automatically persisted:

!!! example "Automatic Persistence"
    === "Jac"
        <div class="code-block">
        ```jac
        node Counter {
            has count: int = 0;

            def increment() -> None;
        }

        impl Counter.increment {
            self.count += 1;
            print(f"Counter is now: {self.count}");
        }

        with entry {
            # Get or create counter
            counters = [root-->(`?Counter)];
            if not counters {
                counter = root ++> Counter();
                print("Created new counter");
            }

            # Increment and save automatically
            counter[0].increment();
        }
        ```
        </div>
    === "Python"
        ```python
        import json
        import os

        class Counter:
            def __init__(self, count=0):
                self.count = count

            def increment(self):
                self.count += 1
                print(f"Counter is now: {self.count}")

            def save(self, filename="counter.json"):
                with open(filename, 'w') as f:
                    json.dump({"count": self.count}, f)

            @classmethod
            def load(cls, filename="counter.json"):
                if os.path.exists(filename):
                    with open(filename, 'r') as f:
                        data = json.load(f)
                        return cls(data["count"])
                return cls()

        # Manual persistence management
        counter = Counter.load()
        counter.increment()
        counter.save()  # Must remember to save!
        ```

### Multi-User Isolation

Each user automatically gets their own isolated graph space:

!!! example "Multi-User Support"
    === "Jac"
        <div class="code-block">
        ```jac
        node UserProfile {
            has username: str;
            has bio: str = "";
        }

        walker GetProfile {
            can get_user_info with entry {
                # 'root' automatically refers to current user's space
                profiles = [root-->(`?UserProfile)];
                if profiles {
                    profile = profiles[0];
                    print(f"Profile: {profile.username}");
                    print(f"Bio: {profile.bio}");
                } else {
                    print("No profile found");
                }
            }
        }

        walker CreateProfile {
            has username: str;
            has bio: str;

            can create with entry {
                # Each user gets their own isolated root
                profile = root ++> UserProfile(
                    username=self.username,
                    bio=self.bio
                );
                print(f"Created profile for {profile[0].username}");
            }
        }

        with entry {
            # This code works for any user automatically
            CreateProfile(username="alice", bio="Jac developer") spawn root;
            GetProfile() spawn root;
        }
        ```
        </div>
    === "Python"
        ```python
        import os
        import json

        class UserProfile:
            def __init__(self, username, bio=""):
                self.username = username
                self.bio = bio

        class UserManager:
            def __init__(self, user_id):
                self.user_id = user_id
                self.data_dir = f"user_data/{user_id}"
                os.makedirs(self.data_dir, exist_ok=True)

            def create_profile(self, username, bio=""):
                profile = UserProfile(username, bio)
                self.save_profile(profile)
                print(f"Created profile for {username}")
                return profile

            def get_profile(self):
                profile_file = f"{self.data_dir}/profile.json"
                if os.path.exists(profile_file):
                    with open(profile_file, 'r') as f:
                        data = json.load(f)
                        profile = UserProfile(data["username"], data["bio"])
                        print(f"Profile: {profile.username}")
                        print(f"Bio: {profile.bio}")
                        return profile
                else:
                    print("No profile found")
                    return None

            def save_profile(self, profile):
                profile_file = f"{self.data_dir}/profile.json"
                with open(profile_file, 'w') as f:
                    json.dump({
                        "username": profile.username,
                        "bio": profile.bio
                    }, f)

        # Manual user context management required
        user_manager = UserManager("user_123")  # Must track user ID
        user_manager.create_profile("alice", "Python developer")
        user_manager.get_profile()
        ```

## Comparison with Python and Traditional Languages

While Jac maintains familiar syntax for Python developers, it introduces powerful new concepts:

### Syntax Familiarity

!!! example "Familiar Python-like Syntax"
    === "Jac"
        <div class="code-block">
        ```jac
        # Variables and functions work similarly
        def calculate_average(numbers: list[float]) -> float {
            if len(numbers) == 0 {
                return 0.0;
            }
            return sum(numbers) / len(numbers);
        }

        with entry {
            scores = [85.5, 92.0, 78.5, 96.0, 88.5];
            avg = calculate_average(scores);
            print(f"Average score: {avg}");

            # Control flow is familiar
            if avg >= 90.0 {
                print("Excellent performance!");
            } elif avg >= 80.0 {
                print("Good performance!");
            } else {
                print("Needs improvement.");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        # Very similar syntax
        def calculate_average(numbers: list[float]) -> float:
            if len(numbers) == 0:
                return 0.0
            return sum(numbers) / len(numbers)

        if __name__ == "__main__":
            scores = [85.5, 92.0, 78.5, 96.0, 88.5]
            avg = calculate_average(scores)
            print(f"Average score: {avg:.1f}")

            # Control flow is identical
            if avg >= 90.0:
                print("Excellent performance!")
            elif avg >= 80.0:
                print("Good performance!")
            else:
                print("Needs improvement.")
        ```

### Key Differences

| Aspect | Python | Jac |
|--------|--------|-----|
| **Relationships** | Manual references | First-class edges |
| **Persistence** | External database | Automatic |
| **Multi-user** | Manual session management | Built-in isolation |
| **Distribution** | Complex setup | Transparent |
| **Graph Operations** | Manual traversal | Spatial queries |
| **Type System** | Optional hints | Mandatory annotations |

## Simple Friend Network Example

Let's build a complete friend network example that demonstrates Jac's core concepts:

!!! example "Complete Friend Network"
    === "Jac"
        <div class="code-block">
        ```jac
        node Person {
            has name: str;
            has age: int;
            has interests: list[str] = [];
        }

        edge FriendsWith {
            has since: str;
            has closeness: int;  # 1-10 scale
        }

        walker FindCommonInterests {
            has target_person: Person;
            has common_interests: list[str] = [];

            can find_common with Person entry {
                if here == self.target_person {
                    return;  # Skip self
                }

                # Find shared interests
                shared = [];
                for interest in here.interests {
                    if interest in self.target_person.interests {
                        shared.append(interest);
                    }
                }

                if shared {
                    self.common_interests.extend(shared);
                    print(f"{here.name} and {self.target_person.name} both like: {', '.join(shared)}");
                }
            }
        }

        with entry {
            # Create friend network
            alice = root ++> Person(
                name="Alice",
                age=25,
                interests=["coding", "music", "hiking"]
            );

            bob = root ++> Person(
                name="Bob",
                age=27,
                interests=["music", "sports", "cooking"]
            );

            charlie = root ++> Person(
                name="Charlie",
                age=24,
                interests=["coding", "gaming", "music"]
            );

            # Create friendships with metadata
            alice +>:FriendsWith(since="2020-01-15", closeness=8):+> bob;
            alice +>:FriendsWith(since="2021-06-10", closeness=9):+> charlie;
            bob +>:FriendsWith(since="2020-12-03", closeness=7):+> charlie;

            print("=== Friend Network Analysis ===");

            # Find Alice's friends
            alice_friends = [alice[0]->:FriendsWith:->(`?Person)];
            print(f"Alice's friends: {[f.name for f in alice_friends]}");

            # Find common interests between Alice and her friends
            finder = FindCommonInterests(target_person=alice[0]);
            for friend in alice_friends {
                friend spawn finder;
            }

            # Find close friendships (closeness >= 8)
            close_friendships = [root->:FriendsWith:closeness >= 8:->];
            print(f"Close friendships ({len(close_friendships)} found):");
            for edge in close_friendships {
                print(f"  Strong bond between friends (closeness: {edge.closeness})");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        class Person:
            def __init__(self, name: str, age: int, interests: List[str] = None):
                self.name = name
                self.age = age
                self.interests = interests or []
                self.friendships = []

        class Friendship:
            def __init__(self, person1: Person, person2: Person, since: str, closeness: int):
                self.person1 = person1
                self.person2 = person2
                self.since = since
                self.closeness = closeness

                # Add bidirectional friendship
                person1.friendships.append(self)
                person2.friendships.append(self)

        def find_common_interests(person1: Person, person2: Person) -> List[str]:
            shared = []
            for interest in person1.interests:
                if interest in person2.interests:
                    shared.append(interest)
            return shared

        # Create friend network
        alice = Person("Alice", 25, ["coding", "music", "hiking"])
        bob = Person("Bob", 27, ["music", "sports", "cooking"])
        charlie = Person("Charlie", 24, ["coding", "gaming", "music"])

        # Create friendships
        friendship1 = Friendship(alice, bob, "2020-01-15", 8)
        friendship2 = Friendship(alice, charlie, "2021-06-10", 9)
        friendship3 = Friendship(bob, charlie, "2020-12-03", 7)

        print("=== Friend Network Analysis ===")

        # Find Alice's friends
        alice_friends = []
        for friendship in alice.friendships:
            friend = friendship.person2 if friendship.person1 == alice else friendship.person1
            alice_friends.append(friend)

        print(f"\nAlice's friends: {[f.name for f in alice_friends]}")

        # Find common interests
        for friend in alice_friends:
            shared = find_common_interests(alice, friend)
            if shared:
                print(f"{friend.name} and {alice.name} both like: {', '.join(shared)}")

        # Find close friendships
        all_friendships = [friendship1, friendship2, friendship3]
        close_friendships = [f for f in all_friendships if f.closeness >= 8]
        print(f"\nClose friendships ({len(close_friendships)} found):")
        for friendship in close_friendships:
            print(f"  Strong bond between friends (closeness: {friendship.closeness})")
        ```

## Key Takeaways

!!! summary "Chapter Summary"
    - **Jac is Python-like** but adds powerful graph programming concepts
    - **Object-Spatial Programming** moves computation to data through nodes, edges, and walkers
    - **Scale-agnostic programming** means code automatically works from single-user to distributed systems
    - **Automatic persistence** and **multi-user isolation** are built into the language
    - **Relationships are first-class** through typed edges, not just object references
    - **Graph traversal** is natural and expressive through spatial syntax

!!! topic "Coming Up"
    In the next chapter, we'll set up your Jac development environment and write your first programs, building on the concepts introduced here.

Jac represents a fundamental shift in how we think about programming. By making graphs and relationships first-class citizens, it enables more natural expression of interconnected systems while automatically handling the complexities of persistence, distribution, and scale. Let's dive deeper and start building!
