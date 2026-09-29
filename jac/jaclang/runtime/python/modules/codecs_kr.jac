"""The _codecs_kr module: Modules/cjkcodecs/_codecs_kr.c (Korean encodings:
euc_kr, cp949 and johab) in native Jac. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.modules.cjkcodecs {
    DecodeWriter,
    MBERR_EXCEPTION,
    MBERR_TOOFEW,
    MBERR_TOOSMALL,
    MultibyteCodec,
    MultibyteCodec_State,
    NOCHAR,
    UNIINV,
    getcodec,
    inbyte,
    inchar,
    map_decode,
    map_encode,
    next_in,
    next_inchar,
    next_out,
    no_codec_init,
    no_decode_reset,
    no_encode_reset,
    no_state_init,
    outbyte,
    outchar,
    register_maps
}
import from jaclang.runtime.python.modules.cjkcodecs_mappings_kr {
    CJK_KR_MAPPINGS,
    cjk_cp949_map,
    cjk_cp949ext_map,
    cjk_kr_mappings,
    cjk_ksx1001_map
}

# EUC-KR codec

glob:priv EUCKR_JAMO_FIRSTBYTE: int = 0xA4,
     EUCKR_JAMO_FILLER: int = 0xD4,
     # cgk2u_choseong / cgk2u_jongseong's "no jamo"
     CGK_NONE: int = 127,
     # johab tables' fill and "no jamo" entries
     JOHAB_FILL: int = 0xFD,
     JOHAB_NONE: int = 0xFF;

import from c {
    glob:priv u2cgk_choseong: list[u8] = [
             u8(0xA1),
             u8(0xA2),
             u8(0xA4),
             u8(0xA7),
             u8(0xA8),
             u8(0xA9),
             u8(0xB1),
             u8(0xB2),
             u8(0xB3),
             u8(0xB5),
             u8(0xB6),
             u8(0xB7),
             u8(0xB8),
             u8(0xB9),
             u8(0xBA),
             u8(0xBB),
             u8(0xBC),
             u8(0xBD),
             u8(0xBE)
         ],
         u2cgk_jungseong: list[u8] = [
             u8(0xBF),
             u8(0xC0),
             u8(0xC1),
             u8(0xC2),
             u8(0xC3),
             u8(0xC4),
             u8(0xC5),
             u8(0xC6),
             u8(0xC7),
             u8(0xC8),
             u8(0xC9),
             u8(0xCA),
             u8(0xCB),
             u8(0xCC),
             u8(0xCD),
             u8(0xCE),
             u8(0xCF),
             u8(0xD0),
             u8(0xD1),
             u8(0xD2),
             u8(0xD3)
         ],
         u2cgk_jongseong: list[u8] = [
             u8(0xD4),
             u8(0xA1),
             u8(0xA2),
             u8(0xA3),
             u8(0xA4),
             u8(0xA5),
             u8(0xA6),
             u8(0xA7),
             u8(0xA9),
             u8(0xAA),
             u8(0xAB),
             u8(0xAC),
             u8(0xAD),
             u8(0xAE),
             u8(0xAF),
             u8(0xB0),
             u8(0xB1),
             u8(0xB2),
             u8(0xB4),
             u8(0xB5),
             u8(0xB6),
             u8(0xB7),
             u8(0xB8),
             u8(0xBA),
             u8(0xBB),
             u8(0xBC),
             u8(0xBD),
             u8(0xBE)
         ],
         # [A1, BE]
         cgk2u_choseong: list[u8] = [
             u8(0),
             u8(1),
             u8(127),
             u8(2),
             u8(127),
             u8(127),
             u8(3),
             u8(4),
             u8(5),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(127),
             u8(6),
             u8(7),
             u8(8),
             u8(127),
             u8(9),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(18)
         ],
         # [A1, BE]
         cgk2u_jongseong: list[u8] = [
             u8(1),
             u8(2),
             u8(3),
             u8(4),
             u8(5),
             u8(6),
             u8(7),
             u8(127),
             u8(8),
             u8(9),
             u8(10),
             u8(11),
             u8(12),
             u8(13),
             u8(14),
             u8(15),
             u8(16),
             u8(17),
             u8(127),
             u8(18),
             u8(19),
             u8(20),
             u8(21),
             u8(22),
             u8(127),
             u8(23),
             u8(24),
             u8(25),
             u8(26),
             u8(27)
         ],
         # JOHAB codec
         u2johabidx_choseong: list[u8] = [
             u8(0x02),
             u8(0x03),
             u8(0x04),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x08),
             u8(0x09),
             u8(0x0A),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x10),
             u8(0x11),
             u8(0x12),
             u8(0x13),
             u8(0x14)
         ],
         u2johabidx_jungseong: list[u8] = [
             u8(0x03),
             u8(0x04),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x0A),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x12),
             u8(0x13),
             u8(0x14),
             u8(0x15),
             u8(0x16),
             u8(0x17),
             u8(0x1A),
             u8(0x1B),
             u8(0x1C),
             u8(0x1D)
         ],
         u2johabidx_jongseong: list[u8] = [
             u8(0x01),
             u8(0x02),
             u8(0x03),
             u8(0x04),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x08),
             u8(0x09),
             u8(0x0A),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x10),
             u8(0x11),
             u8(0x13),
             u8(0x14),
             u8(0x15),
             u8(0x16),
             u8(0x17),
             u8(0x18),
             u8(0x19),
             u8(0x1A),
             u8(0x1B),
             u8(0x1C),
             u8(0x1D)
         ],
         u2johabjamo: list[u16] = [
             u16(0x8841),
             u16(0x8C41),
             u16(0x8444),
             u16(0x9041),
             u16(0x8446),
             u16(0x8447),
             u16(0x9441),
             u16(0x9841),
             u16(0x9C41),
             u16(0x844A),
             u16(0x844B),
             u16(0x844C),
             u16(0x844D),
             u16(0x844E),
             u16(0x844F),
             u16(0x8450),
             u16(0xA041),
             u16(0xA441),
             u16(0xA841),
             u16(0x8454),
             u16(0xAC41),
             u16(0xB041),
             u16(0xB441),
             u16(0xB841),
             u16(0xBC41),
             u16(0xC041),
             u16(0xC441),
             u16(0xC841),
             u16(0xCC41),
             u16(0xD041),
             u16(0x8461),
             u16(0x8481),
             u16(0x84A1),
             u16(0x84C1),
             u16(0x84E1),
             u16(0x8541),
             u16(0x8561),
             u16(0x8581),
             u16(0x85A1),
             u16(0x85C1),
             u16(0x85E1),
             u16(0x8641),
             u16(0x8661),
             u16(0x8681),
             u16(0x86A1),
             u16(0x86C1),
             u16(0x86E1),
             u16(0x8741),
             u16(0x8761),
             u16(0x8781),
             u16(0x87A1)
         ],
         # 0xFD is FILL and 0xFF NONE in the johab tables below.
         johabidx_choseong: list[u8] = [
             u8(0xFF),
             u8(0xFD),
             u8(0x00),
             u8(0x01),
             u8(0x02),
             u8(0x03),
             u8(0x04),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x08),
             u8(0x09),
             u8(0x0A),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x10),
             u8(0x11),
             u8(0x12),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF)
         ],
         johabidx_jungseong: list[u8] = [
             u8(0xFF),
             u8(0xFF),
             u8(0xFD),
             u8(0x00),
             u8(0x01),
             u8(0x02),
             u8(0x03),
             u8(0x04),
             u8(0xFF),
             u8(0xFF),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x08),
             u8(0x09),
             u8(0x0A),
             u8(0xFF),
             u8(0xFF),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x10),
             u8(0xFF),
             u8(0xFF),
             u8(0x11),
             u8(0x12),
             u8(0x13),
             u8(0x14),
             u8(0xFF),
             u8(0xFF)
         ],
         johabidx_jongseong: list[u8] = [
             u8(0xFF),
             u8(0xFD),
             u8(0x01),
             u8(0x02),
             u8(0x03),
             u8(0x04),
             u8(0x05),
             u8(0x06),
             u8(0x07),
             u8(0x08),
             u8(0x09),
             u8(0x0A),
             u8(0x0B),
             u8(0x0C),
             u8(0x0D),
             u8(0x0E),
             u8(0x0F),
             u8(0x10),
             u8(0xFF),
             u8(0x11),
             u8(0x12),
             u8(0x13),
             u8(0x14),
             u8(0x15),
             u8(0x16),
             u8(0x17),
             u8(0x18),
             u8(0x19),
             u8(0x1A),
             u8(0x1B),
             u8(0xFF),
             u8(0xFF)
         ],
         johabjamo_choseong: list[u8] = [
             u8(0xFF),
             u8(0xFD),
             u8(0x31),
             u8(0x32),
             u8(0x34),
             u8(0x37),
             u8(0x38),
             u8(0x39),
             u8(0x41),
             u8(0x42),
             u8(0x43),
             u8(0x45),
             u8(0x46),
             u8(0x47),
             u8(0x48),
             u8(0x49),
             u8(0x4A),
             u8(0x4B),
             u8(0x4C),
             u8(0x4D),
             u8(0x4E),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF),
             u8(0xFF)
         ],
         johabjamo_jungseong: list[u8] = [
             u8(0xFF),
             u8(0xFF),
             u8(0xFD),
             u8(0x4F),
             u8(0x50),
             u8(0x51),
             u8(0x52),
             u8(0x53),
             u8(0xFF),
             u8(0xFF),
             u8(0x54),
             u8(0x55),
             u8(0x56),
             u8(0x57),
             u8(0x58),
             u8(0x59),
             u8(0xFF),
             u8(0xFF),
             u8(0x5A),
             u8(0x5B),
             u8(0x5C),
             u8(0x5D),
             u8(0x5E),
             u8(0x5F),
             u8(0xFF),
             u8(0xFF),
             u8(0x60),
             u8(0x61),
             u8(0x62),
             u8(0x63),
             u8(0xFF),
             u8(0xFF)
         ],
         johabjamo_jongseong: list[u8] = [
             u8(0xFF),
             u8(0xFD),
             u8(0x31),
             u8(0x32),
             u8(0x33),
             u8(0x34),
             u8(0x35),
             u8(0x36),
             u8(0x37),
             u8(0x39),
             u8(0x3A),
             u8(0x3B),
             u8(0x3C),
             u8(0x3D),
             u8(0x3E),
             u8(0x3F),
             u8(0x40),
             u8(0x41),
             u8(0xFF),
             u8(0x42),
             u8(0x44),
             u8(0x45),
             u8(0x46),
             u8(0x47),
             u8(0x48),
             u8(0x4A),
             u8(0x4B),
             u8(0x4C),
             u8(0x4D),
             u8(0x4E),
             u8(0xFF),
             u8(0xFF)
         ];
}

def:priv table_byte(table: ptr[u8], index: int) -> int {
    return int((table + index).view(1)[0]);
}

def euc_kr_encode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    kind: i32,
    data: ptr,
    inpos: ptr[i64],
    inlen: i64,
    outbuf: ptr[ptr[u8]],
    outleft: i64,
    flags: i32
) -> i64 {
    while inpos.view(1)[0] < inlen {
        c = inchar(kind, data, inpos, 0);
        if c < 0x80 {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        }
        if c > 0xFFFF {
            return 1;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        code = map_encode(addressof(cjk_cp949_map), c);
        if code == NOCHAR {
            return 1;
        }
        if (code & 0x8000) == 0 {
            # KS X 1001 coded character
            outbyte(outbuf, 0, (code >> 8) | 0x80);
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
            next_inchar(inpos, 1);
            next_out(outbuf, 2);
            outleft -= 2;
        } else {
            # Mapping is found in CP949 extension,
            # but we encode it in KS X 1001:1998,
            # make-up sequence for EUC-KR.
            if outleft < 8 {
                return MBERR_TOOSMALL;
            }
            # syllable composition precedence
            outbyte(outbuf, 0, EUCKR_JAMO_FIRSTBYTE);
            outbyte(outbuf, 1, EUCKR_JAMO_FILLER);
            # All code points in CP949 extension are in unicode
            # Hangul Syllable area.
            c -= 0xAC00;
            outbyte(outbuf, 2, EUCKR_JAMO_FIRSTBYTE);
            outbyte(outbuf, 3, table_byte(addressof(u2cgk_choseong), c // 588));
            next_out(outbuf, 4);
            outleft -= 4;
            outbyte(outbuf, 0, EUCKR_JAMO_FIRSTBYTE);
            outbyte(outbuf, 1, table_byte(addressof(u2cgk_jungseong), (c // 28) % 21));
            outbyte(outbuf, 2, EUCKR_JAMO_FIRSTBYTE);
            outbyte(outbuf, 3, table_byte(addressof(u2cgk_jongseong), c % 28));
            next_inchar(inpos, 1);
            next_out(outbuf, 4);
            outleft -= 4;
        }
    }
    return 0;
}

def euc_kr_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c < 0x80 {
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            continue;
        }
        if inleft < 2 {
            return MBERR_TOOFEW;
        }
        if c == EUCKR_JAMO_FIRSTBYTE and inbyte(inbuf, 1) == EUCKR_JAMO_FILLER {
            # KS X 1001:1998 make-up sequence
            if inleft < 8 {
                return MBERR_TOOFEW;
            }
            if inbyte(inbuf, 2) != EUCKR_JAMO_FIRSTBYTE
                or inbyte(inbuf, 4) != EUCKR_JAMO_FIRSTBYTE
                or inbyte(inbuf, 6) != EUCKR_JAMO_FIRSTBYTE {
                return 1;
            }
            c = inbyte(inbuf, 3);
            cho = table_byte(addressof(cgk2u_choseong), c - 0xA1)
                if 0xA1 <= c and c <= 0xBE
                else CGK_NONE;
            c = inbyte(inbuf, 5);
            jung = c - 0xBF if 0xBF <= c and c <= 0xD3 else CGK_NONE;
            c = inbyte(inbuf, 7);
            jong = CGK_NONE;
            if c == EUCKR_JAMO_FILLER {
                jong = 0;
            } elif 0xA1 <= c and c <= 0xBE {
                jong = table_byte(addressof(cgk2u_jongseong), c - 0xA1);
            }
            if cho == CGK_NONE or jung == CGK_NONE or jong == CGK_NONE {
                return 1;
            }
            if not outchar(writer, 0xAC00 + cho * 588 + jung * 28 + jong) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 8);
            inleft -= 8;
        } else {
            decoded = map_decode(
                addressof(cjk_ksx1001_map), c ^ 0x80, inbyte(inbuf, 1) ^ 0x80
            );
            if decoded == UNIINV {
                return 1;
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 2);
            inleft -= 2;
        }
    }
    return 0;
}

# CP949 codec

def cp949_encode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    kind: i32,
    data: ptr,
    inpos: ptr[i64],
    inlen: i64,
    outbuf: ptr[ptr[u8]],
    outleft: i64,
    flags: i32
) -> i64 {
    while inpos.view(1)[0] < inlen {
        c = inchar(kind, data, inpos, 0);
        if c < 0x80 {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        }
        if c > 0xFFFF {
            return 1;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        code = map_encode(addressof(cjk_cp949_map), c);
        if code == NOCHAR {
            return 1;
        }
        outbyte(outbuf, 0, (code >> 8) | 0x80);
        if (code & 0x8000) != 0 {
            # MSB set: CP949
            outbyte(outbuf, 1, code & 0xFF);
        } else {
            # MSB unset: ks x 1001
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
        }
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def cp949_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c < 0x80 {
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            continue;
        }
        if inleft < 2 {
            return MBERR_TOOFEW;
        }
        c2 = inbyte(inbuf, 1);
        decoded = map_decode(addressof(cjk_ksx1001_map), c ^ 0x80, c2 ^ 0x80);
        if decoded == UNIINV {
            decoded = map_decode(addressof(cjk_cp949ext_map), c, c2);
            if decoded == UNIINV {
                return 1;
            }
        }
        if not outchar(writer, decoded) {
            return MBERR_EXCEPTION;
        }
        next_in(inbuf, 2);
        inleft -= 2;
    }
    return 0;
}

# JOHAB codec

def johab_encode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    kind: i32,
    data: ptr,
    inpos: ptr[i64],
    inlen: i64,
    outbuf: ptr[ptr[u8]],
    outleft: i64,
    flags: i32
) -> i64 {
    while inpos.view(1)[0] < inlen {
        c = inchar(kind, data, inpos, 0);
        if c < 0x80 {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        }
        if c > 0xFFFF {
            return 1;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        code = 0;
        if c >= 0xAC00 and c <= 0xD7A3 {
            c -= 0xAC00;
            code = 0x8000
                | (table_byte(addressof(u2johabidx_choseong), c // 588) << 10)
                | (table_byte(addressof(u2johabidx_jungseong), (c // 28) % 21) << 5)
                | table_byte(addressof(u2johabidx_jongseong), c % 28);
        } elif c >= 0x3131 and c <= 0x3163 {
            code = int((addressof(u2johabjamo) + (c - 0x3131)).view(1)[0]);
        } else {
            code = map_encode(addressof(cjk_cp949_map), c);
            if code == NOCHAR {
                return 1;
            }
            c1 = code >> 8;
            c2 = code & 0xFF;
            if ((c1 >= 0x21 and c1 <= 0x2C) or (c1 >= 0x4A and c1 <= 0x7D))
                and (c2 >= 0x21 and c2 <= 0x7E) {
                t1 = (c1 - 0x21 + 0x1B2) if c1 < 0x4A else (c1 - 0x21 + 0x197);
                t2 = ((0x5E if (t1 & 1) != 0 else 0) + (c2 - 0x21)) & 0xFF;
                outbyte(outbuf, 0, t1 >> 1);
                outbyte(outbuf, 1, t2 + 0x31 if t2 < 0x4E else t2 + 0x43);
                next_inchar(inpos, 1);
                next_out(outbuf, 2);
                outleft -= 2;
                continue;
            }
            return 1;
        }
        outbyte(outbuf, 0, code >> 8);
        outbyte(outbuf, 1, code & 0xFF);
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def johab_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c < 0x80 {
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            continue;
        }
        if inleft < 2 {
            return MBERR_TOOFEW;
        }
        c2 = inbyte(inbuf, 1);
        if c < 0xD8 {
            # johab hangul
            c_cho = (c >> 2) & 0x1F;
            c_jung = ((c << 3) | (c2 >> 5)) & 0x1F;
            c_jong = c2 & 0x1F;
            i_cho = table_byte(addressof(johabidx_choseong), c_cho);
            i_jung = table_byte(addressof(johabidx_jungseong), c_jung);
            i_jong = table_byte(addressof(johabidx_jongseong), c_jong);
            if i_cho == JOHAB_NONE or i_jung == JOHAB_NONE or i_jong == JOHAB_NONE {
                return 1;
            }
            decoded = 0;
            # we don't use U+1100 hangul jamo yet.
            if i_cho == JOHAB_FILL {
                if i_jung == JOHAB_FILL {
                    if i_jong == JOHAB_FILL {
                        decoded = 0x3000;
                    } else {
                        decoded = 0x3100
                            | table_byte(addressof(johabjamo_jongseong), c_jong);
                    }
                } elif i_jong == JOHAB_FILL {
                    decoded = 0x3100
                        | table_byte(addressof(johabjamo_jungseong), c_jung);
                } else {
                    return 1;
                }
            } elif i_jung == JOHAB_FILL {
                if i_jong == JOHAB_FILL {
                    decoded = 0x3100 | table_byte(addressof(johabjamo_choseong), c_cho);
                } else {
                    return 1;
                }
            } else {
                decoded = 0xAC00
                    + i_cho * 588
                    + i_jung * 28
                    + (0 if i_jong == JOHAB_FILL else i_jong);
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 2);
            inleft -= 2;
        } else {
            # KS X 1001 except hangul jamos and syllables
            if c == 0xDF
                or c > 0xF9
                or c2 < 0x31
                or (c2 >= 0x80 and c2 < 0x91)
                or (c2 & 0x7F) == 0x7F
                or (c == 0xDA and (c2 >= 0xA1 and c2 <= 0xD3)) {
                return 1;
            }
            # unsigned char arithmetic, as C does it
            t1 = (2 * (c - 0xD9) if c < 0xE0 else 2 * c - 0x197) & 0xFF;
            t2 = (c2 - 0x31 if c2 < 0x91 else c2 - 0x43) & 0xFF;
            t1 = (t1 + (0 if t2 < 0x5E else 1) + 0x21) & 0xFF;
            t2 = ((t2 if t2 < 0x5E else t2 - 0x5E) + 0x21) & 0xFF;
            decoded = map_decode(addressof(cjk_ksx1001_map), t1, t2);
            if decoded == UNIINV {
                return 1;
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 2);
            inleft -= 2;
        }
    }
    return 0;
}

import from c {
    glob kr_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("euc_kr"),
                 codecinit=no_codec_init,
                 encode=euc_kr_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=euc_kr_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("cp949"),
                 codecinit=no_codec_init,
                 encode=cp949_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=cp949_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("johab"),
                 codecinit=no_codec_init,
                 encode=johab_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=johab_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             )
         ];
}

def codecs_kr_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(kr_codecs), 3, encoding);
}

def codecs_kr_exec(module: ptr[PyObject]) -> i32 {
    return register_maps(module, addressof(cjk_kr_mappings), CJK_KR_MAPPINGS);
}
