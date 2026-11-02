"""A builtin exception raised with a number or a bool (`raise SystemExit(3)`,
`raise ValueError(n)`) lowers natively, and its message is the argument's
text, as on sv. The raise lowering passed the argument through as the
message pointer, so an int reached the runtime's `i8*` slot and the function
failed with a backend TypeError (E5092) instead of compiling."""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, compile_native, native_str_func }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

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

test "builtin exceptions raised with a scalar carry its text natively" {
    (eng, _) = compile_native("exc_scalar_args.jac");
    sv = sv_module("exc_scalar_args");
    for name in ["int_message", "float_message", "bool_message", "exit_message"] {
        na_fn = native_str_func(eng, name, ctypes.c_char_p, ctypes.c_int64);
        sv_fn = getattr(sv, name);
        for x in [0, 1, 3, -7] {
            na_out = na_fn(x);
            sv_out = sv_fn(x).encode("utf8");
            assert na_out == sv_out , f"{name}({x}): native {na_out!r} != sv {sv_out!r}";
        }
    }
}
