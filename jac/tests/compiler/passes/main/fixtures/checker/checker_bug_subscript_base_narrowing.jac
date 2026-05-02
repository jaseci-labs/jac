"""Bug: isinstance narrowing not applied when the narrowed expression is a subscript target.

Root cause: In the case uni.AtomTrailer() handler in _get_type_of_expression_core,
the narrowed type was only applied when expr.target was a simple Name node.
For subscript targets like path[0] (another AtomTrailer with IndexSlice), the
narrowing from isinstance(path[0], StringVal) was computed but then discarded -
base_type stayed as the full union type.

Fix: Added an elif branch in the AtomTrailer handler that calls
get_narrowed_type_for_expr for non-Name targets and uses the returned narrowed type.
This also requires PR2's subscript key support so that create_key_for_reference
can build a key for path[0].

All functions below should produce 0 errors after the fix.
"""

obj StringVal {
    has lit_value: str = "";
}

obj TokenVal {
    has name: str = "";
}

obj NumberVal {
    has num: int = 0;
}

# Core case: isinstance on path[0] (subscript) narrows it to StringVal,
# allowing .lit_value access. Without the fix, base_type for .lit_value
# remains StringVal|TokenVal and .lit_value is rejected.
def get_lit(path: list[StringVal | TokenVal]) -> str {
    if len(path) == 1 and isinstance(path[0], StringVal) {
        return path[0].lit_value;  # path[0]: StringVal
    }
    return "";
}

# elif variant: each branch narrows to the checked type.
def describe_first(items: list[StringVal | TokenVal | NumberVal]) -> str {
    if isinstance(items[0], StringVal) {
        return items[0].lit_value;   # items[0]: StringVal
    } elif isinstance(items[0], NumberVal) {
        return str(items[0].num);    # items[0]: NumberVal
    }
    return items[0].name;            # items[0]: TokenVal
}
