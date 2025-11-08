While statements in Jac provide iterative execution based on conditional expressions, enabling loops that continue as long as a specified condition remains true. The while loop syntax offers a fundamental control structure for implementing algorithms that require repeated execution with dynamic termination conditions.

**Basic While Loop Syntax**

While statements follow this pattern from the grammar:
```jac
while condition {
    # code block
}
```

**Example Implementation**

The provided example demonstrates a basic counting loop:
```jac
i = 1;
while i < 6 {
    print(i);
    i += 1;
}
```

**Execution flow:**
1. Initialize counter variable `i = 1`
2. Check condition `i < 6` (true, so enter loop)
3. Execute loop body: print `i` and increment `i`
4. Check condition again with new value
5. Repeat until condition becomes false
6. Exit loop when `i` reaches 6

**Key Components**

**Condition Expression**
- Evaluated before each iteration
- Must be a boolean expression or evaluable to boolean
- Loop continues while condition is true
- Loop exits when condition becomes false

**Code Block**
- Enclosed in curly braces `{}`
- Contains statements to execute repeatedly
- Should modify variables that affect the condition to avoid infinite loops
- Can contain any valid Jac statements

**Loop Control Variables**

While loops typically require explicit management of control variables:

**Counter-Based Loops**
```jac
count = 0;
while count < 10 {
    process_item(count);
    count += 1;  # Manual increment required
}
```

**Condition-Based Loops**
```jac
while not finished {
    result = perform_task();
    finished = result.is_complete;
}
```

**Iterator-Based Loops**
```jac
index = 0;
while index < array.length {
    process(array[index]);
    index += 1;
}
```

**Common While Loop Patterns**

**Input Processing**
```jac
user_input = get_input();
while user_input != "quit" {
    process_command(user_input);
    user_input = get_input();
}
```

**Search Operations**
```jac
found = false;
index = 0;
while index < data.length and not found {
    if data[index] == target {
        found = true;
    } else {
        index += 1;
    }
}
```

**Convergence Algorithms**
```jac
error = calculate_error();
iteration = 0;
while error > tolerance and iteration < max_iterations {
    update_parameters();
    error = calculate_error();
    iteration += 1;
}
```

**Infinite Loop Prevention**

While loops require careful design to avoid infinite loops:

**Loop Guards**
```jac
attempts = 0;
max_attempts = 100;
while condition and attempts < max_attempts {
    # loop body
    attempts += 1;
}
```

**Progress Verification**
```jac
previous_value = initial_value;
while not converged {
    current_value = compute_next();
    if current_value == previous_value {
        break;  # Prevent infinite loop
    }
    previous_value = current_value;
}
```

**Integration with Control Statements**

While loops work with control flow statements:

**Break Statement**
```jac
while true {
    input = get_input();
    if input == "exit" {
        break;  # Exit loop immediately
    }
    process(input);
}
```

**Continue Statement**
```jac
i = 0;
while i < 10 {
    i += 1;
    if i % 2 == 0 {
        continue;  # Skip even numbers
    }
    print(i);
}
```

**Nested While Loops**

While loops can be nested for complex iteration patterns:

```jac
row = 0;
while row < height {
    col = 0;
    while col < width {
        process_cell(row, col);
        col += 1;
    }
    row += 1;
}
```

**Object-Spatial Integration**

While loops work within object-spatial contexts:

**Walker State Loops**
```jac
walker Processor {
    can process with `node entry {
        attempts = 0;
        while not here.is_processed and attempts < 3 {
            here.attempt_processing();
            attempts += 1;
        }
        if here.is_processed {
            visit [-->];
        }
    }
}
```

**Node Processing Loops**
```jac
node BatchProcessor {
    can process_batch with Worker entry {
        batch_index = 0;
        while batch_index < self.batch_size {
            self.process_item(batch_index);
            batch_index += 1;
        }
    }
}
```

**Collection Processing**

While loops for manual collection iteration:

**Array Processing**
```jac
index = 0;
while index < items.length {
    item = items[index];
    if item.needs_processing {
        process(item);
    }
    index += 1;
}
```

**Dynamic Collections**
```jac
while queue.has_items() {
    item = queue.dequeue();
    result = process(item);
    if result.creates_new_items {
        queue.enqueue_all(result.new_items);
    }
}
```

**Performance Considerations**

**Condition Evaluation**
- Condition is evaluated before every iteration
- Complex conditions can impact performance
- Consider caching expensive calculations

**Loop Optimization**
```jac
# Less efficient
while expensive_function() < threshold {
    # loop body
}

# More efficient
limit = expensive_function();
while counter < limit {
    # loop body
    counter += 1;
}
```

**Memory Usage**
- Variables declared inside loops are recreated each iteration
- Consider declaring outside loop when appropriate

**Comparison with For Loops**

**While loops are preferred when:**
- Termination condition is complex or dynamic
- Number of iterations is unknown in advance
- Loop control requires custom logic

**For loops are preferred when:**
- Iterating over collections
- Counter-based iteration with known bounds
- Standard increment/decrement patterns

**Error Handling in While Loops**

```jac
while has_work() {
    try {
        task = get_next_task();
        task.execute();
    } except TaskError as e {
        log_error(e);
        continue;  # Skip failed task, continue with next
    } except CriticalError as e {
        log_critical(e);
        break;     # Exit loop on critical error
    }
}
```

**Best Practices**

1. **Always modify loop variables**: Ensure the condition can eventually become false
2. **Use meaningful conditions**: Make loop termination logic clear
3. **Avoid complex conditions**: Keep conditions simple and readable
4. **Include safety guards**: Prevent infinite loops with counters or timeouts
5. **Consider alternatives**: Use for loops when appropriate for better readability

**Common Pitfalls**

1. **Infinite loops**: Forgetting to modify condition variables
2. **Off-by-one errors**: Incorrect boundary conditions
3. **Uninitialized variables**: Using undefined variables in conditions
4. **Side effects**: Unexpected condition changes from function calls

While statements in Jac provide essential iterative control for scenarios requiring dynamic loop termination. They complement for loops by handling cases where the number of iterations is not predetermined, making them valuable for algorithms involving search, convergence, and event-driven processing.
