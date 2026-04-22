"""Test fixture for getattr(obj, "attr", None) to null-safe (obj?.attr) conversion.

This file tests the auto-lint rule W3039 that converts:
- getattr(obj, "attr", None) -> obj?.attr
"""

obj SomeClass {
    has value: int = 0;
    has name: str = "";
}

glob instance = SomeClass();

# Basic assignment context
glob basic = getattr(instance, "value", None);

# Single-quoted attribute
glob basic_sq = getattr(instance, 'name', None);

# Inside a comparison
glob is_missing = getattr(instance, "value", None) is None;

# Inside a boolean expression
glob guarded = getattr(instance, "value", None) and True;

# Inside a ternary
glob ternary = getattr(instance, "value", None) if True else 0;

# As an argument to another function call
def echo(x: object) -> object { return x; }
glob echoed = echo(getattr(instance, "name", None));

# As return value
def fetch_name(o: SomeClass) -> (str | None) {
    return getattr(o, "name", None);
}

# As a standalone expression statement
with entry {
    getattr(instance, "value", None);
}

# Inside an if-statement condition
with entry {
    if getattr(instance, "value", None) {
        print("has value");
    }
}

# Should NOT be converted: non-None default
glob not_none_default = getattr(instance, "value", 0);

# Should NOT be converted: 2-arg form (raises AttributeError on miss)
glob two_arg = getattr(instance, "value");

# Should NOT be converted: non-string attribute name
glob attr_name = "value";
glob dynamic = getattr(instance, attr_name, None);

# Should NOT be converted: attribute name is not a valid identifier
glob invalid_id = getattr(instance, "not-an-ident", None);

# Should NOT be converted: attribute name is a Python keyword
glob keyword_attr = getattr(instance, "class", None);

# Should NOT be converted: lookalike function with same-shaped call
def getattr_lookalike(target: object, name_: str, fallback: object) -> object {
    return fallback;
}
glob lookalike = getattr_lookalike(instance, "value", None);
