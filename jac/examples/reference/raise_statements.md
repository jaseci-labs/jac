Raise statements in Jac provide the mechanism for explicitly throwing exceptions, enabling structured error handling and control flow disruption. These statements allow functions and methods to signal error conditions, invalid states, or exceptional circumstances that require special handling by calling code.

**Basic Raise Statement Syntax**

Raise statements follow this pattern from the grammar:
```jac
raise exception_expression;           # Raise specific exception
raise;                               # Re-raise current exception (in except block)
raise exception_expression from cause; # Raise with explicit cause chain
```

**Example Implementation**

The provided example demonstrates exception raising and handling:
```jac
def foo(value: int) {
    if value < 0 {
        raise ValueError("Value must be non-negative");
    }
}
```

**Exception handling:**
```jac
try {
    foo(-1);
} except ValueError as e {
    print("Raised:", e);
}
```

**Key aspects:**
- **Conditional raising**: Exceptions raised based on input validation
- **Exception type**: `ValueError` indicates the type of error
- **Error message**: Descriptive string explaining the error condition
- **Exception catching**: Try-catch block handles the raised exception

**Exception Types**

Jac supports various built-in exception types:

**Built-in Exceptions**
```jac
raise ValueError("Invalid value provided");
raise TypeError("Expected int, got str");
raise IndexError("List index out of range");
raise KeyError("Dictionary key not found");
raise RuntimeError("General runtime error");
```

**Custom Exceptions**
```jac
class CustomError : Exception {
    def init(message: str) {
        self.message = message;
    }
}

raise CustomError("Application-specific error");
```

**Raise Patterns**

**Input Validation**
```jac
def divide(a: float, b: float) -> float {
    if b == 0.0 {
        raise ZeroDivisionError("Cannot divide by zero");
    }
    return a / b;
}
```

**State Validation**
```jac
def process_data(data: list) {
    if data is None {
        raise ValueError("Data cannot be None");
    }
    if len(data) == 0 {
        raise ValueError("Data cannot be empty");
    }
    # Process data
}
```

**Type Checking**
```jac
def calculate_area(shape: Shape) {
    if not isinstance(shape, Shape) {
        raise TypeError("Expected Shape instance");
    }
    return shape.calculate_area();
}
```

**Re-raising Exceptions**

Bare raise statements re-raise the current exception:

**Exception Logging and Re-raising**
```jac
def sensitive_operation() {
    try {
        risky_function();
    } except Exception as e {
        log_error("Operation failed", e);
        raise;  # Re-raise the same exception
    }
}
```

**Exception Transformation**
```jac
def api_call() {
    try {
        internal_operation();
    } except InternalError as e {
        raise APIError("Public API failed") from e;
    }
}
```

**Exception Chaining**

The `from` clause enables exception chaining:

**Explicit Cause Chain**
```jac
def high_level_operation() {
    try {
        low_level_operation();
    } except LowLevelError as e {
        raise HighLevelError("High-level operation failed") from e;
    }
}
```

**Suppressing Chain**
```jac
def clean_operation() {
    try {
        messy_operation();
    } except MessyError {
        raise CleanError("Clean error message") from None;
    }
}
```

**Conditional Exception Raising**

Raise statements often appear in conditional contexts:

**Guard Clauses**
```jac
def process_file(filename: str) {
    if not filename {
        raise ValueError("Filename cannot be empty");
    }
    if not file_exists(filename) {
        raise FileNotFoundError("File does not exist");
    }
    # Process file
}
```

**State Machine Validation**
```jac
class StateMachine {
    def transition(new_state: str) {
        if not self.is_valid_transition(new_state) {
            raise InvalidStateError("Invalid state transition");
        }
        self.state = new_state;
    }
}
```

**Integration with Object-Spatial Features**

Raise statements work within object-spatial contexts:

