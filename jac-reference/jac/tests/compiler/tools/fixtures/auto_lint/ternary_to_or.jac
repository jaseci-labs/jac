"""Test fixture for ternary to or expression conversion.

This file tests the auto-lint rule that converts:
- x if x else default -> x or default
- x?.attr if x?.attr else default -> x?.attr or default
"""

obj SomeClass {
    has value: int = 0;
    has name: str = "";
}

glob instance = SomeClass();

# Basic ternary with identical value and condition (should be converted)
glob result1 = instance.value if instance.value else 0;

# Null-safe ternary with identical value and condition (should be converted)
glob result2 = instance?.name if instance?.name else "default";

# Different value and condition (should NOT be converted)
glob result3 = instance.value if instance.name else 0;

# Function call in ternary (should be converted if identical)
def get_value -> int {
    return 42;
}
glob result4 = get_value() if get_value() else -1;

# Complex expression (should be converted if identical)
glob result5 = (instance.value + 1) if (instance.value + 1) else 0;

# Nested null-safe access (should be converted)
glob result6 = instance?.value if instance?.value else -1;

# Different types of defaults
glob result7 = instance?.name if instance?.name else "";
glob result8 = instance?.value if instance?.value else None;
