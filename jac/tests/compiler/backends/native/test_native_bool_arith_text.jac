"""Arithmetic on bools renders as Python renders it on the native backend.

bool arithmetic is int arithmetic, so `(x > 1) + (x > 0)` is the int 2 and
`-b`, `~b` and `abs(b)` are ints, while `&`, `|` and `^` between two bools stay
bool. Natively a bool pair used to widen to an i32 that an f-string dropped
(it formatted only i64 and i1 integers, so `f"{(x > 1) + (x > 0)}"` and
`f"{i32_value}"` rendered empty), the unary operators and `abs` kept the i1,
and the checker typed `b + b` as bool. Every assertion compares the native
rendering with the sv rendering of the same fixture function.
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

test "bool arithmetic and sized integers render as they do on sv" {
    (eng, _) = compile_native("bool_arith_text.jac");
    sv = sv_module("bool_arith_text");
    for name in [
        "sum_fstring",
        "mixed_fstring",
        "unary_fstring",
        "bitwise_fstring",
        "spec_fstring",
        "text_calls",
        "local_text",
        "sized_fstring"
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
