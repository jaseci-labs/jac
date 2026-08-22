"""A `*` spread inside a list or set display, in every position.

A spread is not an element: it stands for however many elements the source
container holds at that point in the program, which is a runtime quantity.
So the display cannot be built by walking `values` once and appending each
one; a spread has to expand into a copy loop over its source, and the loop
has to agree with the element storage the rest of the display picked.

Every function here folds its container back to a single integer rather
than only asking whether it was built, because the failure this fixture
guards is a container that is *shorter* than it should be, not one that is
missing. The list folds carry a leading `1` so that length and order are
both encoded -- `[1, 2, 3]` and `[1, 3]` fold to different numbers, and a
dropped element cannot hide behind a coincidence.

Sets are probed by length and membership rather than by iteration, since
set order is not part of the language and the native and bytecode tables
need not agree on it.
"""

glob SPREAD_SRC: list[int] = [2, 3],
     SPREAD_GLOB: list[int] = [1, *SPREAD_SRC, 4];

"""Fold a list of ints to one number; the leading 1 pins the length."""
def fold(c: list[int]) -> int {
    acc = 1;
    for x in c {
        acc = acc * 10 + x;
    }
    return acc;
}


"""Probe a set of small ints by length and membership, never by order."""
def probe(s: set[int]) -> int {
    mask = 0;
    for i in range(8) {
        mask = mask * 2;
        k = 7 - i;
        if k in s {
            mask = mask + 1;
        }
    }
    return len(s) * 1000 + mask;
}


"""Spread last: `[1, *a]`."""
def tail_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [1, *a];
    return fold(c);
}


"""Spread in the middle: `[1, *a, 9]`, the shape that used to drop silently."""
def mid_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [1, *a, 9];
    return fold(c);
}


"""Spread first: `[*a, 9]`, the shape that used to refuse loudly."""
def head_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [*a, 9];
    return fold(c);
}


"""Two spreads and three plain elements interleaved."""
def multi_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    b: list[int] = [4, 5];
    c = [1, *a, 6, *b, 7];
    return fold(c);
}


"""Nothing but a spread: `[*a]`, the copy-constructor form."""
def only_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [*a];
    return fold(c);
}


"""Two spreads back to back with no plain element at all."""
def only_two_spreads(flag: int) -> int {
    a: list[int] = [2, 3];
    b: list[int] = [4, 5];
    c = [*a, *b];
    return fold(c);
}


"""An empty source contributes nothing and must not disturb its neighbours."""
def empty_spread(flag: int) -> int {
    e: list[int] = [];
    c = [1, *e, 2];
    return fold(c);
}


"""An empty source in first position, where there is no element to seed from."""
def empty_head_spread(flag: int) -> int {
    e: list[int] = [];
    c = [*e, 4];
    return fold(c);
}


"""The source is a literal, so the spread's operand is itself a display."""
def literal_spread(flag: int) -> int {
    c = [1, *[2, 3], 4];
    return fold(c);
}


"""A spread of a list that was itself built by a spread."""
def nested_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    b = [*a];
    c = [0, *b];
    return fold(c);
}


"""The source length is a runtime quantity, not a literal arity."""
def dynamic_spread(flag: int) -> int {
    a: list[int] = [];
    for i in range(flag) {
        a.append(i + 1);
    }
    c = [7, *a, 8];
    return fold(c);
}


"""The display carries a declared element type the spread has to agree with."""
def declared_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    c: list[int] = [1, *a, 4];
    return fold(c);
}


"""Pointer-flavoured elements: the copied strings must survive the copy."""
def str_spread(flag: int) -> int {
    a: list[str] = ["bb", "ccc"];
    c = ["a", *a, "dddd"];
    total = 1;
    for s in c {
        total = total * 10 + len(s);
    }
    return total;
}


"""Float-flavoured elements, reported as hundredths."""
def float_spread(flag: int) -> int {
    a: list[float] = [0.5, 0.25];
    c = [1.0, *a];
    total = 0.0;
    for f in c {
        total = total + f;
    }
    return int(total * 100.0);
}


