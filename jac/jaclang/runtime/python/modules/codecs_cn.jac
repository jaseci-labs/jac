"""The _codecs_cn module: Modules/cjkcodecs/_codecs_cn.c (Mainland Chinese
encodings: gb2312, gbk, gb18030 and hz) in native Jac. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api { PyObject }
import from jaclang.runtime.python.modules.cjkcodecs {
    DecodeWriter,
    Gb18030Range,
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
    register_maps,
    set_state_byte,
    state_byte
}
import from jaclang.runtime.python.modules.cjkcodecs_mappings_cn {
    CJK_CN_MAPPINGS,
    cjk_cn_mappings,
    cjk_gb18030_to_unibmp_ranges,
    cjk_gb18030ext_map,
    cjk_gb2312_map,
    cjk_gbcommon_map,
    cjk_gbkext_map
}

# codecs in this file use the first byte of MultibyteCodec_State.c[8]
# to store a 0 or 1 state value
glob:priv CN_STATE_OFFSET: int = 0;

# GBK and GB2312 map differently in few code points that are listed below:
#
#              gb2312                          gbk
# A1A4         U+30FB KATAKANA MIDDLE DOT      U+00B7 MIDDLE DOT
# A1AA         U+2015 HORIZONTAL BAR           U+2014 EM DASH
# A844         undefined                       U+2015 HORIZONTAL BAR

# GBK_DECODE: the code point of `dc1`, `dc2`, UNIINV if unmapped.
def:priv gbk_decode_char(dc1: int, dc2: int) -> int {
    if dc1 == 0xA1 and dc2 == 0xAA {
        return 0x2014;
    }
    if dc1 == 0xA8 and dc2 == 0x44 {
        return 0x2015;
    }
    if dc1 == 0xA1 and dc2 == 0xA4 {
        return 0x00B7;
    }
    decoded = map_decode(addressof(cjk_gb2312_map), dc1 ^ 0x80, dc2 ^ 0x80);
    if decoded != UNIINV {
        return decoded;
    }
    return map_decode(addressof(cjk_gbkext_map), dc1, dc2);
}

# GBK_ENCODE: the code of `code`, NOCHAR if unmapped.
def:priv gbk_encode_char(code: int) -> int {
    if code == 0x2014 {
        return 0xA1AA;
    }
    if code == 0x2015 {
        return 0xA844;
    }
    if code == 0x00B7 {
        return 0xA1A4;
    }
    if code != 0x30FB {
        return map_encode(addressof(cjk_gbcommon_map), code);
    }
    return NOCHAR;
}

# GB2312 codec

def gb2312_encode(
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
        code = map_encode(addressof(cjk_gbcommon_map), c);
        if code == NOCHAR {
            return 1;
        }
        # MSB set: GBK
        if (code & 0x8000) != 0 {
            return 1;
        }
        outbyte(outbuf, 0, (code >> 8) | 0x80);
        outbyte(outbuf, 1, (code & 0xFF) | 0x80);
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def gb2312_decode(
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
        decoded = map_decode(
            addressof(cjk_gb2312_map), c ^ 0x80, inbyte(inbuf, 1) ^ 0x80
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
    return 0;
}

# GBK codec

def gbk_encode(
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
        code = gbk_encode_char(c);
        if code == NOCHAR {
            return 1;
        }
        outbyte(outbuf, 0, (code >> 8) | 0x80);
        if (code & 0x8000) != 0 {
            # MSB set: GBK
            outbyte(outbuf, 1, code & 0xFF);
        } else {
            # MSB unset: GB2312
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
        }
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def gbk_decode(
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
        decoded = gbk_decode_char(c, inbyte(inbuf, 1));
        if decoded == UNIINV {
            return 1;
        }
        if not outchar(writer, decoded) {
            return MBERR_EXCEPTION;
        }
        next_in(inbuf, 2);
        inleft -= 2;
    }
    return 0;
}

# GB18030 codec

# The four bytes of a GB18030 four-byte sequence for `tc` with `first` the
# base of its first byte, written at the output cursor.
def:priv gb18030_four(outbuf: ptr[ptr[u8]], tc: int, first: int) {
    outbyte(outbuf, 3, tc % 10 + 0x30);
    tc = tc // 10;
    outbyte(outbuf, 2, tc % 126 + 0x81);
    tc = tc // 126;
    outbyte(outbuf, 1, tc % 10 + 0x30);
    tc = tc // 10;
    outbyte(outbuf, 0, tc + first);
}

def gb18030_encode(
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
        if c >= 0x10000 {
            if outleft < 4 {
                return MBERR_TOOSMALL;
            }
            gb18030_four(outbuf, c - 0x10000, 0x90);
            next_inchar(inpos, 1);
            next_out(outbuf, 4);
            outleft -= 4;
            continue;
        }
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        code = gbk_encode_char(c);
        if code == NOCHAR {
            code = map_encode(addressof(cjk_gb18030ext_map), c);
        }
        if code == NOCHAR {
            if outleft < 4 {
                return MBERR_TOOSMALL;
            }
            utrrange = addressof(cjk_gb18030_to_unibmp_ranges);
            while int(utrrange.view(1)[0].first) != 0 {
                item = utrrange.view(1)[0];
                if int(item.first) <= c and c <= int(item.last) {
                    gb18030_four(outbuf, c - int(item.first) + int(item.base), 0x81);
                    next_inchar(inpos, 1);
                    next_out(outbuf, 4);
                    outleft -= 4;
                    break;
                }
                utrrange += 1;
            }
            if int(utrrange.view(1)[0].first) == 0 {
                return 1;
            }
            continue;
        }
        outbyte(outbuf, 0, (code >> 8) | 0x80);
        if (code & 0x8000) != 0 {
            # MSB set: GBK or GB18030ext
            outbyte(outbuf, 1, code & 0xFF);
        } else {
            # MSB unset: GB2312
            outbyte(outbuf, 1, (code & 0xFF) | 0x80);
        }
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def gb18030_decode(
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
        # 4 bytes seq
        if c2 >= 0x30 and c2 <= 0x39 {
            if inleft < 4 {
                return MBERR_TOOFEW;
            }
            c3 = inbyte(inbuf, 2);
            c4 = inbyte(inbuf, 3);
            if c < 0x81
                or c > 0xFE
                or c3 < 0x81
                or c3 > 0xFE
                or c4 < 0x30
                or c4 > 0x39 {
                return 1;
            }
            c -= 0x81;
            c2 -= 0x30;
            c3 -= 0x81;
            c4 -= 0x30;
            if c < 4 {
                # U+0080 - U+FFFF
                lseq = (c * 10 + c2) * 1260 + c3 * 10 + c4;
                if lseq < 39420 {
                    utr = addressof(cjk_gb18030_to_unibmp_ranges);
                    while lseq >= int((utr + 1).view(1)[0].base) {
                        utr += 1;
                    }
                    item = utr.view(1)[0];
                    if not outchar(writer, int(item.first) - int(item.base) + lseq) {
                        return MBERR_EXCEPTION;
                    }
                    next_in(inbuf, 4);
                    inleft -= 4;
                    continue;
                }
            } elif c >= 15 {
                # U+10000 - U+10FFFF
                lseq = 0x10000 + ((c - 15) * 10 + c2) * 1260 + c3 * 10 + c4;
                if lseq <= 0x10FFFF {
                    if not outchar(writer, lseq) {
                        return MBERR_EXCEPTION;
                    }
                    next_in(inbuf, 4);
                    inleft -= 4;
                    continue;
                }
            }
            return 1;
        }
        decoded = gbk_decode_char(c, c2);
        if decoded == UNIINV {
            decoded = map_decode(addressof(cjk_gb18030ext_map), c, c2);
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

# HZ codec

def hz_encode_init(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i32 {
    set_state_byte(state, CN_STATE_OFFSET, 0);
    return i32(0);
}

def hz_encode_reset(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    outbuf: ptr[ptr[u8]],
    outleft: i64
) -> i64 {
    if state_byte(state, CN_STATE_OFFSET) != 0 {
        if outleft < 2 {
            return MBERR_TOOSMALL;
        }
        outbyte(outbuf, 0, 0x7E);
        outbyte(outbuf, 1, 0x7D);
        set_state_byte(state, CN_STATE_OFFSET, 0);
        next_out(outbuf, 2);
    }
    return 0;
}

def hz_encode(
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
            if state_byte(state, CN_STATE_OFFSET) != 0 {
                if outleft < 2 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, 0x7E);
                outbyte(outbuf, 1, 0x7D);
                next_out(outbuf, 2);
                outleft -= 2;
                set_state_byte(state, CN_STATE_OFFSET, 0);
            }
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, c);
            next_inchar(inpos, 1);
            next_out(outbuf, 1);
            outleft -= 1;
            if c == 0x7E {
                if outleft < 1 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, 0x7E);
                next_out(outbuf, 1);
                outleft -= 1;
            }
            continue;
        }
        if c > 0xFFFF {
            return 1;
        }
        code = map_encode(addressof(cjk_gbcommon_map), c);
        if code == NOCHAR {
            return 1;
        }
        # MSB set: GBK
        if (code & 0x8000) != 0 {
            return 1;
        }
        if state_byte(state, CN_STATE_OFFSET) == 0 {
            if outleft < 4 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, 0x7E);
            outbyte(outbuf, 1, 0x7B);
            outbyte(outbuf, 2, code >> 8);
            outbyte(outbuf, 3, code & 0xFF);
            next_inchar(inpos, 1);
            next_out(outbuf, 4);
            outleft -= 4;
            set_state_byte(state, CN_STATE_OFFSET, 1);
        } else {
            if outleft < 2 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, code >> 8);
            outbyte(outbuf, 1, code & 0xFF);
            next_inchar(inpos, 1);
            next_out(outbuf, 2);
            outleft -= 2;
        }
    }
    return 0;
}

def hz_decode_init(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i32 {
    set_state_byte(state, CN_STATE_OFFSET, 0);
    return i32(0);
}

def hz_decode_reset(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i64 {
    set_state_byte(state, CN_STATE_OFFSET, 0);
    return 0;
}

def hz_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if c == 0x7E {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            c2 = inbyte(inbuf, 1);
            mode = state_byte(state, CN_STATE_OFFSET);
            if c2 == 0x7E and mode == 0 {
                if not outchar(writer, 0x7E) {
                    return MBERR_EXCEPTION;
                }
            } elif c2 == 0x7B and mode == 0 {
                # set GB
                set_state_byte(state, CN_STATE_OFFSET, 1);
            } elif c2 == 0x0A and mode == 0 {
                # line-continuation
            } elif c2 == 0x7D and mode == 1 {
                # set ASCII
                set_state_byte(state, CN_STATE_OFFSET, 0);
            } else {
                return 1;
            }
            next_in(inbuf, 2);
            inleft -= 2;
            continue;
        }
        if (c & 0x80) != 0 {
            return 1;
        }
        if state_byte(state, CN_STATE_OFFSET) == 0 {
            # ASCII mode
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
        } else {
            # GB mode
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            decoded = map_decode(addressof(cjk_gb2312_map), c, inbyte(inbuf, 1));
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
    glob cn_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("gb2312"),
                 codecinit=no_codec_init,
                 encode=gb2312_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=gb2312_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("gbk"),
                 codecinit=no_codec_init,
                 encode=gbk_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=gbk_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("gb18030"),
                 codecinit=no_codec_init,
                 encode=gb18030_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=gb18030_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("hz"),
                 codecinit=no_codec_init,
                 encode=hz_encode,
                 encinit=hz_encode_init,
                 encreset=hz_encode_reset,
                 decode=hz_decode,
                 decinit=hz_decode_init,
                 decreset=hz_decode_reset
             )
         ];
}

def codecs_cn_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(cn_codecs), 4, encoding);
}

def codecs_cn_exec(module: ptr[PyObject]) -> i32 {
    return register_maps(module, addressof(cjk_cn_mappings), CJK_CN_MAPPINGS);
}
