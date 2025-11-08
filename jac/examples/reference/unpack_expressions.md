Unpack expressions enable the expansion of iterables and mappings into their constituent elements using the `*` and `**` operators. Jac follows Python's unpacking semantics while integrating seamlessly with pipe operations and object-spatial programming constructs.

#### Iterable Unpacking

The single asterisk (`*`) operator unpacks iterables into individual elements:

```jac
first = [1, 2, 3];
second = [4, 5];
combined = [*first, *second];  # [1, 2, 3, 4, 5]

coords = (3, 4);
point3d = (*coords, 5);        # (3, 4, 5)
```

Unpacking preserves evaluation order, ensuring predictable behavior when side effects are involved.

#### Mapping Unpacking

The double asterisk (`**`) operator unpacks mappings into key-value pairs:

```jac
base = {"a": 1, "b": 2};
extend = {"b": 99, "c": 3};
merged = {**base, **extend};   # {"a": 1, "b": 99, "c": 3}
```

When duplicate keys exist, later values override earlier ones, following Python's precedence rules.

#### Function Call Unpacking

Unpacking integrates with function calls and pipe operations:

```jac
def process_data(x: int, y: int, z: int) -> int {
    return x + y + z;
}

# Traditional call unpacking
args = [1, 2, 3];
result = process_data(*args);

# Pipe operation with unpacking
kwargs = {"x": 1, "y": 2, "z": 3};
result = kwargs |> process_data;
```

#### Mixed Argument Patterns

Unpacking can be combined with explicit arguments in flexible patterns:

```jac
def complex_function(a, b, c=10, d=20) {
    return a + b + c + d;
}

# Mixed positional and keyword unpacking
positional = [1, 2];
keywords = {"d": 30};
result = complex_function(*positional, c=15, **keywords);
```

#### Integration with Object-Spatial Operations

Unpacking works seamlessly with object-spatial constructs:

```jac
walker DataCollector {
    has collected_data: list = [];
    
    can gather with entry {
        # Unpack node data into processing function
        node_values = here.get_values();
        processed = process_batch(*node_values);
        
        # Collect results using unpacking
        self.collected_data = [*self.collected_data, *processed];
    }
}

node DataNode {
    has config: dict;
    
    can configure with visitor entry {
        # Unpack configuration into visitor
        visitor.update_config(**self.config);
    }
}
```

#### Type Safety and Validation

Unpacking operations include runtime type checking:

- `*` requires iterable objects (lists, tuples, sets, etc.)
- `**` requires mapping objects with string keys
- Type mismatches raise `TypeError` at runtime

#### Performance Considerations

Unpacking creates new collections rather than sharing references, ensuring data isolation but requiring consideration of memory usage in performance-critical applications. The compiler optimizes common unpacking patterns to minimize overhead.

Unpack expressions provide essential functionality for flexible data manipulation while maintaining the clean, expressive syntax that characterizes Jac's approach to both traditional programming and object-spatial operations.
