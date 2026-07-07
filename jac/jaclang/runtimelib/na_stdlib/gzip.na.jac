import from _zlib_native { z_compress2, z_compress_bound, z_uncompress2, z_crc32 }

glob Z_OK: int = 0,
     Z_DATA_ERROR: int = -3,
     Z_BUF_ERROR: int = -5,
     _MASK32: int = 4294967295;


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

    header = b"\x1f\x8b\x08\x00" + (mtime & _MASK32).to_bytes(4, "little") + xfl.to_bytes(
        1, "little"
    ) + b"\xff";

    crc: int = z_crc32(0, data, source_len);
    trailer = (crc & _MASK32).to_bytes(4, "little") + (source_len & _MASK32).to_bytes(
        4, "little"
    );

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
        rewrapped = b"\x78\x9c" + data[hpos:n];
        src_total: int = len(rewrapped);

        ceiling: int = remaining * 1032 + 1024;
        cap: int = int.from_bytes(data[n - 4:n], "little");
        if cap < 64 {
            cap = 64;
        }
        if cap > ceiling {
            cap = ceiling;
        }
        written: int = 0;
        consumed: int = 0;
        while True {
            dest = b"\x00" * cap;
            dest_len = cap.to_bytes(8, "little");
            src_len = src_total.to_bytes(8, "little");
            rc: int = z_uncompress2(dest, dest_len, rewrapped, src_len);
            if rc == Z_OK or rc == Z_DATA_ERROR {
                written = int.from_bytes(dest_len, "little");
                consumed = int.from_bytes(src_len, "little");
                break;
            }
            if rc == Z_BUF_ERROR and cap < ceiling {
                cap = cap * 2;
                if cap > ceiling {
                    cap = ceiling;
                }
                continue;
            }
            raise ValueError("gzip.decompress: invalid compressed data");
        }

        if consumed < 8 {
            raise ValueError("gzip.decompress: invalid compressed data");
        }
        body_len: int = consumed - 6;
        tpos: int = hpos + body_len;
        if tpos + 8 > n {
            raise ValueError(
                "gzip.decompress: compressed data ended before the end-of-stream marker"
            );
        }

        crc_expected: int = int.from_bytes(data[tpos:tpos + 4], "little");
        isize: int = int.from_bytes(data[tpos + 4:tpos + 8], "little");
        out = dest[0:written];
        if z_crc32(0, out, written) != crc_expected {
            raise ValueError("gzip.decompress: CRC check failed");
        }
        if (written & _MASK32) != isize {
            raise ValueError("gzip.decompress: incorrect length of data produced");
        }

        result = result + out;
        pos = tpos + 8;
    }
    return result;
}
