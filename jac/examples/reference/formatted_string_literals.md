# Formatted String Literals (f-strings)

This document demonstrates the usage of formatted string literals (f-strings) in both Python and Jac languages. F-strings provide a concise and readable way to include expressions inside string literals.

## Basic F-string Syntax

F-strings are prefixed with `f` or `F` and use curly braces `{}` to embed expressions.

**Python:**
```python
name = "John"
print(f"Hello {name}")
print(F'Hello {name}')
```

**Jac:**
```jac
name = "John";
print(f"Hello {name}");
print(F'Hello {name}');
```

## Escaping Curly Braces

To include literal curly braces in f-strings, double them:

```python
print(f"{{It is myname}}, name is: {name}")
```

## Numeric Operations and Formatting

F-strings support expressions and format specifiers for numbers:

### Basic Operations
```python
x = 10
y = 20
print(f"Sum of {x} and {y} is {x + y}")
```

### Number Base Conversions
- **Hexadecimal:** `{value:x}` - converts to lowercase hex
- **Binary:** `{value:b}` - converts to binary
- **Decimal formatting:** `{value:.2f}` - formats to 2 decimal places

```python
y = 20
x = 10
z = 65
pi = 3.14159

print(f"Hex: {y:x}")        # Output: 14
print(f"Binary: {x:b}")     # Output: 1010
print(f"Value: {z:.2f}")    # Output: 65.00
print(f"Pi: {pi:.2f}")      # Output: 3.14
```

### Field Width
```python
print(f"Hex: {z:10}")       # Right-aligned in 10 character field
```

## String Formatting and Conversions

F-strings support conversion flags to change how values are represented:

- `!r` - calls `repr()` on the value
- `!s` - calls `str()` on the value
- `!a` - calls `ascii()` on the value

```python
b = "b"
name = "José"
value = "Hello\nWorld"

print(f"Debug: {b!a}")      # ASCII representation
print(f"Default: {name}")   # Default string representation
print(f"ASCII: {name!a}")   # ASCII-safe representation
print(f"repr: {value!r}")   # repr() representation with quotes
print(f"str: {value!s}")    # str() representation
print(f"ascii: {value!a}")  # ASCII representation with escapes
```

## Nested F-strings

F-strings can be nested inside other f-strings:

```python
name = "John"
print(f"name is {name} {f'inner: {name}'}")
```

## Multiline F-strings

F-strings work with triple quotes for multiline strings:

### Triple Double Quotes
```python
multiline_msg = f"""Hello {name},
This is a multiline f-string.
Your value is: {value}
Sum of {x} + {y} = {x + y}"""
```

### Triple Single Quotes
```python
another_multiline = f'''Welcome {name}!
Here's your data:
- X: {x}
- Y: {y}
- Z: {z}
Binary of {x}: {x:b}'''
```

### Nested Triple Quote F-strings
```python
nested_triple = f"""Outer: {name} {f'''Inner triple: {value}'''}"""
```

## Complex Formatting Examples

F-strings are useful for generating structured output like JSON:

```python
complex_format = f"""
Debug Report for {name}:
{{
    "x": {x},
    "y": {y},
    "hex_y": "{y:x}",
    "repr_value": {value!r}
}}
"""
```

## Raw F-strings

Raw f-strings combine the benefits of raw strings (no escape sequence processing) with f-string interpolation. They are prefixed with `rf` or `fr`.

### Basic Raw F-strings
```python
path = "home"
file = "test.txt"
name = "John"

raw_path = rf"C:\Users\{name}\{path}\{file}"
raw_path2 = fr'D:\Projects\{name}\{file}'
```

### Multiline Raw F-strings
```python
raw_multiline = rf"""Path: C:\Users\{name}\Documents\
File: {file}
Full: C:\Users\{name}\Documents\{file}"""

raw_multiline2 = fr'''Regex pattern: \d+\.\d+
Name: {name}
Pattern for {name}: \b{name}\b'''
```

### Common Use Cases for Raw F-strings

**File Paths (Windows):**
```python
windows_path = rf"\\server\share\{name}\documents\{file}"
```

**Regular Expressions:**
```python
regex_pattern = rf"\b{name}\w*\b"
```

**Literal Backslashes:**
```python
raw_with_newline = rf"Line 1\nLine 2 with {name}\tTabbed"
```

## Language Differences

Both Python and Jac support the same f-string syntax with minor differences:

| Feature | Python | Jac |
|---------|--------|-----|
| Statement termination | Optional | Required `;` |
| Syntax | `f"text {expr}"` | `f"text {expr}";` |
| All formatting features | ✅ | ✅ |
| Raw f-strings | ✅ | ✅ |
| Nested f-strings | ✅ | ✅ |

## Best Practices

1. **Use f-strings for readability** - They are more readable than `.format()` or `%` formatting
2. **Combine with format specifiers** - Use `:` notation for number formatting
3. **Use raw f-strings for paths** - Especially useful for Windows file paths and regex patterns
4. **Leverage conversion flags** - Use `!r`, `!s`, `!a` for debugging and special representations
5. **Escape braces when needed** - Double curly braces `{{` `}}` for literal braces

## Summary

F-strings provide a powerful and intuitive way to format strings in both Python and Jac. They support:
- Variable interpolation
- Expression evaluation
- Number formatting and base conversion
- String conversion flags
- Multiline strings
- Raw string processing
- Nested f-strings

This makes them the preferred choice for most string formatting tasks due to their readability and performance.