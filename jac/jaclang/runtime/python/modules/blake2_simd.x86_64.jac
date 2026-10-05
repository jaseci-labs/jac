"""BLAKE2 parameter block and HACL*'s vectorized BLAKE2 on x86-64.

configure compiles HACL*'s SIMD128 BLAKE2s and SIMD256 BLAKE2b into
Modules/_hacl/libHacl_Hash_BLAKE2.a here; _blake2 selects them when
jacpy_hacl_simd_features() reports the CPU can run them, as
blake2module.c does.
"""

import from jaclang.runtime.python.cpython_api { jacpy_offset }
import from c {
    obj Hacl_Hash_Blake2b_blake2_params {
        has digest_length: u8 = 0,
            key_length: u8 = 0,
            fanout: u8 = 0,
            depth: u8 = 0,
            leaf_length: u32 = 0,
            node_offset: u64 = 0,
            node_depth: u8 = 0,
            inner_length: u8 = 0,
            salt: ptr = ptr(),
            personal: ptr = ptr();
    }  def _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_malloc_with_params_and_key(
        p: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, k: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_malloc_with_params_and_key(
        p: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, k: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_update(
        state: ptr, chunk: ptr, chunk_len: u32
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_digest(
        s: ptr, dst: ptr
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_digest(
        s: ptr, dst: ptr
    ) -> u8;  def _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_copy(state: ptr) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_copy(
        state: ptr
    ) -> ptr;  def _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_free(state: ptr);  def _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_free(
        state: ptr
    );
}

glob:priv UINT32_MAX: i64 = 0xFFFFFFFF;

def simd128_malloc(
    params: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, key: ptr
) -> ptr {
    return _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_malloc_with_params_and_key(
        params, last_node, key
    );
}

def simd256_malloc(
    params: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, key: ptr
) -> ptr {
    return _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_malloc_with_params_and_key(
        params, last_node, key
    );
}

def simd128_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor = jacpy_offset(cursor, UINT32_MAX);
    }
    _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_update(hacl, cursor, u32(remaining));
}

def simd256_update(hacl: ptr, address: ptr, size: i64) {
    remaining = size;
    cursor = address;
    while remaining > UINT32_MAX {
        _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_update(hacl, cursor, u32(UINT32_MAX));
        remaining -= UINT32_MAX;
        cursor = jacpy_offset(cursor, UINT32_MAX);
    }
    _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_update(hacl, cursor, u32(remaining));
}

def simd128_digest(hacl: ptr, output: ptr) -> i64 {
    return i64(_Py_LibHacl_Hacl_Hash_Blake2s_Simd128_digest(hacl, output));
}

def simd256_digest(hacl: ptr, output: ptr) -> i64 {
    return i64(_Py_LibHacl_Hacl_Hash_Blake2b_Simd256_digest(hacl, output));
}

def simd128_copy(hacl: ptr) -> ptr {
    return _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_copy(hacl);
}

def simd256_copy(hacl: ptr) -> ptr {
    return _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_copy(hacl);
}

def simd128_free(hacl: ptr) {
    _Py_LibHacl_Hacl_Hash_Blake2s_Simd128_free(hacl);
}

def simd256_free(hacl: ptr) {
    _Py_LibHacl_Hacl_Hash_Blake2b_Simd256_free(hacl);
}
