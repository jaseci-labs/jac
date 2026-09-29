"""The _codecs_jp module: Modules/cjkcodecs/_codecs_jp.c (Japanese
encodings: shift_jis, cp932, euc_jp, shift_jis_2004, euc_jis_2004,
euc_jisx0213 and shift_jisx0213) in native Jac, with alg_jisx0201.h and
emu_jisx0213_2000.h. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.modules.cjkcodecs {
    DBCINV,
    DecodeWriter,
    MBENC_FLUSH,
    MBERR_EXCEPTION,
    MBERR_TOOFEW,
    MBERR_TOOSMALL,
    MULTIC,
    MultibyteCodec,
    MultibyteCodec_State,
    NOCHAR,
    UNIINV,
    find_pairencmap,
    getcodec,
    inbyte,
    inchar,
    map_decode,
    map_decode_wide,
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
    outchar2,
    register_maps
}
import from jaclang.runtime.python.modules.cjkcodecs_jis {
    EMPBASE,
    EMULATE_JISX0213_2000_DECODE_INVALID,
    EMULATE_JISX0213_2000_ENCODE_INVALID,
    emulate_2000_decode_plane1,
    emulate_2000_decode_plane2,
    emulate_2000_encode_bmp,
    emulate_2000_encode_emp,
    jisx0201_k_decode,
    jisx0201_k_encode,
    jisx0201_r_decode,
    jisx0201_r_encode
}
import from jaclang.runtime.python.modules.cjkcodecs_mappings_jp {
    CJK_JP_MAPPINGS,
    JISX0213_ENCPAIRS,
    cjk_cp932ext_map,
    cjk_jisx0208_map,
    cjk_jisx0212_map,
    cjk_jisx0213_1_bmp_map,
    cjk_jisx0213_1_emp_map,
    cjk_jisx0213_2_bmp_map,
    cjk_jisx0213_2_emp_map,
    cjk_jisx0213_bmp_map,
    cjk_jisx0213_emp_map,
    cjk_jisx0213_pair_encmap,
    cjk_jisx0213_pair_map,
    cjk_jisxcommon_map,
    cjk_jp_mappings
}

def:priv pair_code(body: int, modifier: int) -> int {
    return find_pairencmap(
        body, modifier, addressof(cjk_jisx0213_pair_encmap), JISX0213_ENCPAIRS
    );
}

# CP932 codec

def cp932_encode(
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
        if c <= 0x80 {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        } elif c >= 0xFF61 and c <= 0xFF9F {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c - 0xFEC0);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        } elif c >= 0xF8F0 and c <= 0xF8F3 {
            # Windows compatibility
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            if c == 0xF8F0 {
                outbyte(outbuf, 0, 0xA0);
            } else {
                outbyte(outbuf, 0, c - 0xF8F1 + 0xFD);
            }
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
        code = map_encode(addressof(cjk_cp932ext_map), c);
        if code != NOCHAR {
            outbyte(outbuf, 0, code >> 8);
            outbyte(outbuf, 1, code & 0xFF);
        } else {
            code = map_encode(addressof(cjk_jisxcommon_map), c);
            if code != NOCHAR {
                # MSB set: JIS X 0212
                if (code & 0x8000) != 0 {
                    return 1;
                }
                # JIS X 0208
                c1 = code >> 8;
                c2 = code & 0xFF;
                c2 = ((0x5E if ((c1 - 0x21) & 1) != 0 else 0) + (c2 - 0x21)) & 0xFF;
                c1 = ((c1 - 0x21) >> 1) & 0xFF;
                outbyte(outbuf, 0, c1 + 0x81 if c1 < 0x1F else c1 + 0xC1);
                outbyte(outbuf, 1, c2 + 0x40 if c2 < 0x3F else c2 + 0x41);
            } elif c >= 0xE000 and c < 0xE758 {
                # User-defined area
                c1 = (c - 0xE000) // 188;
                c2 = (c - 0xE000) % 188;
                outbyte(outbuf, 0, c1 + 0xF0);
                outbyte(outbuf, 1, c2 + 0x40 if c2 < 0x3F else c2 + 0x41);
            } else {
                return 1;
            }
        }
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def cp932_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c <= 0x80 {
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            continue;
        } elif c >= 0xA0 and c <= 0xDF {
            # half-width katakana
            if not outchar(writer, 0xF8F0 if c == 0xA0 else 0xFEC0 + c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            continue;
        } elif c >= 0xFD {
            # Windows compatibility
            if not outchar(writer, 0xF8F1 - 0xFD + c) {
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
        decoded = map_decode(addressof(cjk_cp932ext_map), c, c2);
        if decoded == UNIINV {
            if (c >= 0x81 and c <= 0x9F) or (c >= 0xE0 and c <= 0xEA) {
                if c2 < 0x40 or (c2 > 0x7E and c2 < 0x80) or c2 > 0xFC {
                    return 1;
                }
                c = (c - 0x81 if c < 0xE0 else c - 0xC1) & 0xFF;
                c2 = (c2 - 0x40 if c2 < 0x80 else c2 - 0x41) & 0xFF;
                c = (2 * c + (0 if c2 < 0x5E else 1) + 0x21) & 0xFF;
                c2 = ((c2 if c2 < 0x5E else c2 - 0x5E) + 0x21) & 0xFF;
                decoded = map_decode(addressof(cjk_jisx0208_map), c, c2);
                if decoded == UNIINV {
                    return 1;
                }
            } elif c >= 0xF0 and c <= 0xF9 {
                if (c2 >= 0x40 and c2 <= 0x7E) or (c2 >= 0x80 and c2 <= 0xFC) {
                    decoded = 0xE000
                        + 188 * (c - 0xF0)
                        + (c2 - 0x40 if c2 < 0x80 else c2 - 0x41);
                } else {
                    return 1;
                }
            } else {
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

# The JIS X 0213 BMP code of `c`, looking at the next character for a
# combining pair: (code, insize), code -1 for "return 1", -2 for
# MBERR_TOOFEW, NOCHAR when the BMP map has no entry.
def:priv jisx0213_bmp_code(
    kind: i32, data: ptr, inpos: ptr[i64], inlen: i64, flags: i32, c: int
) -> tuple[int, int] {
    code = map_encode(addressof(cjk_jisx0213_bmp_map), c);
    if code != MULTIC {
        return (code, 1);
    }
    if inlen - inpos.view(1)[0] < 2 {
        if (flags & MBENC_FLUSH) != 0 {
            code = pair_code(c, 0);
            return (-1 if code == DBCINV else code, 1);
        }
        return (-2, 1);
    }
    c2 = inchar(kind, data, inpos, 1);
    code = pair_code(c, c2);
    if code == DBCINV {
        code = pair_code(c, 0);
        return (-1 if code == DBCINV else code, 1);
    }
    # Don't consume null char as part of pair
    return (code, 2 if c2 != 0 else 1);
}

# EUC-JIS-2004 codec

def euc_jis_2004_encode(
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
    config = codec.view(1)[0].config;
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
        insize = 1;
        code = 0;
        if c <= 0xFFFF {
            emulated = emulate_2000_encode_bmp(config, c);
            if emulated == -1 {
                return EMULATE_JISX0213_2000_ENCODE_INVALID;
            }
            if emulated != 0 {
                code = emulated;
            } else {
                (code, insize) = jisx0213_bmp_code(kind, data, inpos, inlen, flags, c);
                if code == -1 {
                    return 1;
                }
                if code == -2 {
                    return MBERR_TOOFEW;
                }
                if code == NOCHAR {
                    code = map_encode(addressof(cjk_jisxcommon_map), c);
                }
                if code == NOCHAR {
                    if c >= 0xFF61 and c <= 0xFF9F {
                        # JIS X 0201 half-width katakana
                        if outleft < 2 {
                            return MBERR_TOOSMALL;
                        }
                        outbyte(outbuf, 0, 0x8E);
                        outbyte(outbuf, 1, c - 0xFEC0);
                        next_inchar(inpos, 1);
                        next_out(outbuf, 2);
                        outleft -= 2;
                        continue;
                    } elif c == 0xFF3C {
                        # F/W REVERSE SOLIDUS (see NOTES)
                        code = 0x2140;
                    } elif c == 0xFF5E {
                        # F/W TILDE (see NOTES)
                        code = 0x2232;
                    } else {
                        return 1;
                    }
                }
            }
        } elif (c >> 16) == (EMPBASE >> 16) {
            if emulate_2000_encode_emp(config, c) {
                return EMULATE_JISX0213_2000_ENCODE_INVALID;
            }
            code = map_encode(addressof(cjk_jisx0213_emp_map), c & 0xFFFF);
            if code == NOCHAR {
                return insize;
            }
        } else {
            return insize;
        }
        if (code & 0x8000) != 0 {
            # Codeset 2
            if outleft < 3 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, 0x8F);
            outbyte(outbuf, 1, code >> 8);
            outbyte(outbuf, 2, (code & 0xFF) | 0x80);
            next_inchar(inpos, insize);
            next_out(outbuf, 3);
            outleft -= 3;
        } else {
            # Codeset 1
            if outleft < 2 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, (code >> 8) | 0x80);
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
            next_inchar(inpos, insize);
            next_out(outbuf, 2);
            outleft -= 2;
        }
    }
    return 0;
}

def euc_jis_2004_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    config = codec.view(1)[0].config;
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
        if c == 0x8E {
            # JIS X 0201 half-width katakana
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            if c2 >= 0xA1 and c2 <= 0xDF {
                if not outchar(writer, 0xFEC0 + c2) {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, 2);
                inleft -= 2;
            } else {
                return 1;
            }
        } elif c == 0x8F {
            if inleft < 3 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1) ^ 0x80;
            c3 = inbyte(inbuf, 2) ^ 0x80;
            # JIS X 0213 Plane 2 or JIS X 0212 (see NOTES)
            decoded = UNIINV;
            if emulate_2000_decode_plane2(config, c2, c3) {
                decoded = 0x9B1D;
            } else {
                decoded = map_decode(addressof(cjk_jisx0213_2_bmp_map), c2, c3);
                if decoded == UNIINV {
                    code = map_decode(addressof(cjk_jisx0213_2_emp_map), c2, c3);
                    if code != UNIINV {
                        decoded = EMPBASE | code;
                    } else {
                        decoded = map_decode(addressof(cjk_jisx0212_map), c2, c3);
                        if decoded == UNIINV {
                            return 1;
                        }
                    }
                }
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 3);
            inleft -= 3;
        } else {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c = c ^ 0x80;
            c2 = inbyte(inbuf, 1) ^ 0x80;
            # JIS X 0213 Plane 1
            if emulate_2000_decode_plane1(config, c, c2) {
                return EMULATE_JISX0213_2000_DECODE_INVALID;
            }
            decoded = UNIINV;
            if c == 0x21 and c2 == 0x40 {
                decoded = 0xFF3C;
            } elif c == 0x22 and c2 == 0x32 {
                decoded = 0xFF5E;
            } else {
                decoded = map_decode(addressof(cjk_jisx0208_map), c, c2);
                if decoded == UNIINV {
                    decoded = map_decode(addressof(cjk_jisx0213_1_bmp_map), c, c2);
                }
                if decoded == UNIINV {
                    code = map_decode(addressof(cjk_jisx0213_1_emp_map), c, c2);
                    if code != UNIINV {
                        decoded = EMPBASE | code;
                    } else {
                        code = map_decode_wide(addressof(cjk_jisx0213_pair_map), c, c2);
                        if code == UNIINV {
                            return 1;
                        }
                        if not outchar2(writer, code >> 16, code & 0xFFFF) {
                            return MBERR_EXCEPTION;
                        }
                        next_in(inbuf, 2);
                        inleft -= 2;
                        continue;
                    }
                }
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

# EUC-JP codec

def euc_jp_encode(
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
        code = map_encode(addressof(cjk_jisxcommon_map), c);
        if code == NOCHAR {
            if c >= 0xFF61 and c <= 0xFF9F {
                # JIS X 0201 half-width katakana
                if outleft < 2 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, 0x8E);
                outbyte(outbuf, 1, c - 0xFEC0);
                next_inchar(inpos, 1);
                next_out(outbuf, 2);
                outleft -= 2;
                continue;
            } elif c == 0xFF3C {
                # FULL-WIDTH REVERSE SOLIDUS
                code = 0x2140;
            } elif c == 0xA5 or c == 0x203E {
                # YEN SIGN, OVERLINE
                if outleft < 1 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, 0x5C if c == 0xA5 else 0x7E);
                next_inchar(inpos, 1);
                next_out(outbuf, 1);
                outleft -= 1;
                continue;
            } else {
                return 1;
            }
        }
        if (code & 0x8000) != 0 {
            # JIS X 0212
            if outleft < 3 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, 0x8F);
            outbyte(outbuf, 1, code >> 8);
            outbyte(outbuf, 2, (code & 0xFF) | 0x80);
            next_inchar(inpos, 1);
            next_out(outbuf, 3);
            outleft -= 3;
        } else {
            # JIS X 0208
            if outleft < 2 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, (code >> 8) | 0x80);
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
            next_inchar(inpos, 1);
            next_out(outbuf, 2);
            outleft -= 2;
        }
    }
    return 0;
}

def euc_jp_decode(
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
        if c == 0x8E {
            # JIS X 0201 half-width katakana
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            if c2 >= 0xA1 and c2 <= 0xDF {
                if not outchar(writer, 0xFEC0 + c2) {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, 2);
                inleft -= 2;
            } else {
                return 1;
            }
        } elif c == 0x8F {
            if inleft < 3 {
                return MBERR_TOOFEW;
            }
            # JIS X 0212
            decoded = map_decode(
                addressof(cjk_jisx0212_map),
                inbyte(inbuf, 1) ^ 0x80,
                inbyte(inbuf, 2) ^ 0x80
            );
            if decoded == UNIINV {
                return 1;
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 3);
            inleft -= 3;
        } else {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            # JIS X 0208
            decoded = UNIINV;
            if c == 0xA1 and c2 == 0xC0 {
                # FULL-WIDTH REVERSE SOLIDUS
                decoded = 0xFF3C;
            } else {
                decoded = map_decode(addressof(cjk_jisx0208_map), c ^ 0x80, c2 ^ 0x80);
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
    }
    return 0;
}

# SHIFT_JIS codec

def shift_jis_encode(
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
        code = 0;
        if c < 0x80 {
            code = c;
        } elif c == 0x00A5 {
            # YEN SIGN
            code = 0x5C;
        } elif c == 0x203E {
            # OVERLINE
            code = 0x7E;
        } elif jisx0201_k_encode(c) >= 0 {
            code = jisx0201_k_encode(c);
        } elif c > 0xFFFF {
            return 1;
        } else {
            code = NOCHAR;
        }
        if code < 0x80 or (code >= 0xA1 and code <= 0xDF) {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, code);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        if code == NOCHAR {
            code = map_encode(addressof(cjk_jisxcommon_map), c);
            if code == NOCHAR {
                if c == 0xFF3C {
                    # FULL-WIDTH REVERSE SOLIDUS
                    code = 0x2140;
                } else {
                    return 1;
                }
            }
            # MSB set: JIS X 0212
            if (code & 0x8000) != 0 {
                return 1;
            }
        }
        c1 = code >> 8;
        c2 = code & 0xFF;
        c2 = ((0x5E if ((c1 - 0x21) & 1) != 0 else 0) + (c2 - 0x21)) & 0xFF;
        c1 = ((c1 - 0x21) >> 1) & 0xFF;
        outbyte(outbuf, 0, c1 + 0x81 if c1 < 0x1F else c1 + 0xC1);
        outbyte(outbuf, 1, c2 + 0x40 if c2 < 0x3F else c2 + 0x41);
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def shift_jis_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c < 0x80 or jisx0201_k_decode(c) >= 0 {
            if not outchar(writer, c if c < 0x80 else jisx0201_k_decode(c)) {
                return MBERR_EXCEPTION;
            }
        } elif (c >= 0x81 and c <= 0x9F) or (c >= 0xE0 and c <= 0xEA) {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            if c2 < 0x40 or (c2 > 0x7E and c2 < 0x80) or c2 > 0xFC {
                return 1;
            }
            c1 = (c - 0x81 if c < 0xE0 else c - 0xC1) & 0xFF;
            c2 = (c2 - 0x40 if c2 < 0x80 else c2 - 0x41) & 0xFF;
            c1 = (2 * c1 + (0 if c2 < 0x5E else 1) + 0x21) & 0xFF;
            c2 = ((c2 if c2 < 0x5E else c2 - 0x5E) + 0x21) & 0xFF;
            decoded = UNIINV;
            if c1 == 0x21 and c2 == 0x40 {
                # FULL-WIDTH REVERSE SOLIDUS
                decoded = 0xFF3C;
            } else {
                decoded = map_decode(addressof(cjk_jisx0208_map), c1, c2);
                if decoded == UNIINV {
                    return 1;
                }
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 2);
            inleft -= 2;
            continue;
        } else {
            return 1;
        }
        # JIS X 0201
        next_in(inbuf, 1);
        inleft -= 1;
    }
    return 0;
}

# SHIFT_JIS-2004 codec

def shift_jis_2004_encode(
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
    config = codec.view(1)[0].config;
    while inpos.view(1)[0] < inlen {
        c = inchar(kind, data, inpos, 0);
        code = NOCHAR;
        # JISX0201_ENCODE
        if jisx0201_r_encode(c) >= 0 {
            code = jisx0201_r_encode(c);
        } elif jisx0201_k_encode(c) >= 0 {
            code = jisx0201_k_encode(c);
        }
        if code < 0x80 or (code >= 0xA1 and code <= 0xDF) {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, code);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            continue;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        insize = 1;
        if code == NOCHAR {
            if c <= 0xFFFF {
                emulated = emulate_2000_encode_bmp(config, c);
                if emulated == -1 {
                    return EMULATE_JISX0213_2000_ENCODE_INVALID;
                }
                if emulated != 0 {
                    code = emulated;
                } else {
                    (code, insize) = jisx0213_bmp_code(
                        kind, data, inpos, inlen, flags, c
                    );
                    if code == -1 {
                        return 1;
                    }
                    if code == -2 {
                        return MBERR_TOOFEW;
                    }
                    if code == NOCHAR {
                        code = map_encode(addressof(cjk_jisxcommon_map), c);
                        if code == NOCHAR {
                            return 1;
                        }
                        # abandon JIS X 0212 codes
                        if (code & 0x8000) != 0 {
                            return 1;
                        }
                    }
                }
            } elif (c >> 16) == (EMPBASE >> 16) {
                if emulate_2000_encode_emp(config, c) {
                    return EMULATE_JISX0213_2000_ENCODE_INVALID;
                }
                code = map_encode(addressof(cjk_jisx0213_emp_map), c & 0xFFFF);
                if code == NOCHAR {
                    return insize;
                }
            } else {
                return insize;
            }
        }
        c1 = code >> 8;
        c2 = (code & 0xFF) - 0x21;
        if (c1 & 0x80) != 0 {
            # Plane 2
            if c1 >= 0xEE {
                c1 -= 0x87;
            } elif c1 >= 0xAC or c1 == 0xA8 {
                c1 -= 0x49;
            } else {
                c1 -= 0x43;
            }
        } else {
            # Plane 1
            c1 -= 0x21;
        }
        if (c1 & 1) != 0 {
            c2 += 0x5E;
        }
        c1 = c1 >> 1;
        outbyte(outbuf, 0, c1 + (0x81 if c1 < 0x1F else 0xC1));
        outbyte(outbuf, 1, c2 + (0x40 if c2 < 0x3F else 0x41));
        next_inchar(inpos, insize);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def shift_jis_2004_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    config = codec.view(1)[0].config;
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        # JISX0201_DECODE
        single = jisx0201_r_decode(c);
        if single < 0 {
            single = jisx0201_k_decode(c);
        }
        if single >= 0 {
            if not outchar(writer, single) {
                return MBERR_EXCEPTION;
            }
        } elif (c >= 0x81 and c <= 0x9F) or (c >= 0xE0 and c <= 0xFC) {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            if c2 < 0x40 or (c2 > 0x7E and c2 < 0x80) or c2 > 0xFC {
                return 1;
            }
            c1 = (c - 0x81 if c < 0xE0 else c - 0xC1) & 0xFF;
            c2 = (c2 - 0x40 if c2 < 0x80 else c2 - 0x41) & 0xFF;
            c1 = (2 * c1 + (0 if c2 < 0x5E else 1)) & 0xFF;
            c2 = ((c2 if c2 < 0x5E else c2 - 0x5E) + 0x21) & 0xFF;
            if c1 < 0x5E {
                # Plane 1
                c1 += 0x21;
                if emulate_2000_decode_plane1(config, c1, c2) {
                    return EMULATE_JISX0213_2000_DECODE_INVALID;
                }
                decoded = map_decode(addressof(cjk_jisx0208_map), c1, c2);
                if decoded == UNIINV {
                    decoded = map_decode(addressof(cjk_jisx0213_1_bmp_map), c1, c2);
                }
                if decoded == UNIINV {
                    code = map_decode(addressof(cjk_jisx0213_1_emp_map), c1, c2);
                    if code != UNIINV {
                        decoded = EMPBASE | code;
                    }
                }
                if decoded == UNIINV {
                    code = map_decode_wide(addressof(cjk_jisx0213_pair_map), c1, c2);
                    if code == UNIINV {
                        return 1;
                    }
                    if not outchar2(writer, code >> 16, code & 0xFFFF) {
                        return MBERR_EXCEPTION;
                    }
                } elif not outchar(writer, decoded) {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, 2);
                inleft -= 2;
            } else {
                # Plane 2
                if c1 >= 0x67 {
                    c1 += 0x07;
                } elif c1 >= 0x63 or c1 == 0x5F {
                    c1 -= 0x37;
                } else {
                    c1 -= 0x3D;
                }
                decoded = UNIINV;
                if emulate_2000_decode_plane2(config, c1, c2) {
                    decoded = 0x9B1D;
                } else {
                    decoded = map_decode(addressof(cjk_jisx0213_2_bmp_map), c1, c2);
                    if decoded == UNIINV {
                        code = map_decode(addressof(cjk_jisx0213_2_emp_map), c1, c2);
                        if code == UNIINV {
                            return 1;
                        }
                        decoded = EMPBASE | code;
                    }
                }
                if not outchar(writer, decoded) {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, 2);
                inleft -= 2;
            }
            continue;
        } else {
            return 1;
        }
        # JIS X 0201
        next_in(inbuf, 1);
        inleft -= 1;
    }
    return 0;
}

import from c {
    glob jp_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("shift_jis"),
                 codecinit=no_codec_init,
                 encode=shift_jis_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=shift_jis_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("cp932"),
                 codecinit=no_codec_init,
                 encode=cp932_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=cp932_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("euc_jp"),
                 codecinit=no_codec_init,
                 encode=euc_jp_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=euc_jp_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("shift_jis_2004"),
                 codecinit=no_codec_init,
                 encode=shift_jis_2004_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=shift_jis_2004_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("euc_jis_2004"),
                 codecinit=no_codec_init,
                 encode=euc_jis_2004_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=euc_jis_2004_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("euc_jisx0213"),
                 config=ptr(2000),
                 codecinit=no_codec_init,
                 encode=euc_jis_2004_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=euc_jis_2004_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("shift_jisx0213"),
                 config=ptr(2000),
                 codecinit=no_codec_init,
                 encode=shift_jis_2004_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=shift_jis_2004_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             )
         ];
}

def codecs_jp_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(jp_codecs), 7, encoding);
}

def codecs_jp_exec(module: ptr[PyObject]) -> i32 {
    return register_maps(module, addressof(cjk_jp_mappings), CJK_JP_MAPPINGS);
}
