"""Compile-time hashing of static container keys.

A string key that is a compile-time literal has a compile-time-computable
hash, so a dict/set operation on it need not hash it again at runtime. The
compile-time hash must byte-for-byte agree with the runtime hash function,
which the fixture checks by round-tripping keys between literal and
runtime-concatenated spellings - a divergence turns lookups into misses.
"""

import ctypes;
import from tests.support { compile_native, get_func }

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
