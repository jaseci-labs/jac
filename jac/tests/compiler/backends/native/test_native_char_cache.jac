"""Single-character access is served from the immortal __jac_chars cache.

`for c in str` and `s[i]` extract single characters. The native backend returns
a pointer into a shared 256-entry static table (a CPython latin1-style cache)
instead of heap-allocating a fresh RC string per character. Regressing this made
string iteration allocate (and leak) one string per character, blowing up memory
on string-heavy workloads. These tests pin both the IR shape (uses __jac_chars,
no per-character RC allocation) and the runtime behavior (characters compare and
concatenate correctly, and a cached character still reports length 1).
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, names_function, native_address, native_force_opts, native_str_func }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "char_cache.jac";


def _compile(fixture: str) -> tuple {
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


test "single-character access uses the __jac_chars cache, not per-char rc_alloc" {
    (eng, ir) = _compile(FIXTURE);
    txt = str(ir.gen.llvm_ir);

    # The immortal 256-entry cache global is emitted.
    assert "__jac_chars" in txt , "char cache global __jac_chars not emitted";

    # Neither the iterate-a-string function nor the index function allocates a
    # string per character: the character is a pointer into the static cache.
    scan_ir = _fn_body(txt, "char_scan");
    idx_ir = _fn_body(txt, "char_index");
    assert "__jac_chars" in scan_ir , "char_scan does not use the char cache";
    assert "__jac_chars" in idx_ir , "s[i] does not use the char cache";
    assert "@\"__rc_alloc\"" not in scan_ir , (
        "char_scan heap-allocates a string per character (char cache regressed)"
    );
    assert "@\"__rc_alloc\"" not in idx_ir , (
        "s[i] heap-allocates a string (char cache regressed)"
    );
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


"""Return the LLVM IR text of a single `define ... @name(` function body."""
def _fn_body(txt: str, name: str) -> str {
    start = txt.find("define ");
    while start != -1 {
        end = txt.find("\n}", start);
        if end == -1 {
            break;
        }
        block = txt[start:end + 2];
        header_end = block.find("\n");
        header = block[:header_end] if header_end != -1 else block;
        if names_function(header, name) {
            return block;
        }
        start = txt.find("define ", end);
    }
    return "";
}
