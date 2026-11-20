"""Behavioral tests for tagged scalar optionals (#7626 C5).

`int | None` lowers as a JacOptional {tag, payload} value instead of
silently collapsing to a bare int (where None was indistinguishable from
0). Pins return/assign/param seams and `is None` tag reads, matching the
Python backend: use_pick (6, -1), opt_local (5, -1), use_opt_param
(7, -5).
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "scalar optional: fn returning int|None distinguishes None from 0" {
    (eng, _) = compile_native("optional_scalar.jac");
    f = get_func(eng, "use_pick", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 6 , "pick(3) == 6 through the optional";
    assert f(0) == -1 , "pick(0) is None -- NOT 0";
}

test "scalar optional: int|None local assigns None and a value" {
    (eng, _) = compile_native("optional_scalar.jac");
    f = get_func(eng, "opt_local", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 5 , "x = 4 then x + 1";
    assert f(0) == -1 , "x stays None";
}

test "scalar optional: int|None parameter passes None and a value" {
    (eng, _) = compile_native("optional_scalar.jac");
    f = get_func(eng, "use_opt_param", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 7 , "value flows through the optional param";
    assert f(0) == -5 , "explicit None selects the alternative";
}
