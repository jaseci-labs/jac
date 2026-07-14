"""`struct` module on the native backend: the canonical, sv-congruent way to
reinterpret bytes as ints/floats and back (#6404).

`struct.unpack` always returns a tuple; `struct.pack` returns length-aware
`bytes`; `struct.calcsize` returns the format's byte width. Every function
returns a scalar for the ctypes harness.
"""

import struct;

def u_u32_le() -> int {
    return struct.unpack("<I", b"\x01\x00\x00\x00")[0];
}

def u_i32_le() -> int {
    return struct.unpack("<i", b"\xff\xff\xff\xff")[0];
}

def u_u32_be() -> int {
    return struct.unpack(">I", b"\x00\x00\x00\x01")[0];
}

def u_i16_le() -> int {
    return struct.unpack("<h", b"\xfe\xff")[0];
}

def u_u16_le() -> int {
    return struct.unpack("<H", b"\x00\x80")[0];
}

def u_u8() -> int {
    return struct.unpack("<B", b"\xff")[0];
}

def u_i8() -> int {
    return struct.unpack("<b", b"\xff")[0];
}

def u_u64_le() -> int {
    return struct.unpack("<Q", b"\x01\x00\x00\x00\x00\x00\x00\x00")[0];
}

def u_two_le() -> int {
    out = struct.unpack("<HH", b"\x01\x00\x02\x00");
    return out[0] * 1000 + out[1];
}

def u_f32() -> float {
    return struct.unpack("<f", struct.pack("<f", 1.5))[0];
}

def u_f64() -> float {
    return struct.unpack("<d", struct.pack("<d", 3.25))[0];
}

def calcsize_mix() -> int {
    return struct.calcsize("<If");
}

def calcsize_pad() -> int {
    return struct.calcsize("<Bxh");
}

def pack_unpack_u32_le() -> int {
    p = struct.pack("<I", 305419896);
    return struct.unpack("<I", p)[0];
}

def pack_unpack_u32_be() -> int {
    p = struct.pack(">I", 305419896);
    return struct.unpack(">I", p)[0];
}

def pack_multi() -> int {
    p = struct.pack("<HH", 7, 9);
    out = struct.unpack("<HH", p);
    return out[0] * 1000 + out[1];
}

def unpack_short_raises() -> int {
    try {
        out = struct.unpack("<I", b"\x01\x02");
        return out[0];
    } except Exception as e {
        return -1;
    }
}
