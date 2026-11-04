"""A global int initialized with a literal in u64 range holds its 64-bit
pattern, as js_engine's tag masks and PCRE2's U64_MAX expect."""

glob WIDE_MASK: int = 0xFFFF_0000_0000_0000,
     ALL_ONES: int = 18446744073709551615,
     HIGH_BIT: int = 0x8000_0000_0000_0000;

def tag_of(v: int) -> int {
    return (v & WIDE_MASK) >> 48;
}

with entry {
    print("mask", WIDE_MASK == -281474976710656, ALL_ONES == -1);
    print("tag", tag_of(WIDE_MASK) & 65535);
    print("high", HIGH_BIT == -9223372036854775807 - 1);
}
