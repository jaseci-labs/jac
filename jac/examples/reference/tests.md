Tests in Jac provide built-in support for unit testing and validation of code functionality. The `test` keyword creates test blocks that can be executed to verify program correctness.

#### Syntax

```jac
test {
    # test code
}

test "descriptive test name" {
    # named test code
}
```

#### Basic Testing

Simple test assertions:

```jac
test "basic arithmetic" {
    assert 2 + 2 == 4;
    assert 10 - 5 == 5;
    assert 3 * 4 == 12;
    assert 15 / 3 == 5;
}

test {
    # Anonymous test
    x = 10;
    y = 20;
    assert x < y;
    assert x + y == 30;
}
```

#### Testing Functions

Validate function behavior:

```jac
can calculate_area(radius: float) -> float {
    return 3.14159 * radius * radius;
}

test "area calculation" {
    assert calculate_area(1.0) == 3.14159;
    assert calculate_area(2.0) == 12.56636;
    assert abs(calculate_area(3.0) - 28.27431) < 0.00001;
}
```

#### Testing Objects and Classes

Test object creation and methods:

```jac
obj Rectangle {
    has width: float;
    has height: float;
    
    can area -> float {
        return self.width * self.height;
    }
    
    can perimeter -> float {
        return 2 * (self.width + self.height);
    }
}

test "rectangle operations" {
    rect = Rectangle(width=5.0, height=3.0);
    
    assert rect.area() == 15.0;
    assert rect.perimeter() == 16.0;
    
    # Test property modification
    rect.width = 10.0;
    assert rect.area() == 30.0;
}
```

#### Testing Graph Operations

Test node and edge functionality:

```jac
node DataNode {
    has value: int;
}

edge Connection {
    has weight: float = 1.0;
}

test "graph construction" {
    # Create nodes
    n1 = DataNode(value=10);
    n2 = DataNode(value=20);
    n3 = DataNode(value=30);
    
    # Connect nodes
    n1 ++>:Connection:++> n2;
    n2 ++>:Connection(weight=2.0):++> n3;
    
    # Test connections
    assert len([n1 -->]) == 1;
    assert len([n2 <--]) == 1;
    assert len([n2 -->]) == 1;
    
    # Test edge properties
    edge = [n2 -->:Connection:][0];
    assert edge.weight == 2.0;
}
```

#### Testing Walkers

Verify walker behavior:

```jac
walker TestWalker {
    has visited: list = [];
    
    can traverse with entry {
        self.visited.append(here.value);
        visit [-->];
    }
}

test "walker traversal" {
    # Setup graph
    root = DataNode(value=1);
    child1 = DataNode(value=2);
    child2 = DataNode(value=3);
    
    root ++> child1;
    root ++> child2;
    
    # Test walker
    walker = TestWalker();
    result = walker spawn root;
    
    assert 1 in walker.visited;
    assert 2 in walker.visited;
    assert 3 in walker.visited;
    assert len(walker.visited) == 3;
}
```

#### Exception Testing

Test error handling:

```jac
can divide(a: float, b: float) -> float {
    if b == 0 {
        raise ZeroDivisionError("Cannot divide by zero");
    }
    return a / b;
}

test "exception handling" {
    # Test normal operation
    assert divide(10, 2) == 5;
    
    # Test exception
    error_raised = False;
    try {
        divide(10, 0);
    } except ZeroDivisionError {
        error_raised = True;
    }
    assert error_raised;
}
```

#### Parameterized Testing

Test with multiple inputs:

```jac
test "parameterized validation" {
    test_cases = [
        {"input": 0, "expected": "zero"},
        {"input": 1, "expected": "positive"},
        {"input": -1, "expected": "negative"}
    ];
    
    for case in test_cases {
        result = classify_number(case["input"]);
        assert result == case["expected"];
    }
}
```

#### Setup and Teardown

Organize test environment:

```jac
test "with setup and cleanup" {
    # Setup
    temp_file = create_temp_file();
    original_state = save_current_state();
    
    try {
        # Test operations
        write_data(temp_file, "test data");
        assert file_exists(temp_file);
        assert read_data(temp_file) == "test data";
    } finally {
        # Cleanup
        delete_file(temp_file);
        restore_state(original_state);
    }
}
```

#### Testing Async Operations

Test asynchronous code:

```jac
test "async operations" {
    async can fetch_data -> str {
        await simulate_delay(0.1);
        return "async result";
    }
    
    # Test async function
    result = await fetch_data();
    assert result == "async result";
}
```

#### Test Organization

Group related tests:

```jac
# Math operations tests
test "addition operations" {
    assert add(2, 3) == 5;
    assert add(-1, 1) == 0;
    assert add(0, 0) == 0;
}

test "multiplication operations" {
    assert multiply(2, 3) == 6;
    assert multiply(-2, 3) == -6;
    assert multiply(0, 5) == 0;
}

# String operations tests
test "string manipulation" {
    assert uppercase("hello") == "HELLO";
    assert lowercase("WORLD") == "world";
    assert capitalize("jac") == "Jac";
}
```

#### Best Practices

1. **Descriptive Names**: Use clear test names that explain what's being tested
2. **Single Responsibility**: Each test should verify one specific behavior
3. **Independent Tests**: Tests shouldn't depend on each other
4. **Clear Assertions**: Make test expectations obvious
5. **Test Edge Cases**: Include boundary conditions and error cases

#### Running Tests

Tests can be executed:
- Individually by name
- All tests in a module
- Tests matching a pattern
- With verbose output for debugging

#### Integration Testing

Test complete workflows:

```jac
test "end-to-end graph processing" {
    # Build complex graph
    graph = build_test_graph();
    
    # Run processing walker
    processor = DataProcessor();
    results = processor spawn graph.root;
    
    # Verify results
    assert len(results) == expected_count;
    assert all_nodes_processed(graph);
    assert results.summary.errors == 0;
}
```

Tests in Jac provide a comprehensive framework for validating code correctness, from simple unit tests to complex integration scenarios, ensuring robust and reliable applications.
