Visit statements in Jac implement the fundamental object-spatial operation that enables walkers to traverse through node-edge topological structures. This statement embodies the core Object-Spatial Programming (OSP) paradigm of "computation moving to data" rather than the traditional approach of moving data to computation.

**Theoretical Foundation**

In OSP theory, the visit statement ($\triangleright$) allows walkers to move between nodes and edges in the topological structure, representing the dynamic traversal capability central to the paradigm. Walkers are autonomous computational entities that traverse node-edge structures, carrying state and behaviors that execute based on their current location.

**Basic Visit Syntax**

The basic syntax for visit statements follows this pattern:
```jac
visit target [else fallback_block]
```

**Directional Visit Patterns**

The example demonstrates directional traversal using arrow notation:
```jac
visit [-->] else {
    visit root;
    disengage;
}
```

The `[-->]` syntax represents traversal along outgoing edges from the current node. This pattern enables walkers to:

- **Explore connected nodes**: Move to nodes reachable via outgoing edges
- **Follow topological paths**: Traverse the graph structure according to connection patterns
- **Implement search algorithms**: Use systematic traversal to locate specific nodes or data

**Queue Insertion Index Semantics**

Visit statements support an advanced feature that controls traversal behavior through queue insertion indices:

```jac
visit :0:[-->];    # Insert at beginning (index 0)
visit :-1:[-->];   # Insert at end (index -1)
visit :2:[-->];    # Insert at index 2
visit :-3:[-->];   # Insert 3 positions from end
visit [-->];       # Default behavior
```

This syntax controls where new destinations are inserted into the walker's traversal queue:

- **`:0:`** - Insert at the beginning of the queue (index 0)
  - Results in **depth-first** style traversal
  - Newly discovered nodes are visited immediately before previously queued nodes
  - The walker explores paths deeply before backtracking

- **`:-1:`** - Insert at the end of the queue (index -1)
  - Results in **breadth-first** style traversal  
  - Newly discovered nodes are visited after all currently queued nodes
  - The walker explores all nodes at the current level before moving deeper

- **Other positive indices** (e.g., `:1:`, `:2:`, `:3:`)
  - Insert at the specified position from the beginning
  - Enables custom traversal ordering strategies
  - Useful for priority-based or weighted traversal algorithms

- **Other negative indices** (e.g., `:-2:`, `:-3:`)
  - Insert at the specified position from the end
  - Allows fine-grained control over queue ordering
  - Supports complex traversal patterns beyond simple depth/breadth-first

- **No index** - Default queue insertion behavior
  - Implementation-specific ordering
  - Typically follows standard traversal semantics

**Practical Example**

Consider a walker that uses conditional queue insertion:
```jac
walker MyWalker {
    can does with MyNode entry {
        if here.val == 20 {
            visit :0:[-->];  # Depth-first from this node
        }
        elif here.val == 30 {
            visit :-1:[-->]; # Breadth-first from this node
        }
        else {
            visit [-->];     # Default traversal
        }
    }
}
```

This demonstrates:
- **Dynamic traversal strategies**: Different nodes can trigger different traversal behaviors
- **Fine-grained control**: Precise specification of exploration patterns
- **Adaptive algorithms**: Traversal strategy can change based on node properties or walker state

**Traversal Queue Mechanics**

When a walker executes a visit statement:

1. **Target identification**: The walker identifies all nodes matching the visit pattern (e.g., `[-->]`)
2. **Queue insertion**: New destinations are inserted at the specified index:
   - `:0:` pushes to the front (stack-like behavior)
   - `:-1:` appends to the end (queue-like behavior)
3. **Next visit**: The walker moves to the node at the front of its queue
4. **Continuation**: Process repeats until the queue is empty or walker disengages

This queue-based approach enables sophisticated traversal patterns while maintaining the intuitive OSP programming model.

**Conditional Traversal with Else Clauses**

Visit statements support else clauses that execute when the primary visit target is unavailable:

- **Fallback behavior**: When `[-->]` finds no outgoing edges, the else block executes
- **Graceful handling**: Provides alternative actions when traversal paths are exhausted
- **Control flow**: Enables complex navigation logic with built-in error handling

**Walker Abilities and Visit Integration**

The example shows a walker ability that automatically triggers visit behavior:
```jac
walker Visitor {
    can travel with `root entry {
        visit [-->] else {
            visit root;
            disengage;
        }
    }
}
```

Key aspects:
- **Implicit activation**: The `travel` ability triggers automatically when the walker enters a root node
- **Context-sensitive execution**: Behavior adapts based on the walker's current location
- **Distributed computation**: Logic executes at data locations rather than centralized functions

**Node Response to Walker Visits**

Nodes can define abilities that respond to walker visits:
```jac
node item {
    can speak with Visitor entry {
        print("Hey There!!!");
    }
}
```

This demonstrates:
- **Location-bound computation**: Nodes contain computational abilities triggered by visitor arrival
- **Type-specific responses**: Different behaviors for different walker types
- **Bidirectional interaction**: Both walkers and nodes participate in computation

**Traversal Lifecycle**

The complete traversal process involves:

1. **Walker spawning**: `root spawn Visitor()` activates the walker at the root node
2. **Ability triggering**: The walker's `travel` ability executes upon entry
3. **Visit execution**: The walker moves to connected nodes via `visit [-->]`
4. **Node response**: Each visited node's `speak` ability triggers
5. **Fallback handling**: If no outgoing edges exist, the else clause executes
6. **Termination**: `disengage` removes the walker from active traversal

**Object-Spatial Benefits**

Visit statements enable several key advantages:

- **Natural graph algorithms**: Traversal logic maps directly to problem domain topology
- **Decoupled computation**: Algorithms separate from data structure implementation
- **Context-aware processing**: Computation adapts to local data and connection patterns
- **Intuitive control flow**: Navigation follows the natural structure of connected data

**Common Patterns**

Visit statements support various traversal patterns:
- **Breadth-first exploration**: Systematic traversal of all reachable nodes using `visit :-1:[-->]`
- **Depth-first search**: Following paths to their conclusion before backtracking using `visit :0:[-->]`
- **Conditional navigation**: Choosing paths based on node properties or walker state
- **Cyclic traversal**: Returning to previously visited nodes for iterative processing
- **Hybrid strategies**: Mixing depth-first and breadth-first based on node properties

The provided example demonstrates a simple breadth-first traversal where a walker visits all nodes connected to the root, printing a message at each location. This illustrates how visit statements transform graph traversal from complex algorithmic implementation to intuitive navigation through connected data structures.

Visit statements represent a fundamental shift in programming paradigms, enabling developers to express algorithms in terms of movement through data topologies rather than data manipulation through function calls.
