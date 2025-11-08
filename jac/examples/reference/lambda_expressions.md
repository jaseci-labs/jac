Lambda expressions in Jac provide a concise way to create anonymous functions for functional programming patterns. These expressions enable the creation of small, single-expression functions without the overhead of formal function definitions, supporting Jac's functional programming capabilities while maintaining type safety through required parameter annotations.

**Basic Lambda Syntax**

Lambda expressions follow this general pattern:
```jac
lambda parameters : expression
```

**Example Usage**

The provided example demonstrates basic lambda creation and invocation:
```jac
x = lambda a: int, b: int : b + a;
print(x(5, 4));  # Outputs: 9
```

**Components breakdown:**
- **`lambda` keyword**: Introduces the lambda expression
- **Parameter list**: `a: int, b: int` with required type annotations
- **Colon separator**: `:` separates parameters from the expression body
- **Expression body**: `b + a` defines the computation
- **Assignment**: Lambda stored in variable `x` for later use
- **Invocation**: `x(5, 4)` calls the lambda with arguments

**Type Annotations**

Unlike Python, Jac requires explicit type annotations for all lambda parameters:

**Required Parameter Types**
```jac
square = lambda x: int : x * x;
divide = lambda a: float, b: float : a / b;
concat = lambda s1: str, s2: str : s1 + s2;
```

**Benefits of typed parameters:**
- **Compile-time verification**: Type mismatches caught early
- **Self-documentation**: Parameter types clearly specified
- **IDE support**: Better autocomplete and error detection
- **Performance optimization**: Compiler can generate specialized code

**Return Type Inference**

Lambda return types are automatically inferred from the expression:
```jac
lambda x: int : x * 2        # Returns int
lambda x: float : x / 2.0    # Returns float
lambda x: str : x.upper()    # Returns str
```

**Functional Programming Patterns**

**Higher-Order Functions**
Lambdas integrate with higher-order functions:
```jac
numbers = [1, 2, 3, 4, 5];
squared = map(lambda x: int : x * x, numbers);
evens = filter(lambda x: int : x % 2 == 0, numbers);
```

**Event Handlers**
```jac
button.on_click(lambda event: Event : handle_click(event));
```

**Sorting and Comparison**
```jac
people.sort(key=lambda person: Person : person.age);
```

**Expression Limitations**

Lambda expressions are limited to single expressions:

**Valid lambdas:**
```jac
lambda x: int : x + 1                    # Arithmetic
lambda x: int : x if x > 0 else -x       # Conditional expression  
lambda pair: tuple : pair[0] + pair[1]   # Tuple access
lambda obj: MyClass : obj.method()       # Method calls
```

**Invalid lambdas (require full functions):**
```jac
# Multiple statements not allowed
lambda x: int : {
    y = x * 2;
    return y + 1;
}

# Loops not allowed
lambda items: list : for item in items { process(item); }
```

**Variable Capture and Closures**

Lambdas can capture variables from their enclosing scope:
```jac
multiplier = 3;
triple = lambda x: int : x * multiplier;
print(triple(5));  # Outputs: 15
```

**Closure behavior:**
- **Lexical scoping**: Lambdas capture variables from creation context
- **Late binding**: Variable values resolved at call time
- **Immutable capture**: Captured variables maintain their reference

**Complex Lambda Examples**

**Multi-parameter operations:**
```jac
distance = lambda x1: float, y1: float, x2: float, y2: float : 
    ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5;
```

**Conditional logic:**
```jac
max_value = lambda a: int, b: int : a if a > b else b;
```

**String processing:**
```jac
capitalize_words = lambda text: str : 
    " ".join(word.capitalize() for word in text.split());
```

**Object property access:**
```jac
get_name = lambda obj: Person : obj.name;
```

**Integration with Collections**

Lambdas work seamlessly with collection operations:

**List comprehensions:**
```jac
transform = lambda x: int : x * 2;
results = [transform(i) for i in range(5)];
```

**Dictionary operations:**
```jac
key_mapper = lambda item: str : item.id;
grouped = {key_mapper(item): item for item in items};
```

**Set operations:**
```jac
validator = lambda x: int : x > 0;
valid_numbers = {x for x in numbers if validator(x)};
```

**Object-Spatial Integration**

Lambdas can be used within object-spatial constructs:

**Walker abilities:**
```jac
walker Processor {
    can process with `node entry {
        transform = lambda data: str : data.upper();
        here.data = transform(here.data);
    }
}
```

**Node filtering:**
```jac
valid_nodes = [n for n in [-->] if lambda node: Node : node.is_active()(n)];
```

**Edge processing:**
```jac
edge_weights = map(lambda e: Edge : e.weight, current_edges);
```

**Performance Considerations**

**Efficiency:**
- **Lightweight creation**: Minimal overhead for lambda instantiation
- **Optimized execution**: Compiled to efficient function calls
- **Type specialization**: Optimized based on parameter types

**Memory usage:**
- **Closure overhead**: Captured variables increase memory footprint
- **Garbage collection**: Lambdas cleaned up when references released
- **Optimization**: Simple lambdas may be inlined by compiler

**Common Patterns**

**Data transformation:**
```jac
processor = lambda item: dict : {
    "id": item.id,
    "name": item.name.upper(),
    "processed": true
};
```

**Validation:**
```jac
is_valid_email = lambda email: str : "@" in email and "." in email;
```

**Configuration:**
```jac
config_getter = lambda key: str : config.get(key, default_value);
```

**Best Practices**

1. **Keep it simple**: Use lambdas for single expressions only
2. **Type clearly**: Always provide explicit parameter types
3. **Descriptive names**: Use meaningful variable names for stored lambdas
4. **Avoid complexity**: Use regular functions for complex logic
5. **Consider readability**: Don't sacrifice clarity for brevity

**Comparison with Regular Functions**

**Lambda appropriate for:**
- Simple transformations
- Event handlers
- Inline operations
- Functional programming patterns

**Regular functions appropriate for:**
- Complex logic
- Multiple statements
- Detailed documentation needs
- Reusable algorithms

Lambda expressions in Jac provide a powerful tool for functional programming while maintaining the language's emphasis on type safety and clarity. They enable concise expression of simple operations while integrating seamlessly with both traditional programming constructs and Jac's innovative object-spatial features.
