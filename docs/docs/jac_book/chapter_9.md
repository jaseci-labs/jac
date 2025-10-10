# Chapter 9: Nodes and Edges
---

In Object-Spatial Programming, **nodes** and **edges** are the fundamental building blocks of your application's graph. A node represents an entity or a location for your data, while an edge represents a typed, directional relationship between two nodes.
This chapter will show you how to define these core components and how to give your nodes special abilities, allowing them to interact with the walkers that visit them.


## Node Abilities
---
So far, we have seen how walkers can be programmed with intelligence to traverse a graph and collect information. But in Jac, nodes are not just passive data containers. They can have their own abilities—methods that are specifically designed to trigger when a certain type of walker arrives.
This two-way dynamic enables powerful, flexible interactions between walkers and the graph they explore.

### Usecase: Uninformed State Agent
Imagine you have a generic agent, a StateAgent, whose job is to collect information about its environment. This agent knows nothing in advance about the types of nodes it will encounter. In a traditional program, this would be difficult; how can code act on data structures it doesn't know exist?

In Jac, we can make the nodes themselves intelligent. They can recognize the StateAgent when it arrives and "teach" it about their own data.
First, let's define our simple StateAgent. Its only feature is a state dictionary to store any information it gathers.


First, let's define our StateAgent walker:
```jac
walker StateAgent {
    # This dictionary will hold the data collected during the journey.
    has state: dict = {};

    # The walker's journey starts at the root node.
    can start with `root entry {
        # From the root, visit all directly connected nodes.
        visit [-->];
    }
}
```

Next, we will define two different types of nodes, `Weather` and `Time`. Each one will have a special ability that only triggers for a StateAgent.

```jac
node Weather {
    has temp: int = 80;

    # This ability is only triggered when a walker of type 'StateAgent' arrives.
    can get with StateAgent entry {
        # 'visitor' is a special keyword that refers to the walker currently on this node.
        visitor.state["temperature"] = self.temp;
    }
}
```

The `Weather` node knows that when a `StateAgent` visits, it should update the agent's state dictionary by adding a "temperature" key with its own local temp value.


```jac
node Time {
    has hour: int = 12;

    # This node also has a specific ability for the StateAgent.
    can get with StateAgent entry {
        visitor.state["time"] = f"{self.hour}:00 PM";
    }
}
```
Similarly, the `Time` node updates the agent's state with the current hour.

Finally, let's build the graph and dispatch our agent.

```jac
with entry {
    # Create and connect our nodes to the root.
    root ++> Weather();
    root ++> Time();

    # Create an instance of our agent and spawn it on the root node to begin.
    agent = StateAgent() spawn root;

    # After the walker has finished visiting all connected nodes,
    # print the state it has collected.
    print(agent.state);
}
```

When you run this program, the `StateAgent` starts at the `root`, visits both the `Weather` node and the `Time` node, and at each stop, the node's specific ability is triggered. By the time the walker's journey is complete, its state dictionary has been fully populated by the nodes themselves.


```jac
# node_abilities.jac
walker StateAgent{
    has state: dict = {};

    can start with `root entry {
        visit [-->];
    }
}

node Weather {
    has temp: int = 80;

    can get with StateAgent entry {
        visitor.state["temperature"] = self.temp;
    }
}

node Time {
    has hour: int = 12;

    can get with StateAgent entry {
        visitor.state["time"] = f"{self.hour}:00 PM";
    }
}

with entry {
    root ++> Weather();
    root ++> Time();

    agent = StateAgent() spawn root;
    print(agent.state);
}
```


```terminal
$ jac run node_abilities.jac

{"temperature": 80, "time": "12:00 PM"}
```

This pattern is incredibly powerful. It allows you to build a complex world of specialized nodes and then explore it with simple, generic agents. The intelligence is distributed throughout the graph, not just centralized in the walker.

## Node Inheritance
---

In Jac, nodes are more than just data—they can encapsulate behavior and interact with walkers. When building modular systems, it’s often useful to group nodes by type or functionality. This is where node inheritance comes in.

Let’s revisit the `Weather` and `Time` nodes from the previous example. While they each provide different types of information, they serve a common purpose: delivering contextual data to an agent. In Jac, we can express this shared role using inheritance, just like in traditional object-oriented programming.

We define a base node archetype called `Service`. This acts as a common interface for all context-providing nodes. Any node that inherits from `Service` is guaranteed to support certain interactions—either by shared methods or simply by tagging it with a common type.

```jac
node Service {}
```

Next, we will redefine `Weather` and `Time` to inherit from `Service`. This tells our system that they are both specific kinds of `Service` nodes.

```jac
# Weather is a type of Service.
node Weather(Service) {
    has temp: int = 80;

    can get with StateAgent entry {
        visitor.state["temperature"] = self.temp;
    }
}

# Time is also a type of Service.
node Time(Service) {
    has hour: int = 12;

    can get with StateAgent entry {
        visitor.state["time"] = f"{self.hour}:00 PM";
    }
}
```
<br />

Now that our nodes are organized, we can make our `StateAgent` walker much smarter. Instead of blindly visiting every node connected to the root, we can instruct it to only visit nodes that are a Service.

```jac
walker StateAgent {
    has state: dict = {};

    can start with `root entry {
        visit [-->(`?Service)];  # Visit any node that is a subtype of Service
    }
}
```
<br />

This simple change makes your `StateAgent` incredibly flexible. If you later add new service nodes to your graph, like `Location` or `Date`, you don't need to change the walker's code at all. As long as the new nodes inherit from `Service`, the walker will automatically visit them.


The ```-->(`?NodeType)``` syntax is a powerful feature of Jac that allows you to filter nodes by type. It tells the walker to visit any node that matches the `NodeType` type, regardless of its specific implementation.

### Usecase: A Smarter NPC

Let's apply these advanced patterns to a practical and engaging example. We will create an NPC (non-player character) in a game whose behavior changes based on the **weather** or **time of day**. For instance, the NPC might be cheerful in the morning, grumpy when it's hot, or sleepy at night.

We have already built the perfect foundation for this.
- We have `Weather` and `Time` nodes that can provide environmental context.
- They both inherit from a common `Service` type.
- We have a StateAgent walker that can automatically visit all `Service` nodes and collect their data into its state dictionary.

Now, let's build the NPC itself.

#### Step 1 - The Mood Function

Our NPC needs to determine its mood based on the environmental data collected by the StateAgent. Instead of writing complex if/else statements, we can delegate this creative task to a Large Language Model (LLM).

Using the byLLM plugin, we can define a function that sends the agent's state to an LLM and asks it to return a mood.

Here’s the code for our mood function:
```jac
import from byllm { Model }

# Configure the LLM
glob npc_model = Model(model_name="gpt-4.1-mini");

"""Adjusts the tone or personality of the shop keeper npc depending on weather/time."""
def get_ambient_mood(state: dict) -> str by npc_model();
```
This function, `get_ambient_mood`, takes a dictionary (the walker’s state) and sends it to the model. The model interprets the contents like `temperature` and `time`—and returns a textual mood that fits the situation.

#### Step 2 - The NPC Node

Next, we'll define the `NPC` node. Its key feature is an ability that triggers when our StateAgent visits. This ability uses the get_ambient_mood function to determine its own mood based on the information the agent has already collected.


```jac

node NPC {
    can get with StateAgent entry {
        visitor.state["npc_mood"] = get_ambient_mood(visitor.state);
    }
}
```
This is where the NPC’s personality is generated—based entirely on the graph-derived context.


#### Walker Composition
Our `StateAgent` knows how to collect environmental data, but it doesn't know to visit an `NPC` node. We can create a new, more specialized walker that does both.

Using walker inheritance, we can create an NPCWalker that inherits all the abilities of StateAgent and adds a new ability to visit NPC nodes.

```jac
walker NPCWalker(StateAgent) {
    can visit_npc with `root entry {
        visit [-->(`?NPC)];
    }
}
```
The `NPCWalker` first inherits the behavior of `StateAgent` (which collects context), and then adds a second phase to interact with the NPC after that context is built.


#### Putting It All Together

Finally, we can compose everything in a single entry point:
```jac
import from byllm { Model }

