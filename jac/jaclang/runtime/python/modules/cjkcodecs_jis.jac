"""The JIS X 0201 and JIS X 0213:2000 helpers the Japanese and ISO-2022
codecs share: Modules/cjkcodecs/alg_jisx0201.h and emu_jisx0213_2000.h in
native Jac. These routines may be quite inefficient, but it's used only to
emulate old standards. See ../LICENSE.cpython.
"""

glob EMPBASE: int = 0x20000,
     # emu_jisx0213_2000.h's results for a code point JIS X 0213:2000 lacks.
     EMULATE_JISX0213_2000_ENCODE_INVALID: int = 1,
     EMULATE_JISX0213_2000_DECODE_INVALID: int = 2;

# `config` is (void *)2000: the codec emulates JIS X 0213:2000.
def emulates_2000(config: ptr) -> bool {
    return int(config) == 2000;
}

# EMULATE_JISX0213_2000_ENCODE_BMP: -1 when the code point is not in JIS X
# 0213:2000, its code when 2000 maps it differently, else 0 (no emulation).
def emulate_2000_encode_bmp(config: ptr, c: int) -> int {
    if emulates_2000(config)
        and (
            c == 0x9B1C
            or c == 0x4FF1
            or c == 0x525D
            or c == 0x541E
            or c == 0x5653
            or c == 0x59F8
            or c == 0x5C5B
            or c == 0x5E77
            or c == 0x7626
            or c == 0x7E6B
        ) {
        return -1;
    }
    if emulates_2000(config) and c == 0x9B1D {
        return 0x8000 | 0x7D3B;
    }
    return 0;
}

# EMULATE_JISX0213_2000_ENCODE_EMP: whether the code point is not in JIS X
# 0213:2000.
def emulate_2000_encode_emp(config: ptr, c: int) -> bool {
    return emulates_2000(config) and c == 0x20B9F;
}

# EMULATE_JISX0213_2000_DECODE_PLANE1: whether plane 1's c1, c2 is not in
# JIS X 0213:2000.
def emulate_2000_decode_plane1(config: ptr, c1: int, c2: int) -> bool {
    return emulates_2000(config)
        and (
            (c1 == 0x2E and c2 == 0x21)
            or (c1 == 0x2F and c2 == 0x7E)
            or (c1 == 0x4F and c2 == 0x54)
            or (c1 == 0x4F and c2 == 0x7E)
            or (c1 == 0x74 and c2 == 0x27)
            or (c1 == 0x7E and c2 == 0x7A)
            or (c1 == 0x7E and c2 == 0x7B)
            or (c1 == 0x7E and c2 == 0x7C)
            or (c1 == 0x7E and c2 == 0x7D)
            or (c1 == 0x7E and c2 == 0x7E)
        );
}

# EMULATE_JISX0213_2000_DECODE_PLANE2(_CHAR): whether plane 2's c1, c2 is
# 2000's U+9B1D.
def emulate_2000_decode_plane2(config: ptr, c1: int, c2: int) -> bool {
    return emulates_2000(config) and c1 == 0x7D and c2 == 0x3B;
}

# JISX0201_R_ENCODE / JISX0201_K_ENCODE: the JIS X 0201 byte of `c`, or
# -1.
def jisx0201_r_encode(c: int) -> int {
    if c < 0x80 and c != 0x5C and c != 0x7E {
        return c;
    }
    if c == 0x00A5 {
        return 0x5C;
    }
    if c == 0x203E {
        return 0x7E;
    }
    return -1;
}

def jisx0201_k_encode(c: int) -> int {
    if c >= 0xFF61 and c <= 0xFF9F {
        return c - 0xFEC0;
    }
    return -1;
}

# JISX0201_R_DECODE_CHAR / JISX0201_K_DECODE_CHAR: the code point of byte
# `c`, or -1.
def jisx0201_r_decode(c: int) -> int {
    if c < 0x5C {
        return c;
    }
    if c == 0x5C {
        return 0x00A5;
    }
    if c < 0x7E {
        return c;
    }
    if c == 0x7E {
        return 0x203E;
    }
    if c == 0x7F {
        return 0x7F;
    }
    return -1;
}

def jisx0201_k_decode(c: int) -> int {
    if c >= 0xA1 and c <= 0xDF {
        return 0xFEC0 + c;
    }
    return -1;
}
