"""Bundled native `zlib` cross-backend equivalence fixture (#6940 Phase 2).

The SAME `import from zlib { ... }` binds CPython's `zlib` on the sv (Python)
backend and the bundled `na_stdlib/zlib.na.jac` Mechanism-F module — a thin
pure-Jac surface over the system `libz` (the FFI floor) — on the na (native
LLVM) backend. This fixture pins the two implementations congruent on the
one-shot DEFLATE surface: `compress` produces byte-identical output (asserted
through `crc32` of the compressed stream), `decompress` round-trips, and the
`crc32` / `adler32` checksums (with and without a continuation seed) match
CPython exactly. ES/JS opts out.
"""

import from zlib { compress, decompress, crc32, adler32 }

def zlib_py() -> dict {
    data = b"hello world, hello world, hello zlib zlib zlib!";
    comp = compress(data, 6);
    back = decompress(comp);
    empty_rt = decompress(compress(b"", 6));
    return {
        "crc_basic": crc32(b"hello"),
        "crc_seed": crc32(b"world", crc32(b"hello")),
        "crc_empty": crc32(b""),
        "adler_basic": adler32(b"hello"),
        "adler_seed": adler32(b"world", adler32(b"hello")),
        "comp_crc": crc32(comp),
        "comp_smaller": 1 if len(comp) < len(data) else 0,
        "roundtrip_ok": 1 if back == data else 0,
        "roundtrip_len": len(back),
        "decomp_crc": crc32(back),
        "empty_ok": 1 if empty_rt == b"" else 0,
    };
}

cl def zlib_cl() -> dict {
    return {};
}

na {
    def zlib_na() -> dict[str, any] {
        data = b"hello world, hello world, hello zlib zlib zlib!";
        comp = compress(data, 6);
        back = decompress(comp);
        empty_rt = decompress(compress(b"", 6));
        return {
            "crc_basic": crc32(b"hello"),
            "crc_seed": crc32(b"world", crc32(b"hello")),
            "crc_empty": crc32(b""),
            "adler_basic": adler32(b"hello"),
            "adler_seed": adler32(b"world", adler32(b"hello")),
            "comp_crc": crc32(comp),
            "comp_smaller": 1 if len(comp) < len(data) else 0,
            "roundtrip_ok": 1 if back == data else 0,
            "roundtrip_len": len(back),
            "decomp_crc": crc32(back),
            "empty_ok": 1 if empty_rt == b"" else 0,
        };
    }
}
