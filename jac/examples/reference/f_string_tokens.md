F-string tokens in Jac provide formatted string literals with embedded expressions, enabling dynamic string construction with type-safe expression evaluation. F-strings offer a readable and efficient way to create formatted text.

#### Basic F-String Syntax

```jac
name = "Alice";
age = 30;
message = f"Hello, {name}! You are {age} years old.";
```

#### Expression Embedding

F-strings can embed any valid Jac expression:

```jac
# Variables and arithmetic
width = 10;
height = 5;
area_text = f"Area: {width * height} square units";

# Function calls
import math;
radius = 7.5;
circle_info = f"Circle area: {math.pi * radius ** 2:.2f}";

# Method calls
text = "hello world";
formatted = f"Uppercase: {text.upper()}, Length: {len(text)}";
```

#### Format Specifications

```jac
value = 3.14159;
formatted = f"Pi: {value:.2f}";        # 2 decimal places
scientific = f"Value: {value:.2e}";    # Scientific notation

number = 255;
binary = f"Binary: {number:b}";        # Binary representation
hex_val = f"Hex: {number:x}";          # Hexadecimal
```

#### Object-Spatial Integration

```jac
walker ReportGenerator {
    can generate_report with entry {
        node_info = f"Node {here.id}: value={here.value}, neighbors={len([-->])}";
        print(node_info);
        
        visit [-->];
    }
}
```

#### Multi-Line F-Strings

```jac
user = {"name": "Alice", "email": "alice@example.com"};
report = f"""
User Report:
Name: {user['name']}
Email: {user['email']}
Status: {'Active' if user.get('active', True) else 'Inactive'}
""";
```

#### Complex Expressions

```jac
# Conditional expressions
score = 85;
grade = f"Grade: {('A' if score >= 90 else 'B' if score >= 80 else 'C')}";

# Safe null handling
safe = f"Name: {user.name if user else 'Unknown'}";
```

#### Performance Considerations

- Compile-time expression parsing
- Efficient concatenation without multiple string operations
- Type-aware formatting optimization

#### Best Practices

1. Keep expressions simple within f-strings
2. Use format specifications for consistent output
3. Handle None values with conditional expressions
4. Break complex f-strings into multiple lines when needed

F-strings provide a powerful and efficient mechanism for string formatting in Jac, supporting both simple variable interpolation and complex expression evaluation while maintaining type safety.
