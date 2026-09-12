"""Embedded NULs survive native str operations (issue #6789, root-cause fix).

Native str used to be measured with strlen, so any embedded NUL truncated
concatenation silently -- `chr(65) + chr(0) + chr(66)` had length 1 on na
where sv yields 3. The runtime is now length-aware end to end: literals
stamp their length via `_static_str_struct_const`, concatenation and
substrings stamp via `_str_finish`, and `chr()` now stamps length 1 instead
of relying on its terminator. The old W6010 syntactic warning was retired:
with truncation gone there is nothing to warn about, and foreign C strings
never appear as literal `chr(0)` calls.

Each test compiles the fixture on both backends and compares scalar results.
The JIT string ABI reads returned payloads NUL-bounded, so content checks
come back as ints (lengths and `ord()` of indexed bytes) rather than strs.
"""

import ctypes;
import importlib;
import os;
import sys;
import from tests.support { TESTS_DIR, native_force_opts, native_str_func }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile the nul_concat fixture natively and return the JIT engine."""
def compile_nul_fixture -> ExecutionEngine {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "nul_concat.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , "No native engine produced for nul_concat.jac";
    return eng;
}

"""Import the fixture on the sv/bytecode pathway and hand back its module."""
def sv_module -> any {
    added = False;
    if FIXTURES not in sys.path {
        sys.path.insert(0, FIXTURES);
        added = True;
    }
    try {
        sys.modules.pop("nul_concat", None);
        return importlib.import_module("nul_concat");
    } finally {
        if added {
            sys.path.remove(FIXTURES);
        }
    }
}

test "chr(0) survives a str concat chain on both backends" {
    eng = compile_nul_fixture();
    sv = sv_module();
    for (name, want) in [
        ("chain_len", 3),
        ("chain_mid_ord", 0),
        ("chain_last_ord", 66)
    ] {
        na_out = native_str_func(eng, name, ctypes.c_int64)();
        sv_out = getattr(sv, name)();
        assert na_out == sv_out == want , (
            f"{name}: na {na_out!r} != sv {sv_out!r} (expected {want})"
        );
    }
}

test "a literal with an embedded NUL keeps all bytes on both backends" {
    eng = compile_nul_fixture();
    sv = sv_module();
    for (name, want) in [("nul_lit_len", 3), ("nul_lit_mid_ord", 0)] {
        na_out = native_str_func(eng, name, ctypes.c_int64)();
        sv_out = getattr(sv, name)();
        assert na_out == sv_out == want , (
            f"{name}: na {na_out!r} != sv {sv_out!r} (expected {want})"
        );
    }
}

test "dynamic chr(v & 0xFF) round-trips a zero byte on both backends" {
    eng = compile_nul_fixture();
    sv = sv_module();
    for v in [0x00, 0x41, 0x4100] {
        na_len = native_str_func(eng, "dyn_chain_len", ctypes.c_int64, ctypes.c_int64)(
            v
        );
        sv_len = sv.dyn_chain_len(v);
        assert na_len == sv_len == 3 , (
            "dyn_chain_len("
            + str(v)
            + "): na "
            + repr(na_len)
            + " != sv "
            + repr(sv_len)
        );
        na_ord = native_str_func(
            eng, "dyn_chain_mid_ord", ctypes.c_int64, ctypes.c_int64
        )(
            v
        );
        sv_ord = sv.dyn_chain_mid_ord(v);
        assert na_ord == sv_ord , (
            "dyn_chain_mid_ord("
            + str(v)
            + "): na "
            + repr(na_ord)
            + " != sv "
            + repr(sv_ord)
        );
    }
}
