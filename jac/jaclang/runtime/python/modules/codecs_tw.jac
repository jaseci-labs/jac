"""The _codecs_tw module: Modules/cjkcodecs/_codecs_tw.c (Taiwan's
encodings, big5 and cp950) in native Jac. See ../LICENSE.cpython.
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
import from jaclang.runtime.python.modules.cjkcodecs_mappings_tw {
    CJK_TW_MAPPINGS,
    cjk_big5_map,
    cjk_cp950ext_map,
    cjk_tw_mappings
}

# BIG5 codec

def big5_encode(
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
        code = map_encode(addressof(cjk_big5_map), c);
        if code == NOCHAR {
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

def big5_decode(
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
        decoded = map_decode(addressof(cjk_big5_map), c, inbyte(inbuf, 1));
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

# CP950 codec

def cp950_encode(
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
        code = map_encode(addressof(cjk_cp950ext_map), c);
        if code == NOCHAR {
            code = map_encode(addressof(cjk_big5_map), c);
            if code == NOCHAR {
                return 1;
            }
        }
        outbyte(outbuf, 0, code >> 8);
        outbyte(outbuf, 1, code & 0xFF);
        next_inchar(inpos, 1);
        next_out(outbuf, 2);
        outleft -= 2;
    }
    return 0;
}

def cp950_decode(
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
        decoded = map_decode(addressof(cjk_cp950ext_map), c, c2);
        if decoded == UNIINV {
            decoded = map_decode(addressof(cjk_big5_map), c, c2);
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

import from c {
    glob tw_codecs: list[MultibyteCodec] = [
             MultibyteCodec(
                 encoding=ptr[u8]("big5"),
                 codecinit=no_codec_init,
                 encode=big5_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=big5_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             ),
             MultibyteCodec(
                 encoding=ptr[u8]("cp950"),
                 codecinit=no_codec_init,
                 encode=cp950_encode,
                 encinit=no_state_init,
                 encreset=no_encode_reset,
                 decode=cp950_decode,
                 decinit=no_state_init,
                 decreset=no_decode_reset
             )
         ];
}

def codecs_tw_getcodec(
    module: ptr[PyObject], encoding: ptr[PyObject]
) -> ptr[PyObject] {
    return getcodec(module, addressof(tw_codecs), 2, encoding);
}

def codecs_tw_exec(module: ptr[PyObject]) -> i32 {
    return register_maps(module, addressof(cjk_tw_mappings), CJK_TW_MAPPINGS);
}
