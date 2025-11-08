Collection values in Jac provide rich data structures for organizing and manipulating groups of related data. Jac supports all major collection types found in modern programming languages, along with powerful comprehension syntax for creating collections programmatically.

**Basic Collection Types**

**Dictionary (`dict`)**
- Key-value mappings using curly braces: `{"a": "b", "c": "d"}`
- Keys and values can be of any type
- Mutable and ordered (insertion order preserved)

**Set (`set`)**  
- Unordered collections of unique elements: `{"a"}`
- Automatically eliminates duplicates
- Mutable and supports mathematical set operations

**Tuple (`tuple`)**
- Ordered, immutable sequences: `("a", )`
- Note the trailing comma for single-element tuples
- Useful for fixed-size data groupings

**List (`list`)**
- Ordered, mutable sequences: `['a']`
- Support indexing, slicing, and dynamic resizing
- Most versatile collection type for general use

**Collection Comprehensions**

Jac supports comprehensive syntax for creating collections using iterative expressions:

**Dictionary Comprehensions**
```jac
{key_expr: value_expr for item in iterable}
{num: num ** 2 for num in range(1, 6)}
```

**Set Comprehensions**
```jac
{expr for item in iterable if condition}
{num ** 2 for num in range(1, 11) if num % 2 == 0}
```

**List Comprehensions**
```jac
[expr for item in iterable if condition]
[num ** 2 for num in squares_generator if num != 9]
```

**Generator Expressions**
```jac
(expr for item in iterable)
(num ** 2 for num in range(1, 6))
```

**Comprehension Features**

- **Filtering**: Use `if` conditions to selectively include elements
- **Transformation**: Apply expressions to transform source data
- **Nested iteration**: Support for multiple `for` clauses
- **Conditional logic**: Complex filtering and transformation logic

The provided code example demonstrates practical usage of all collection types and comprehensions, showing how to create dictionaries with computed values, filter sets based on conditions, generate sequences efficiently, and work with basic collection literals.
