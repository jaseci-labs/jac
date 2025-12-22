
# Basic f-string examples
glob name = "John";

with entry {
    print(f"Hello {name}");
    print(F'Hello {name}');
    print(f"{{It is myname}}, name is: {name}");
}

# Numeric operations and formatting
glob x = 10,
     y = 20,
     z = 65,
     pi = 3.14159;

with entry {
    print(f"Sum of {x} and {y} is {x + y}");
    print(f"Hex: {y:x}");
    print(f"Binary: {x:b}");
    print(f"Value: {z:.2f}");
    print(f"Hex: {z:10}");
    print(f"Pi: {pi:.2f}");
}

# String formatting and conversions
glob b = "b",
     name = "José",
     value = "Hello\nWorld";

with entry {
    print(f"Debug: {b!a}");
    print(f"Default: {name}");
    print(f"ASCII: {name!a}");
    print(f"repr: {value!r}");
    print(f"str: {value!s}");
    print(f"ascii: {value!a}");
}

# Nested f-strings
glob name = "John";

with entry {
    print(f"name is {name} {f'inner: {name}'}");
}

# Multiline f-strings with triple quotes
glob multiline_msg = f"""Hello {name},
    This is a multiline f-string.
    Your value is: {value}
    Sum of {x} + {y} = {x + y}""";

with entry {
    print(multiline_msg);
}

glob another_multiline = f'''Welcome {name}!
    Here's your data:
    - X: {x}
    - Y: {y}
    - Z: {z}
    Binary of {x}: {x:b}''';

with entry {
    print(another_multiline);
}

# Nested triple quote f-strings
glob nested_triple = f"""Outer: {name} {f'''Inner triple: {value}'''}""";

with entry {
    print(nested_triple);
}

# Complex JSON-like formatting
glob complex_format = f"""
    Debug Report for {name}:
    {{
        "x": {x},
        "y": {y},
        "hex_y": "{y:x}",
        "repr_value": {value!r}
    }}
    """;

with entry {
    print(complex_format);
}

# Raw f-strings for paths and patterns
glob path = "home",
     file = "test.txt",
     raw_path = rf"C:\Users\{name}\{path}\{file}",
     raw_path2 = fr'D:\Projects\{name}\{file}';

with entry {
    print(raw_path);
    print(raw_path2);
}

# Multiline raw f-strings
glob raw_multiline = rf"""Path: C:\Users\{name}\Documents\
    File: {file}
    Full: C:\Users\{name}\Documents\{file}""";

with entry {
    print(raw_multiline);
}

glob raw_multiline2 = fr'''Regex pattern: \d+\.\d+
    Name: {name}
    Pattern for {name}: \b{name}\b''';

with entry {
    print(raw_multiline2);
}

# Raw f-strings with special patterns
glob regex_pattern = rf"\b{name}\w*\b",
     raw_with_newline = rf"Line 1\nLine 2 with {name}\tTabbed",
     windows_path = rf"\\server\share\{name}\documents\{file}";

with entry {
    print(regex_pattern);
    print(raw_with_newline);
    print(windows_path);
}
# Basic raw f-strings
