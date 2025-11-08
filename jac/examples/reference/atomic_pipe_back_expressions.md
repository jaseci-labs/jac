Atomic pipe back expressions in Jac provide an alternative directional flow for data processing using the `<:` operator. This feature complements the pipe forward operator (`:>`) by enabling right-to-left data flow, offering flexibility in expression composition and readability.

**Atomic Pipe Back Syntax**

The pipe back operator `<:` takes data from the right side and passes it to the function or expression on the left side:

```jac
print <: "Hello world!";
```

This expression takes the string `"Hello world!"` and pipes it back to the `print` function, equivalent to calling `print("Hello world!")`.

**Mixed Directional Piping**

Jac allows combining pipe forward (`:>`) and pipe back (`<:`) operators in the same expression for flexible data flow:

```jac
c = len <: a + b :> len;
```

This complex expression demonstrates:
1. `a + b` - concatenates two lists
2. `:> len` - pipes the result forward to `len` function  
3. `len <:` - pipes the length result back to another `len` function call

**Comparison of Pipe Directions**

**Pipe Forward (`:>`)** - Left to right flow:
```jac
data :> function1 :> function2;
```

**Pipe Back (`<:`)** - Right to left flow:
```jac
function2 <: function1 <: data;
```

**Mixed Flow** - Combining directions:
```jac
result = function1 <: data :> function2;
```

**Use Cases for Pipe Back**

Pipe back expressions are particularly useful when:

- **Function-first thinking**: When you want to emphasize the operation before the data
- **Complex compositions**: Building expressions that read more naturally with mixed flow
- **Code organization**: Structuring expressions to match logical thinking patterns
- **Readability preferences**: Some algorithms express more clearly with backward flow

**Expression Evaluation**

Despite the directional syntax, evaluation follows standard precedence rules. The pipe operators provide syntactic convenience while maintaining logical evaluation order.

**Benefits**

- **Flexibility**: Choose the most readable direction for data flow
- **Composition**: Mix directions for optimal expression clarity
- **Expressiveness**: Match syntax to problem domain thinking patterns
- **Consistency**: Maintain functional programming patterns with directional choice

Atomic pipe back expressions enhance Jac's functional programming capabilities by providing bidirectional data flow options that improve code readability and expressiveness.
