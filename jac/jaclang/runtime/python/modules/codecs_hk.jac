"""The _codecs_hk module: Modules/cjkcodecs/_codecs_hk.c (Hong Kong's
big5hkscs) in native Jac. The Big5 maps it builds on are _codecs_tw's,
imported through that module's map capsule as the C does. See
../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.modules.cjkcodecs {
    DbcsMap,
    DecodeWriter,
    MBENC_FLUSH,
    MBERR_EXCEPTION,
    MBERR_INTERNAL,
    MBERR_TOOFEW,
    MBERR_TOOSMALL,
    MULTIC,
    MultibyteCodec,
    MultibyteCodec_State,
    NOCHAR,
    UNIINV,
    getcodec,
    importmap,
    inbyte,
    inchar,
    map_decode,
    map_encode,
    next_in,
    next_inchar,
    next_out,
    no_decode_reset,
    no_encode_reset,
    no_state_init,
    outbyte,
    outchar,
    outchar2,
    register_maps
}
import from jaclang.runtime.python.modules.cjkcodecs_mappings_hk {
    CJK_HK_MAPPINGS,
    cjk_big5hkscs_bmp_map,
    cjk_big5hkscs_map,
    cjk_big5hkscs_nonbmp_map,
    cjk_big5hkscs_phint_0,
    cjk_big5hkscs_phint_12130,
    cjk_big5hkscs_phint_21924,
    cjk_hk_mappings
}

import from c {
    # The big5 map of _codecs_tw, which big5hkscs_codec_init imports (the
    # C's CJK_MOD_SPECIFIC_STATE).
    glob:priv big5_map: ptr[DbcsMap] = ptr[DbcsMap]();
    # There are four possible pair unicode -> big5hkscs maps as in HKSCS 2004:
    #  U+00CA U+0304 -> 8862  (U+00CA alone is mapped to 8866)
    #  U+00CA U+030C -> 8864
    #  U+00EA U+0304 -> 88a3  (U+00EA alone is mapped to 88a7)
    #  U+00EA U+030C -> 88a5
    # These are handled by not mapping tables but a hand-written code.
    glob:priv big5hkscs_pairenc_table: list[u16] = [
             u16(0x8862),
             u16(0x8864),
             u16(0x88A3),
             u16(0x88A5)
         ];
}

# BIG5HKSCS codec

def big5hkscs_codec_init(codec: ptr[MultibyteCodec]) -> i32 {
    map = importmap("_codecs_tw", "__map_big5");
    if map.is_null() {
        return i32(-1);
    }
    big5_map = map;
    return i32(0);
}

def big5hkscs_encode(
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
        insize = 1;
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        code = NOCHAR;
        if c < 0x10000 {
            code = map_encode(addressof(cjk_big5hkscs_bmp_map), c);
            if code != NOCHAR {
                if code == MULTIC {
                    remaining = inlen - inpos.view(1)[0];
                    c2 = inchar(kind, data, inpos, 1) if remaining >= 2 else 0;
                    if remaining >= 2
                        and (c & 0xFFDF) == 0x00CA
                        and (c2 & 0xFFF7) == 0x0304 {
                        code = int(
                            (
                                addressof(big5hkscs_pairenc_table)
                                + (((c >> 4) | (c2 >> 3)) & 3)
                            ).view(
                                1
                            )[0]
                        );
                        insize = 2;
                    } elif remaining < 2 and (flags & MBENC_FLUSH) == 0 {
                        return MBERR_TOOFEW;
                    } elif c == 0xCA {
                        code = 0x8866;
                    } else {
                        # c == 0xea
                        code = 0x88A7;
                    }
                }
            } else {
                code = map_encode(big5_map, c);
                if code == NOCHAR {
                    return 1;
                }
            }
        } elif c < 0x20000 {
            return insize;
        } elif c < 0x30000 {
            code = map_encode(addressof(cjk_big5hkscs_nonbmp_map), c & 0xFFFF);
            if code == NOCHAR {
                return insize;
            }
        } else {
            return insize;
        }
        outbyte(outbuf, 0, code >> 8);
        outbyte(outbuf, 1, code & 0xFF);
        next_inchar(inpos, insize);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

# BH2S
def:priv bh2s(c1: int, c2: int) -> int {
    return (c1 - 0x87) * (0xFE - 0x40 + 1) + (c2 - 0x40);
}

def big5hkscs_decode(
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
        if 0xC6 > c or c > 0xC8 or (c < 0xC7 and c2 < 0xA1) {
            decoded = map_decode(big5_map, c, c2);
            if decoded != UNIINV {
                if not outchar(writer, decoded) {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, 2);
                inleft -= 2;
                continue;
            }
        }
        decoded = map_decode(addressof(cjk_big5hkscs_map), c, c2);
        if decoded != UNIINV {
            s = bh2s(c, c2);
            hintbase = ptr[u8]();
            if bh2s(0x87, 0x40) <= s and s <= bh2s(0xA0, 0xFE) {
                hintbase = addressof(cjk_big5hkscs_phint_0);
                s -= bh2s(0x87, 0x40);
            } elif bh2s(0xC6, 0xA1) <= s and s <= bh2s(0xC8, 0xFE) {
                hintbase = addressof(cjk_big5hkscs_phint_12130);
                s -= bh2s(0xC6, 0xA1);
            } elif bh2s(0xF9, 0xD6) <= s and s <= bh2s(0xFE, 0xFE) {
                hintbase = addressof(cjk_big5hkscs_phint_21924);
                s -= bh2s(0xF9, 0xD6);
            } else {
                return MBERR_INTERNAL;
            }
            if (int((hintbase + (s >> 3)).view(1)[0]) & (1 << (s & 7))) != 0 {
                decoded = decoded | 0x20000;
            }
            if not outchar(writer, decoded) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 2);
            inleft -= 2;
            continue;
        }
        pair = (c << 8) | c2;
        written = True;
        if pair == 0x8862 {
            written = outchar2(writer, 0x00CA, 0x0304);
        } elif pair == 0x8864 {
            written = outchar2(writer, 0x00CA, 0x030C);
        } elif pair == 0x88A3 {
            written = outchar2(writer, 0x00EA, 0x0304);
        } elif pair == 0x88A5 {
            written = outchar2(writer, 0x00EA, 0x030C);
        } else {
            return 1;
        }
        if not written {
            return MBERR_EXCEPTION;
        }
        # all decoded code points are pairs, above.
        next_in(inbuf, 2);
        inleft -= 2;
    }
    return 0;
}

import from c {
    glob hk_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("big5hkscs"),
                 codecinit=big5hkscs_codec_init,
                 encode=big5hkscs_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=big5hkscs_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             )
         ];
}

def codecs_hk_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(hk_codecs), 1, encoding);
}

def codecs_hk_exec(module: ptr[PyObject]) -> i32 {
    return register_maps(module, addressof(cjk_hk_mappings), CJK_HK_MAPPINGS);
}
