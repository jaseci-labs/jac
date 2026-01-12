# **1. Introduction to Jac**

---
This chapter gets you started with the Jac programming language. We will begin by explaining what Jac is and how it works, then walk you through how to model relationships in your code. Along the way, you'll learn about Jac's core concepts through practical examples.

> Jac introduces Object-Spatial Programming (OSP), a new way of thinking about software where computation can move to your data. This allows you to build applications that can be easily scaled and distributed.

## **What is Jac and Why It Exists**

---
Jac was created to better handle the interconnected, graph-like data structures found in many modern applications, such as social networks, knowledge graphs, and AI workflows. While traditional programming languages treat relationships as secondary concerns, Jac makes them first-class citizens.

<br/>
### **Traditional Approach to Modelling Relationships**

In many programming languages, you can model relationships using structures like functions, classes, or pointers.

Let's look at how you might build a simple social network in Python. First, you would define a `Person` class. This class might include a list of other `Person` objects to represent friendships.

```python
class Person:
    def __init__(self, name):
        self.name = name
        self.friends = []

    def add_friend(self, friend):
        self.friends.append(friend)
        friend.friends.append(self)
```

<br/>

Since a friendship is a two-way connection, you need to make sure that when one person adds a friend, the new friend is also updated. This requires extra logic in your code.

```python
# Create people and relationships
alice = Person("Alice")
bob = Person("Bob")
charlie = Person("Charlie")

# Establish relationships
alice.add_friend(bob)
bob.add_friend(alice)  # This is redundant but necessary in Python
bob.add_friend(charlie)
charlie.add_friend(bob)  # Again, redundant but necessary
```

<br/>

### **Modelling Relationships Naturally**

Now, let's see how you can define the same relationships in Jac.

First, we will define a `Person` node and a `FriendsWith` edge. In Jac, nodes are like objects that hold data. The edge defines the type of relationship between two nodes.

```jac
node Person {
    has name: str;
}

edge FriendsWith;
```

<br/>

In the code above, we define a `Person` node with a `name` attribute and a `FriendsWith` edge. Now, you can create people and establish friendships between them in a much more natural way.

```jac
# Create people
alice = root ++> Person(name="Alice");
bob = root ++> Person(name="Bob");
charlie = root ++> Person(name="Charlie");

# Create relationships naturally
alice <+:FriendsWith:+> bob;
bob <+:FriendsWith:+> charlie;
```

<br/>

The line alice `<+:FriendsWith:+> bob;` creates a `FriendsWith` relationship, which is a typed connection between the two nodes. This is one of Jac's core features.

## **Object-Spatial Programming Paradigm Overview**

---
Object-Spatial Programming (OSP) is built on three fundamental concepts:

- **Nodes**: Stateful entities that hold data
- **Edges**: Typed relationships between nodes
- **Walkers**: Mobile computation that traverses the graph

### **Nodes: Data with Location**

Nodes are like objects that have a specific location within a graph structure.

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
    # This is where your program starts.
    # We will create the nodes in the graph here.
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

<br/>

### **Edges: First-Class Relationships**

In Jac, edges are used to create typed connections between your nodes. Think of them as the lines that connect the dots in your data's structure.

```jac
node Person {
    has name: str;
    has age: int;
}

edge FamilyRelation {
    # Edges can also have properties
    has relationship_type: str;
}

with entry {
    # First, let's create our family members as nodes
    parent = root ++> Person(name="John", age=45);
    child1 = root ++> Person(name="Alice", age=20);
    child2 = root ++> Person(name="Bob", age=18);

    # Now, let's create the relationships between them
    parent +>:FamilyRelation(relationship_type="parent"):+> child1;
    parent +>:FamilyRelation(relationship_type="parent"):+> child2;
    child1 +>:FamilyRelation(relationship_type="sibling"):+> child2;

     # You can now ask questions about these relationships
    children = [parent[0]->:FamilyRelation:relationship_type=="parent":->(`?Person)];

    print(f"{parent[0].name} has {len(children)} children:");
    for child in children {
        print(f"  - {child.name} (age {child.age})");
    }
}
```

<br/>

### **Walkers: Mobile Computation**

Walkers are one of Jac's most interesting features. They are like little workers that you can program to travel through your graph of nodes and edges to perform tasks.
Next, we'll create a `walker` that can travel through our friend network and greet each person. Add the following `walker` definition to your code.

```jac
node Person {
    has name: str;
    has visited: bool = False;  # To keep track of who we've greeted
}

edge FriendsWith;

