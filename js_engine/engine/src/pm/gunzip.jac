"""Binary-safe gzip/zlib inflate for the package manager.

engine/src/ffi/zlib.jac returns decompressed data as `str`, which truncates at
the first NUL byte — fine for HTTP text bodies, fatal for tarballs. This wrapper
inflates into a growable io_alloc'd buffer and returns (ptr, len) as a ByteBuf.
Auto-detects gzip vs zlib headers (windowBits 47); tarballs are gzip.
"""

import from "libz.so.1" {
    def inflateInit2_(
        strm: int, windowBits: int, version: str, stream_size: int
    ) -> int;  def inflate(strm: int, flush: int) -> int;  def inflateEnd(
        strm: int
    ) -> int;
}
import from engine.src.ffi.libc { calloc, free, memcpy }
import from engine.src.runtime.mem {
    io_alloc,
    io_free,
    read_u32,
    write_i32,
    write_i64,
    write_byte
}
import from engine.src.pm.bytes { ByteBuf, bytebuf_from }

# z_stream layout (x86-64), see ffi/zlib.jac for the full table.
glob:priv _ZS_NEXT_IN: int = 0,
     _ZS_AVAIL_IN: int = 8,
     _ZS_NEXT_OUT: int = 24,
     _ZS_AVAIL_OUT: int = 32,
     _SIZEOF_Z_STREAM: int = 112,
     _ZLIB_VERSION: str = "1.3",
     _Z_OK: int = 0,
     _Z_STREAM_END: int = 1,
     _Z_BUF_ERROR: int = -5,
     _Z_SYNC_FLUSH: int = 2;

glob:pub GUNZIP_WBITS_AUTO: int = 47,
     GUNZIP_WBITS_GZIP: int = 31,
     GUNZIP_WBITS_RAW: int = -15;  # gzip or zlib header

"""Inflate ptr[0..n). Returns a ByteBuf with len -1 (ptr 0) on error."""
def:pub gunzip_bytes_wbits(data_ptr: int, data_len: int, wbits: int) -> ByteBuf {
    bad: ByteBuf = ByteBuf(ptr=0, len=-1, cap=0);
    if data_ptr == 0 or data_len <= 0 {
        return bad;
    }
    strm: int = calloc(1, _SIZEOF_Z_STREAM);
    if strm == 0 {
        return bad;
    }
    if inflateInit2_(strm, wbits, _ZLIB_VERSION, _SIZEOF_Z_STREAM) != _Z_OK {
        free(strm);
        return bad;
    }
    write_i64(strm, _ZS_NEXT_IN, data_ptr);
    write_i32(strm, _ZS_AVAIL_IN, data_len);
    cap: int = data_len * 4;
    if cap < 65536 {
        cap = 65536;
    }
    out: int = io_alloc(cap + 1);
    total: int = 0;
    ok: bool = True;
    while True {
        if total >= cap {
            ncap: int = cap * 2;
            nout: int = io_alloc(ncap + 1);
            memcpy(nout, out, total);
            io_free(out);
            out = nout;
            cap = ncap;
        }
        write_i64(strm, _ZS_NEXT_OUT, out + total);
        write_i32(strm, _ZS_AVAIL_OUT, cap - total);
        ret: int = inflate(strm, _Z_SYNC_FLUSH);
        avail_out: int = read_u32(strm, _ZS_AVAIL_OUT);
        total = cap - avail_out;
        if ret == _Z_STREAM_END {
            break;
        }
        if ret != _Z_OK and ret != _Z_BUF_ERROR {
            ok = False;
            break;
        }
        avail_in: int = read_u32(strm, _ZS_AVAIL_IN);
        if avail_in == 0 and avail_out != 0 {
            # input exhausted without Z_STREAM_END: truncated stream
            ok = False;
            break;
        }
    }
    inflateEnd(strm);
    free(strm);
    if not ok {
        io_free(out);
        return bad;
    }
    write_byte(out, total, 0);
    return bytebuf_from(out, total);
}

def:pub gunzip_bytes(data_ptr: int, data_len: int) -> ByteBuf {
    return gunzip_bytes_wbits(data_ptr, data_len, GUNZIP_WBITS_AUTO);
}

"""True when ptr[0..n) starts with the gzip magic (1f 8b)."""
def:pub gunzip_is_gzip(ptr: int, n: int) -> bool {
    if n < 2 {
        return False;
    }
    b0: int = read_u32(ptr, 0) & 255;
    b1: int = (read_u32(ptr, 0) >> 8) & 255;
    return b0 == 31 and b1 == 139;
}
