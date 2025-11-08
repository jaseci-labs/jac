Connect expressions in Jac provide the fundamental mechanism for creating topological relationships between nodes, implementing the edge creation and management aspects of Object-Spatial Programming. These expressions enable the construction of graph structures where computation can flow through connected data locations.

**Theoretical Foundation**

In OSP theory, edges are first-class entities that represent directed relationships between nodes, encoding both the topology of connections and the semantics of those relationships. Connect expressions create these edge instances, establishing the pathways through which walkers can traverse and enabling the "computation moving to data" paradigm.

**Basic Connection Syntax**

**Simple Connections**
The simplest form creates basic edges between nodes:
```jac
source ++> destination
```

This creates a directed edge from the source node to the destination node, enabling walker traversal from source to destination.

**Typed Edge Connections**
More sophisticated connections can specify edge types and properties:
```jac
source +>:EdgeType:property=value:+> destination
```

This syntax allows for:
- **Edge typing**: Specifying the class of edge to create (`EdgeType`)
- **Property assignment**: Setting initial values for edge properties (`property=value`)
- **Semantic relationships**: Encoding meaning into the connection itself

**Edge as First-Class Objects**

Edges in Jac are not merely references but full-fledged objects with their own properties and behaviors:

```jac
edge MyEdge {
    has val: int = 5;
}
```

This defines an edge class with:
- **State**: Properties that can store data (`val: int`)
- **Default values**: Initial property assignments (`= 5`)
- **Type identity**: Distinguished from other edge types

**Dynamic Connection Creation**

The example demonstrates dynamic topology construction within walker abilities:

```jac
impl Creator.create {
    end = here;
    for i=0 to i<7 by i+=1  {
        if i % 2 == 0 {
            end ++> (end := node_a(value=i));
        } else {
            end +>:MyEdge:val=i:+> (end := node_a(value=i + 10));
        }
    }
}
```

Key aspects:
- **Contextual reference**: `here` refers to the walker's current location
- **Sequential construction**: Building connected chains of nodes dynamically
- **Conditional topology**: Using different connection types based on conditions
- **Property parameterization**: Setting edge properties based on runtime values (`val=i`)

**Connection Patterns**

**Chain Building**
Creating linear sequences of connected nodes:
```jac
end ++> (end := node_a(value=i));
```

This pattern:
- Connects the current `end` node to a newly created node
- Updates `end` to reference the new node for the next iteration
- Builds a chain topology suitable for sequential processing

**Typed Connections with Properties**
Creating semantically rich connections:
```jac
end +>:MyEdge:val=i:+> (end := node_a(value=i + 10));
```

This pattern:
- Creates edges of specific type (`MyEdge`)
- Assigns properties during creation (`val=i`)
- Enables edge-based filtering and processing in traversal

**Edge Traversal and Filtering**

Connect expressions enable sophisticated traversal patterns through edge filtering:

```jac
for i in [->:MyEdge:val <= 6:->] {
    print(i.value);
}
```

This demonstrates:
- **Edge-type filtering**: Only traverse `MyEdge` connections
- **Property-based selection**: Filter edges where `val <= 6`
- **Traversal integration**: Iterate over filtered edge destinations
- **Data access**: Access properties of connected nodes (`i.value`)

**Bidirectional vs. Directional Connections**

Jac supports various connection directionalities:
- **Outgoing**: `++>` creates edges from source to destination
- **Incoming**: `<++` creates edges from destination to source  
- **Bidirectional**: `<++>` creates edges in both directions

**Connection in Object-Spatial Context**

Connect expressions integrate seamlessly with walker traversal:

1. **Topology Construction**: Walkers can build the graph structure they will later traverse
2. **Dynamic Adaptation**: Connections can be created based on discovered data or conditions
3. **Typed Relationships**: Different edge types enable specialized traversal behaviors
4. **Property-Rich Edges**: Edge properties provide context for traversal decisions

**Lifecycle and Memory Management**

Connected structures follow OSP lifecycle rules:
- **Node dependency**: Edges automatically deleted when endpoint nodes are deleted
- **Referential integrity**: Prevents dangling edge references
- **Dynamic modification**: Connections can be created and destroyed during execution

**Use Cases**

Connect expressions enable various topological patterns:

**Graph Construction**
- **Social networks**: Users connected by relationship types (friend, follower, etc.)
- **Workflow systems**: Tasks connected by dependency relationships
- **State machines**: States connected by transition conditions

**Algorithm Implementation**
- **Search trees**: Building searchable hierarchical structures
- **Path planning**: Creating route networks with weighted connections
- **Data pipelines**: Connecting processing stages with typed flows

**Real-World Modeling**
- **Transportation networks**: Locations connected by route types (road, rail, air)
- **Organizational structures**: Entities connected by reporting relationships
- **Knowledge graphs**: Concepts connected by semantic relationships

**Performance Considerations**

Connect expressions in Jac are designed for efficiency:
- **Incremental construction**: Build topology as needed rather than pre-allocating
- **Type-specific optimization**: Edge types enable specialized storage and traversal
- **Property indexing**: Edge properties can be indexed for fast filtering
- **Memory locality**: Related nodes and edges can be co-located for cache efficiency

The example demonstrates a complete pattern where a walker constructs a mixed topology using both simple and typed connections, then traverses the structure using edge filtering to process specific subsets of the data. This showcases how connect expressions enable both the construction and utilization phases of object-spatial programming, creating rich topological structures that support sophisticated computational patterns.

Connect expressions represent a fundamental departure from traditional data structure approaches, enabling developers to construct and modify graph topologies dynamically while maintaining type safety and semantic clarity through edge typing and property systems.
