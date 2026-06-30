import from _zlib_native { z_compress2, z_compress_bound, z_uncompress, z_crc32 }

glob Z_OK: int = 0,
     _MASK32: int = 4294967295;


def:pub compress(data: bytes, compresslevel: int = 9, mtime: int = 0) -> bytes {
    source_len: int = len(data);

    bound: int = z_compress_bound(source_len);
    dest = b"\x00" * bound;
    dest_len = bound.to_bytes(8, "little");
    rc: int = z_compress2(dest, dest_len, data, source_len, compresslevel);
    if rc != Z_OK {
        raise ValueError("gzip.compress: zlib error code " + str(rc));
    }
    written: int = int.from_bytes(dest_len, "little");
    body = dest[2:written - 4];

    xfl: int = 0;
    if compresslevel == 9 {
        xfl = 2;
    } elif compresslevel == 1 {
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

    if n < 18 {
        raise ValueError("gzip.decompress: not a gzip file (truncated header)");
    }
    if data[0] != 31 or data[1] != 139 {
        raise ValueError("gzip.decompress: not a gzip file (bad magic)");
    }
    if data[2] != 8 {
        raise ValueError("gzip.decompress: unsupported compression method");
    }

    flg: int = data[3];
    pos: int = 10;

    if (flg & 4) != 0 {
        xlen: int = int.from_bytes(data[pos:pos + 2], "little");
        pos = pos + 2 + xlen;
    }

    if (flg & 8) != 0 {
        while pos < n and data[pos] != 0 {
            pos += 1;
        }
        pos += 1;
    }
    if (flg & 16) != 0 {
        while pos < n and data[pos] != 0 {
            pos += 1;
        }
        pos += 1;
    }

    if (flg & 2) != 0 {
        pos += 2;
    }
    if pos > n - 8 {
        raise ValueError("gzip.decompress: not a gzip file (truncated header)");
    }

    crc_expected: int = int.from_bytes(data[n - 8:n - 4], "little");
    isize: int = int.from_bytes(data[n - 4:n], "little");
    body = data[pos:n - 8];

    rewrapped = b"\x78\x9c" + body + b"\x00\x00\x00\x00";

    cap: int = isize;
    if cap < 64 {
        cap = 64;
    }
    dest = b"\x00" * cap;
    dest_len = cap.to_bytes(8, "little");
    z_uncompress(dest, dest_len, rewrapped, len(rewrapped));
    written: int = int.from_bytes(dest_len, "little");
    out = dest[0:written];

    if (written & _MASK32) != isize {
        raise ValueError(
            "gzip.decompress: invalid or truncated stream (length mismatch)"
        );
    }
    if z_crc32(0, out, written) != crc_expected {
        raise ValueError("gzip.decompress: CRC check failed (corrupt stream)");
    }
    return out;
}