"""A spread that appends to a list built one element at a time afterwards."""
def spread_then_mutate(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [1, *a];
    c.append(4);
    return fold(c);
}


"""Set display, spread last."""
def set_tail(flag: int) -> int {
    a: list[int] = [2, 3];
    s = {1, *a};
    return probe(s);
}


"""Set display, spread first."""
def set_head(flag: int) -> int {
    a: list[int] = [2, 3];
    s = {*a, 4};
    return probe(s);
}


"""Set display, spread in the middle."""
def set_mid(flag: int) -> int {
    a: list[int] = [2, 3];
    s = {1, *a, 5};
    return probe(s);
}


"""Two spreads into one set."""
def set_multi(flag: int) -> int {
    a: list[int] = [2, 3];
    b: list[int] = [4, 5];
    s = {1, *a, *b};
    return probe(s);
}


"""Spread-only set."""
def set_only(flag: int) -> int {
    a: list[int] = [2, 3];
    s = {*a};
    return probe(s);
}


"""The spread carries duplicates of elements already written out."""
def set_dedup(flag: int) -> int {
    a: list[int] = [1, 2, 2];
    s = {1, *a, 2};
    return probe(s);
}


"""An empty spread into a set."""
def set_empty_spread(flag: int) -> int {
    e: list[int] = [];
    s = {6, *e};
    return probe(s);
}


"""A set spread into a set: the source is hashed storage, not an array."""
def set_from_set(flag: int) -> int {
    a: set[int] = {2, 3};
    s = {1, *a};
    return probe(s);
}


"""A set spread into a list: the length is right even when the order is not."""
def list_from_set(flag: int) -> int {
    a: set[int] = {2, 3};
    c: list[int] = [*a];
    total = 0;
    for x in c {
        total = total + x * x;
    }
    return len(c) * 1000 + total;
}


"""A spread in a module-level initializer, which runs inside glob init."""
def glob_spread(flag: int) -> int {
    return fold(SPREAD_GLOB);
}


"""A spread in a display that is an argument rather than a binding."""
def call_arg_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    return fold([1, *a, 4]);
}


"""A spread inside a comprehension's output expression."""
def compr_spread(flag: int) -> int {
    a: list[int] = [2, 3];
    rows = [[0, *a] for _ in range(2)];
    total = 1;
    for r in rows {
        total = total * 10 + len(r);
    }
    return total;
}


"""A list spread whose source is reused afterwards, so the copy must be a copy."""
def source_survives(flag: int) -> int {
    a: list[int] = [2, 3];
    c = [1, *a];
    c.append(9);
    return fold(c) * 100 + fold(a);
}


with entry:__main__ {
    assert tail_spread(0) == 1123;
    assert mid_spread(0) == 11239;
    assert head_spread(0) == 1239;
    assert multi_spread(0) == 11236457;
    assert only_spread(0) == 123;
    assert only_two_spreads(0) == 12345;
    assert empty_spread(0) == 112;
    assert empty_head_spread(0) == 14;
    assert literal_spread(0) == 11234;
    assert nested_spread(0) == 1023;
    assert dynamic_spread(2) == 17128;
    assert declared_spread(0) == 11234;
    assert str_spread(0) == 11234;
    assert float_spread(0) == 175;
    assert spread_then_mutate(0) == 11234;
    assert glob_spread(0) == 11234;
    assert call_arg_spread(0) == 11234;
    assert compr_spread(0) == 133;
    assert set_tail(0) == 3014;
    assert set_head(0) == 3028;
    assert set_mid(0) == 4046;
    assert set_multi(0) == 5062;
    assert set_only(0) == 2012;
    assert set_dedup(0) == 2006;
    assert set_empty_spread(0) == 1064;
    assert set_from_set(0) == 3014;
    assert list_from_set(0) == 2013;
    assert source_survives(0) == 1124023;
    print("OK list_set_spread");
}
