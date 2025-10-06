Pipe back expressions use the `<|` operator to pass values into functions from right to left, providing an alternative to traditional function call syntax that emphasizes the function being applied.

**What is the Pipe Back Operator?**

The pipe back operator `<|` takes a value on its right and passes it to a function on its left. Think of it as reversing the typical function call syntax:

- Traditional: `double(5)` - function first, then argument
- Pipe back: `double <| 5` - function first, operator, then argument

The key difference is readability and style - the operator makes the data flow explicit.

**Basic Pipe Back Syntax**

Lines 9-10 demonstrate the basic form:

| Traditional Call | Pipe Back | Result | Line |
|------------------|-----------|--------|------|
| `double(5)` | `double <| 5` | 10 | 9 |
| `add_five(10)` | `add_five <| 10` | 15 | 10 |

Line 9 shows `result1 = double <| 5`:
- `5` is the value on the right
- `<|` is the pipe back operator
- `double` is the function on the left
- Result: `5 * 2 = 10`

This is exactly equivalent to `result1 = double(5)`, but reads as "double, applied to 5" rather than "double of 5".

**Function Definitions**

Lines 3-5 define simple transformation functions:

| Function | Operation | Example | Line |
|----------|-----------|---------|------|
| `double(x)` | Multiply by 2 | `double(5) = 10` | 3 |
| `triple(x)` | Multiply by 3 | `triple(5) = 15` | 4 |
| `add_five(x)` | Add 5 | `add_five(10) = 15` | 5 |

These demonstrate how pipe back works with different functions.

**Pipe Back with Lambda Expressions**

Line 13 demonstrates using pipe back with inline lambda functions. This breaks down as:
- `(lambda n: int : n * 3)` creates an inline function that multiplies by 3
- `<|` applies the lambda to the value
- `10` is the input value
- Result: `10 * 3 = 30`

The lambda must be wrapped in parentheses when used with pipe back. This pattern is useful for one-off transformations without defining a separate function.

**Pipe Back with Built-in Functions**

Line 16 shows using pipe back with built-in functions. This applies the built-in `sum` function to the list, producing 15. The pipe back operator works with any callable:
- User-defined functions (lines 3-5)
- Lambda expressions (line 13)
- Built-in functions (line 16)
- Methods and other callables

**Multiple Operations**

Lines 19-20 show sequential pipe back operations. While you can't chain pipe back operators in a single expression (unlike forward pipe), you can sequence them across statements. This applies transformations step by step.

**Pipe Back vs Forward Pipe**

Understanding the relationship between the two pipe operators:

| Operator | Direction | Syntax | Reading Style | Example Line |
|----------|-----------|--------|---------------|--------------|
| `\|>` (forward) | Left to right | `value \|> function` | Data-first | - |
| `<\|` (backward) | Right to left | `function <\| value` | Function-first | 9, 10 |

**Forward pipe** (covered in pipe_expressions.md):

**Pipe back**:

Both produce the same result, but emphasize different aspects:
- Forward pipe emphasizes the data being transformed
- Pipe back emphasizes the transformation being applied

**When to Use Pipe Back**

Pipe back is particularly useful when:

1. **Function is more important than data**:

2. **Familiar with functional languages**:
Pipe back is common in languages like Haskell (`$`), F# (`<|`), and Elm (`<|`).

3. **Function has descriptive name**:

**Comparison with Traditional Syntax**

All three forms are equivalent:

| Style | Syntax | Readability Focus |
|-------|--------|-------------------|
| Traditional | `double(5)` | Familiar, concise |
| Pipe back | `double <| 5` | Function emphasis |
| Forward pipe | `5 \|> double` | Data flow emphasis |

Choose based on what you want to emphasize:
- Traditional: General-purpose, widely understood
- Pipe back: Emphasize the operation being performed
- Forward pipe: Emphasize the data being transformed

**Practical Examples**

**Example 1: Validation pipeline**
Emphasizes that validation is being performed.

**Example 2: Processing with built-ins**
Makes the operation clear before showing the data.

**Example 3: Lambda transformations**
Inline transformation with pipe back style.

**Key Differences from Forward Pipe**

Forward pipe (`|>`) supports chaining:

Pipe back (`<|`) doesn't chain in the same way:

For chaining multiple operations, forward pipe is typically more natural.

**Output Demonstration**

Line 22 prints all results:
- `result1 = 10` (double of 5)
- `result2 = 15` (add_five of 10)
- `result3 = 30` (lambda triple of 10)
- `total = 15` (sum of list)
- `result4 = 12` (triple of temp, which is double of 2)

**Key Takeaways**

- `<|` passes values from right to left into functions
- Syntax: `function <| value`
- Equivalent to traditional function calls but with different emphasis
- Works with user functions, lambdas, and built-ins
- Emphasizes the function/operation over the data
- Complements forward pipe (`|>`) which emphasizes data flow
- Choose based on what you want to emphasize in your code
- From functional programming languages like Haskell and F#

The pipe back operator is a stylistic choice that can make code more readable when you want to emphasize the operation being performed rather than the data being transformed.
