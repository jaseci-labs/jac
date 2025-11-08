Control statements provide essential flow control mechanisms for managing program execution within loops and conditional structures. These statements enable precise control over iteration and branching, complementing Jac's object-spatial features with traditional imperative programming constructs.

#### Basic Control Operations

Jac supports fundamental control statements for loop management:

**`break`**: Immediately exits the current loop and transfers control to the statement following the loop structure.

**`continue`**: Skips the remainder of the current loop iteration and proceeds to the next iteration.

**`skip`**: Data spatial equivalent for walker traversal control (covered in walker statements documentation).

**Break Statement**

The `break` statement immediately terminates the innermost loop and transfers control to the statement following the loop:

```jac
for i in range(9) {
    if i > 2 {
        print("loop is stopped!!");
        break;
    }
    print(i);
}
```

**Execution flow:**
1. Loop begins with `i = 0`
2. Prints `0`, then `1`, then `2`
3. When `i = 3`, condition `i > 2` becomes true
4. Prints "loop is stopped!!"
5. `break` executes, immediately exiting the loop
6. Execution continues after the loop block

**Continue Statement**

The `continue` statement skips the remainder of the current loop iteration and jumps to the next iteration:

```jac
for j in "WIN" {
    if j == "W" {
        continue;
    }
    print(j);
}
```

**Execution flow:**
1. First iteration: `j = "W"`
2. Condition `j == "W"` is true
3. `continue` executes, skipping the `print(j)` statement
4. Second iteration: `j = "I"`
5. Condition is false, `print("I")` executes
6. Third iteration: `j = "N"`
7. Condition is false, `print("N")` executes

**Loop Integration**

Control statements work with all Jac loop constructs:

**For-In Loops**
```jac
for item in collection {
    if condition {
        break;     # Exit loop
    }
    if other_condition {
        continue;  # Skip to next item
    }
    # Process item
}
```

**For-To-By Loops**
```jac
for i=0 to i<10 by i+=1 {
    if i % 2 == 0 {
        continue;  # Skip even numbers
    }
    if i > 7 {
        break;     # Stop when i exceeds 7
    }
    print(i);      # Prints 1, 3, 5, 7
}
```

**While Loops**
```jac
while condition {
    if exit_condition {
        break;     # Exit while loop
    }
    if skip_condition {
        continue;  # Skip to condition check
    }
    # Loop body
}
```

**Nested Loop Behavior**

Control statements affect only the innermost loop:

```jac
for i in range(3) {
    for j in range(3) {
        if j == 1 {
            break;     # Exits inner loop only
        }
        print(i, j);
    }
    print("Outer loop continues");
}
```

**Output pattern:**
- Inner loop breaks when `j == 1`
- Outer loop continues for all values of `i`
- Each outer iteration prints "Outer loop continues"

**Conditional Integration**

Control statements work seamlessly with Jac's conditional expressions:

**Simple Conditions**
```jac
for item in items {
    if item.is_valid() {
        continue;  # Skip invalid items
    }
    process(item);
}
```

**Complex Conditions**
```jac
for data in dataset {
    if data.type == "error" and data.severity > threshold {
        print("Critical error found");
        break;     # Stop processing on critical error
    }
    analyze(data);
}
```

**Function and Method Context**

Control statements can be used within functions and methods:

```jac
def process_list(items: list) -> list {
    results = [];
    for item in items {
        if item < 0 {
            continue;   # Skip negative values
        }
        if item > 100 {
            break;      # Stop at first value over 100
        }
        results.append(item * 2);
    }
    return results;
}
```

**Object-Spatial Integration**

While control statements primarily affect traditional loops, they complement object-spatial operations:

```jac
walker Processor {
    can process_nodes with `root entry {
        for node in [-->] {
            if node.should_skip {
                continue;  # Skip certain nodes
            }
            if node.stop_condition {
                break;     # Exit processing loop
            }
            node.process();
        }
    }
}
```

**Error Handling Patterns**

Control statements enable robust error handling:

**Early Exit on Error**
```jac
for operation in operations {
    if operation.has_error() {
        print("Error detected, stopping");
        break;
    }
    operation.execute();
}
```

**Skip Invalid Data**
```jac
for record in data_records {
    if not record.is_valid() {
        continue;  # Skip malformed records
    }
    process_record(record);
}
```

**Performance Considerations**

Control statements are optimized for efficiency:

**Break Optimization**
- Immediately exits loop without further condition checking
- Minimal overhead for early termination
- Useful for search algorithms and error conditions

**Continue Optimization**
- Jumps directly to next iteration
- Skips unnecessary computation in current iteration
- Efficient for filtering operations

**Common Patterns**

**Search and Exit**
```jac
found = false;
for item in search_space {
    if item.matches(criteria) {
        found = true;
        break;
    }
}
```

**Filter Processing**
```jac
for data in input_stream {
    if not meets_criteria(data) {
        continue;
    }
    process_valid_data(data);
}
```

**Batch Processing with Limits**
```jac
processed = 0;
for item in large_dataset {
    if processed >= batch_limit {
        break;
    }
    process_item(item);
    processed += 1;
}
```

**Best Practices**

1. **Clear Intent**: Use control statements to make loop logic explicit
2. **Early Exit**: Use `break` for efficiency when search conditions are met
3. **Filtering**: Use `continue` to skip invalid or unnecessary data
4. **Limit Scope**: Control statements affect only the immediate loop
5. **Readable Code**: Combine with clear conditional logic for maintainability

Control statements in Jac provide essential building blocks for algorithmic logic, enabling developers to implement efficient loops with precise flow control. While Jac's object-spatial features offer novel traversal mechanisms, traditional control statements remain crucial for implementing conventional algorithms and handling edge cases in data processing workflows.
