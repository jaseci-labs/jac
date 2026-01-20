"""Test fixture for hasattr to null-safe (obj?.attr) conversion.

This file tests the auto-lint rule that converts:
- hasattr(obj, "attr") -> obj?.attr
- obj.attr if hasattr(obj, "attr") else default -> obj?.attr if obj?.attr else default
"""

obj SomeClass {
    has value: int = 0;
    has name: str = "";
}

glob instance = SomeClass();

# Basic hasattr in if-else expression
glob result1 = instance.value if hasattr(instance, "value") else 0;

# hasattr with different attribute
glob result2 = instance.name if hasattr(instance, "name") else "default";

# hasattr with None as else value
glob result3 = instance.name if hasattr(instance, "name") else None;

# hasattr in binary expression (and)
glob result4 = hasattr(instance, "value") and instance.value > 0;

# hasattr in binary expression (or)
glob result5 = hasattr(instance, "name") or False;

# hasattr with single quotes
glob result6 = instance.value if hasattr(instance, 'value') else -1;

# Nested hasattr - should only convert the hasattr calls
glob result7 = instance.value if hasattr(instance, "value") else (instance.name if hasattr(instance, "name") else "none");

# hasattr that should NOT be converted (variable attribute name)
glob attr_name = "value";
glob result8 = instance.value if hasattr(instance, attr_name) else 0;

# hasattr that should NOT be converted (more than 2 args - invalid anyway)
# This would be a syntax error in real code, but the auto-lint should not touch it

# Regular function call that looks like hasattr but isn't
def hasattr_lookalike(obj: object, attr: str) -> bool {
    return True;
}
glob result9 = hasattr_lookalike(instance, "value");