# Configure different models
glob npc_model = Model(model_name="gpt-4.1-mini");

node Service{}

walker StateAgent{
    has state: dict = {};

    can start with `root entry {
        visit [-->(`?Service)];
    }
}

node Weather(Service) {
    has temp: int = 80;

    can get with StateAgent entry {
        visitor.state["temperature"] = self.temp;
    }
}

node Time(Service) {
    has hour: int = 12;

    can get with StateAgent entry {
        visitor.state["time"] = f"{self.hour}:00 PM";
    }
}

"""Adjusts the tone or personality of the shop keeper npc depending on weather/time."""
def get_ambient_mood(state: dict) -> str by npc_model();

node NPC {
    can get with StateAgent entry {
        visitor.state["npc_mood"] = get_ambient_mood(visitor.state);
    }
}

walker NPCWalker(StateAgent) {
    can visit_npc with `root entry{
        visit [-->(`?NPC)];
    }
}


with entry {
    root ++> Weather();
    root ++> Time();
    root ++> NPC();

    agent = NPCWalker() spawn root;
    print(agent.state['npc_mood']);
}
```
<br />

```terminal
$ jac run npc_mood.jac

"The shopkeeper greets you warmly with a bright smile, saying, "What a hot day we’re having!
Perfect time to stock up on some refreshing potions or cool drinks. Let me know if you need
anything to beat the heat!"
```
<br />


## Edge Types and Relationships
---
In Jac, edges are the pathways that connect your nodes. They are more than just simple pointers; they are first-class citizens of the graph. This means an `edge` can have its own attributes and abilities, allowing you to model rich, complex relationships like friendships, ownership, or enrollment.

Edges in Jac are not just connections - they're full objects with their own properties and behaviors. This makes relationships as important as the data they connect.

### Basic Edge Declaration

You define an edge's blueprint using the `edge` keyword, and you can give it has attributes just like a node or object.

Let's model a simple school environment with Student, Teacher, and Classroom nodes, and the various relationships that connect them.

```jac
# Basic node for representing teachers
node Teacher {
    has name: str;
    has subject: str;
    has years_experience: int;
    has email: str;
}

