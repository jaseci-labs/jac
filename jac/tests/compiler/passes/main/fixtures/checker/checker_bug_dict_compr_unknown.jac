"""Bug #25: Dict comprehensions return UnknownType.

_get_type_of_expression_core has no case for DictCompr, so dict
comprehensions fall through to UnknownType.

Expected: `{k: v for k, v in items}` should infer as dict.
"""

with entry {
    items = [("a", 1), ("b", 2)];
    d = {k: v for (k, v) in items};

    # Should infer as dict, so assigning to str should error
    bad: str = d;  # <-- Should be Error (dict not assignable to str)
}
