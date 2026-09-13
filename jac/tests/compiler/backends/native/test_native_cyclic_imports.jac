"""Behavioral tests for circular native imports (issue #7593 item 11).

A two-module import cycle must compile and link: the entry module's
NaIRGenPass never treats itself as its own foreign import, dep definitions
arrive via NativeCompilePass link_in, and the back-edge import resolves
against the entry module's own definitions instead of recompiling it as a
dependency. Module-level glob initializers run dependencies-first
(topological order over native_transitive_sources) behind a once-guard, so
cyclic modules initialize exactly once without crashing.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "cyclic import: mandated two-file cycle compiles" {
    (native_program, eng, _) = compile_native("cycle_ping.jac");
    assert eng is not None;
}

test "cyclic import: mutual recursion computes across modules" {
    (native_program, eng, _) = compile_native("cycle_ping.jac");
    get_func(eng, "jac_entry", None)();
    f = get_func(eng, "ping", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 7 , f"ping(7) expected 7, got {f(7)}";
    assert f(0) == 0 , f"ping(0) expected 0, got {f(0)}";
}

test "glob init: transitive runtime initializer runs dependencies first" {
    (native_program, eng, _) = compile_native("glob_chain_entry.jac");
    get_func(eng, "jac_entry", None)();
    got = get_func(eng, "get_b", ctypes.c_int64)();
    assert got == 7 , f"get_b() expected 7 (leaf inits before mid), got {got}";
}

test "glob init: cyclic modules init once without crashing" {
    (native_program, eng, _) = compile_native("cycle_glob_a.jac");
    get_func(eng, "jac_entry", None)();
    av = get_func(eng, "get_av", ctypes.c_int64)();
    bv = get_func(eng, "get_bv", ctypes.c_int64)();
    assert av == 11 , f"get_av() expected 11, got {av}";
    assert bv == 22 , f"get_bv() expected 22, got {bv}";
    cross_a = get_func(eng, "read_bv", ctypes.c_int64)();
    cross_b = get_func(eng, "read_av", ctypes.c_int64)();
    assert cross_a == 22 , f"read_bv() expected 22, got {cross_a}";
    assert cross_b == 11 , f"read_av() expected 11, got {cross_b}";
}
