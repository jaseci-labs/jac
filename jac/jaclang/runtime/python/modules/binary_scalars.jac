"""Endian-aware scalar storage shared by native binary formats and arrays.

Derived from Python 3.14.6; see ../LICENSE.cpython.
"""

def read_bits(address: ptr, size: int, little: bool) -> u64 {
    data = ptr[u8](address);
    bits: u64 = 0;
    if little {
        i = size - 1;
        while i >= 0 {
            bits = wrapping_shl(bits, 8) | u64((data + i).view(1)[0]);
            i -= 1;
        }
        return bits;
    }
    for i in range(size) {
        bits = wrapping_shl(bits, 8) | u64((data + i).view(1)[0]);
    }
    return bits;
}

def write_bits(address: ptr, size: int, little: bool, bits: u64) {
    data = ptr[u8](address);
    if little {
        for i in range(size) {
            (data + i).view(1)[0] = u8(bits & u64(255));
            bits = bits >> u64(8);
        }
        return;
    }
    i = size - 1;
    while i >= 0 {
        (data + i).view(1)[0] = u8(bits & u64(255));
        bits = bits >> u64(8);
        i -= 1;
    }
}

def integer_from_bits(bits: u64, size: int, signed: bool) -> ptr[PyObject] {
    if signed {
        if size < 8 and bits & (u64(1) << i64(size * 8 - 1)) != 0 {
            bits |= wrapping_shl(~u64(0), u64(size * 8));
        }
        value = -i64(~bits) - i64(1) if bits > u64(9223372036854775807) else i64(bits);
        return required(PyLong_FromLongLong(value));
    }
    return required(PyLong_FromUnsignedLongLong(bits));
}
