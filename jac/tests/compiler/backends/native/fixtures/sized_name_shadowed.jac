"""A module's own definition named like a fixed-width type shadows the cast."""

def u16(data: bytes, at: int) -> int {
    return int(data[at]) | (int(data[at + 1]) << 8);
}

def wrapping_add(a: int, b: int) -> int {
    return a + b + 1000;
}

def shadowed_u16_reads_bytes -> int {
    return u16(b"\x01\x02", 0);
}

def shadowed_wrapping_is_the_module_function -> int {
    return wrapping_add(1, 2);
}

def unshadowed_cast_still_casts -> int {
    return int(u32(7)) + int(i8.wrap(300));
}
