Jac provides comprehensive data access mechanisms through attribute access and subscript operations that extend Python's familiar syntax with additional conveniences for pipe operations and null-safe access patterns.

#### Attribute Access

Standard dot notation provides access to object attributes and methods:

```jac
car = Car(make="Tesla", model="3");
print(car.model);      # → "3"
```

Jac extends attribute access with directional dot operators that integrate with pipe expressions:

| Operator | Syntax | Purpose |
|----------|--------|---------|
| `.` | `obj.attr` | Standard attribute access |
| `.>` | `obj.>method` | Forward piping attribute access |
| `<.` | `obj<.method` | Backward piping attribute access |

The directional operators provide syntactic sugar for pipe operations, enabling more fluid expression chaining.

#### Null-Safe Access

The optional access operator (`?`) provides null-safe attribute and method access:

```jac
print(user?.address?.zip_code);
# Returns None if user or address is None, avoiding exceptions
```

This operator short-circuits the entire access chain when encountering null values, preventing runtime errors in complex object hierarchies.

#### Subscript Operations

Array-style indexing follows Python conventions with support for negative indices and slice operations:

```jac
letters = ["a", "b", "c", "d"];
print(letters[0]);     # "a"
print(letters[1:3]);   # ["b", "c"]
print(letters[-1]);    # "d"
print(letters[::2]);   # ["a", "c"] - every second element
```

Subscript operations support the full range of Python slicing syntax including start, stop, and step parameters.

#### Chained Access Patterns

Attribute and subscript operations can be freely combined to access nested data structures:

```jac
node DataContainer {
    has metadata: dict = {"values": [1, 2, 3], "config": {"debug": true}};
}

container = DataContainer();
value = container.metadata["values"][2];        # 3
debug_mode = container.metadata["config"]["debug"];  # true
```

#### Null-Safe Subscripting

Null-safe access extends to subscript operations:

```jac
config_value = settings?.["theme"]?.["primary_color"];
# Safely accesses nested dictionary values
```

This pattern is particularly useful when working with optional configuration data or API responses with variable structure.

#### Integration with Object-Spatial Constructs

Access operations work seamlessly with object-spatial programming elements:

```jac
walker DataInspector {
    can analyze with entry {
        # Safe access to node properties
        node_type = here?.node_type;
        data_size = here?.data?.["size"];
        
        # Process based on available data
        if (node_type == "processing" and data_size > threshold) {
            visit here.high_priority_neighbors;
        }
    }
}

node ProcessingNode {
    has data: dict;
    has node_type: str = "processing";
    has high_priority_neighbors: list;
    
    can get_status with visitor entry {
        # Visitor can access node data safely
        status = self.data?.["status"] or "unknown";
        visitor.record_status(status);
    }
}
```

#### Performance Considerations

Null-safe operations include runtime checks that add minimal overhead while significantly improving code robustness. The compiler optimizes common access patterns to minimize performance impact.

#### Error Handling

Standard access operations raise appropriate exceptions for invalid keys or attributes, while null-safe operations return `None` for missing intermediate values. This distinction enables explicit error handling strategies based on application requirements.

Subscripted and dotted expressions provide the foundation for safe, expressive data access patterns that integrate naturally with both traditional programming constructs and object-spatial operations.
