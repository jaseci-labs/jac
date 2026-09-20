"""Zlib: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import from zlib { compress, decompress, crc32, adler32 }

def zlib_py() -> dict[any, any] {
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

def zlib_cl() -> dict[any, any] {
    return {};
}


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
