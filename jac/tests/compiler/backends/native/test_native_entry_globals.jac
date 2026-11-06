"""Behavioral tests for entry-block assignments as module globals (#7626 A1).

Python treats `with entry` assignments as module globals: a lambda or def
reads them dynamically, late-bound at call time. These tests pin the native
backend to the same semantics -- entry-block top-level assignments lower to
native module globals initialized in jac_entry, so entry lambdas, stored
closures, and free defs all observe the same module state as CPython.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    assert_native_identity,
    compile_native,
    get_func,
    native_force_opts
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

glob EXPECTED_AUG_BOOL = (
         "float aug 5.0 4.5 1.5 4.0 19.0 1.5\n"
         "float /= 0.0 ZeroDivisionError\n"
         "seq aug {'a': 1, 'b': 2} [1, 2, 1, 2] ababab [7]\n"
         "list alias [1, 1] []\n"
         "bool() False True False True False True\n"
         "bool() text False True True 2 1\n"
         "bool as float 0.25 0.5 0.5 2.5 1.0\n"
         "bool() count x ab [1] []\n"
         "True count x ab [1] []\n"
         "divmod (1, 0) (1, 0) (5, 0)\n"
         "round 1 1 0\n"
         "def bool() False False False False False\n"
         "def bool() True True True True True\n"
         "def bool as float 11.0 11.0 1.5 0.5 0.5 0.0\n"
         "def bool() count x ab [1] []\n"
         "def True count x ab [1] []\n"
         "def divmod (1, 0) (1, 0) (5, 0)\n"
         "def round 1 1 0\n"
         "def set {False, True} {False, True}\n"
         "def seq aug [1, 2, 1, 2] ababab {'a': 1, 'b': 2}\n"
         "def list alias [1, 1] []\n"
     );

test "entry globals: lambda reads an entry-assigned name late-bound" {
    (eng, _) = compile_native("entry_globals.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    n = get_func(eng, "acc_len", ctypes.c_int64);
    assert n() == 2 , "both appends ran through the stored closure";
    at = get_func(eng, "acc_at", ctypes.c_int64, ctypes.c_int64);
    assert at(0) == 8 , "f(1) before rebind reads k == 7 (Python parity)";
    assert at(1) == 101 , "f(1) after rebind reads k == 100: entry names are late-bound module globals";
}

test "entry globals: a free def reads entry-assigned module state" {
    (eng, _) = compile_native("entry_globals.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "read_k", ctypes.c_int64);
    assert f() == 100 , "def sees the final entry-assigned value of k";
}

test "entry globals: augmented assignment and bool() rows match Python" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "entry_aug_bool.jac"), profiles=["managed"]
    );
    assert out == EXPECTED_AUG_BOOL , f"got {out!r}";
}
