import from _zlib_native {
    ZInflateResult,
    Z_OK,
    Z_STREAM_END,
    Z_MEM_ERROR,
    z_compress2,
    z_compress_bound,
    z_crc32,
    z_inflate_all,
    z_inflate_bound
}

glob _MASK32: int = 4294967295;


def:pub compress(data: bytes, compresslevel: int = 9, mtime: int = 0) -> bytes {
    source_len: int = len(data);

    bound: int = z_compress_bound(source_len);
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(8, "little");
    rc: int = z_compress2(dest, dest_len, data, source_len, compresslevel);
    if rc != Z_OK {
        raise ValueError("gzip.compress: zlib compression failed");
    }
    written: int = int.from_bytes(dest_len, "little");
    body = dest[2:written - 4];

    xfl: int = 0;
    if compresslevel == 9 {
        xfl = 2;
    } elif compresslevel >= 0 and compresslevel < 2 {
        xfl = 4;
    }

    header = b"\x1f\x8b\x08\x00"
        + (mtime & _MASK32).to_bytes(4, "little")
        + xfl.to_bytes(1, "little")
        + b"\xff";

    crc: int = z_crc32(0, data, source_len);
    trailer = (crc & _MASK32).to_bytes(4, "little")
        + (source_len & _MASK32).to_bytes(4, "little");

    return header + body + trailer;
}


def:pub decompress(data: bytes) -> bytes {
    n: int = len(data);
    if n == 0 {
        return b"";
    }

    result = b"";
    pos: int = 0;
    while pos < n {
        if data[pos] != 31 or (pos + 1 < n and data[pos + 1] != 139) {
            raise ValueError("gzip.decompress: not a gzip file (bad magic)");
        }
        if n - pos < 10 {
            raise ValueError("gzip.decompress: truncated gzip member header");
        }
        if data[pos + 2] != 8 {
            raise ValueError("gzip.decompress: unknown compression method");
        }

        flg: int = data[pos + 3];
        hpos: int = pos + 10;

        if (flg & 4) != 0 {
            if hpos + 2 > n {
                raise ValueError("gzip.decompress: truncated gzip member header");
            }
            xlen: int = int.from_bytes(data[hpos:hpos + 2], "little");
            hpos = hpos + 2 + xlen;
            if hpos > n {
                raise ValueError("gzip.decompress: truncated gzip member header");
            }
        }
        if (flg & 8) != 0 {
            while hpos < n and data[hpos] != 0 {
                hpos += 1;
            }
            if hpos >= n {
                raise ValueError("gzip.decompress: truncated gzip member header");
            }
            hpos += 1;
        }
        if (flg & 16) != 0 {
            while hpos < n and data[hpos] != 0 {
                hpos += 1;
            }
            if hpos >= n {
                raise ValueError("gzip.decompress: truncated gzip member header");
            }
            hpos += 1;
        }
        if (flg & 2) != 0 {
            hpos += 2;
        }

        if n - hpos < 10 {
            raise ValueError(
                "gzip.decompress: compressed data ended before the end-of-stream marker"
            );
        }

        remaining: int = n - hpos;
        ceiling: int = z_inflate_bound(remaining);
        cap: int = int.from_bytes(data[n - 4:n], "little");
        if cap < 64 {
            cap = 64;
        }
        if cap > ceiling {
            cap = ceiling;
        }

        res: ZInflateResult = z_inflate_all(data, hpos, remaining, -15, cap, ceiling);
        if res.status == Z_MEM_ERROR {
            raise MemoryError("gzip.decompress: allocation failed");
        }
        if res.status != Z_STREAM_END {
            raise ValueError("gzip.decompress: invalid compressed data");
        }
        member = res.data;
        written: int = len(member);

        tpos: int = hpos + res.consumed;
        if tpos + 8 > n {
            raise ValueError(
                "gzip.decompress: compressed data ended before the end-of-stream marker"
            );
        }

        crc_expected: int = int.from_bytes(data[tpos:tpos + 4], "little");
        isize: int = int.from_bytes(data[tpos + 4:tpos + 8], "little");
        if z_crc32(0, member, written) != crc_expected {
            raise ValueError("gzip.decompress: CRC check failed");
        }
        if (written & _MASK32) != isize {
            raise ValueError("gzip.decompress: incorrect length of data produced");
        }

        if len(result) == 0 {
            result = member;
        } else {
            result = result + member;
        }
        pos = tpos + 8;
    }
    return result;
}
