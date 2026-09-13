"""Behavioral tests for entry-block assignments as module globals (#7626 A1).

Python treats `with entry` assignments as module globals: a lambda or def
reads them dynamically, late-bound at call time. These tests pin the native
backend to the same semantics -- entry-block top-level assignments lower to
native module globals initialized in jac_entry, so entry lambdas, stored
closures, and free defs all observe the same module state as CPython.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "entry globals: lambda reads an entry-assigned name late-bound" {
    (native_program, eng, _) = compile_native("entry_globals.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    n = get_func(eng, "acc_len", ctypes.c_int64);
    assert n() == 2 , "both appends ran through the stored closure";
    at = get_func(eng, "acc_at", ctypes.c_int64, ctypes.c_int64);
    assert at(0) == 8 , "f(1) before rebind reads k == 7 (Python parity)";
    assert at(1) == 101 , "f(1) after rebind reads k == 100: entry names are late-bound module globals";
}

test "entry globals: a free def reads entry-assigned module state" {
    (native_program, eng, _) = compile_native("entry_globals.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "read_k", ctypes.c_int64);
    assert f() == 100 , "def sees the final entry-assigned value of k";
}
