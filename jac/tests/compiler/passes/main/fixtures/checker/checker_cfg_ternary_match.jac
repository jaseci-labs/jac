"""Test CFG-based narrowing for ternary expressions and match cases.

Phase 2: These tests verify that ternary (IfElseExpr) and match case
narrowing work through the CFG rather than the scope stack.
"""

obj Dog {
    has name: str,
        bark_count: int = 0;
}

obj Cat {
    has name: str,
        purr_count: int = 0;
}

def use_dog(d: Dog) -> int {
    return d.bark_count;
}

# --- Ternary: basic narrowing ---
def ternary_is_not_none(x: Dog | None) -> Dog {
    return x if x is not None else Dog(name="default");
}

def ternary_is_none(x: Dog | None) -> Dog {
    return Dog(name="default") if x is None else x;
}

def ternary_isinstance(animal: Dog | Cat) -> int {
    return animal.bark_count if isinstance(animal, Dog) else animal.purr_count;
}

def ternary_truthiness(x: Dog | None) -> Dog {
    return x or Dog(name="default");
}

# --- Ternary: narrowing in function arguments ---
def ternary_fn_arg_isinstance(val: Dog | None) -> int {
    return use_dog(val) if isinstance(val, Dog) else 0;
}

def ternary_fn_arg_is_not_none(val: Dog | None) -> int {
    return use_dog(val) if val is not None else 0;
}

def ternary_fn_arg_truthiness(val: Dog | None) -> int {
    return use_dog(val) if val else 0;
}

# --- Ternary: narrowing in attribute access ---
def ternary_attr_truthiness(val: Dog | None) -> int {
    return val.bark_count if val else 0;
}

def ternary_attr_isinstance(val: Dog | Cat) -> int {
    return val.bark_count if isinstance(val, Dog) else 0;
}

# --- Match: basic narrowing (already works via scope) ---
def match_class_pattern(animal: Dog | Cat) -> str {
    match animal {
        case Dog():
            return animal.name;

        case Cat():
            return animal.name;

    }
    return "";
}

def match_attr_access(animal: Dog | Cat) -> int {
    match animal {
        case Dog():
            return animal.bark_count;

        case Cat():
            return animal.purr_count;

    }
    return 0;
}
