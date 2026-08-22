"""A leading `*` spread of a list of tuples into a set display.

Native lists register one instantiation per storage flavour, and every
pointer-element list shares `List.ptr`, whose element slot is deliberately
erased to a byte pointer. A set has a `tupleN` flavour on top of that: it
hashes and compares the N bytes behind the pointer rather than the pointer
itself. A leading spread seeded the set's flavour from the source list's
*lowered* element type, so the erased byte pointer came back and the set
was built on the plain pointer flavour, whose keys are hashed and compared
as NUL-terminated C strings over the boxed tuple's own bytes.

Two int pairs whose first component matches therefore read as the same
one-byte string: they collapsed into a single member and a pair that was
never inserted answered True to `in`. Nothing was written to stderr.

Every function folds its set back to a number carrying both the length and
a membership answer, since the failure is a set that is *shorter* than it
should be rather than one that is missing. Sets are never iterated here:
their order is not part of the language and the native and bytecode tables
need not agree on it.
"""

glob PAIRS: list[tuple[int, int]] = [(1, 2), (1, 3), (1, 2)];

obj Rows {
    has pairs: list[tuple[int, int]] = [];
}

"""Duplicates must collapse by value: two members survive, not one."""
def head_dup(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2), (1, 3), (1, 2)];
    s = {*a};
    return len(s);
}


"""Both inserted pairs answer True to `in`."""
def head_member(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2), (3, 4)];
    s = {*a};
    return (1 if (1, 2) in s else 0) * 10 + (1 if (3, 4) in s else 0);
}


"""A pair that was never inserted must answer False, first component or not."""
def head_absent(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2)];
    s = {*a};
    return (1 if (1, 9) in s else 0) * 10 + (1 if (4, 2) in s else 0);
}


"""A leading zero byte truncated every key to the empty string."""
def head_zero_lead(flag: int) -> int {
    a: list[tuple[int, int]] = [(0, 1), (0, 2), (0, 3)];
    s = {*a};
    return len(s) * 10 + (1 if (0, 2) in s else 0);
}


"""A three-wide layout: the flavour is per element size, not per element kind."""
def head_triple(flag: int) -> int {
    a: list[tuple[int, int, int]] = [(1, 2, 3), (1, 2, 4), (1, 2, 3)];
    s = {*a};
    return len(s) * 10 + (1 if (1, 2, 4) in s else 0);
}


"""The source is a module-level list, so the copy loop lands in glob init."""
def head_glob(flag: int) -> int {
    s = {*PAIRS};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""Contrast: a set comprehension of tuples already picks the layout flavour."""
def compr_set(flag: int) -> int {
    s = {(1, x) for x in [2, 3, 2]};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""Contrast: a set source carries its own element size through the spread."""
def head_set_spread(flag: int) -> int {
    src = {(1, x) for x in [2, 3]};
    s = {*src};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""A list of tuples spread in a position other than the first."""
def tail_list_spread(flag: int) -> int {
    src = {(1, x) for x in [2]};
    a: list[tuple[int, int]] = [(1, 3), (1, 2)];
    s = {*src, *a};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""Two list spreads, the second one non-leading."""
def two_list_spreads(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2), (1, 3)];
    b: list[tuple[int, int]] = [(1, 3), (1, 4)];
    s = {*a, *b};
    return len(s) * 10 + (1 if (1, 4) in s else 0);
}


"""The genuinely string-flavoured spread, which must keep its C-string keys."""
def str_head_spread(flag: int) -> int {
    a: list[str] = ["ab", "cd", "ab"];
    s = {*a};
    return len(s) * 10 + (1 if "cd" in s else 0);
}


"""A scalar-flavoured spread, whose element slot was never erased."""
def int_head_spread(flag: int) -> int {
    a: list[int] = [2, 3, 2];
    s = {*a};
    return len(s) * 10 + (1 if 3 in s else 0);
}


"""A source that is a parameter, whose declared type sits on the ParamVar."""
def _from_param(a: list[tuple[int, int]]) -> int {
    s = {*a};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


def param_spread(flag: int) -> int {
    return _from_param([(1, 2), (1, 3), (1, 2)]);
}


"""A string parameter, which must keep the C-string keys it always had."""
def _from_str_param(a: list[str]) -> int {
    s = {*a};
    return len(s) * 10 + (1 if "cd" in s else 0);
}


def param_str_spread(flag: int) -> int {
    return _from_str_param(["ab", "cd", "ab"]);
}


"""A source that is an object field rather than a binding."""
def field_spread(flag: int) -> int {
    b = Rows(pairs=[(1, 2), (1, 3), (1, 2)]);
    s = {*b.pairs};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""A source that is a call result, which never has a binding at all."""
def _pairs -> list[tuple[int, int]] {
    return [(1, 2), (1, 3), (1, 2)];
}


def call_spread(flag: int) -> int {
    s = {*_pairs()};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""A source that is a slice of a list of tuples."""
def slice_spread(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2), (1, 3), (1, 4)];
    s = {*a[0:2]};
    return len(s) * 10 + (1 if (1, 3) in s else 0);
}


"""The copy must be a copy: mutating the source afterwards leaves the set."""
def source_survives(flag: int) -> int {
    a: list[tuple[int, int]] = [(1, 2), (1, 3)];
    s = {*a};
    a.append((1, 4));
    return len(s) * 100 + len(a) * 10 + (1 if (1, 4) in s else 0);
}


with entry:__main__ {
    assert head_dup(0) == 2;
    assert head_member(0) == 11;
    assert head_absent(0) == 0;
    assert head_zero_lead(0) == 31;
    assert head_triple(0) == 21;
    assert head_glob(0) == 21;
    assert compr_set(0) == 21;
    assert head_set_spread(0) == 21;
    assert tail_list_spread(0) == 21;
    assert two_list_spreads(0) == 31;
    assert str_head_spread(0) == 21;
    assert int_head_spread(0) == 21;
    assert param_spread(0) == 21;
    assert param_str_spread(0) == 21;
    assert field_spread(0) == 21;
    assert call_spread(0) == 21;
    assert slice_spread(0) == 21;
    assert source_survives(0) == 230;
    print("OK set_spread_tuple");
}
