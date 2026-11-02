"""BLAKE2 parameter block and HACL*'s vectorized BLAKE2, off x86-64.

HACL* compiles its SIMD128 BLAKE2s and SIMD256 BLAKE2b only for x86-64
(blake2_simd.x86_64.jac); jacpy_hacl_simd_features() is 0 everywhere else, so
_blake2 never selects them and these entry points are never reached.
"""

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
    }
}

def simd128_malloc(
    params: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, key: ptr
) -> ptr {
    return ptr();
}

def simd256_malloc(
    params: &mut Pinned[Hacl_Hash_Blake2b_blake2_params], last_node: i32, key: ptr
) -> ptr {
    return ptr();
}

def simd128_update(hacl: ptr, address: ptr, size: i64) {}

def simd256_update(hacl: ptr, address: ptr, size: i64) {}

def simd128_digest(hacl: ptr, output: ptr) -> i64 {
    return 0;
}

def simd256_digest(hacl: ptr, output: ptr) -> i64 {
    return 0;
}

def simd128_copy(hacl: ptr) -> ptr {
    return ptr();
}

def simd256_copy(hacl: ptr) -> ptr {
    return ptr();
}

def simd128_free(hacl: ptr) {}

def simd256_free(hacl: ptr) {}
