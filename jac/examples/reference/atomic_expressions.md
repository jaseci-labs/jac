Atomic expressions in Jac represent the most fundamental and indivisible units of expression evaluation. They serve as building blocks for more complex expressions and include literals, identifiers, and other primary expression forms.

**Atomic Pipe Forward Expressions**

The example demonstrates atomic pipe forward operations using the `:>` operator, which enables a functional programming style by passing values through a chain of operations:

```jac
"Hello world!" :> print;
```

This expression takes the string literal `"Hello world!"` and pipes it forward to the `print` function, equivalent to calling `print("Hello world!")`.

**Chained Atomic Operations**

Atomic expressions can be chained together for more complex operations:

```jac
"Welcome" :> type :> print;
```

This chains multiple operations:
1. Start with the string `"Welcome"`
2. Pipe it to `type` function to get the type information
3. Pipe the result to `print` to display it

**Benefits of Atomic Pipe Expressions**

- **Readability**: Left-to-right reading flow that matches natural language
- **Composition**: Easy chaining of operations without nested function calls
- **Functional style**: Enables pipeline-based programming patterns
- **Clarity**: Makes data flow explicit and easy to follow

**Comparison with Traditional Syntax**

Traditional nested function calls:
```jac
print(type("Welcome"));
```

Atomic pipe forward style:
```jac
"Welcome" :> type :> print;
```

The pipe forward syntax eliminates the need to read expressions from inside-out, making code more intuitive and maintainable.

Atomic expressions form the foundation of Jac's expression system, enabling both traditional and functional programming paradigms while maintaining clear, readable code structure.
