Data spatial references provide specialized syntax for navigating and manipulating topological structures, enabling direct expression of graph relationships and traversal patterns. These references make topological relationships first-class citizens in the programming model.

#### Edge Reference Syntax

Edge references use square bracket notation with directional operators to express graph navigation:

```jac
[-->]                    # All nodes connected by outgoing edges (default)
[<--]                    # All nodes connected by incoming edges (default)
[<-->]                   # All nodes connected by bidirectional edges (default)
[edge -->]               # All outgoing edges themselves
[edge <--]               # All incoming edges themselves
[edge <-->]              # All bidirectional edges themselves
[->:EdgeType:->]          # Typed nodes via outgoing edges
[edge ->:EdgeType:->]     # Typed outgoing edges themselves
[node --> target]        # Specific edge path to nodes
[edge --> target]        # Specific edges in path
```

The square bracket syntax creates collections of edges or nodes that can be used for traversal, filtering, or manipulation operations. **By default, edge reference syntax returns the connected nodes**, not the edges themselves. To explicitly reference edges, use the `edge` keyword prefix.

#### Node vs Edge References

Understanding the distinction between node and edge references is crucial for effective graph navigation:

**Default Node References**:
```jac
[-->]                    # Returns: connected nodes via outgoing edges
[<--]                    # Returns: connected nodes via incoming edges
visit [-->];             # Walker visits the connected nodes
```

**Explicit Edge References**:
```jac
[edge -->]               # Returns: the edge objects themselves
[edge <--]               # Returns: incoming edge objects
visit [edge -->];        # Walker visits the edges (and their connected nodes)
```

When a walker visits edges explicitly, it will execute abilities on both the edge and its connected node, providing access to edge properties and enabling edge-based computation.

#### Directional Navigation

Directional operators express the flow of relationships within the graph:

**Outgoing (`-->`)**: References edges that originate from the current node, representing relationships where the current node is the source.

**Incoming (`<--`)**: References edges that terminate at the current node, representing relationships where the current node is the target.

**Bidirectional (`<-->`)**: References edges that can be traversed in either direction, representing symmetric relationships.

#### Edge Connection Operations

Connection operators create new edges between nodes, establishing topological relationships:

```jac
source_node ++> target_node;                    # Create directed edge
source_node <++ target_node;                    # Create reverse directed edge
source_node <++> target_node;                   # Create bidirectional edge
source_node ++>:EdgeType(weight=5):++> target;  # Create typed edge with data
```

These operators enable dynamic graph construction where relationships can be established programmatically based on computational logic.

#### Edge Disconnection Operations

The `del` operator removes edges from the graph structure:

```jac
del source_node --> target_node;    # Remove specific edge
del [-->];                          # Remove all outgoing edges
del [<--:FollowEdge:];             # Remove typed incoming edges
```

Disconnection operations maintain graph integrity by properly cleaning up references and ensuring consistent topological state.

#### Filtered References

Edge references support inline filtering for selective graph operations:

```jac
# Node filtering (default behavior)
[-->(active == true)]              # Nodes that are active
[<--(score > threshold)]            # Nodes with high scores
[<-->(?name.startswith("test"))]   # Nodes with test names

# Edge filtering (explicit edge references)
[edge -->(weight > threshold)]     # Edges meeting weight criteria
[edge <--:FollowEdge:]             # Incoming edges of specific type
[edge <-->(`ConnectionType)]        # Edges of specific type
```

Filtering enables precise graph queries that combine topological navigation with data-driven selection criteria. When filtering edges explicitly, the walker can access edge properties during traversal.

#### Integration with Walker Traversal

Data spatial references integrate seamlessly with walker traversal patterns:

```jac
walker NetworkAnalyzer {
    has visited: set = set();
    
    can explore with entry {
        # Mark current node as visited
        self.visited.add(here);
        
        # Find unvisited neighbors (returns nodes by default)
        unvisited_neighbors = [-->] |> filter(|n| n not in self.visited);
        
        # Continue traversal to unvisited nodes
        if (unvisited_neighbors) {
            visit unvisited_neighbors;  # Visits nodes only
        }
        
        # Analyze connection patterns (edge references)
        strong_connections = [edge <-->:StrongEdge:];
        weak_connections = [edge <-->:WeakEdge:];
        
        # Visit edges to analyze their properties
        # This will execute abilities on both edges and connected nodes
        visit [edge -->:AnalysisEdge:];
        
        # Report analysis results
        report {
            "node_id": here.id,
            "strong_count": len(strong_connections),
            "weak_count": len(weak_connections)
        };
    }
}
```

When visiting edges explicitly with `visit [edge -->]`, the walker will:
1. Execute entry abilities on the edge
2. Automatically queue and visit the connected node
3. Execute abilities on both the edge and the target node

When visiting nodes with `visit [-->]` (default), the walker will:
1. Execute abilities only on the target nodes
2. Skip edge traversal abilities

#### Type-Safe Graph Operations

References support type checking and validation for robust graph manipulation:

```jac
node DataNode {
    has data: dict;
    has node_type: str;
}

edge ProcessingEdge(DataNode, DataNode) {
    has processing_weight: float;
    has edge_type: str = "processing";
}

walker TypedProcessor {
    can process with DataNode entry {
        # Type-safe edge references
        processing_edges = [-->:ProcessingEdge:];
        
        # Filtered by edge properties
        high_priority = processing_edges |> filter(|e| e.processing_weight > 0.8);
        
        # Continue to high-priority targets
        visit high_priority |> map(|e| e.target);
    }
}
```

#### Dynamic Graph Construction

References enable dynamic graph construction based on runtime conditions:

```jac
walker GraphBuilder {
    can build_connections with entry {
        # Analyze current node data
        similarity_threshold = 0.7;
        
        # Find similar nodes in the graph
        all_nodes = [-->*];  # Get all reachable nodes
        similar_nodes = all_nodes |> filter(|n| 
            calculate_similarity(here.data, n.data) > similarity_threshold
        );
        
        # Create similarity edges
        for similar_node in similar_nodes {
            similarity_score = calculate_similarity(here.data, similar_node.data);
            here ++>:SimilarityEdge(score=similarity_score):++> similar_node;
        }
    }
}
```

Data spatial references provide the foundational syntax for expressing topological relationships and enabling computation to flow naturally through graph structures, making complex graph algorithms both intuitive and maintainable.

#### Edge vs Node Traversal Behavior

Understanding the distinction between edge and node traversal is fundamental to effective data spatial programming:

**Default Node Traversal**:
- `[-->]` returns connected nodes, not edges
- `visit [-->]` executes abilities only on target nodes
- Walker moves directly from node to node
- Edge properties are not accessible during traversal

**Explicit Edge Traversal**:
- `[edge -->]` returns edge objects themselves
- `visit [edge -->]` executes abilities on both edges and nodes
- Walker processes edge first, then automatically queues connected node
- Full access to edge properties and data during traversal

This distinction enables precise control over computational flow:
```jac
# Process only nodes
visit [-->];                      # Direct node-to-node movement

# Process edges and nodes
visit [edge -->];                 # Edge abilities execute, then node abilities

# Access edge data without traversal
edge_weights = [edge -->] |> map(|e| e.weight);

# Filter by edge properties, visit connected nodes
high_priority_nodes = [edge -->(priority > 0.8)] |> map(|e| e.target);
visit high_priority_nodes;
```

The choice between node and edge traversal depends on whether edge computation or properties are needed for the algorithm's logic.