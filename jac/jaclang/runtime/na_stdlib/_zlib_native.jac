import from z {
    def compress2(dst: bytes, dlen: bytes, src: bytes, slen: u64, lvl: i32) -> i32;
}
import from z { def compressBound(slen: u64) -> u64;  }
import from z { def crc32_z(crc: u64, buf: bytes, n: u64) -> u64;  }
import from z { def adler32_z(adler: u64, buf: bytes, n: u64) -> u64;  }
import from z {
    def inflateInit2_(
        strm: bytes, windowBits: i32, version: int, stream_size: i32
    ) -> i32;
}
import from z { def inflate(strm: bytes, flush: i32) -> i32;  }
import from z { def inflateEnd(strm: bytes) -> i32;  }
import from z { def zlibVersion -> int;  }
import from c { def memchr(s: bytes, c: i32, n: u64) -> int;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }

glob _ZS_NEXT_IN: int = 0,
     _ZS_AVAIL_IN: int = 8,
     _ZS_TOTAL_IN: int = 16,
     _ZS_NEXT_OUT: int = 24,
     _ZS_AVAIL_OUT: int = 32,
     _ZS_TOTAL_OUT: int = 40;

glob _Z_STREAM_SIZE: int = 112,
     _UINT32_MAX: int = 4294967295;

glob:pub Z_OK: int = 0,
     Z_STREAM_END: int = 1,
     Z_MEM_ERROR: int = -4,
     Z_BUF_ERROR: int = -5;


def _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}


def:pub z_compress_bound(source_len: int) -> int {
    return int(compressBound(u64(source_len)));
}


def:pub z_compress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, level: int
) -> int {
    return _signed32(compress2(dest, dest_len, source, u64(source_len), i32(level)));
}


def:pub z_crc32(crc: int, buf: bytes, n: int) -> int {
    return int(crc32_z(u64(crc), buf, u64(n)));
}


def:pub z_adler32(adler: int, buf: bytes, n: int) -> int {
    return int(adler32_z(u64(adler), buf, u64(n)));
}


def:pub z_inflate_bound(src_len: int, slack: int = 1024) -> int {
    return src_len * 1032 + slack;
}


def _payload_addr(buf: bytes) -> int {
    if len(buf) == 0 {
        return 0;
    }
    return memchr(buf, i32(buf[0]), u64(1));
}


def _store_u32(addr: int, value: int) {
    if value > _UINT32_MAX {
        value = _UINT32_MAX;
    }
    __mem_store_i32(addr, i32.wrap(value));
}


obj:pub ZInflateResult {
    has status: int,
        consumed: int,
        data: bytes,
        init_ok: bool = True;
}


def:pub z_inflate_all(
    src: bytes, src_off: int, src_len: int, window_bits: int, cap: int, ceiling: int
) -> ZInflateResult {
    strm: bytes = b"\x00" * _Z_STREAM_SIZE;
    sa: int = _payload_addr(strm);
    in_ptr: int = 0;
    if src_len > 0 {
        in_ptr = _payload_addr(src) + src_off;
    }
    __mem_store_i64(sa + _ZS_NEXT_IN, in_ptr);
    _store_u32(sa + _ZS_AVAIL_IN, src_len);
    rc: int = _signed32(
        inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(_Z_STREAM_SIZE))
    );
    if rc != Z_OK {
        return ZInflateResult(status=rc, consumed=0, data=b"", init_ok=False);
    }
    if cap < 1 {
        cap = 1;
    }
    buf: bytes = b"\x00" * cap;
    ba: int = _payload_addr(buf);
    status: int = Z_OK;
    total: int = 0;
    fed: int = 0;
    while status == Z_OK {
        if total == cap {
            if cap >= ceiling {
                status = Z_BUF_ERROR;
                break;
            }
            fed = __mem_load_i64(sa + _ZS_TOTAL_IN);
            newcap: int = cap * 2;
            if fed > 0 {
                pred: int = (total * src_len) // fed + total // 4 + 4096;
                if pred > newcap {
                    newcap = pred;
                }
            }
            if newcap > ceiling {
                newcap = ceiling;
            }
            nbuf: bytes = b"\x00" * newcap;
            memcpy(nbuf, ba, u64(total));
            buf = nbuf;
            ba = _payload_addr(nbuf);
            cap = newcap;
        }
        __mem_store_i64(sa + _ZS_NEXT_OUT, ba + total);
        _store_u32(sa + _ZS_AVAIL_OUT, cap - total);
        status = _signed32(inflate(strm, i32(0)));
        total = __mem_load_i64(sa + _ZS_TOTAL_OUT);
        if status == Z_BUF_ERROR {
            fed = __mem_load_i64(sa + _ZS_TOTAL_IN);
            if fed < src_len {
                _store_u32(sa + _ZS_AVAIL_IN, src_len - fed);
                status = Z_OK;
            } elif total == cap {
                status = Z_OK;
            }
        }
    }
    data = b"";
    if status == Z_STREAM_END {
        if total < cap {
            __mem_store_i64(ba - 8, total);
        }
        data = buf;
    }
    consumed: int = __mem_load_i64(sa + _ZS_TOTAL_IN);
    inflateEnd(strm);
    return ZInflateResult(status=status, consumed=consumed, data=data);
}
