import from _zlib_native {
    ZInflateResult,
    Z_OK,
    Z_STREAM_END,
    Z_MEM_ERROR,
    z_compress2,
    z_compress_bound,
    z_crc32,
    z_adler32,
    z_inflate_all,
    z_inflate_bound
}


def:pub crc32(data: bytes, value: int = 0) -> int {
    return z_crc32(value, data, len(data));
}


def:pub adler32(data: bytes, value: int = 1) -> int {
    return z_adler32(value, data, len(data));
}


def:pub compress(data: bytes, level: int = -1) -> bytes {
    source_len: int = len(data);

    bound: int = z_compress_bound(source_len);
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(8, "little");
    rc: int = z_compress2(dest, dest_len, data, source_len, level);
    if rc != Z_OK {
        raise ValueError("zlib.compress: libz error code " + str(rc));
    }
    return dest[0:int.from_bytes(dest_len, "little")];
}


def:pub decompress(data: bytes | bytearray) -> bytes {
    source: bytes;
    if isinstance(data, bytearray) {
        source = bytes(data);
    } else {
        source = data;
    }
    source_len: int = len(source);

    cap: int = source_len * 4;
    if cap < 8192 {
        cap = 8192;
    }
    ceiling: int = z_inflate_bound(source_len, 67108864);
    res: ZInflateResult = z_inflate_all(source, 0, source_len, 15, cap, ceiling);
    if res.status == Z_STREAM_END {
        return res.data;
    }
    if res.status == Z_MEM_ERROR {
        raise MemoryError("zlib.decompress: allocation failed");
    }
    if not res.init_ok {
        raise ValueError(
            "zlib.decompress: inflate init failed (libz error code "
                + str(res.status)
                + ")"
        );
    }
    raise ValueError(
        "zlib.decompress: invalid or truncated stream (libz error code "
            + str(res.status)
            + ")"
    );
}