# Basic node for representing students
node Student {
    has name: str;
    has age: int;
    has grade_level: int;
    has student_id: str;
}

node Classroom {
    has room_number: str;
    has capacity: int;
    has has_projector: bool = True;
}

# Edge for student enrollment
edge EnrolledIn {
    has enrollment_date: str;
    has grade: str = "Not Assigned";
    has attendance_rate: float = 100.0;
}

# Edge for teaching assignments
edge Teaches {
    has start_date: str;
    has schedule: str;  # "MWF 9:00-10:00"
    has is_primary: bool = True;
}

# Edge for friendship between students
edge FriendsWith {
    has since: str;
    has closeness: int = 5;  # 1-10 scale
}

with entry {
    # 1. Create the main classroom node and attach it to the root.
    science_lab = root ++> Classroom(
        room_number="Lab-A",
        capacity=24,
        has_projector=True
    );

    # 2. Create a teacher AND the 'Teaches' edge that connects them to the classroom.
    dr_smith = science_lab +>:Teaches(
        start_date="2024-08-01",
        schedule="TR 10:00-11:30"
    ):+> Teacher(
        name="Dr. Smith",
        subject="Chemistry",
        years_experience=12,
        email="smith@school.edu"
    );
}
```
Let's break down the edge creation syntax: <+:EdgeType(attributes):+>.
science_lab: The starting node (the "source" of the edge).

- `<+: ... :+>`: This syntax creates a bi-directional edge. It means the relationship can be traversed from science_lab to dr_smith and also from dr_smith back to science_lab.
- `Teaches(...)`: The type of edge we are creating, along with the data for its attributes.
- `Teacher(...)`: The destination node.

## Graph Navigation and Filtering
---
Jac provides powerful and expressive syntax for navigating and querying graph structures. Walkers can traverse connections directionally—forward or backward—and apply filters to control exactly which nodes or edges should be visited.

### Directional Traversal
- `-->` : Follows outgoing edges from the current node.
- `<--` : Follows incoming edges to the current node.

These can be wrapped in a visit statement to direct walker movement:
```jac
visit [-->];   # Move to all connected child nodes
visit [<--];   # Move to all parent nodes
```


### Filter by Node Type
To narrow traversal to specific node types, use the filter syntax:
```jac
-->(`?NodeType)
```

This ensures the walker only visits nodes of the specified archetype.
```jac
# Example: Visit all Student nodes connected to the root
walker FindStudents {
    can start with `root entry {
        visit [-->(`?Student)];
    }
}
```
This allows your walker to selectively traverse part of the graph, even in the presence of mixed node types.

### Filtering by Node Attributes
To make your walkers more intelligent, you can instruct them to only visit nodes of a specific type. You achieve this using the (?NodeType) filter. It's also called **attribute-based filtering**.


```jac
-->(`?NodeType: attr1 op value1, attr2 op value2, ...)
```
Where:

- `NodeType` is the node archetype to match (e.g., `Student`)
- `attr1`, `attr2` are properties of that node
- `op` is a comparison operator


#### Supported Operators

| Operator   | Description                    | Example                             |
|------------|--------------------------------|-------------------------------------|
| `==`       | Equality                       | `grade == 90`                        |
| `!=`       | Inequality                     | `status != "inactive"`              |
| `<`        | Less than                      | `age < 18`                           |
| `>`        | Greater than                   | `score > 70`                         |
| `<=`       | Less than or equal to          | `temp <= 100`                       |
| `>=`       | Greater than or equal to       | `hour >= 12`                        |
| `is`       | Identity comparison            | `mood is "happy"`                   |
| `is not`   | Negative identity comparison   | `type is not "admin"`              |
| `in`       | Membership (value in list)     | `role in ["student", "teacher"]`    |
| `not in`   | Negative membership            | `status not in ["inactive", "banned"]` |

#### Example
```jac
# Find all students with a grade above 85
walker FindTopStudents {
    can start with `root entry {
        visit [-->(`?Student: grade > 85)];
    }
}
```
This walker will only visit `Student` nodes where the `grade` property is greater than 85.

### Filtering by Edge Type and Attributes

In addition to filtering by node types and attributes, Jac also allows you to filter based on edge types and edge attributes, enabling precise control over traversal paths in complex graphs.

To traverse only edges of a specific type, use the following syntax:
```jac
visit [->:EdgeType->];
```

This tells the walker to follow only edges labeled as `EdgeType`, regardless of the type of the nodes they connect.

#### Example
```jac
# Only follow "enrolled_in" edges
visit [->:enrolled_in->];
```

### Edge Atribute Filtering
You can further refine edge traversal by applying attribute-based filters directly to the edge:
```jac
visit [->:EdgeType: attr1 op val1, attr2 op val2:->];
```
This format allows you to filter based on metadata stored on the edge itself, not the nodes.

#### Example
```jac
# Follow "graded" edges where score is above 80
visit [->:graded: score > 80:->];
```
This pattern is especially useful when edges carry contextual data, such as timestamps, weights, relationships, or scores.

## Wrapping Up
---
In this chapter, we explored the foundational concepts of nodes and edges in Jac. We learned how to define nodes with properties, create edges to represent relationships, and navigate the graph using walkers. We also saw how to filter nodes and edges based on types and attributes, enabling powerful queries and interactions.

These concepts form the backbone of Object-Spatial Programming, allowing you to model complex systems and relationships naturally. As you continue to build your Jac applications, keep these principles in mind to create rich, interconnected data structures that reflect the real-world entities and relationships you want to represent.

## Key Takeaways
---

**Node Fundamentals:**

- **Spatial objects**: Nodes can be connected and automatically persist when linked to root
- **Property storage**: Nodes hold data using `has` declarations with automatic constructors
- **Automatic persistence**: Nodes connected to root persist between program runs
- **Type safety**: All node properties must have explicit types

**Edge Fundamentals:**

- **First-class relationships**: Edges are full objects with their own properties and behaviors
- **Typed connections**: Edges define the nature of relationships between nodes
- **Bidirectional support**: Edges can be traversed in both directions
- **Rich metadata**: Store relationship-specific data directly in edge properties

**Graph Operations:**

- **Creation syntax**: Use `++>` to create new connections, `-->` to reference existing ones
- **Navigation patterns**: `[-->]` for outgoing, `[<--]` for incoming connections
- **Filtering support**: Apply conditions to find specific nodes or edges
- **Traversal efficiency**: Graph operations are optimized for spatial queries

**Practical Applications:**

- **Natural modeling**: Represent real-world entities and relationships directly
- **Query capabilities**: Find related data through graph traversal
- **Persistence automation**: No manual database management required
- **Scalable architecture**: Graph structure supports distributed processing

!!! tip "Try It Yourself"
    Practice with nodes and edges by building:
    - A classroom management system with students, teachers, and courses
    - A family tree with person nodes and relationship edges
    - A social network with users and friendship connections
    - An inventory system with items and location relationships

    Remember: Nodes represent entities, edges represent relationships - think spatially!

---

*Your graph foundation is solid! Now let's add mobile computation with walkers and abilities.*
