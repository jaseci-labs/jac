"""Single-character access is served from the immortal __jac_chars cache.

`for c in str` and `s[i]` extract single characters. The native backend returns
a pointer into a shared 256-entry static table (a CPython latin1-style cache)
instead of heap-allocating a fresh RC string per character. Regressing this made
string iteration allocate (and leak) one string per character, blowing up memory
on string-heavy workloads. The test pins the runtime behavior: characters compare
and concatenate correctly, and a cached character still reports length 1.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    native_address,
    native_force_opts,
    native_str_func
}
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "char_cache.jac";


def _compile(fixture: str) -> tuple[any, ...] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return (eng, ir);
}


def _get(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}


test "cached characters behave as real strings at runtime" {
    (eng, _) = _compile(FIXTURE);

    scan = native_str_func(eng, "char_scan", ctypes.c_int64, ctypes.c_char_p);
    assert scan(b"foobar") == 2;  # two 'o'
    assert scan(b"banana") == 0;

    idx = native_str_func(
        eng, "char_index", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    assert idx(b"Hello", 0).decode("utf-8") == "H";
    assert idx(b"Hello", 4).decode("utf-8") == "o";

    combine = native_str_func(eng, "combine", ctypes.c_int64, ctypes.c_char_p);
    assert combine(b"Hello") == 5;  # concat of 5 cached chars
    assert combine(b"") == 0;
}
