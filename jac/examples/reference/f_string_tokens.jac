"""F-string tokens: Formatted string literals with interpolation."""

with entry {
    x = "World";
    y = 42;

    # Double-quoted f-strings
    print(f"Hello {x}! Number: {y}");

    # Single-quoted f-strings
    print(f'Value: {y}');

    # Triple-quoted f-strings
    msg = f"""
    Multi-line
    Value: {y}
    """;
    print(msg);

    # Escaped braces {{ }}
    print(f"Escaped: {{braces}} and value {y}");

    # Expressions in f-strings
    print(f"Math: {5 + 3}, {10 * 2}");

    # Method calls
    text = "hello";
    print(f"Upper: {text.upper()}");

    # Dictionary access
    d = {"name": "Alice", "age": 30};
    print(f"Name: {d['name']}, Age: {d['age']}");

    # Conditionals
    age = 20;
    print(f"Status: {('Adult' if age >= 18 else 'Minor')}");

    # Nested f-strings
    val = 100;
    print(f"Nested: {f'{val}'}");

    print("Complete");
}
