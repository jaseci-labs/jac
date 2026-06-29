import from _zlib_native {
    z_compress2,
    z_uncompress,
    z_compress_bound,
    z_crc32,
    z_adler32
}

glob Z_OK: int = 0,
     Z_BUF_ERROR: int = -5;


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


def:pub decompress(data: bytes) -> bytes {
    source_len: int = len(data);
    if source_len == 0 {
        return b"";
    }
    cap: int = source_len * 4;
    if cap < 256 {
        cap = 256;
    }

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
