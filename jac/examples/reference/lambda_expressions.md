Lambda expressions in Jac create anonymous functions with a concise syntax, perfect for short function definitions that you need to use inline or pass as arguments.

**What are Lambda Expressions?**

Lambda expressions are a way to create small, unnamed functions without using the full `def` syntax. They're ideal for simple operations that you only need once, like transforming data in a map or filter operation.

**Basic Lambda Syntax**

The general structure of a lambda expression follows this pattern:

| Component | Description | Required |
|-----------|-------------|----------|
| `lambda` keyword | Marks the start of a lambda expression | Yes |
| Parameters | Input parameters with optional type hints | No |
| `->` return type | Type hint for the return value | No |
| `:` separator | Separates signature from body | Yes |
| Expression | Single expression to evaluate and return | Yes |

**Lambda with Full Type Annotations**

Line 5 shows a lambda with complete type annotations. The expression `lambda a: int, b: int -> int : a + b` defines a function that takes two integer parameters and returns their sum. This is equivalent to:

The lambda version is more concise and can be assigned to a variable (line 5) or passed directly as an argument.

**Lambda Without Parameters**

Lines 9-10 demonstrate the simplest form of lambda: one that takes no parameters and just returns a constant value. The syntax `lambda : 42` creates a function that always returns 42 when called.

**Lambda Without Return Type Hints**

Lines 13-14 show that type hints are optional. You can write `lambda x: int, y: int : x * y` without specifying the return type. Jac will infer the return type from the expression.

**Lambda with Only Return Type**

Lines 17-18 demonstrate specifying just the return type without parameters: `lambda -> int : 100`. This is useful when you want to document what the lambda returns even though it takes no inputs.

**Default Parameter Values**

Lines 21-24 show how lambdas can have default parameter values, just like regular functions:

| Call | Values Used | Result |
|------|-------------|--------|
| `power()` (line 22) | x=2, y=3 (defaults) | 8 |
| `power(5)` (line 23) | x=5, y=3 (y default) | 125 |
| `power(5, 2)` (line 24) | x=5, y=2 | 25 |

**Lambdas as Function Arguments**

One of the most common uses for lambdas is passing them as arguments to higher-order functions.

Lines 27-29 demonstrate using a lambda with the `map` function to square each number in a list. The lambda `lambda x: int : x ** 2` is applied to each element.

Lines 32-33 show using a lambda with `filter` to select only even numbers. The lambda `lambda x: int : x % 2 == 0` returns true for even numbers.

**Lambdas with Conditional Expressions**

Lines 36-38 demonstrate that the expression body of a lambda can be a conditional (ternary) expression. The lambda `lambda a: int, b: int : a if a > b else b` returns the maximum of two values.

**Lambda Returning Lambda**

Lines 41-43 show a more advanced pattern: a lambda that returns another lambda. This creates closures where the inner lambda captures variables from the outer lambda. Line 41 creates a function that returns an "adder" function, and line 42 creates a specific adder that adds 5 to its input.

```mermaid
graph LR
    A[make_adder(5)] --> B[Returns: lambda y: 5 + y]
    B --> C[add_five(10)]
    C --> D[Returns: 15]
```

**Lambda as Sort Key**

Lines 46-48 demonstrate using a lambda as a key function for sorting. The `sorted` function uses the lambda `lambda s: str : len(s)` to determine the sort order, sorting strings by their length rather than alphabetically.

**Lambda Limitations**

Important things to know about lambdas in Jac:

| Feature | Supported in Lambda? |
|---------|---------------------|
| Single expression | Yes |
| Multiple statements | No |
| Assignments | No (except walrus `:=`) |
| Type annotations | Yes |
| Default parameters | Yes |
| Variadic arguments (`*args`, `**kwargs`) | No |
| Control flow statements (if/for/while as statements) | No |
| Conditional expressions (ternary) | Yes |

For complex logic requiring multiple statements or control flow, use regular `def` functions instead.

**When to Use Lambdas**

Use lambdas when you need:
- Simple, one-line operations
- Inline function definitions for `map`, `filter`, `sorted`, etc.
- Callback functions that are used only once
- Closures with simple logic

Use regular functions when you need:
- Multiple statements or complex logic
- Better documentation with docstrings
- Reusable code that appears in multiple places
- Variadic arguments or complex parameter handling
