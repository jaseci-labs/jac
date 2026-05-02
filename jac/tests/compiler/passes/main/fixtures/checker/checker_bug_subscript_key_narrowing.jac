"""Bug: subscript expressions (e.g. items[0].field) not tracked as narrowing keys.

Root cause: create_key_for_reference (type_evaluator.impl.jac) and
get_expr_key (symbol_utils.jac) only built keys for dotted attribute chains
(e.g. "a.b.c"). They returned None for subscript expressions like items[0],
so `if items[0].start is not None` produced a None key and the narrowing
was silently dropped. The affected_symbols fast-path in the CFG walk also
missed subscript keys, breaking CFG propagation entirely for this pattern.

Fix: Extended both functions to handle constant integer subscripts,
producing keys like "items[0]" and "items[0].start".

All functions below should produce 0 errors after the fix.
"""

obj Segment {
    has start: int | None = None,
        end: int | None = None;
}

# Guard on subscript attribute: items[0].start is not None
# should narrow items[0].start from int | None to int.
def segment_length(items: list[Segment]) -> int {
    if items[0].start is not None and items[0].end is not None {
        return items[0].end - items[0].start;  # both narrowed to int
    }
    return 0;
}

# Chained: guard on [0].start, use [0].start inside if.
def first_start(items: list[Segment]) -> int {
    if items[0].start is not None {
        return items[0].start;  # narrowed to int
    }
    return -1;
}
