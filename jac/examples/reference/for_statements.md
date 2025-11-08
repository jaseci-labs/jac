For statements provide powerful iteration mechanisms with multiple syntax variants designed for different looping scenarios. Jac supports both traditional iteration patterns and expressive loop constructs that enhance readability while reducing common programming errors.

#### For Loop Variants

Jac offers three distinct for loop syntaxes:

**For-In Loops**: Iterate over collections and iterables with clean, readable syntax.

**For-To-By Loops**: Explicit counter-based iteration with clear initialization, termination, and increment specifications.

**Async For Loops**: Asynchronous iteration for concurrent processing patterns.

#### For-In Loop Syntax

For-in loops provide clean iteration over collections and sequences:

```jac
for variable in iterable {
    # loop body
}
```

This syntax works with all iterable types including strings, lists, ranges, and custom collections.

#### String and Character Iteration

```jac
for character in "hello" {
    print(character);  # Prints 'h', 'e', 'l', 'l', 'o'
}
```

String iteration processes each character individually, providing natural text processing capabilities.

#### Range-Based Iteration

```jac
for number in range(1, 5) {
    print(number);  # Prints 1, 2, 3, 4
}

for index in range(len(array)) {
    process(array[index]);
}
```

Range objects generate sequences efficiently with exclusive end boundaries, following Python conventions.

#### Collection Iteration

For-in loops work seamlessly with all Jac collection types:

```jac
# List iteration
for item in [1, 2, 3, 4, 5] {
    process_item(item);
}

# Dictionary key iteration
for key in {"name": "John", "age": 30} {
    print(f"{key}: {data[key]}");
}

# Set iteration
for element in {1, 2, 3, 4} {
    validate_element(element);
}
```

#### For-To-By Loop Syntax

For-to-by loops provide explicit control over counter-based iteration:

```jac
for initialization to condition by increment {
    # loop body
}
```

This syntax makes loop components explicit and reduces common iteration errors.

#### For-To-By Examples

```jac
# Basic counting
for i=0 to i<10 by i+=1 {
    print(i);  # Prints 0 through 9
}

# Custom increments
for count=100 to count>0 by count-=5 {
    print(f"Countdown: {count}");
}

# Complex conditions
for x=1.0 to x<=100.0 by x*=1.5 {
    # Exponential growth pattern
    process_value(x);
}
```

#### Nested Loop Patterns

Different loop syntaxes can be combined for complex iteration patterns:

```jac
for outer_char in "abc" {
    for inner_num in range(1, 3) {
        for counter=1 to counter<=2 by counter+=1 {
            print(f"{outer_char}-{inner_num}-{counter}");
        }
    }
}
```

This demonstrates the flexibility of mixing for-in and for-to-by syntaxes based on specific needs.

#### Advanced For-In Patterns

**Enumeration with Index**:
```jac
for index, value in enumerate(collection) {
    print(f"Item {index}: {value}");
}
```

**Dictionary Items**:
```jac
for key, value in data.items() {
    process_pair(key, value);
}
```

**Destructuring Assignment**:
```jac
for name, age, city in user_records {
    create_user_profile(name, age, city);
}
```

#### Object-Spatial Integration

For loops integrate naturally with object-spatial programming constructs:

```jac
walker GraphTraverser {
    can traverse_neighbors with entry {
        # Iterate over connected nodes
        for neighbor in [-->] {
            if neighbor.is_processable {
                visit neighbor;
            }
        }
    }
    
    can process_edges with entry {
        # Iterate over specific edge types
        for edge in [-->:DataEdge:] {
            edge.process_data();
        }
    }
}

node CollectionNode {
    has items: list;
    
    can process_items with visitor entry {
        for item in self.items {
            result = visitor.process_item(item);
            if result.should_stop {
                break;
            }
        }
    }
}
```

#### Control Flow Integration

For loops work seamlessly with control statements:

```jac
for item in large_collection {
    if item.should_skip() {
        continue;  # Skip to next iteration
    }
    
    if item.is_terminal() {
        break;     # Exit loop entirely
    }
    
    process_item(item);
}
```

#### Asynchronous For Loops

For asynchronous iteration over async iterables:

```jac
async for data_chunk in async_data_stream {
    processed = await process_chunk(data_chunk);
    await store_result(processed);
}
```

Async for loops enable efficient processing of streaming data and concurrent operations.

#### Performance Considerations

**For-In Optimization**: Optimized for collection traversal with minimal memory overhead and efficient iterator protocols.

**For-To-By Optimization**: Specialized arithmetic operations and efficient condition evaluation for counter-based loops.

**Memory Efficiency**: Iterators generate values on demand, supporting large datasets without excessive memory usage.

#### Complex Iteration Patterns

**Multi-Variable For-To-By**:
```jac
for i=0, j=len(array)-1 to i<j by i+=1, j-=1 {
    # Two-pointer technique
    if array[i] + array[j] == target {
        return (i, j);
    }
}
```

**Conditional Iteration**:
```jac
for item in collection if item.is_valid() {
    # Only iterate over valid items
    process_valid_item(item);
}
```

**Batch Processing**:
```jac
for batch in chunked(large_dataset, batch_size=1000) {
    process_batch(batch);
    if should_pause() {
        break;
    }
}
```

#### Graph Traversal Patterns

For loops enable sophisticated graph processing:

```jac
walker PathAnalyzer {
    has path_lengths: dict = {};
    
    can analyze_paths with entry {
        # Analyze all possible paths
        for target_node in [-->*] {
            path_length = calculate_distance(here, target_node);
            self.path_lengths[target_node.id] = path_length;
        }
        
        # Process paths by length
        for length=1 to length<=max_depth by length+=1 {
            nodes_at_distance = [n for n, d in self.path_lengths.items() if d == length];
            for node in nodes_at_distance {
                process_node_at_distance(node, length);
            }
        }
    }
}
```

#### Error Handling in Loops

```jac
for item in potentially_problematic_collection {
    try {
        result = risky_operation(item);
        store_result(result);
    } except ProcessingError as e {
        log_error(f"Failed to process {item}: {e}");
        continue;  # Skip problematic items
    }
}
```

#### Best Practices

**Choose Appropriate Syntax**: Use for-in for collections, for-to-by for explicit counter control.

**Clear Variable Names**: Use descriptive names that indicate the purpose of loop variables.

**Avoid Side Effects**: Minimize modifications to collections during iteration to prevent unexpected behavior.

**Performance Awareness**: Consider memory usage and computational complexity for large datasets.

**Control Flow**: Use break and continue judiciously to implement complex iteration logic clearly.

For statements provide flexible, expressive iteration capabilities that support both traditional programming patterns and modern object-spatial operations, enabling developers to write clear, efficient code for a wide range of computational scenarios.
