"""Congruence gate for conditional expressions inside f-string interpolations.

Roadmap item N8a of jaseci-labs/jac#7967: an interpolation value must be
lowered by ordinary expression codegen, so a ternary inside `{...}` renders the
same on the native (`na`) backend as it does on sv/bytecode. Every assertion
here compares the native result against the sv result for the same fixture
function rather than a hardcoded constant, so a divergence in either backend
fails the test.

The ternaries are all same-representation (two `str` branches or two `int`
branches). A ternary whose branches lower to DIFFERENT representations (say
`str | None` against `str`) is a separate gap -- it fails identically outside
an f-string -- and is tracked as roadmap item N3.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support {
    TESTS_DIR,
    compile_native,
    native_force_opts,
    native_str_func
}

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

test "f-string ternary interpolations match the sv rendering" {
    (eng, _) = compile_native("fstring_conditional.jac");
    sv = sv_module("fstring_conditional");
    cases = [
        "pick_str",
        "pick_int",
        "pick_literal",
        "pick_spec",
        "pick_nested",
        "pick_call",
        "pick_call_ternary",
        "pick_chained"
    ];
    for name in cases {
        na_fn = native_str_func(eng, name, ctypes.c_char_p, ctypes.c_int64);
        sv_fn = getattr(sv, name);
        for c in [0, 1] {
            na_out = na_fn(c);
            sv_out = sv_fn(c).encode("utf8");
            assert na_out == sv_out , (
                f"{name}({c}): native {na_out!r} != sv {sv_out!r}"
            );
        }
    }
}
