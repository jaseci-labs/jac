"""Test fixture for comprehension → JavaScript transpilation.

Covers list, set, dict, and generator comprehensions,
including filters, nested loops, and expression variants.
"""

# --- List Comprehensions ---

def list_compr_map(items: list) -> list {
    return [x * 2 for x in items];
}

def list_compr_filter(items: list) -> list {
    return [x for x in items if x > 0];
}

def list_compr_map_filter(items: list) -> list {
    return [x * 2 for x in items if x > 0];
}

def list_compr_multi_filter(items: list) -> list {
    return [x for x in items if x > 0 if x < 100];
}

def list_compr_method(items: list) -> list {
    return [x.strip() for x in items];
}

def list_compr_ternary(items: list) -> list {
    return [x if x > 0 else 0 for x in items];
}

# --- Set Comprehensions ---

def set_compr_basic(items: list) -> set {
    return {x * 2 for x in items};
}

def set_compr_filter(items: list) -> set {
    return {x for x in items if x > 0};
}

# --- Dict Comprehensions ---

def dict_compr_basic(pairs: list) -> dict {
    return {k: v for (k, v) in pairs};
}

def dict_compr_filter(pairs: list) -> dict {
    return {k: v for (k, v) in pairs if v > 0};
}

def dict_compr_transform(pairs: list) -> dict {
    return {k: v * 2 for (k, v) in pairs};
}

# --- Generator Expressions ---

def gen_compr_basic(items: list) -> list {
    return list((x * 2 for x in items));
}

def gen_compr_filter(items: list) -> list {
    return list((x for x in items if x > 0));
}

# --- Nested Loops ---

def nested_compr_basic(a: list, b: list) -> list {
    return [x + y for x in a for y in b];
}

def nested_compr_filter(a: list, b: list) -> list {
    return [x + y for x in a for y in b if x != y];
}
