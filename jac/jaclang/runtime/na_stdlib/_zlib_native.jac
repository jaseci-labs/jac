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

import from _zlib_abi {
    ZS_NEXT_IN,
    ZS_AVAIL_IN,
    ZS_TOTAL_IN,
    ZS_NEXT_OUT,
    ZS_AVAIL_OUT,
    ZS_TOTAL_OUT,
    Z_STREAM_SIZE,
    zs_load_total
}

glob _UINT32_MAX: int = 4294967295;

glob:pub Z_OK: int = 0,
     Z_STREAM_END: int = 1,
     Z_MEM_ERROR: int = -4,
     Z_BUF_ERROR: int = -5;


def _signed32(status: int) -> int;


def:pub z_compress_bound(source_len: int) -> int;


def:pub z_compress2(
    dest: bytes, dest_len: bytes, source: bytes, source_len: int, level: int
) -> int;


def:pub z_crc32(crc: int, buf: bytes, n: int) -> int;


def:pub z_adler32(adler: int, buf: bytes, n: int) -> int;


def:pub z_inflate_bound(src_len: int, slack: int = 1024) -> int;


def _payload_addr(buf: bytes) -> int;


def _store_u32(addr: int, value: int);


obj:pub ZInflateResult {
    has status: int,
        consumed: int,
        data: bytes,
        init_ok: bool = True;
}


def:pub z_inflate_all(
    src: bytes, src_off: int, src_len: int, window_bits: int, cap: int, ceiling: int
) -> ZInflateResult;
