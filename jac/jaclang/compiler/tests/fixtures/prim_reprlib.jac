"""Bundled native `reprlib` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from reprlib { Repr, repr }` binds CPython's `reprlib` on the
sv (Python) backend and the bundled `na_stdlib/reprlib.jac` Mechanism-B module
on the na (native LLVM) backend. All results are exact strings, so they marshal
cleanly across the harness.

The probe covers the congruent subset: bool/int/float/str scalars, escaping and
quote selection, `maxstring`/`maxlong` middle-ellipsis fill, lists, sorted-key
dicts, `maxlist`/`maxdict` truncation, and `maxlevel` depth cutoff. Sets,
frozensets, and tuples fall outside the native module's scope (sets raise
`ValueError`; other unrecognized values repr as `"None"`) and are not probed.
ES/JS opts out.
"""

import from reprlib { Repr, repr }


def reprlib_py -> dict[any, any] {
    r: Repr = Repr();
    r.maxlist = 2;
    l1: list[any] = [1, 2, 3];
    l2: list[any] = [1, 2, 3, 4, 5, 6, 7, 8];
    l3: list[any] = [];
    n1: list[any] = [1];
    n2: list[any] = [n1];
    n3: list[any] = [n2];
    n4: list[any] = [n3];
    n5: list[any] = [n4];
    n6: list[any] = [n5];
    n7: list[any] = [n6];
    d1: dict[str, any] = {"b": 1, "a": 2, "c": 3, "d": 4, "e": 5};
    d3: dict[str, any] = {};
    ml: list[any] = [1, 2, 3, 4];
    return {
        "su": repr("h\u00e9llo"),
        "i": repr(42),
        "b": repr(True),
        "f": repr(1.5),
        "s1": repr("hello"),
        "s2": repr("he'llo"),
        "s3": repr("a\nb"),
        "s4": repr("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        "s5": repr(""),
        "n": repr(None),
        "l1": repr(l1),
        "l2": repr(l2),
        "l3": repr(l3),
        "l4": repr(n7),
        "d1": repr(d1),
        "d3": repr(d3),
        "ml": r.repr(ml)
    };
}


def reprlib_cl -> dict[any, any] {
    return {};
}


def reprlib_na -> dict[str, any] {
    r: Repr = Repr();
    r.maxlist = 2;
    l1: list[any] = [1, 2, 3];
    l2: list[any] = [1, 2, 3, 4, 5, 6, 7, 8];
    l3: list[any] = [];
    n1: list[any] = [1];
    n2: list[any] = [n1];
    n3: list[any] = [n2];
    n4: list[any] = [n3];
    n5: list[any] = [n4];
    n6: list[any] = [n5];
    n7: list[any] = [n6];
    d1: dict[str, any] = {"b": 1, "a": 2, "c": 3, "d": 4, "e": 5};
    d3: dict[str, any] = {};
    ml: list[any] = [1, 2, 3, 4];
    return {
        "su": repr("h\u00e9llo"),
        "i": repr(42),
        "b": repr(True),
        "f": repr(1.5),
        "s1": repr("hello"),
        "s2": repr("he'llo"),
        "s3": repr("a\nb"),
        "s4": repr("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        "s5": repr(""),
        "n": repr(None),
        "l1": repr(l1),
        "l2": repr(l2),
        "l3": repr(l3),
        "l4": repr(n7),
        "d1": repr(d1),
        "d3": repr(d3),
        "ml": r.repr(ml)
    };
}
