# Basic f-string examples
name = "John"
print(f"Hello {name}")
print(f"Hello {name}")
print(f"{{It is myname}}, name is: {name}")

# Numeric operations and formatting
x = 10
y = 20
z = 65
pi = 3.14159

print(f"Sum of {x} and {y} is {x + y}")
print(f"Hex: {y:x}")
print(f"Binary: {x:b}")
print(f"Value: {z:.2f}")
print(f"Hex: {z:10}")
print(f"Pi: {pi:.2f}")

# String formatting and conversions
b = "b"
name = "José"
value = "Hello\nWorld"

print(f"Debug: {b!a}")
print(f"Default: {name}")
print(f"ASCII: {name!a}")
print(f"repr: {value!r}")
print(f"str: {value!s}")
print(f"ascii: {value!a}")

# Nested f-strings
name = "John"
print(f"name is {name} {f'inner: {name}'}")

# Multiline f-strings with triple quotes
multiline_msg = f"""Hello {name},
    This is a multiline f-string.
    Your value is: {value}
    Sum of {x} + {y} = {x + y}"""
print(multiline_msg)

another_multiline = f"""Welcome {name}!
    Here's your data:
    - X: {x}
    - Y: {y}
    - Z: {z}
    Binary of {x}: {x:b}"""
print(another_multiline)

# Nested triple quote f-strings
nested_triple = f"""Outer: {name} {f'''Inner triple: {value}'''}"""
print(nested_triple)

# Complex JSON-like formatting
complex_format = f"""
    Debug Report for {name}:
    {{
        "x": {x},
        "y": {y},
        "hex_y": "{y:x}",
        "repr_value": {value!r}
    }}
"""
print(complex_format)

# Raw f-strings for paths and patterns
path = "home"
file = "test.txt"

# Basic raw f-strings
raw_path = rf"C:\Users\{name}\{path}\{file}"
raw_path2 = rf"D:\Projects\{name}\{file}"
print(raw_path)
print(raw_path2)

# Multiline raw f-strings
raw_multiline = rf"""Path: C:\Users\{name}\Documents\
    File: {file}
    Full: C:\Users\{name}\Documents\{file}"""
print(raw_multiline)

raw_multiline2 = rf"""Regex pattern: \d+\.\d+
    Name: {name}
    Pattern for {name}: \b{name}\b"""
print(raw_multiline2)

# Raw f-strings with special patterns
regex_pattern = rf"\b{name}\w*\b"
raw_with_newline = rf"Line 1\nLine 2 with {name}\tTabbed"
windows_path = rf"\\server\share\{name}\documents\{file}"

print(regex_pattern)
print(raw_with_newline)
print(windows_path)
