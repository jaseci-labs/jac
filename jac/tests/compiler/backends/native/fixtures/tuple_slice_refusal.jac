"""A slice of a fixed tuple has no native lowering.

The subscript lowering used to fall through to the index path, where a
range's start stood in for an index: `t[1:3]` read element 1 instead of
building `(6, 7)`.
"""
def tail_of_three -> int {
    t = (5, 6, 7);
    s = t[1:3];
    print(s);
    return 0;
}
