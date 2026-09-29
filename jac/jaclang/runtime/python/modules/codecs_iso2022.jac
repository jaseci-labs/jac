"""The _codecs_iso2022 module: Modules/cjkcodecs/_codecs_iso2022.c (the
ISO-2022 encodings iso2022_kr, iso2022_jp, iso2022_jp_1, iso2022_jp_2,
iso2022_jp_2004, iso2022_jp_3 and iso2022_jp_ext) in native Jac. The
character sets' maps are _codecs_kr's, _codecs_jp's and _codecs_cn's,
imported through their map capsules as the C does. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    PyErr_NoMemory,
    PyMem_Free,
    PyMem_Malloc,
    PyObject
}
import from jaclang.runtime.python.modules.cjkcodecs {
    DBCINV,
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
    PairEncodeMap,
    UNIINV,
    find_pairencmap,
    getcodec,
    importmap,
    inbyte,
    inchar,
    map_decode,
    map_decode_wide,
    map_encode,
    next_in,
    next_inchar,
    next_out,
    no_codec_init,
    outbyte,
    outchar,
    outchar2,
    set_state_byte,
    state_byte
}
import from jaclang.runtime.python.modules.cjkcodecs_jis {
    emulate_2000_decode_plane1,
    emulate_2000_decode_plane2,
    emulate_2000_encode_bmp,
    emulate_2000_encode_emp,
    jisx0201_k_decode,
    jisx0201_k_encode,
    jisx0201_r_decode,
    jisx0201_r_encode
}
import from jaclang.runtime.python.modules.cjkcodecs_mappings_jp { JISX0213_ENCPAIRS }

# STATE
#
#   state->c[0-3]
#
#    00000000
#    ||^^^^^|
#    |+-----+----  G0-3 Character Set
#    +-----------  Is G0-3 double byte?
#
#   state->c[4]
#
#    00000000
#          ||
#          |+----  Locked-Shift?
#          +-----  ESC Throughout

glob:priv ESC: int = 0x1B,
     SO: int = 0x0E,
     SI: int = 0x0F,
     LF: int = 0x0A,
     MAX_ESCSEQLEN: int = 16,
     CHARSET_ISO8859_1: Final[i64] = 0x41,
     CHARSET_ASCII: Final[i64] = 0x42,
     CHARSET_ISO8859_7: Final[i64] = 0x46,
     CHARSET_JISX0201_K: Final[i64] = 0x49,
     CHARSET_JISX0201_R: Final[i64] = 0x4A,
     CHARSET_DBCS: Final[i64] = 0x80,
     CHARSET_GB2312: Final[i64] = 0x41 | 0x80,
     CHARSET_JISX0208: Final[i64] = 0x42 | 0x80,
     CHARSET_KSX1001: Final[i64] = 0x43 | 0x80,
     CHARSET_JISX0212: Final[i64] = 0x44 | 0x80,
     CHARSET_JISX0213_2000_1: Final[i64] = 0x4F | 0x80,
     CHARSET_JISX0213_2: Final[i64] = 0x50 | 0x80,
     CHARSET_JISX0213_2004_1: Final[i64] = 0x51 | 0x80,
     CHARSET_JISX0208_O: Final[i64] = 0x40 | 0x80,
     MAP_UNMAPPABLE: int = 0xFFFF,
     # for JIS X 0213
     MAP_MULTIPLE_AVAIL: int = 0xFFFE,
     F_SHIFTED: int = 0x01,
     F_ESCTHROUGHOUT: int = 0x02,
     # iso2022_config.flags
     NO_SHIFT: Final[i32] = 0x01,
     USE_G2: Final[i32] = 0x02,
     USE_JISX0208_EXT: Final[i32] = 0x04,
     # The imported maps (the C's CJK_MOD_SPECIFIC_STATE), by slot.
     KR_CP949: int = 0,
     KR_KSX1001: int = 1,
     JP_JISXCOMMON: int = 2,
     JP_JISX0208: int = 3,
     JP_JISX0212: int = 4,
     JP_JISX0213_BMP: int = 5,
     JP_JISX0213_1_BMP: int = 6,
     JP_JISX0213_2_BMP: int = 7,
     JP_JISX0213_EMP: int = 8,
     JP_JISX0213_1_EMP: int = 9,
     JP_JISX0213_2_EMP: int = 10,
     JP_JISX0213_PAIR: int = 11,
     CN_GBCOMMON: int = 12,
     CN_GB2312: int = 13;

import from c {
    # struct iso2022_designation. An entry without an initializer has the
    # no-op one.
    obj Iso2022Designation {
        has mark: u8,
            plane: u8,
            width: u8,
            initializer: Callable[[ptr[MultibyteCodec]], i32],
            decoder: Callable[[ptr[MultibyteCodec], ptr[u8]], u32],
            encoder: Callable[[ptr[MultibyteCodec], ptr[u32], ptr[i64]], u16];
    }
    # struct iso2022_config.
    obj Iso2022Config {
        has flags: i32,
            designations: ptr[Iso2022Designation];
    }  glob:priv imported_maps: list[ptr[DbcsMap]] = [
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap](),
             ptr[DbcsMap]()
         ];
}

def:priv imported(slot: int) -> ptr[DbcsMap] {
    return (addressof(imported_maps) + slot).view(1)[0];
}

# IMPORT_MAP(locale, charset, ...): False with the exception set on failure.
def:priv import_map(slot: int, locale: str, charset: str) -> bool {
    map = importmap("_codecs_" + locale, "__map_" + charset);
    if map.is_null() {
        return False;
    }
    (addressof(imported_maps) + slot).view(1)[0] = map;
    return True;
}

def:priv config_of(codec: ptr[MultibyteCodec]) -> ptr[Iso2022Config] {
    return ptr[Iso2022Config](codec.view(1)[0].config);
}

# CONFIG_ISSET.
def:priv config_isset(codec: ptr[MultibyteCodec], flag: i32) -> bool {
    return (config_of(codec).view(1)[0].flags & flag) != 0;
}

# CONFIG_DESIGNATIONS.
def:priv designations(codec: ptr[MultibyteCodec]) -> ptr[Iso2022Designation] {
    return config_of(codec).view(1)[0].designations;
}

def:priv state_flag(state: ptr[MultibyteCodec_State], flag: int) -> bool {
    return (state_byte(state, 4) & flag) != 0;
}

def:priv set_state_flag(state: ptr[MultibyteCodec_State], flag: int) {
    set_state_byte(state, 4, state_byte(state, 4) | flag);
}

def:priv clear_state_flag(state: ptr[MultibyteCodec_State], flag: int) {
    set_state_byte(state, 4, state_byte(state, 4) & ~flag);
}

# IS_ESCEND
def:priv is_escend(c: int) -> bool {
    return (c >= 0x41 and c <= 0x5A) or c == 0x40;
}

# IS_ISO2022ESC: this is not a complete list of ISO-2022 escape sequence
# headers, but it's enough to implement CJK instances of iso-2022.
def:priv is_iso2022esc(c2: int) -> bool {
    return c2 == 0x28 or c2 == 0x29 or c2 == 0x24 or c2 == 0x2E or c2 == 0x26;
}

# iso-2022 codec implementation

def iso2022_codec_init(codec: ptr[MultibyteCodec]) -> i32 {
    desig = designations(codec);
    while desig.view(1)[0].mark != 0 {
        if desig.view(1)[0].initializer(codec) != 0 {
            return i32(-1);
        }
        desig += 1;
    }
    return i32(0);
}

def iso2022_encode_init(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i32 {
    set_state_byte(state, 4, 0);
    set_state_byte(state, 0, CHARSET_ASCII);
    set_state_byte(state, 1, CHARSET_ASCII);
    return i32(0);
}

def iso2022_encode_reset(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    outbuf: ptr[ptr[u8]],
    outleft: i64
) -> i64 {
    if state_flag(state, F_SHIFTED) {
        if outleft < 1 {
            return MBERR_TOOSMALL;
        }
        outbyte(outbuf, 0, SI);
        next_out(outbuf, 1);
        outleft -= 1;
        clear_state_flag(state, F_SHIFTED);
    }
    if state_byte(state, 0) != CHARSET_ASCII {
        if outleft < 3 {
            return MBERR_TOOSMALL;
        }
        outbyte(outbuf, 0, ESC);
        outbyte(outbuf, 1, 0x28);
        outbyte(outbuf, 2, 0x42);
        next_out(outbuf, 3);
        outleft -= 3;
        set_state_byte(state, 0, CHARSET_ASCII);
    }
    return 0;
}

# The encoder's `Py_UCS4 buf[2]` and `Py_ssize_t length`, in C memory a
# designation encoder reads and writes.
import from c {
    obj EncodeScratch {
        has buf0: u32,
            buf1: u32,
            length: i64;
    }
}

def:priv call_encoder(
    dsg: ptr[Iso2022Designation],
    codec: ptr[MultibyteCodec],
    scratch: ptr[EncodeScratch]
) -> int {
    return int(dsg.view(1)[0].encoder(codec, ptr[u32](scratch), ptr[i64](scratch) + 1));
}

def iso2022_encode(
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
    scratch = ptr[EncodeScratch](PyMem_Malloc(u64(16)));
    if scratch.is_null() {
        PyErr_NoMemory();
        return MBERR_EXCEPTION;
    }
    r = iso2022_encode_with(
        state, codec, kind, data, inpos, inlen, outbuf, outleft, flags, scratch
    );
    PyMem_Free(ptr(scratch));
    return r;
}

def:priv iso2022_encode_with(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    kind: i32,
    data: ptr,
    inpos: ptr[i64],
    inlen: i64,
    outbuf: ptr[ptr[u8]],
    outleft: i64,
    flags: i32,
    scratch: ptr[EncodeScratch]
) -> i64 {
    while inpos.view(1)[0] < inlen {
        c = inchar(kind, data, inpos, 0);
        if c < 0x80 {
            if state_byte(state, 0) != CHARSET_ASCII {
                if outleft < 3 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, ESC);
                outbyte(outbuf, 1, 0x28);
                outbyte(outbuf, 2, 0x42);
                set_state_byte(state, 0, CHARSET_ASCII);
                next_out(outbuf, 3);
                outleft -= 3;
            }
            if state_flag(state, F_SHIFTED) {
                if outleft < 1 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, SI);
                clear_state_flag(state, F_SHIFTED);
                next_out(outbuf, 1);
                outleft -= 1;
            }
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
        encoded = MAP_UNMAPPABLE;
        dsg = designations(codec);
        while dsg.view(1)[0].mark != 0 {
            scratch.view(1)[0].buf0 = u32(c);
            scratch.view(1)[0].buf1 = u32(0);
            scratch.view(1)[0].length = 1;
            encoded = call_encoder(dsg, codec, scratch);
            if encoded == MAP_MULTIPLE_AVAIL {
                # this implementation won't work for pair
                # of non-bmp characters.
                if inlen - inpos.view(1)[0] < 2 {
                    if (flags & MBENC_FLUSH) == 0 {
                        return MBERR_TOOFEW;
                    }
                    scratch.view(1)[0].length = -1;
                } else {
                    scratch.view(1)[0].buf1 = u32(inchar(kind, data, inpos, 1));
                    scratch.view(1)[0].length = 2;
                }
                encoded = call_encoder(dsg, codec, scratch);
                if encoded != MAP_UNMAPPABLE {
                    insize = int(scratch.view(1)[0].length);
                    break;
                }
            } elif encoded != MAP_UNMAPPABLE {
                break;
            }
            dsg += 1;
        }
        item = dsg.view(1)[0];
        mark = int(item.mark);
        if mark == 0 {
            return 1;
        }
        plane = int(item.plane);
        width = int(item.width);
        if plane == 0 {
            # G0
            if state_flag(state, F_SHIFTED) {
                if outleft < 1 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, SI);
                clear_state_flag(state, F_SHIFTED);
                next_out(outbuf, 1);
                outleft -= 1;
            }
            if state_byte(state, 0) != mark {
                if width == 1 {
                    if outleft < 3 {
                        return MBERR_TOOSMALL;
                    }
                    outbyte(outbuf, 0, ESC);
                    outbyte(outbuf, 1, 0x28);
                    outbyte(outbuf, 2, mark & 0x7F);
                    set_state_byte(state, 0, mark);
                    next_out(outbuf, 3);
                    outleft -= 3;
                } elif mark == CHARSET_JISX0208 {
                    if outleft < 3 {
                        return MBERR_TOOSMALL;
                    }
                    outbyte(outbuf, 0, ESC);
                    outbyte(outbuf, 1, 0x24);
                    outbyte(outbuf, 2, mark & 0x7F);
                    set_state_byte(state, 0, mark);
                    next_out(outbuf, 3);
                    outleft -= 3;
                } else {
                    if outleft < 4 {
                        return MBERR_TOOSMALL;
                    }
                    outbyte(outbuf, 0, ESC);
                    outbyte(outbuf, 1, 0x24);
                    outbyte(outbuf, 2, 0x28);
                    outbyte(outbuf, 3, mark & 0x7F);
                    set_state_byte(state, 0, mark);
                    next_out(outbuf, 4);
                    outleft -= 4;
                }
            }
        } elif plane == 1 {
            # G1
            if state_byte(state, 1) != mark {
                if width == 1 {
                    if outleft < 3 {
                        return MBERR_TOOSMALL;
                    }
                    outbyte(outbuf, 0, ESC);
                    outbyte(outbuf, 1, 0x29);
                    outbyte(outbuf, 2, mark & 0x7F);
                    set_state_byte(state, 1, mark);
                    next_out(outbuf, 3);
                    outleft -= 3;
                } else {
                    if outleft < 4 {
                        return MBERR_TOOSMALL;
                    }
                    outbyte(outbuf, 0, ESC);
                    outbyte(outbuf, 1, 0x24);
                    outbyte(outbuf, 2, 0x29);
                    outbyte(outbuf, 3, mark & 0x7F);
                    set_state_byte(state, 1, mark);
                    next_out(outbuf, 4);
                    outleft -= 4;
                }
            }
            if not state_flag(state, F_SHIFTED) {
                if outleft < 1 {
                    return MBERR_TOOSMALL;
                }
                outbyte(outbuf, 0, SO);
                set_state_flag(state, F_SHIFTED);
                next_out(outbuf, 1);
                outleft -= 1;
            }
        } else {
            # G2 and G3 is not supported: no encoding in
            # CJKCodecs are using them yet
            return MBERR_INTERNAL;
        }
        if width == 1 {
            if outleft < 1 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, encoded);
            next_out(outbuf, 1);
            outleft -= 1;
        } else {
            if outleft < 2 {
                return MBERR_TOOSMALL;
            }
            outbyte(outbuf, 0, encoded >> 8);
            outbyte(outbuf, 1, encoded & 0xFF);
            next_out(outbuf, 2);
            outleft -= 2;
        }
        next_inchar(inpos, insize);
    }
    return 0;
}

def iso2022_decode_init(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i32 {
    set_state_byte(state, 4, 0);
    set_state_byte(state, 0, CHARSET_ASCII);
    set_state_byte(state, 1, CHARSET_ASCII);
    set_state_byte(state, 2, CHARSET_ASCII);
    return i32(0);
}

def iso2022_decode_reset(
    state: ptr[MultibyteCodec_State], codec: ptr[MultibyteCodec]
) -> i64 {
    set_state_byte(state, 0, CHARSET_ASCII);
    clear_state_flag(state, F_SHIFTED);
    return 0;
}

# iso2022processesc: 0 when the escape sequence at the input designated a
# charset (the input advanced past it), else the decoder's error result.
def:priv iso2022processesc(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    inbuf: ptr[ptr[u8]],
    inleft: i64
) -> tuple[i64, i64] {
    esclen = 0;
    i = 1;
    while i < MAX_ESCSEQLEN {
        if i >= inleft {
            return (MBERR_TOOFEW, inleft);
        }
        if is_escend(inbyte(inbuf, i)) {
            esclen = i + 1;
            break;
        } elif config_isset(codec, USE_JISX0208_EXT)
            and i + 1 < inleft
            and inbyte(inbuf, i) == 0x26
            and inbyte(inbuf, i + 1) == 0x40 {
            i += 2;
        }
        i += 1;
    }
    charset = 0;
    designation = 0;
    if esclen == 0 {
        # unterminated escape sequence
        return (1, inleft);
    } elif esclen == 3 {
        if inbyte(inbuf, 1) == 0x24 {
            charset = inbyte(inbuf, 2) | CHARSET_DBCS;
            designation = 0;
        } else {
            charset = inbyte(inbuf, 2);
            if inbyte(inbuf, 1) == 0x28 {
                designation = 0;
            } elif inbyte(inbuf, 1) == 0x29 {
                designation = 1;
            } elif config_isset(codec, USE_G2) and inbyte(inbuf, 1) == 0x2E {
                designation = 2;
            } else {
                return (3, inleft);
            }
        }
    } elif esclen == 4 {
        if inbyte(inbuf, 1) != 0x24 {
            return (4, inleft);
        }
        charset = inbyte(inbuf, 3) | CHARSET_DBCS;
        if inbyte(inbuf, 2) == 0x28 {
            designation = 0;
        } elif inbyte(inbuf, 2) == 0x29 {
            designation = 1;
        } else {
            return (4, inleft);
        }
    } elif esclen == 6 {
        # designation with prefix
        if config_isset(codec, USE_JISX0208_EXT)
            and inbyte(inbuf, 3) == ESC
            and inbyte(inbuf, 4) == 0x24
            and inbyte(inbuf, 5) == 0x42 {
            charset = 0x42 | CHARSET_DBCS;
            designation = 0;
        } else {
            return (6, inleft);
        }
    } else {
        return (esclen, inleft);
    }
    # raise error when the charset is not designated for this encoding
    if charset != CHARSET_ASCII {
        dsg = designations(codec);
        while dsg.view(1)[0].mark != 0 {
            if int(dsg.view(1)[0].mark) == charset {
                break;
            }
            dsg += 1;
        }
        if dsg.view(1)[0].mark == 0 {
            return (esclen, inleft);
        }
    }
    set_state_byte(state, designation, charset);
    next_in(inbuf, esclen);
    return (0, inleft - esclen);
}

# ISO8859_7_DECODE: the code point of `c`, or -1.
def:priv iso8859_7_decode(c: int) -> int {
    if c < 0xA0 {
        return c;
    }
    if c < 0xC0 and (0x288F3BC9 & (1 << (c - 0xA0))) != 0 {
        return c;
    }
    if c >= 0xB4
        and c <= 0xFE
        and (c >= 0xD4 or (0xBFFFFD77 & (1 << (c - 0xB4))) != 0) {
        return 0x02D0 + c;
    }
    if c == 0xA1 {
        return 0x2018;
    }
    if c == 0xA2 {
        return 0x2019;
    }
    if c == 0xAF {
        return 0x2015;
    }
    return -1;
}

# iso2022processg2: not written to use encoder, decoder functions because
# only few encodings use G2 designations in CJKCodecs.
def:priv iso2022processg2(
    codec: ptr[MultibyteCodec],
    state: ptr[MultibyteCodec_State],
    inbuf: ptr[ptr[u8]],
    writer: ptr[DecodeWriter]
) -> i64 {
    g2 = state_byte(state, 2);
    c3 = inbyte(inbuf, 2);
    decoded = -1;
    if g2 == CHARSET_ISO8859_1 {
        if c3 >= 0x80 {
            return 3;
        }
        decoded = c3 + 0x80;
    } elif g2 == CHARSET_ISO8859_7 {
        decoded = iso8859_7_decode(c3 ^ 0x80);
        if decoded < 0 {
            return 3;
        }
    } elif g2 == CHARSET_ASCII {
        if (c3 & 0x80) != 0 {
            return 3;
        }
        decoded = c3;
    } else {
        return MBERR_INTERNAL;
    }
    if not outchar(writer, decoded) {
        return MBERR_EXCEPTION;
    }
    next_in(inbuf, 3);
    return 0;
}

def iso2022_decode(
    state: ptr[MultibyteCodec_State],
    codec: ptr[MultibyteCodec],
    inbuf: ptr[ptr[u8]],
    inleft: i64,
    writer: ptr[DecodeWriter]
) -> i64 {
    dsgcache = ptr[Iso2022Designation]();
    while inleft > 0 {
        c = inbyte(inbuf, 0);
        if state_flag(state, F_ESCTHROUGHOUT) {
            # ESC throughout mode:
            # for non-iso2022 escape sequences
            # assume as ISO-8859-1
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
            if is_escend(c) {
                clear_state_flag(state, F_ESCTHROUGHOUT);
            }
            continue;
        }
        bypass = False;
        if c == ESC {
            if inleft < 2 {
                return MBERR_TOOFEW;
            }
            if is_iso2022esc(inbyte(inbuf, 1)) {
                (err, inleft) = iso2022processesc(codec, state, inbuf, inleft);
                if err != 0 {
                    return err;
                }
            } elif config_isset(codec, USE_G2) and inbyte(inbuf, 1) == 0x4E {
                # SS2
                if inleft < 3 {
                    return MBERR_TOOFEW;
                }
                err = iso2022processg2(codec, state, inbuf, writer);
                if err != 0 {
                    return err;
                }
                inleft -= 3;
            } else {
                if not outchar(writer, ESC) {
                    return MBERR_EXCEPTION;
                }
                set_state_flag(state, F_ESCTHROUGHOUT);
                next_in(inbuf, 1);
                inleft -= 1;
            }
        } elif c == SI {
            if config_isset(codec, NO_SHIFT) {
                bypass = True;
            } else {
                clear_state_flag(state, F_SHIFTED);
                next_in(inbuf, 1);
                inleft -= 1;
            }
        } elif c == SO {
            if config_isset(codec, NO_SHIFT) {
                bypass = True;
            } else {
                set_state_flag(state, F_SHIFTED);
                next_in(inbuf, 1);
                inleft -= 1;
            }
        } elif c == LF {
            clear_state_flag(state, F_SHIFTED);
            if not outchar(writer, LF) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
        } elif c < 0x20 {
            # C0
            bypass = True;
        } elif c >= 0x80 {
            return 1;
        } else {
            charset = state_byte(state, 1)
                if state_flag(state, F_SHIFTED)
                else state_byte(state, 0);
            if charset == CHARSET_ASCII {
                bypass = True;
            } else {
                dsg = ptr[Iso2022Designation]();
                if not dsgcache.is_null()
                    and int(dsgcache.view(1)[0].mark) == charset {
                    dsg = dsgcache;
                } else {
                    dsg = designations(codec);
                    while int(dsg.view(1)[0].mark) != charset {
                        dsg += 1;
                    }
                    dsgcache = dsg;
                }
                width = int(dsg.view(1)[0].width);
                if inleft < width {
                    return MBERR_TOOFEW;
                }
                decoded = int(dsg.view(1)[0].decoder(codec, inbuf.view(1)[0]));
                if decoded == MAP_UNMAPPABLE {
                    return width;
                }
                written = True;
                if decoded < 0x30000 {
                    written = outchar(writer, decoded);
                } else {
                    # JIS X 0213 pairs
                    written = outchar2(writer, decoded >> 16, decoded & 0xFFFF);
                }
                if not written {
                    return MBERR_EXCEPTION;
                }
                next_in(inbuf, width);
                inleft -= width;
            }
        }
        if bypass {
            if not outchar(writer, c) {
                return MBERR_EXCEPTION;
            }
            next_in(inbuf, 1);
            inleft -= 1;
        }
    }
    return 0;
}

# mapping access functions

def:priv data_at(data: ptr[u8], index: int) -> int {
    return int((data + index).view(1)[0]);
}

def ksx1001_init(codec: ptr[MultibyteCodec]) -> i32 {
    if not import_map(KR_CP949, "kr", "cp949")
        or not import_map(KR_KSX1001, "kr", "ksx1001") {
        return i32(-1);
    }
    return i32(0);
}

def ksx1001_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = map_decode(imported(KR_KSX1001), data_at(data, 0), data_at(data, 1));
    return u32(MAP_UNMAPPABLE if u == UNIINV else u);
}

def ksx1001_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    c = int(data.view(1)[0]);
    if c < 0x10000 {
        coded = map_encode(imported(KR_CP949), c);
        if coded != NOCHAR and (coded & 0x8000) == 0 {
            return u16(coded);
        }
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0208_init(codec: ptr[MultibyteCodec]) -> i32 {
    if not import_map(JP_JISXCOMMON, "jp", "jisxcommon")
        or not import_map(JP_JISX0208, "jp", "jisx0208") {
        return i32(-1);
    }
    return i32(0);
}

def jisx0208_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    # F/W REVERSE SOLIDUS
    if data_at(data, 0) == 0x21 and data_at(data, 1) == 0x40 {
        return u32(0xFF3C);
    }
    u = map_decode(imported(JP_JISX0208), data_at(data, 0), data_at(data, 1));
    return u32(MAP_UNMAPPABLE if u == UNIINV else u);
}

def jisx0208_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    c = int(data.view(1)[0]);
    if c < 0x10000 {
        # F/W REVERSE SOLIDUS
        if c == 0xFF3C {
            return u16(0x2140);
        }
        coded = map_encode(imported(JP_JISXCOMMON), c);
        if coded != NOCHAR and (coded & 0x8000) == 0 {
            return u16(coded);
        }
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0212_init(codec: ptr[MultibyteCodec]) -> i32 {
    if not import_map(JP_JISXCOMMON, "jp", "jisxcommon")
        or not import_map(JP_JISX0212, "jp", "jisx0212") {
        return i32(-1);
    }
    return i32(0);
}

def jisx0212_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = map_decode(imported(JP_JISX0212), data_at(data, 0), data_at(data, 1));
    return u32(MAP_UNMAPPABLE if u == UNIINV else u);
}

def jisx0212_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    c = int(data.view(1)[0]);
    if c < 0x10000 {
        coded = map_encode(imported(JP_JISXCOMMON), c);
        if coded != NOCHAR and (coded & 0x8000) != 0 {
            return u16(coded & 0x7FFF);
        }
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0213_init(codec: ptr[MultibyteCodec]) -> i32 {
    if jisx0208_init(codec) != 0
        or not import_map(JP_JISX0213_BMP, "jp", "jisx0213_bmp")
        or not import_map(JP_JISX0213_1_BMP, "jp", "jisx0213_1_bmp")
        or not import_map(JP_JISX0213_2_BMP, "jp", "jisx0213_2_bmp")
        or not import_map(JP_JISX0213_EMP, "jp", "jisx0213_emp")
        or not import_map(JP_JISX0213_1_EMP, "jp", "jisx0213_1_emp")
        or not import_map(JP_JISX0213_2_EMP, "jp", "jisx0213_2_emp")
        or not import_map(JP_JISX0213_PAIR, "jp", "jisx0213_pair") {
        return i32(-1);
    }
    return i32(0);
}

def:priv pair_code(body: int, modifier: int) -> int {
    return find_pairencmap(
        body,
        modifier,
        ptr[PairEncodeMap](imported(JP_JISX0213_PAIR).view(1)[0].encdata),
        JISX0213_ENCPAIRS
    );
}

# The JIS X 0213 plane 1 decoding the 2000 and 2004 decoders share.
def:priv jisx0213_1_decode(data: ptr[u8]) -> int {
    c1 = data_at(data, 0);
    c2 = data_at(data, 1);
    # F/W REVERSE SOLIDUS
    if c1 == 0x21 and c2 == 0x40 {
        return 0xFF3C;
    }
    u = map_decode(imported(JP_JISX0208), c1, c2);
    if u != UNIINV {
        return u;
    }
    u = map_decode(imported(JP_JISX0213_1_BMP), c1, c2);
    if u != UNIINV {
        return u;
    }
    u = map_decode(imported(JP_JISX0213_1_EMP), c1, c2);
    if u != UNIINV {
        return u | 0x20000;
    }
    u = map_decode_wide(imported(JP_JISX0213_PAIR), c1, c2);
    if u != UNIINV {
        return u;
    }
    return MAP_UNMAPPABLE;
}

def:priv jisx0213_2_decode(data: ptr[u8]) -> int {
    c1 = data_at(data, 0);
    c2 = data_at(data, 1);
    u = map_decode(imported(JP_JISX0213_2_BMP), c1, c2);
    if u != UNIINV {
        return u;
    }
    u = map_decode(imported(JP_JISX0213_2_EMP), c1, c2);
    if u != UNIINV {
        return u | 0x20000;
    }
    return MAP_UNMAPPABLE;
}

def jisx0213_2000_1_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    if emulate_2000_decode_plane1(ptr(2000), data_at(data, 0), data_at(data, 1)) {
        return u32(MAP_UNMAPPABLE);
    }
    return u32(jisx0213_1_decode(data));
}

def jisx0213_2000_2_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = jisx0213_2_decode(data);
    # EMULATE_JISX0213_2000_DECODE_PLANE2_CHAR only sets u; the lookups
    # after it (not else-chained) decide.
    return u32(u);
}

def jisx0213_2004_1_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    return u32(jisx0213_1_decode(data));
}

def jisx0213_2004_2_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    return u32(jisx0213_2_decode(data));
}

# jisx0213_encoder: `config` is (void *)2000 or NULL.
def:priv jisx0213_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64], config: ptr
) -> int {
    c = int(data.view(1)[0]);
    size = int(length.view(1)[0]);
    if size == 1 {
        # first character
        if c >= 0x10000 {
            if (c >> 16) == (0x20000 >> 16) {
                if emulate_2000_encode_emp(config, c) {
                    return MAP_UNMAPPABLE;
                }
                coded = map_encode(imported(JP_JISX0213_EMP), c & 0xFFFF);
                if coded != NOCHAR {
                    return coded;
                }
            }
            return MAP_UNMAPPABLE;
        }
        emulated = emulate_2000_encode_bmp(config, c);
        if emulated == -1 {
            return MAP_UNMAPPABLE;
        }
        if emulated != 0 {
            return emulated;
        }
        coded = map_encode(imported(JP_JISX0213_BMP), c);
        if coded != NOCHAR {
            if coded == MULTIC {
                return MAP_MULTIPLE_AVAIL;
            }
            return coded;
        }
        coded = map_encode(imported(JP_JISXCOMMON), c);
        if coded != NOCHAR {
            if (coded & 0x8000) != 0 {
                return MAP_UNMAPPABLE;
            }
            return coded;
        }
        return MAP_UNMAPPABLE;
    }
    if size == 2 or size == -1 {
        # second character of unicode pair
        c2 = int((data + 1).view(1)[0]);
        # Don't consume null char as part of pair
        if size == 2 and c2 != 0 {
            coded = pair_code(c, c2);
            if coded != DBCINV {
                return coded;
            }
        }
        # flush unterminated
        length.view(1)[0] = 1;
        coded = pair_code(c, 0);
        return MAP_UNMAPPABLE if coded == DBCINV else coded;
    }
    return MAP_UNMAPPABLE;
}

def jisx0213_2000_1_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0213_encoder(codec, data, length, ptr(2000));
    if coded == MAP_UNMAPPABLE or coded == MAP_MULTIPLE_AVAIL {
        return u16(coded);
    }
    if (coded & 0x8000) != 0 {
        return u16(MAP_UNMAPPABLE);
    }
    return u16(coded);
}

def:priv paironly(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64], config: ptr
) -> u16 {
    ilength = int(length.view(1)[0]);
    coded = jisx0213_encoder(codec, data, length, config);
    if ilength == 1 {
        return u16(
            MAP_MULTIPLE_AVAIL if coded == MAP_MULTIPLE_AVAIL else MAP_UNMAPPABLE
        );
    }
    if ilength == 2 {
        if int(length.view(1)[0]) != 2 {
            return u16(MAP_UNMAPPABLE);
        }
        return u16(coded);
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0213_2000_1_encoder_paironly(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    return paironly(codec, data, length, ptr(2000));
}

def jisx0213_2000_2_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0213_encoder(codec, data, length, ptr(2000));
    if coded == MAP_UNMAPPABLE or coded == MAP_MULTIPLE_AVAIL {
        return u16(coded);
    }
    if (coded & 0x8000) != 0 {
        return u16(coded & 0x7FFF);
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0213_2004_1_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0213_encoder(codec, data, length, ptr());
    if coded == MAP_UNMAPPABLE or coded == MAP_MULTIPLE_AVAIL {
        return u16(coded);
    }
    if (coded & 0x8000) != 0 {
        return u16(MAP_UNMAPPABLE);
    }
    return u16(coded);
}

def jisx0213_2004_1_encoder_paironly(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    return paironly(codec, data, length, ptr());
}

def jisx0213_2004_2_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0213_encoder(codec, data, length, ptr());
    if coded == MAP_UNMAPPABLE or coded == MAP_MULTIPLE_AVAIL {
        return u16(coded);
    }
    if (coded & 0x8000) != 0 {
        return u16(coded & 0x7FFF);
    }
    return u16(MAP_UNMAPPABLE);
}

def jisx0201_r_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = jisx0201_r_decode(data_at(data, 0));
    return u32(MAP_UNMAPPABLE if u < 0 else u);
}

def jisx0201_r_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0201_r_encode(int(data.view(1)[0]));
    return u16(MAP_UNMAPPABLE if coded < 0 else coded);
}

def jisx0201_k_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = jisx0201_k_decode(data_at(data, 0) ^ 0x80);
    return u32(MAP_UNMAPPABLE if u < 0 else u);
}

def jisx0201_k_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    coded = jisx0201_k_encode(int(data.view(1)[0]));
    return u16(MAP_UNMAPPABLE if coded < 0 else coded - 0x80);
}

def gb2312_init(codec: ptr[MultibyteCodec]) -> i32 {
    if not import_map(CN_GBCOMMON, "cn", "gbcommon")
        or not import_map(CN_GB2312, "cn", "gb2312") {
        return i32(-1);
    }
    return i32(0);
}

def gb2312_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    u = map_decode(imported(CN_GB2312), data_at(data, 0), data_at(data, 1));
    return u32(MAP_UNMAPPABLE if u == UNIINV else u);
}

def gb2312_encoder(
    codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]
) -> u16 {
    c = int(data.view(1)[0]);
    if c < 0x10000 {
        coded = map_encode(imported(CN_GBCOMMON), c);
        if coded != NOCHAR and (coded & 0x8000) == 0 {
            return u16(coded);
        }
    }
    return u16(MAP_UNMAPPABLE);
}

def dummy_decoder(codec: ptr[MultibyteCodec], data: ptr[u8]) -> u32 {
    return u32(MAP_UNMAPPABLE);
}

def dummy_encoder(codec: ptr[MultibyteCodec], data: ptr[u32], length: ptr[i64]) -> u16 {
    return u16(MAP_UNMAPPABLE);
}

# registry tables
import from c {
    glob:priv iso2022_kr_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_KSX1001),
                 plane=u8(1),
                 width=u8(2),
                 initializer=ksx1001_init,
                 decoder=ksx1001_decoder,
                 encoder=ksx1001_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0201_R),
                 plane=u8(0),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=jisx0201_r_decoder,
                 encoder=jisx0201_r_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208_O),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_1_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0212),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0212_init,
                 decoder=jisx0212_decoder,
                 encoder=jisx0212_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0201_R),
                 plane=u8(0),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=jisx0201_r_decoder,
                 encoder=jisx0201_r_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208_O),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_2_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0212),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0212_init,
                 decoder=jisx0212_decoder,
                 encoder=jisx0212_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_KSX1001),
                 plane=u8(0),
                 width=u8(2),
                 initializer=ksx1001_init,
                 decoder=ksx1001_decoder,
                 encoder=ksx1001_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_GB2312),
                 plane=u8(0),
                 width=u8(2),
                 initializer=gb2312_init,
                 decoder=gb2312_decoder,
                 encoder=gb2312_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0201_R),
                 plane=u8(0),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=jisx0201_r_decoder,
                 encoder=jisx0201_r_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208_O),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_ISO8859_1),
                 plane=u8(2),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=dummy_decoder,
                 encoder=dummy_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_ISO8859_7),
                 plane=u8(2),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=dummy_decoder,
                 encoder=dummy_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_2004_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2004_1),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2004_1_decoder,
                 encoder=jisx0213_2004_1_encoder_paironly
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2004_1),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2004_1_decoder,
                 encoder=jisx0213_2004_1_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2004_2_decoder,
                 encoder=jisx0213_2004_2_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_3_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2000_1),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2000_1_decoder,
                 encoder=jisx0213_2000_1_encoder_paironly
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2000_1),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2000_1_decoder,
                 encoder=jisx0213_2000_1_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0213_2),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0213_init,
                 decoder=jisx0213_2000_2_decoder,
                 encoder=jisx0213_2000_2_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_jp_ext_designations: list[Iso2022Designation] = [
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0212),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0212_init,
                 decoder=jisx0212_decoder,
                 encoder=jisx0212_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0201_R),
                 plane=u8(0),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=jisx0201_r_decoder,
                 encoder=jisx0201_r_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0201_K),
                 plane=u8(0),
                 width=u8(1),
                 initializer=no_codec_init,
                 decoder=jisx0201_k_decoder,
                 encoder=jisx0201_k_encoder
             ),
             Iso2022Designation(
                 mark=u8(CHARSET_JISX0208_O),
                 plane=u8(0),
                 width=u8(2),
                 initializer=jisx0208_init,
                 decoder=jisx0208_decoder,
                 encoder=jisx0208_encoder
             ),
             Iso2022Designation()
         ],
         iso2022_kr_config: Iso2022Config = Iso2022Config(
             flags=i32(0), designations=addressof(iso2022_kr_designations)
         ),
         iso2022_jp_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_designations)
         ),
         iso2022_jp_1_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_1_designations)
         ),
         iso2022_jp_2_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_G2 | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_2_designations)
         ),
         iso2022_jp_2004_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_2004_designations)
         ),
         iso2022_jp_3_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_3_designations)
         ),
         iso2022_jp_ext_config: Iso2022Config = Iso2022Config(
             flags=NO_SHIFT | USE_JISX0208_EXT,
             designations=addressof(iso2022_jp_ext_designations)
         );
}

import from c {
    glob iso2022_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_kr"),
                 config=addressof(iso2022_kr_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp"),
                 config=addressof(iso2022_jp_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp_1"),
                 config=addressof(iso2022_jp_1_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp_2"),
                 config=addressof(iso2022_jp_2_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp_2004"),
                 config=addressof(iso2022_jp_2004_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp_3"),
                 config=addressof(iso2022_jp_3_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("iso2022_jp_ext"),
                 config=addressof(iso2022_jp_ext_config),
                 codecinit=iso2022_codec_init,
                 encode=iso2022_encode,
                 encinit=iso2022_encode_init,
                 encreset=iso2022_encode_reset,
                 decode=iso2022_decode,
                 decinit=iso2022_decode_init,
                 decreset=iso2022_decode_reset
             )
         ];
}

def codecs_iso2022_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(iso2022_codecs), 7, encoding);
}

# no mapping table here
def codecs_iso2022_exec(module: ptr[PyObject]) -> i32 {
    return i32(0);
}
