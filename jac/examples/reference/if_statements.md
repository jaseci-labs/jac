If statements provide conditional execution control, enabling programs to make decisions based on boolean expressions. Jac's if statement syntax supports the familiar if-elif-else pattern with mandatory code blocks, ensuring clear and safe conditional logic.

#### Basic Conditional Syntax

If statements follow a structured pattern with required code blocks:

```jac
if condition {
    # code block executed when condition is true
}
```

The condition must evaluate to a boolean value, and the code block is enclosed in mandatory curly braces for clarity and consistency.

#### Complete Conditional Structure

The full conditional structure supports multiple decision branches:

```jac
if primary_condition {
    # executed when primary condition is true
} elif secondary_condition {
    # executed when secondary condition is true
} else {
    # executed when no conditions are true
}
```

#### Chained Comparison Operations

Jac supports elegant chained comparisons for range checking and multiple relationships:

```jac
score = 85;
if 0 <= score <= 59 {
    grade = "F";
} elif 60 <= score <= 69 {
    grade = "D";
} elif 70 <= score <= 79 {
    grade = "C";
} elif 80 <= score <= 89 {
    grade = "B";
} else {
    grade = "A";
}
```

Chained comparisons provide natural mathematical notation that improves readability and reduces the need for complex boolean expressions.

#### Boolean Logic Integration

If statements work with complex boolean expressions using logical operators:

```jac
# Logical AND
if user.is_authenticated and user.has_permission("read") {
    display_content();
}

# Logical OR
if is_admin or is_moderator {
    access_admin_panel();
}

# Logical NOT
if not is_maintenance_mode {
    process_requests();
}

# Complex combinations
if (user.age >= 18 and user.verified) or user.has_guardian_consent {
    allow_registration();
}
```

#### Sequential Evaluation Behavior

Elif statements provide efficient multi-way branching with sequential evaluation:

```jac
temperature = 75;
if temperature < 32 {
    status = "freezing";
} elif temperature < 50 {
    status = "cold";        # Only checked if temperature >= 32
} elif temperature < 80 {
    status = "comfortable"; # Only checked if temperature >= 50
} else {
    status = "hot";         # Only if temperature >= 80
}
```

Once a condition matches, remaining elif and else blocks are skipped, ensuring exactly one block executes and optimizing performance.

#### Object-Spatial Integration

If statements integrate seamlessly with object-spatial programming constructs:

```jac
walker PathValidator {
    can validate_path with entry {
        if here.is_accessible {
            # Continue traversal
            visit [-->];
        } elif here.has_alternate_route {
            # Try alternate path
            visit here.alternate_nodes;
        } else {
            # No valid path found
            report "Path blocked at node";
            disengage;
        }
    }
}

node SecurityNode {
    has access_level: int;
    
    can check_access with visitor entry {
        if visitor.security_clearance >= self.access_level {
            visitor.grant_access();
        } else {
            visitor.deny_access();
            # Prevent further traversal
        }
    }
}
```

#### Type-Safe Conditional Operations

Jac's type system ensures conditional safety through compile-time checking:

```jac
# Type checking with isinstance
if isinstance(data, dict) {
    process_dictionary(data);
} elif isinstance(data, list) {
    process_list(data);
}

# Null safety patterns
if user_input is not None {
    validated_input = validate(user_input);
    if validated_input.is_valid {
        process_input(validated_input);
    }
}
```

#### Nested Conditional Patterns

If statements support nesting for complex decision trees:

```jac
walker DecisionMaker {
    can make_decision with entry {
        if here.has_data {
            if here.data.is_valid {
                if here.data.priority == "high" {
                    process_immediately(here.data);
                } else {
                    queue_for_processing(here.data);
                }
            } else {
                clean_invalid_data(here);
            }
        } else {
            request_data_update(here);
        }
    }
}
```

#### Conditional Expression Support

If statements work with various expression types:

```jac
# Function call conditions
if validate_credentials(username, password) {
    login_user(username);
}

# Property access conditions
if node.status == "active" and node.load < threshold {
    assign_task(node, new_task);
}

# Collection membership
if user_id in authorized_users {
    grant_access();
}

# Complex expressions
if calculate_risk_score(transaction) > risk_threshold {
    flag_for_review(transaction);
}
```

#### Performance Optimization

If statements include several performance optimizations:

**Short-Circuit Evaluation**: Logical operators (`and`, `or`) stop evaluation as soon as the result is determined, minimizing unnecessary computation.

**Branch Prediction**: The compiler optimizes frequently taken branches based on usage patterns.

**Condition Ordering**: Place most likely conditions first in elif chains for optimal performance.

#### Common Conditional Patterns

**Input Validation**:
```jac
if input_data is None or len(input_data) == 0 {
    raise ValueError("Invalid input data");
}
```

**Range Validation**:
```jac
if not (0 <= index < array_length) {
    raise IndexError("Index out of bounds");
}
```

**Error Handling**:
```jac
if operation.has_error() {
    log_error(operation.get_error());
    return default_value;
} else {
    return operation.get_result();
}
```

**Configuration-Based Logic**:
```jac
if config.debug_enabled {
    log_debug_info(current_state);
}

if config.feature_flags.new_algorithm {
    use_new_algorithm();
} else {
    use_legacy_algorithm();
}
```

#### Integration with Graph Traversal

If statements enable sophisticated conditional traversal patterns:

```jac
walker SmartTraverser {
    has visited: set = set();
    
    can traverse with entry {
        # Avoid cycles
        if here in self.visited {
            disengage;
        }
        
        self.visited.add(here);
        
        # Conditional traversal based on node properties
        if here.node_type == "data" {
            process_data_node(here);
            visit [-->:DataEdge:];
        } elif here.node_type == "control" {
            if here.should_continue() {
                visit [-->];
            } else {
                disengage;
            }
        }
    }
}
```

If statements provide the foundation for decision-making in Jac programs, supporting both traditional programming patterns and sophisticated object-spatial operations with clear, readable syntax and robust type safety.