# This walker will greet every person it meets
walker GreetFriends {
    can greet with Person entry {
        if not here.visited {
            here.visited = True;
            print(f"Hello, {here.name}!");

            # Now, tell the walker to go to all connected friends
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

    # Start the walker on the 'alice' node to greet everyone
    alice[0] spawn GreetFriends();
}
```

<br/>

To make the walker visit a person's friends, we use the `visit` statement. It tells the walker to travel across any outgoing FriendsWith edges.

## Scale-Agnostic Programming Concept

---
One of the key benefits of Jac is that you can write your code once and have it work for a single user or for millions of users. Your code can run on a single computer or on a large, distributed system without any changes.

> The same Jac code works whether you have 1 user or 1 million users, running on a single machine or distributed across the globe.

### **Automatic Persistence**

Jac automatically saves any data that is connected to the graph's root node. This means you don't have to worry about setting up or managing a database. You can focus on what your application does, not on how it stores data.

Here is an example of a simple counter. When you run this on a Jac server, the count will be saved automatically.

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

<br/>

To see the automatic persistence for yourself, you can run the counter code on a Jac server. The server turns your Jac program into an API, and it handles saving the data in your graph between runs.
First, save the counter code into a file named "counter.jac". Then, run the following command in your terminal:

```jac
jac start counter.jac
```

### **Multi-User Isolation**

When your Jac application is running on a server, Jac automatically gives each user their own isolated graph. This means you don't have to write any special code to keep one user's data separate from another's; it's handled for you. The root node in your code always refers to the graph of the current user.

```jac
node UserProfile {
    has username: str;
    has bio: str = "";
}

walker GetProfile {
    can get_user_info with entry {
         # 'root' automatically points to the current user's graph
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
        # It looks for the profile connected to the current user's root
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

<br/>

In a live application, one user might call `CreateProfile` to set up their information. When another user calls `GetProfile`, they will only see their own profile, not anyone else's.

## Comparison with Python and Traditional Languages

---

If you have experience with Python, you'll find Jac's syntax easy to learn. Core programming concepts like variables, functions, and control flow work in a very similar way.

### **Syntax Familiarity**

For example, take a look at how you define and use functions and if/else statements in Jac.

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

This familiar foundation makes it easier for you to get started and begin building with Jac's unique features like nodes, edges, and walkers.
<br/>

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

---

Let's walk through building a complete friend network from scratch. This will show you how Jac's core concepts(nodes, edges, and walkers) work together in a practical example.

### Step 1: Define Your Nodes and Edges

First, we need to define the structure of our data. We'll create a `Person` node to hold information about each individual and a `FriendsWith` edge to represent their relationships.

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
```

<br/>

### Step 2: Create the People and Their Connections

Now that we have our blueprints, let's create a few people and connect them as friends. Notice how we can add data directly to the `FriendsWith` edge when we create it.

```jac
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
```

<br/>

### Step 3: Create a Walker to Find Common Interests

Next, we need a way to analyze our network. Let's create a `walker` that can travel between friends and find out what interests they have in common.

```jac
walker FindCommonInterests {
    # The walker needs to know who we're comparing against.
    has target_person: Person;
    # It will store the results of its search here.
    has common_interests: list[str] = [];

    # This ability runs automatically whenever the walker lands on a Person node.
    can find_common with Person entry {
        # We don't want to compare the person with themselves.
        if here == self.target_person {
            return;  # Skip self
        }

        # Find any interests this person shares with our target_person
        shared = [];
        for interest in here.interests {
            if interest in self.target_person.interests {
                shared.append(interest);
            }
        }

        # If we found any, print them and add them to our list.
        if shared {
            self.common_interests.extend(shared);
            print(f"{here.name} and {self.target_person.name} both like: {', '.join(shared)}");
        }
    }
}
```

<br/>

To use this walker, we'll give it a `target_person` (like Alice) and then "spawn" it on her friends' nodes. As the walker visits each friend, its `find_common ability` will trigger, comparing interests and printing the results.

### Step 4: Bring It All Together

Finally, let's update our `with entry` block to use the walker and analyze the network we created. We'll start by finding all of Alice's friends and then send our walker to visit them.

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

    # 1. Find all nodes connected to Alice by a FriendsWith edge
    alice_friends = [alice[0]->:FriendsWith:->(`?Person)];
    print(f"Alice's friends: {[f.name for f in alice_friends]}");

    # 2. Create an instance of our walker, telling it to compare against Alice
    finder = FindCommonInterests(target_person=alice[0]);

    # 3. Send the walker to visit each of Alice's friends
    for friend in alice_friends {
        friend spawn finder;
    }

    # Find close friendships (closeness >= 8)
    close_friendships = [root-->->:FriendsWith:closeness >= 8:->];
    print(f"Close friendships ({len(close_friendships)} found):");
}

```
</div>

<br/>

This example shows how you can model complex relationships and then create walkers to navigate and analyze them using Jac's Object-Spatial Programming model. The walker moves through the graph, performing actions based on the data it finds, all in a way that is clear and easy to understand.


## Key Takeaways

Here’s a quick summary of what you’ve learned in this chapter.

---
**Core Concepts:**

- **Object-Spatial Programming (OSP)**: This is the core idea behind Jac. It means you can move your code (computation) to your data using a combination of nodes, edges, and walkers.
- **Nodes**: These are the primary objects in your program that hold your data.
- **Edges**: These are the connections that define the relationships between your nodes.
- **Walkers**: These are small, mobile programs you create to travel through your network of nodes and edges to perform tasks.

**Key Advantages:**

- **Write Code That Scales**: Your Jac code works automatically for a single user or for millions, running on one machine or a distributed system, without needing changes.
- **No Database Headaches**: Jac automatically saves the data in your graph, so you don't have to set up or manage a database yourself.
- **Model Relationships Naturally: Working with connected data feels intuitive and straightforward because of the graph-based approach.
- **Built-in User Separation**: Jac automatically keeps each user's data separate, so you don't have to build complex logic to manage user sessions.
- **Familiar Python-like Syntax**: Jac is easy to learn for Python developers, letting you focus on its powerful new features right away.


Start thinking about problems that involve connected data, as these are the areas where Jac truly excels:
- Social networks and user connections
- Knowledge graphs and information relationships
- Workflow systems and process connections
- Data pipelines and transformation chains

!!! Note
    Remember: Jac shines when your problem naturally involves connected data!

---

*Ready to start your Object-Spatial Programming journey? Let's get to know Variables, Types, and Basic Syntax next!*
