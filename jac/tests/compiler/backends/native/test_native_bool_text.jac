"""Booleans render as True and False on the native backend.

A membership test used to lower to a 0/1 integer rather than the i1 every
other comparison produces, and an f-string interpolation formatted any bool
with %lld, so `f"{x in s}"` and `repr(x < 0)` rendered 1 and 0. Every
assertion compares the native rendering with the sv rendering of the same
fixture function.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, compile_native, native_str_func }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Import the fixture on the sv/bytecode pathway and hand back its module."""
def sv_module(stem: str) -> object {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop(stem, None);
        return importlib.import_module(stem);
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
    }
}

test "membership and comparison results render as True and False" {
    (eng, _) = compile_native("bool_text.jac");
    sv = sv_module("bool_text");
    for name in [
        "membership_fstring",
        "comparison_fstring",
        "spec_fstring",
        "repr_fstring",
        "repr_text",
        "str_text"
    ] {
        na_fn = native_str_func(eng, name, ctypes.c_char_p, ctypes.c_int64);
        sv_fn = getattr(sv, name);
        for x in [0, 1, 2, 5] {
            na_out = na_fn(x);
            sv_out = sv_fn(x).encode("utf8");
            assert na_out == sv_out , f"{name}({x}): native {na_out!r} != sv {sv_out!r}";
        }
    }
}
