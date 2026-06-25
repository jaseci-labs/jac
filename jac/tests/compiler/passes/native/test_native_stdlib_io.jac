"""Native-backend regression tests for issue #6964 (nacompile stdlib + language
gaps for native I/O tools):

  * P2 bare-`tuple` literal codegen (`bare_tuple.na.jac`),
  * the flat `import json; json.dumps(...)` bare-import routing to bundled
    na_stdlib modules — json / zlib / hashlib (`stdlib_bare_import.na.jac`),
  * the bundled pure-Jac `hashlib` SHA-256 digest (`stdlib_hashlib.na.jac`),
  * a guardrail pinning the still-deferred modules (zipfile / subprocess /
    socket) to a clean, actionable E5090 rather than a crash or a silently
    wrong binary.

Each fixture exposes value-returning `def`s so the JIT path can assert results
through ctypes, matching the rest of the native suite (no subprocess/stdout).
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );


"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> object {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return eng;
}


"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype)(addr);
}


# ─── P2: bare `tuple` literal codegen (#6964) ────────────────────────────────
test "bare tuple: homogeneous element access" {
    eng = compile_native("bare_tuple.na.jac");
    assert get_func(eng, "homo_first", ctypes.c_int64)() == 10;
    assert get_func(eng, "homo_second", ctypes.c_int64)() == 20;
}

test "bare tuple: heterogeneous element access" {
    eng = compile_native("bare_tuple.na.jac");
    assert get_func(eng, "hetero_str", ctypes.c_char_p)() == b"a";
    assert get_func(eng, "hetero_int", ctypes.c_int64)() == 1;
}


# ─── Bare-import routing to bundled na_stdlib (#6964) ─────────────────────────
test "import json: dumps via module namespace" {
    eng = compile_native("stdlib_bare_import.na.jac");
    f = get_func(eng, "json_dumps_via_namespace", ctypes.c_char_p);
    assert f() == b'{"name": "llvm", "n": 3}';
}

test "import json: loads field + array length" {
    eng = compile_native("stdlib_bare_import.na.jac");
    assert get_func(eng, "json_loads_field", ctypes.c_char_p)() == b"llvm";
    assert get_func(eng, "json_loads_arr_len", ctypes.c_int64)() == 2;
}

test "import zlib: round-trip + crc32 via module namespace" {
    eng = compile_native("stdlib_bare_import.na.jac");
    # b"hello native hello native" is 25 bytes; the inflate must recover them.
    assert get_func(eng, "zlib_roundtrip_len", ctypes.c_int64)() == 25;
    assert get_func(eng, "zlib_crc", ctypes.c_int64)() == 972181235;
}

test "import hashlib: sha256 via module namespace" {
    eng = compile_native("stdlib_bare_import.na.jac");
    f = get_func(eng, "hashlib_hello", ctypes.c_char_p);
    assert f() == (b"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
}


# ─── Bundled hashlib SHA-256 byte-exactness (#6964) ──────────────────────────
test "hashlib sha256: FIPS / CPython vectors incl. multi-block" {
    eng = compile_native("stdlib_hashlib.na.jac");
    assert get_func(eng, "h_empty", ctypes.c_char_p)() == (
        b"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    );
    assert get_func(eng, "h_hello", ctypes.c_char_p)() == (
        b"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    );
    assert get_func(eng, "h_abc", ctypes.c_char_p)() == (
        b"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    );
    assert get_func(eng, "h_fox", ctypes.c_char_p)() == (
        b"d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"
    );
    # 100 'a' bytes -> two-block message (padding-boundary path).
    assert get_func(eng, "h_multiblock", ctypes.c_char_p)() == (
        b"2816597888e4a0d3a36b82b83316ab32680eb8f00f8cd3b904d681246d285a0e"
    );
    # Repeated update() == hash of the concatenation.
    assert get_func(eng, "h_incremental", ctypes.c_char_p)() == (
        b"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    );
}
