Jac provides a rich set of built-in data types that cover the fundamental data structures needed for most programming tasks. These types are similar to Python's built-in types but are integrated into Jac's type system and syntax.

**Primitive Types**

- **`int`**: Integer numbers (e.g., `42`, `-17`, `0`)
- **`float`**: Floating-point numbers (e.g., `3.14`, `-2.5`, `1e-10`)
- **`str`**: String literals (e.g., `"hello"`, `'world'`)
- **`bool`**: Boolean values (`True` or `False`)
- **`bytes`**: Byte sequences for binary data

**Collection Types**

- **`list`**: Ordered, mutable sequences (e.g., `[1, 2, 3]`, `['a', 'b', 'c']`)
- **`tuple`**: Ordered, immutable sequences (e.g., `(1, 2, 3)`, `('a', 'b')`)
- **`dict`**: Key-value mappings (e.g., `{'name': 'john', 'age': 28}`)
- **`set`**: Unordered collections of unique elements (e.g., `{1, 2, 3}`, `{'unique', 'values'}`)

**Meta Types**

- **`type`**: Represents the type of a type (metaclass)
- **`any`**: Represents any type (used for type annotations when type is unknown or flexible)

#### Implicit Typing Library

Jac exposes common generics from Python's `typing` module without requiring
explicit imports.  Standard type names such as `List`, `Dict`, and `Optional`
can be referenced directly by prefixing them with a backtick:

```jac
let names: `List[str]` = [];
let cache: `Dict[str, int]` = {};
```

These identifiers are recognized by the compiler automatically, simplifying type
annotations and eliminating repetitive import statements. All available types from
python `typing` library is availabe through this idiom. 

**Type Usage**

Built-in types can be used in several contexts:

1. **Variable declarations**: `glob name: str = "Jaseci";`
2. **Function parameters**: `def process(data: list) -> dict { ... }`
3. **Type checking**: `type(variable)` returns the type of a variable
4. **Type annotations**: Providing explicit type information for better code clarity

**Type Inference**

Jac can automatically infer types from literal values:
- `9.2` → `float`
- `44` → `int`  
- `[2, 4, 6, 10]` → `list`
- `{'name':'john', 'age':28}` → `dict`
- `("jaseci", 5, 4, 14)` → `tuple`
- `True` → `bool`
- `"Jaseci"` → `str`
- `{5, 8, 12, "unique"}` → `set`

The provided code example demonstrates the declaration of global variables using different built-in types and shows how the `type()` function can be used to inspect the runtime type of variables. This type introspection capability is useful for debugging and dynamic programming scenarios.
