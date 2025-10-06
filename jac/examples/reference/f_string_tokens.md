**F-String Tokens in Jac**

F-strings (formatted string literals) provide powerful string interpolation, allowing you to embed expressions and values directly within string literals using the `f` prefix.

**Basic F-String Syntax (Lines 7-11)**

Lines 4-5 define variables for interpolation:

**Double-quoted f-strings (Line 8)**:
- `f` prefix marks the string as formatted
- `{x}` evaluates variable x and inserts "World"
- `{y}` evaluates variable y and inserts 42
- Output: "Hello World! Number: 42"

**Single-quoted f-strings (Line 11)**:
- Works with single quotes too
- Same interpolation behavior
- Output: "Value: 42"

**F-String Components**

| Component | Syntax | Purpose | Example |
|-----------|--------|---------|---------|
| Prefix | `f` or `F` | Marks string as formatted | `f"text"` |
| Braces | `{expression}` | Interpolation placeholder | `{x}`, `{x + 1}` |
| Escaped braces | `{{` or `}}` | Literal braces | `{{not interpolated}}` |

**Triple-Quoted F-Strings (Lines 13-18)**

Lines 14-17:
- Triple quotes allow multi-line strings
- Preserves line breaks and formatting
- Interpolation works across lines
- Useful for templates and formatted output

**Escaped Braces (Line 21)**

Line 21: `print(f"Escaped: {{braces}} and value {y}");`
- `{{` produces literal `{`
- `}}` produces literal `}`
- `{y}` still interpolates normally
- Output: "Escaped: {braces} and value 42"

**Escape Sequence Table**

| Syntax | Output | Use Case |
|--------|--------|----------|
| `{x}` | Value of x | Interpolation |
| `{{` | `{` | Literal left brace |
| `}}` | `}` | Literal right brace |
| `{{{{` | `{{` | Escaped pair |

**Expressions in F-Strings (Line 24)**

Line 24: `print(f"Math: {5 + 3}, {10 * 2}");`
- Any expression can be inside braces
- `{5 + 3}` evaluates to 8
- `{10 * 2}` evaluates to 20
- Output: "Math: 8, 20"
- Each expression evaluated independently

**Expression Evaluation Flow**

```mermaid
graph TD
    A["f-string with expression"] --> B[Parse string]
    B --> C[Find expressions in braces]
    C --> D[Evaluate each expression]
    D --> E[Convert result to string]
    E --> F[Insert into final string]
    F --> G[Return complete string]

    style D fill:#2e7d32,stroke:#fff,color:#fff
    style E fill:#e65100,stroke:#fff,color:#fff
```

**Method Calls (Lines 26-28)**

Lines 27-28:
- `{text.upper()}` calls method on object
- Method executes and returns "HELLO"
- Result interpolated into string
- Output: "Upper: HELLO"

**Dictionary Access (Lines 30-32)**

Lines 31-32:
- `{d['name']}` accesses dictionary key
- Uses quotes inside f-string (different quote types)
- `{d['age']}` gets age value
- Output: "Name: Alice, Age: 30"

**Conditionals in F-Strings (Lines 34-36)**

Lines 35-36:
- Ternary expression inside braces
- Parentheses for clarity
- Evaluates to "Adult" (age >= 18)
- Output: "Status: Adult"

**F-String Expression Types**

| Expression Type | Example | Result |
|----------------|---------|--------|
| Variable | `{x}` | Value of x |
| Arithmetic | `{5 + 3}` | 8 |
| Method call | `{text.upper()}` | Uppercase text |
| Dictionary | `{d['key']}` | Value at key |
| Conditional | `{a if cond else b}` | a or b based on cond |
| Function call | `{len(items)}` | Length of items |

**Nested F-Strings (Lines 38-40)**

Lines 39-40:
- F-string inside f-string interpolation
- Inner f-string evaluated first
- Result inserted into outer f-string
- Output: "Nested: 100"
- Generally avoid - reduces readability

**Quote Handling in F-Strings**

Different quote combinations work:

**Complex Expression Examples**

Chained method calls:

List comprehension:

Multiple operations:

Function with arguments:

**Best Practices**

1. **Keep expressions simple**: Complex logic belongs in variables
2. **Use meaningful variable names**: Makes f-strings readable
3. **Match quote types**: Use different quotes for outer string and dict keys
4. **Avoid side effects**: F-string expressions shouldn't modify state
5. **Consider alternatives**: Very complex formatting might need `.format()` or templates

**F-String Advantages**

| Advantage | Description | Example |
|-----------|-------------|---------|
| Readability | Clear, inline interpolation | `f"Hello {name}"` |
| Conciseness | Less verbose than concatenation | vs `"Hello " + name` |
| Performance | Faster than % formatting | Optimized at compile time |
| Flexibility | Any expression allowed | `{func(x, y)}` |
| Type conversion | Automatic str() conversion | Works with any type |

**Common Patterns**

Debug printing:

Formatted output:

Building messages:

Template strings:

**Performance Notes**

F-strings are:
- Evaluated at runtime (not compile time for expressions)
- Faster than `"".format()` and `%` formatting
- Similar speed to manual concatenation
- Optimized by Python interpreter
- No function call overhead

**Comparison with Other Methods**

| Method | Syntax | Readability | Performance |
|--------|--------|-------------|-------------|
| F-string | `f"{x} {y}"` | Excellent | Fast |
| .format() | `"{} {}".format(x, y)` | Good | Slower |
| % formatting | `"%s %s" % (x, y)` | Fair | Slower |
| Concatenation | `str(x) + " " + str(y)` | Poor | Fast |

**When to Use F-Strings**

Use f-strings when:
- Building strings with variable interpolation
- Creating debug or log messages
- Formatting output for users
- Constructing dynamic strings
- Need inline expression evaluation

Avoid when:
- String is a constant template used repeatedly (use .format() with template)
- Internationalization needed (f-strings can't be extracted for translation)
- Very complex formatting logic (use dedicated template engine)

**Error Handling**

F-string errors occur at different times:

**Syntax errors (parse time)**:

**Runtime errors (execution time)**:

**Type Conversion**

F-strings automatically convert to string:
- `{42}` → "42"
- `{[1,2,3]}` → "[1, 2, 3]"
- `{None}` → "None"
- Custom objects use `__str__()` or `__repr__()`

Objects without string representation may show:

**Advanced Usage**

While not shown in this basic example, f-strings support:
- Format specifiers: `{value:.2f}` for decimals
- Alignment: `{text:>10}` for right-align
- Sign control: `{num:+}` to always show sign
- Conversion flags: `{obj!r}` for repr(), `{obj!s}` for str()

These advanced features follow Python's format specification mini-language.
