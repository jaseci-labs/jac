"""sorted() and list() accept every iterable the native iterator protocol walks.

sorted() used to copy and sort lists only, so sorted() of a set, tuple,
dict, bytes or str did not lower; list() had no path for a dict, a str or a
range object. Both now materialize any other iterable through the iterator
protocol. Every assertion compares the native rendering with the sv
rendering of the same fixture function.
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

test "sorted and list materialize any native iterable" {
    (eng, _) = compile_native("sorted_sources.jac");
    sv = sv_module("sorted_sources");
    for name in [
        "sorted_set",
        "sorted_tuple",
        "sorted_bytes",
        "sorted_reverse",
        "sorted_dict_keys",
        "sorted_str",
        "list_of_range",
        "list_of_dict"
    ] {
        na_fn = native_str_func(eng, name, ctypes.c_char_p, ctypes.c_int64);
        sv_fn = getattr(sv, name);
        for x in [0, 2, 7] {
            na_out = na_fn(x);
            sv_out = sv_fn(x).encode("utf8");
            assert na_out == sv_out , f"{name}({x}): native {na_out!r} != sv {sv_out!r}";
        }
    }
}