**Walker Error Handling**
```jac
walker DataProcessor {
    can process with `node entry {
        if not here.is_valid {
            raise ProcessingError("Invalid node data");
        }
        try {
            here.process_data();
        } except DataError as e {
            raise WalkerError("Walker processing failed") from e;
        }
    }
}
```

**Node Validation**
```jac
node SecureNode {
    can validate_access with Visitor entry {
        if not visitor.has_permission {
            raise PermissionError("Access denied");
        }
        if visitor.security_level < self.required_level {
            raise SecurityError("Insufficient security level");
        }
    }
}
```

**Exception Handling Patterns**

**Resource Management**
```jac
def acquire_resource() {
    resource = None;
    try {
        resource = allocate_resource();
        if not resource.is_valid {
            raise ResourceError("Failed to allocate resource");
        }
        return resource;
    } except Exception as e {
        if resource {
            resource.cleanup();
        }
        raise;
    }
}
```

**Retry Patterns**
```jac
def retry_operation(max_attempts: int) {
    for attempt=1 to attempt<=max_attempts by attempt+=1 {
        try {
            return perform_operation();
        } except TemporaryError as e {
            if attempt == max_attempts {
                raise FinalError("All retry attempts failed") from e;
            }
            wait_before_retry();
        }
    }
}
```

**Error Context Preservation**

**Detailed Error Information**
```jac
def parse_config(config_data: str) {
    try {
        return json.parse(config_data);
    } except JsonError as e {
        line_number = e.get_line_number();
        raise ConfigError("Invalid config at line {}".format(line_number)) from e;
    }
}
```

**Performance Considerations**

**Exception Overhead**
- Raising exceptions is expensive compared to normal control flow
- Use exceptions for exceptional conditions, not normal program flow
- Consider early validation to avoid deep call stack exceptions

**Optimization Strategies**
```jac
# Efficient: Check before expensive operation
def safe_operation(data: list) {
    if not validate_data(data) {
        raise ValidationError("Invalid data");
    }
    return expensive_operation(data);
}

# Less efficient: Exception in expensive operation
def unsafe_operation(data: list) {
    try {
        return expensive_operation(data);
    } except InternalError {
        raise OperationError("Operation failed");
    }
}
```

**Exception Safety**

**Exception-Safe Code**
```jac
def atomic_operation() {
    state = save_state();
    try {
        perform_risky_operation();
    } except Exception as e {
        restore_state(state);
        raise;
    }
}
```

**Best Practices**

1. **Use specific exception types**: Choose appropriate exception classes
2. **Provide descriptive messages**: Include context and possible solutions
3. **Validate early**: Check preconditions at function entry
4. **Preserve exception chains**: Use `from` clause for causal relationships
5. **Clean up resources**: Ensure proper cleanup even when exceptions occur

**Common Exception Patterns**

**Factory Methods**
```jac
def create_object(type_name: str) {
    if type_name not in valid_types {
        raise ValueError("Unknown type: {}".format(type_name));
    }
    return type_constructors[type_name]();
}
```

**Protocol Validation**
```jac
def send_message(message: Message) {
    if not message.is_valid() {
        raise ProtocolError("Invalid message format");
    }
    if message.size() > MAX_MESSAGE_SIZE {
        raise MessageTooLargeError("Message exceeds size limit");
    }
    transmit(message);
}
```

**Graceful Degradation**
```jac
def get_user_preference(user_id: str, key: str) {
    try {
        return database.get_preference(user_id, key);
    } except DatabaseError as e {
        log_warning("Database error, using default", e);
        raise PreferenceError("Cannot retrieve preference") from e;
    }
}
```

**Integration with Testing**

```jac
def test_division_by_zero() {
    try {
        result = divide(10, 0);
        assert false, "Expected ZeroDivisionError";
    } except ZeroDivisionError {
        # Test passes - expected exception
        pass;
    }
}
```

Raise statements in Jac provide essential error signaling capabilities that enable robust exception handling, clear error communication, and structured error recovery patterns. They support both simple error reporting and sophisticated exception chaining, making them valuable tools for building reliable applications that can gracefully handle exceptional conditions and provide meaningful error feedback.
