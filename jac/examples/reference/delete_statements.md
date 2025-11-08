Delete statements in Jac remove objects, nodes, edges, or properties from memory and graph structures. The `del` keyword provides a unified interface for deletion operations across different contexts.

#### Syntax

```jac
del expression;
```

#### Deleting Variables

Remove variables from the current scope:

```jac
# Delete single variable
x = 10;
del x;  # x no longer exists

# Delete multiple variables
a, b, c = 1, 2, 3;
del a, b, c;
```

#### Deleting Object Properties

Remove attributes from objects:

```jac
obj Person {
    has name: str;
    has age: int;
    has email: str = "";
}

with entry {
    p = Person(name="Alice", age=30, email="alice@example.com");
    
    # Delete optional property
    del p.email;
    
    # Accessing deleted property may raise error
}
```

#### Deleting List Elements

Remove items from lists by index:

```jac
items = [1, 2, 3, 4, 5];

# Delete by index
del items[2];  # items = [1, 2, 4, 5]

# Delete slice
del items[1:3];  # items = [1, 5]

# Delete with negative index
del items[-1];  # items = [1]
```

#### Deleting Dictionary Entries

Remove key-value pairs:

```jac
data = {"a": 1, "b": 2, "c": 3};

# Delete by key
del data["b"];  # data = {"a": 1, "c": 3}

# Conditional deletion
if "c" in data {
    del data["c"];
}
```

#### Deleting Nodes

Remove nodes from the graph structure:

```jac
node DataNode {
    has value: any;
}

walker Cleaner {
    can clean with entry {
        # Delete nodes matching criteria
        for n in [-->] {
            if n.value is None {
                del n;  # Node and its edges are removed
            }
        }
    }
}
```

#### Deleting Edges

Remove connections between nodes:

```jac
# Delete specific edge types
del source_node -->:EdgeType:--> target_node;

# Delete all outgoing edges
del node [-->];

# Delete filtered edges
del node [-->(?.weight < threshold)];
```

#### Graph Operations

Complex deletion patterns:

```jac
walker GraphPruner {
    has min_connections: int = 2;
    
    can prune with entry {
        # Delete weakly connected nodes
        weak_nodes = [];
        for n in [-->] {
            if len(n[<-->]) < self.min_connections {
                weak_nodes.append(n);
            }
        }
        
        # Delete collected nodes
        for n in weak_nodes {
            del n;  # Automatically removes associated edges
        }
    }
}
```

#### Edge Deletion Patterns

```jac
node Network {
    can remove_connection(target: node) {
        # Delete edge between self and target
        del self --> target;
    }
    
    can clear_outgoing {
        # Delete all outgoing edges
        del self [-->];
    }
    
    can prune_weak_edges(threshold: float) {
        # Delete edges below threshold
        del self [-->(?.weight < threshold)];
    }
}
```

#### Cascading Deletions

When nodes are deleted, associated edges are automatically removed:

```jac
with entry {
    # Create connected structure
    a = Node();
    b = Node();
    c = Node();
    
    a ++> b ++> c;
    
    # Deleting b removes edges a->b and b->c
    del b;
    
    # a and c still exist but are disconnected
}
```

#### Memory Management

Jac handles cleanup automatically:

```jac
walker MemoryManager {
    can cleanup with entry {
        # Process large data
        temp_nodes = [];
        for i in range(1000) {
            n = DataNode(data=large_object);
            temp_nodes.append(n);
        }
        
        # Process nodes...
        
        # Explicit cleanup
        for n in temp_nodes {
            del n;
        }
        # Memory is reclaimed
    }
}
```

#### Best Practices

1. **Check Before Delete**: Verify existence before deletion
2. **Handle Dependencies**: Consider edge deletion when removing nodes  
3. **Batch Operations**: Group deletions for efficiency
4. **Clean Up Resources**: Delete temporary nodes/edges after use
5. **Document Side Effects**: Deletion can affect graph connectivity

#### Common Patterns

##### Filtered Node Deletion
```jac
walker FilterDelete {
    can delete_by_type(type_name: str) {
        targets = [-->(`type_name)];
        for t in targets {
            del t;
        }
    }
}
```

##### Conditional Edge Removal
```jac
can prune_edges(node: node, condition: func) {
    edges = node[<-->];
    for e in edges {
        if condition(e) {
            del e;
        }
    }
}
```

##### Safe Deletion
```jac
can safe_delete(item: any) -> bool {
    try {
        del item;
        return True;
    } except {
        return False;
    }
}
```

Delete statements provide essential cleanup capabilities for managing memory and graph structure integrity in Jac programs. They work seamlessly with the object-spatial model to maintain consistent graph states.
