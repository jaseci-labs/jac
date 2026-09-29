"""Set displays and set constructors whose elements are tuples.

A tuple expression lowers to a by-value struct, but a native set stores a
tuple through a boxed pointer and hashes/compares the bytes behind it (the
`tupleN` flavour). `.add()` and set comprehensions boxed each element before
inserting it; the set display did not. It keyed the whole set by the first
element's *unboxed* struct type, which `_hash_key_spec` does not recognise,
so the set fell onto the scalar `i64` flavour and building the hash helpers
crashed native lowering ("Operands must be the same type, got ({i64, i64},
i64)"). `{(1, 2)}` was enough.

Every function folds its set back into one number carrying the length and
membership answers. Sets are never iterated in an order-sensitive way: the
native and bytecode tables need not agree on order. `n` is the only
parameter so both codespaces run through one `(int) -> int` signature.
"""

glob dropped = 0,
     PAIRS: set[tuple[int, int]] = {(1, 2), (3, 4), (1, 2)};


obj Node {
    has tag: int = 0;

    def drop {
        dropped += 1;
    }
}


"""The minimal shape: a two-member display of int pairs."""
def lit_pairs(n: int) -> int {
    s = {(1, 2), (3, 4)};
    return len(s) * 100 + (10 if (1, 2) in s else 0) + (1 if (5, 6) in s else 0);
}


"""A duplicate collapses by value, not by allocation."""
def lit_dup(n: int) -> int {
    s = {(1, 2), (1, 3), (1, 2)};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""A single-member display: only the first-element path runs."""
def lit_single(n: int) -> int {
    s = {(5, 6)};
    return len(s) * 10 + (1 if (5, 6) in s else 0);
}


"""Components computed at run time rather than constants."""
def lit_runtime(n: int) -> int {
    s = {(n, n + 1), (n + 1, n), (n, n + 1)};
    return len(s) * 10 + (1 if (n + 1, n) in s else 0);
}


"""A three-wide layout: the flavour is per element size."""
def lit_triple(n: int) -> int {
    s = {(1, 2, 3), (1, 2, 4), (1, 2, 3)};
    return len(s) * 10 + (1 if (1, 2, 4) in s else 0);
}


"""Tuples holding strings compare their str members by content."""
def lit_str_pairs(n: int) -> int {
    s = {("a", 1), ("b", 2), ("a", 1)};
    return len(s) * 100
        + (10 if ("a" + "", 1) in s else 0)
        + (1 if ("a", 2) in s else 0);
}


"""Float components."""
def lit_float_pairs(n: int) -> int {
    s = {(1.5, 2.5), (1.5, 2.5), (0.5, 2.5)};
    return len(s) * 10 + (1 if (0.5, 2.5) in s else 0);
}


"""A display under a declared type, then grown with `.add()`."""
def lit_declared_add(n: int) -> int {
    s: set[tuple[int, int]] = {(1, 1), (2, 2)};
    s.add((3, 3));
    s.add((1, 1));
    return len(s) * 10 + (1 if (3, 3) in s else 0);
}


def _make_pairs -> set[tuple[int, int]] {
    return {(7, 8), (9, 10), (7, 8)};
}


"""A display returned through a declared `set[tuple[...]]` return type."""
def lit_returned(n: int) -> int {
    s = _make_pairs();
    return len(s) * 100 + (10 if (9, 10) in s else 0) + (1 if (8, 7) in s else 0);
}


"""A module-level display, built in glob init."""
def lit_glob(n: int) -> int {
    return len(PAIRS) * 10 + (1 if (3, 4) in PAIRS else 0);
}


"""Destructuring iteration reads every component back."""
def lit_iter_sum(n: int) -> int {
    total = 0;
    for (a, b) in {(1, 2), (3, 4), (1, 2)} {
        total += a * b;
    }
    return total;
}


"""A set comprehension of tuples, which already boxed its elements."""
def compr_pairs(n: int) -> int {
    s = {(i, i * 2) for i in range(3)};
    return len(s) * 10 + (1 if (2, 4) in s else 0);
}


"""`set()` over a list of tuples."""
def ctor_pairs(n: int) -> int {
    s = set([(1, 2), (1, 2), (3, 4)]);
    return len(s) * 10 + (1 if (3, 4) in s else 0);
}


"""The boxes a display builds are released with the set, members included."""
def lit_owned_members(n: int) -> int {
    before = dropped;
    s = {(Node(tag=1), 1), (Node(tag=2), 2)};
    size = len(s);
    s = {(Node(tag=3), 3)};
    return (dropped - before) * 10 + size;
}


with entry:__main__ {
    assert lit_pairs(0) == 210;
    assert lit_dup(0) == 21;
    assert lit_single(0) == 11;
    assert lit_runtime(4) == 21;
    assert lit_triple(0) == 21;
    assert lit_str_pairs(0) == 210;
    assert lit_float_pairs(0) == 21;
    assert lit_declared_add(0) == 31;
    assert lit_returned(0) == 210;
    assert lit_glob(0) == 21;
    assert lit_iter_sum(0) == 14;
    assert compr_pairs(0) == 31;
    assert ctor_pairs(0) == 21;
    assert lit_owned_members(0) == 22;
    print("OK set_literal_tuple");
}
