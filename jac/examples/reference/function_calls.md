Function calls in Jac provide the fundamental mechanism for invoking defined functions and methods, supporting both traditional positional arguments and named keyword arguments. The function call system integrates seamlessly with Jac's type system and expression evaluation, enabling flexible and expressive function invocation patterns.

**Basic Function Call Syntax**

Function calls in Jac follow the familiar pattern:
```jac
function_name(arguments)
```

**Function Definition Context**

The example demonstrates calling a function with a clear signature:
```jac
def foo(x: int, y: int, z: int) {
    return (x * y, y * z);
}
```

Key aspects:
- **Required type annotations**: All parameters must specify their types
- **Multiple return values**: Functions can return tuples
- **Clear interface**: Type system provides compile-time verification

**Keyword Arguments**

Jac supports keyword argument syntax for explicit parameter naming:
```jac
output = foo(x=4, y=4 if a % 3 == 2 else 3, z=9);
```

**Benefits of keyword arguments:**
- **Clarity**: Makes function calls self-documenting
- **Flexibility**: Arguments can be provided in any order
- **Maintainability**: Changes to parameter order don't break existing calls
- **Readability**: Complex function calls become more understandable

**Complex Expressions as Arguments**

Function arguments can be sophisticated expressions:
```jac
y=4 if a % 3 == 2 else 3
```

This demonstrates:
- **Conditional expressions**: Using ternary operator syntax in arguments
- **Variable references**: Accessing variables from enclosing scope (`a`)
- **Expression evaluation**: Complex computations resolved before function call
- **Type safety**: Expression results must match parameter types

**Argument Evaluation Order**

Arguments are evaluated from left to right before the function is called:
1. `x=4` evaluates to `4`
2. `y=4 if a % 3 == 2 else 3` evaluates the conditional expression
3. `z=9` evaluates to `9`
4. Function `foo` is called with the resolved values

**Return Value Handling**

Functions can return multiple values as tuples:
```jac
return (x * y, y * z);
```

**Calling code receives the tuple:**
```jac
output = foo(x=4, y=4 if a % 3 == 2 else 3, z=9);
```

The `output` variable contains the returned tuple, which can be:
- **Used directly**: Passed to other functions or printed
- **Unpacked**: Destructured into individual variables
- **Indexed**: Accessed using tuple indexing syntax

**Mixed Argument Styles**

Jac supports combining positional and keyword arguments:
```jac
# Positional arguments first
result = foo(4, y=3, z=9);

# All keyword arguments
result = foo(x=4, y=3, z=9);

# All positional arguments
result = foo(4, 3, 9);
```

**Method Calls**

Function call syntax extends to method invocation:
```jac
obj.method(arg1, arg2=value);
```

**Static method calls:**
```jac
ClassName.static_method(arg1, arg2);
```

**Chained Calls**

Function calls can be chained for fluent interfaces:
```jac
result = obj.method1(arg).method2().method3(param=value);
```

**Function Calls in Expressions**

Function calls integrate with all expression contexts:

**Arithmetic expressions:**
```jac
total = calculate(a, b) + calculate(c, d);
```

**Conditional expressions:**
```jac
value = process(data) if is_valid(data) else default_value();
```

**Assignment expressions:**
```jac
x, y = get_coordinates(location);
```

**Nested function calls:**
```jac
result = outer_function(inner_function(param), other_param);
```

**Error Handling**

Function calls participate in Jac's exception handling:
```jac
try {
    result = potentially_failing_function(args);
} except Exception as e {
    handle_error(e);
}
```

**Type Safety and Validation**

Jac's type system ensures function call safety:
- **Compile-time checking**: Argument types verified against parameter types
- **Type inference**: Return types inferred for further usage
- **Error prevention**: Mismatched types caught before runtime

**Performance Considerations**

Function calls in Jac are optimized for:
- **Efficient argument passing**: Minimal overhead for parameter transmission
- **Type specialization**: Optimized execution paths for specific type combinations
- **Inlining opportunities**: Small functions may be inlined for performance

**Integration with Object-Spatial Features**

Function calls work seamlessly with Jac's object-spatial constructs:

**Within walker abilities:**
```jac
walker Processor {
    can process with `node entry {
        result = calculate_value(here.property);
        here.update_state(result);
    }
}
```

**Within node abilities:**
```jac
node DataNode {
    can process with Walker entry {
        processed = transform_data(self.data);
        visitor.receive_result(processed);
    }
}
```

**Common Patterns**

**Configuration and Setup**
```jac
config = load_configuration(file_path, defaults=default_config);
```

**Data Processing**
```jac
cleaned_data = clean_data(raw_data, rules=cleaning_rules);
processed = transform(cleaned_data, format="json");
```

**Validation and Error Checking**
```jac
if validate_input(user_data, schema=input_schema) {
    process_valid_data(user_data);
}
```

**Best Practices**

1. **Use keyword arguments**: For functions with multiple parameters of the same type
2. **Type consistency**: Ensure argument expressions match parameter types
3. **Clear naming**: Choose descriptive function and parameter names
4. **Error handling**: Wrap potentially failing function calls in try-catch blocks
5. **Documentation**: Use type annotations to self-document function interfaces

Function calls in Jac provide a robust foundation for code organization and reuse, combining the familiarity of traditional function invocation with the safety and expressiveness of a modern type system. The support for keyword arguments and complex expressions as parameters enables clear, maintainable code that integrates well with both traditional programming patterns and Jac's innovative object-spatial features.
