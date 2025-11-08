Walker statements control the movement and lifecycle of computational entities within topological structures. These statements implement the core data spatial paradigm where computation moves to data through controlled traversal of nodes and edges.

#### Visit Statement

The visit statement directs a walker to traverse to specified locations within the topological structure:

```jac
visit expression;
visit :expression: expression;
visit expression else { /* fallback code */ }
```

Visit statements add destinations to the walker's traversal queue, enabling dynamic path construction during execution. The walker processes queued destinations sequentially, triggering entry and exit abilities at each location. When visiting edges, both the edge and its appropriate endpoint node are automatically queued to maintain proper traversal flow.

The optional edge filtering syntax allows walkers to traverse only specific edge types, enabling sophisticated graph navigation patterns. The else clause provides fallback behavior when traversal conditions are not met.

#### Ignore Statement

The ignore statement excludes specific nodes or edges from traversal consideration:

```jac
ignore expression;
```

This statement prevents walkers from visiting specified locations, effectively creating traversal filters that help optimize pathfinding and implement selective graph exploration strategies. Ignored locations remain in the graph structure but become invisible to the current walker's traversal logic.

#### Disengage Statement

The disengage statement immediately terminates a walker's active traversal:

```jac
disengage;
```

When executed, disengage clears the walker's traversal queue and transitions it back to inactive object state. The walker preserves all accumulated data and state from its traversal, making this information available for subsequent processing. This statement enables early termination patterns and conditional traversal completion.

#### Traversal Control Patterns

These statements combine to enable sophisticated traversal algorithms:

```jac
walker PathFinder {
    has target: str;
    has visited: set[node] = set();
    
    can search with entry {
        # Mark current location as visited
        self.visited.add(here);
        
        # Check if target found
        if (here.name == self.target) {
            report here;
            disengage;
        }
        
        # Continue to unvisited neighbors
        unvisited = [-->] |> filter(|n| n not in self.visited);
        if (unvisited) {
            visit unvisited;
        } else {
            # Backtrack if no unvisited neighbors
            disengage;
        }
    }
}
```

Walker statements embody the fundamental principle of mobile computation, enabling algorithmic behaviors to flow through data structures while maintaining clear separation between computational logic (walkers) and data storage (nodes and edges).
