"""Endian-aware scalar storage shared by native binary formats and arrays.

Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_memory_byte,
    jacpy_memory_set,
    jacpy_int,
    jacpy_uint,
    required
}

def read_bits(address: u64, size: int, little: bool) -> u64 {
    bits: u64 = 0;
    for i in range(size) {
        shift = (i if little else size - 1 - i) * 8;
        bits |= u64(jacpy_memory_byte(address, i64(i))) << i64(shift);
    }
    return bits;
}

def write_bits(address: u64, size: int, little: bool, bits: u64) {
    for i in range(size) {
        shift = (i if little else size - 1 - i) * 8;
        jacpy_memory_set(address, i64(i), i64((bits >> i64(shift)) & u64(255)));
    }
}

def integer_from_bits(bits: u64, size: int, signed: bool) -> u64 {
    if signed {
        if size < 8 and bits & (u64(1) << i64(size * 8 - 1)) != 0 {
            bits |= wrapping_shl(~u64(0), u64(size * 8));
        }
        value = -i64(~bits) - i64(1) if bits > u64(9223372036854775807) else i64(bits);
        return required(jacpy_int(value));
    }
    return required(jacpy_uint(bits));
}
