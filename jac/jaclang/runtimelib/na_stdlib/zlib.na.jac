"""Bundled native `zlib` — pure-Jac surface over the libz FFI floor.

Part of the native standard library shipped under
`jaclang/runtimelib/na_stdlib` (issue #6940 Phase 2). On the native (na)
pathway `import from zlib { compress, decompress, crc32, adler32 }` resolves to
this module through the shared bundled-stdlib resolver; on the sv/Python pathway
the identical import binds CPython's real `zlib`. The two are held congruent by
the tri-backend equivalence suite (prim_zlib.jac).

This is the Mechanism-F architecture from #6940: the DEFLATE engine is never
reimplemented — it is the system `libz`, reached through the thin FFI floor in
`_zlib_native.na.jac`. This module is the stable, Python-shaped API on top:
CPython argument orders and defaults (`crc32(data, value=0)`,
`adler32(data, value=1)`, `compress(data, level=-1)`), zlib-format
(RFC 1950, 15-bit window) compressed streams, and byte-for-byte congruent
output for a given level.

PORTABILITY: native-host-only (inherited from the libz floor). The raw DEFLATE
(negative-window) path that `zipfile` needs is a separate follow-up over a
persistent `z_stream` binding, tracked under #6940 Phase 2.
"""

import from _zlib_native {
    z_compress2,
    z_uncompress,
    z_compress_bound,
    z_crc32,
    z_adler32
}

# libz status codes (zlib.h).
glob Z_OK: int = 0,
     Z_BUF_ERROR: int = -5;


"""Compute the CRC-32 checksum of `data`, continuing from `value` (CPython
`zlib.crc32`). Returns the unsigned 32-bit checksum."""
def:pub crc32(data: bytes, value: int = 0) -> int {
    return z_crc32(value, data, len(data));
}


"""Compute the Adler-32 checksum of `data`, continuing from `value` (CPython
`zlib.adler32`; the initial value is 1, not 0). Returns the unsigned 32-bit
checksum."""
def:pub adler32(data: bytes, value: int = 1) -> int {
    return z_adler32(value, data, len(data));
}


"""Compress `data`, returning a zlib-format (RFC 1950) byte string. `level` is
0..9 or -1 for the library default (CPython `zlib.compress`)."""
def:pub compress(data: bytes, level: int = -1) -> bytes {
    source_len: int = len(data);
    # compressBound is the safe upper bound, so one shot always fits — no retry.
    bound: int = z_compress_bound(source_len);
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(8, "little");
    rc: int = z_compress2(dest, dest_len, data, source_len, level);
    if rc != Z_OK {
        raise ValueError("zlib.compress: libz error code " + str(rc));
    }
    return dest[0:int.from_bytes(dest_len, "little")];
}


"""Decompress a zlib-format (RFC 1950) byte string (CPython `zlib.decompress`).

libz's one-shot `uncompress` needs the output size up front, which a zlib
stream does not carry, so this starts from an input-relative estimate and
doubles the buffer on Z_BUF_ERROR until the whole stream fits — the same
grow-on-demand strategy CPython's decompressor uses internally. A hard ceiling
keeps a truncated or non-zlib stream from looping forever."""
def:pub decompress(data: bytes) -> bytes {
    source_len: int = len(data);
    if source_len == 0 {
        return b"";
    }
    cap: int = source_len * 4;
    if cap < 256 {
        cap = 256;
    }
    # Generous slack over any plausible legitimate expansion; past it the stream
    # is taken to be invalid/truncated rather than merely under-budgeted.
    ceiling: int = (source_len * 1024) + 67108864;
    while True {
        dest = b"\x00" * cap;
        dest_len = cap.to_bytes(8, "little");
        rc: int = z_uncompress(dest, dest_len, data, source_len);
        if rc == Z_OK {
            return dest[0:int.from_bytes(dest_len, "little")];
        }
        if rc == Z_BUF_ERROR and cap < ceiling {
            cap = cap * 2;
            continue;
        }
        raise ValueError(
            "zlib.decompress: invalid or truncated stream (libz error code " + str(
                rc
            ) + ")"
        );
    }
}
