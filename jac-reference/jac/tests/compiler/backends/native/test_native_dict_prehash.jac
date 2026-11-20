"""Compile-time hashing of static container keys.

A string key that is a compile-time literal has a compile-time-computable
FNV-1a hash, yet every dict/set operation used to hash it again at runtime
(inserts even hashed twice: once in find, once for the control byte). The
hash-core helpers are split into a prehashed core taking the hash as an
argument plus a thin public wrapper that computes it, and every emitter
site with a literal string key passes the compile-time constant instead.

Two properties are pinned here. Consistency: the compile-time hash must
byte-for-byte agree with the emitted hash function, which the fixture
checks by round-tripping keys between literal and runtime-concatenated
spellings - a divergence turns lookups into misses. Shape: the IR at
static-key sites must call the prehashed cores, not the hashing wrappers.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
import jaclang;

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

# ─────────────────────────────────────────────────────────────────────
# Consistency: compile-time hashes agree with the runtime hash function
# ─────────────────────────────────────────────────────────────────────

test "literal-inserted keys are found via runtime-built keys" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "static_insert_runtime_lookup", ctypes.c_int64);
    # digits 1,2,3,4 in order; a 9 digit marks a hash-divergence miss
    assert f() == 1234 , f"got {f()}";
}

test "runtime-inserted keys are found via literal keys" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "runtime_insert_static_lookup", ctypes.c_int64);
    assert f() == 567 , f"got {f()}";
}

test "literal subscript stores land where runtime lookups probe" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "static_store_runtime_lookup", ctypes.c_int64);
    assert f() == 56 , f"got {f()}";
}

test "set literals answer runtime membership probes" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "set_static_runtime_membership", ctypes.c_int64);
    assert f() == 111 , f"got {f()}";
}

test "literal and runtime spellings address the same slot" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "overwrite_across_paths", ctypes.c_int64);
    # three writes to one key: final value 3, len stays 1
    assert f() == 31 , f"got {f()}";
}

# Native strings are NUL-terminated, so the runtime hash and comparison stop
# at the first NUL - "a\0b" IS "a" at runtime. A compile-time hash spanning
# the full literal would probe a different slot than every runtime operation
# on the same key, so literals with embedded NULs must refuse the prehash and
# fall back to the hashing wrapper.
test "an embedded-NUL literal degrades to the runtime hash" {
    (eng, _) = compile_native("dict_prehash.jac");
    f = get_func(eng, "embedded_nul_key", ctypes.c_int64);
    assert f() == 1 , f"expected runtime-consistent lookup, got {f()}";
}

# ─────────────────────────────────────────────────────────────────────
# Shape: static-key sites call the prehashed cores
# ─────────────────────────────────────────────────────────────────────

test "static-key sites lower to prehashed core calls" {
    (_, ir) = compile_native("dict_prehash.jac");
    llvm_text = str(ir.gen.llvm_ir);
    for marker in ("_set_ph_", "_get_ph_", "_contains_ph_", "_add_ph_") {
        assert marker in llvm_text , (
            f"expected prehashed core '{marker}' at static-key sites"
        );
    }
}

test "the kwargs sink builds through prehashed inserts" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "kwargs_spread.jac")),
        options=native_force_opts()
    );
    assert not prog.errors_had , str([str(e) for e in prog.errors_had]);
    llvm_text = str(ir.gen.llvm_ir);
    assert "_set_ph_" in llvm_text , (
        "expected the sink's literal keyword inserts to use the prehashed core"
    );
}
