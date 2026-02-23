"""Builtin function primitives not covered by prim_builtins / prim_jac_runtime.

Covers type constructors: dict, set, tuple, frozenset, bytes, complex, bytearray.

Not cross-backend testable: print, input, open, type, id, hash, repr,
vars, dir, issubclass, isinstance, iter, next, callable (builtins like
`len` don't exist as standalone references in JS), ascii (quoting style
differs), hasattr/getattr (dict keys != object attributes in Python).
"""

def builtins_extra_py() -> dict {
    # type constructors
    d: dict = dict([["a", 1], ["b", 2]]);
    s: list = sorted(list(set([3, 1, 2, 1])));
    t: list = list(tuple([10, 20, 30]));
    fs: list = sorted(list(frozenset([5, 3, 5, 1])));
    by: list = list(bytes([65, 66, 67]));
    ba: list = list(bytearray([68, 69]));

    # complex constructor
    c = complex(3, 4);
    c_eq: bool = c == complex(3, 4);

    return {
        "dict": d, "set": s, "tuple": t,
        "frozenset": fs, "bytes": by, "bytearray": ba,
        "complex_eq": c_eq
    };
}

cl def builtins_extra_cl() -> dict {
    d: dict = dict([["a", 1], ["b", 2]]);
    s: list = sorted(list(set([3, 1, 2, 1])));
    t: list = list(tuple([10, 20, 30]));
    fs: list = sorted(list(frozenset([5, 3, 5, 1])));
    by: list = list(bytes([65, 66, 67]));
    ba: list = list(bytearray([68, 69]));

    c = complex(3, 4);
    c_eq: bool = c == complex(3, 4);

    return {
        "dict": d, "set": s, "tuple": t,
        "frozenset": fs, "bytes": by, "bytearray": ba,
        "complex_eq": c_eq
    };
}
