import from _bz2_native { bz2_compress, bz2_decompress }

glob BZ_OK: int = 0,
     BZ_OUTBUFF_FULL: int = -8;


def:pub compress(data: bytes, compresslevel: int = 9) -> bytes {
    source_len: int = len(data);

    bound: int = source_len + (source_len // 100) + 600;
    if bound > 4294967295 {
        raise ValueError("bz2.compress: input too large for libbz2 one-shot API");
    }
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(4, "little");
    rc: int = bz2_compress(dest, dest_len, data, source_len, compresslevel);
    if rc != BZ_OK {
        raise ValueError("bz2.compress: libbz2 error code " + str(rc));
    }
    return dest[0:int.from_bytes(dest_len, "little")];
}


def:pub decompress(data: bytes) -> bytes {
    source_len: int = len(data);
    if source_len == 0 {
        return b"";
    }
    if source_len > 4294967295 {
        raise ValueError("bz2.decompress: input too large for libbz2 one-shot API");
    }
    cap: int = source_len * 4;
    if cap < 256 {
        cap = 256;
    }

    ceiling: int = (source_len * 1024) + 67108864;
    if ceiling > 4294967295 {
        ceiling = 4294967295;
    }
    if cap > ceiling {
        cap = ceiling;
    }
    while True {
        dest = b"\x00" * cap;
        dest_len = cap.to_bytes(4, "little");
        rc: int = bz2_decompress(dest, dest_len, data, source_len);
        if rc == BZ_OK {
            return dest[0:int.from_bytes(dest_len, "little")];
        }
        if rc == BZ_OUTBUFF_FULL {
            if cap < ceiling {
                cap = cap * 2;
                if cap > ceiling {
                    cap = ceiling;
                }
                continue;
            }

            raise ValueError(
                "bz2.decompress: decompressed output exceeds the one-shot API limit"
            );
        }
        raise ValueError(
            "bz2.decompress: invalid or truncated stream (libbz2 error code " + str(
                rc
            ) + ")"
        );
    }
}
