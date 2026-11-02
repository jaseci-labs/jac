"""A slice of a fixed tuple builds the sliced tuple, or is refused.

The subscript lowering used to fall through to the index path, where a
range's start stood in for an index: `t[1:3]` read element 1 instead of
building `(6, 7)`.
"""
def tail_of_three -> int {
    t = (5, 6, 7);
    s = t[1:3];
    return len(s) * 100 + s[0] * 10 + s[1];
}
