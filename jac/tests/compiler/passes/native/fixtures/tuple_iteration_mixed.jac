"""Fixture: a tuple whose elements do not share one storage width.

`tuple_iteration.jac` covers the tuples that iterate. This one must NOT: the
loop variable is a single slot, and the checker types it from the tuple's
first element (`int` here), not from the union of all three. Materializing the
elements into tagged `jacval` slots would therefore compile and run, and the
`isinstance` in the body would test the loop variable's declared type rather
than the member actually stored -- a wrong answer with nothing on stderr.

So the mixed tuple is refused with E5092 and the module demotes to the server
codespace, where Python semantics answer it correctly. The list twin below is
the same three values in the spelling that does lower: a list literal's
element type widens to `int | str`, so the body's `isinstance` reads the tag
the element was boxed with.
"""

"""A tuple of an int, a str and an int: three elements, two storage widths."""
def mixed_tuple(seed: int) -> int {
    acc = seed;
    for v in (1, 'ab', 3) {
        acc = acc * 5;
        if isinstance(v, str) {
            acc = acc + len(v);
        } elif isinstance(v, int) {
            acc = acc + v;
        }
    }
    return acc;
}


"""The same three values as a list, which lowers."""
def mixed_list(seed: int) -> int {
    acc = seed;
    for v in [1, 'ab', 3] {
        acc = acc * 5;
        if isinstance(v, str) {
            acc = acc + len(v);
        } elif isinstance(v, int) {
            acc = acc + v;
        }
    }
    return acc;
}


with entry {
    print(mixed_tuple(0));
    print(mixed_list(0));
}
