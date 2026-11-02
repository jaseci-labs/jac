"""zlib FFI bindings for response body decompression (Phase 6.12).

Provides inflate-only wrappers around libz.so for gzip and raw-deflate
decompression.  We never compress — only decompress incoming HTTP bodies.

z_stream struct layout (x86-64 Linux, sizeof = 112):
    offset  field        type
    0       next_in      Bytef*        (8 bytes)
    8       avail_in     uInt          (4 bytes)
    16      total_in     uLong         (8 bytes, padded)
    24      next_out     Bytef*        (8 bytes)
    32      avail_out    uInt          (4 bytes)
    40      total_out    uLong         (8 bytes, padded)
    48      msg          char*         (8 bytes)
    56      state        internal*     (8 bytes)
    64      zalloc       alloc_func    (8 bytes)
    72      zfree        free_func     (8 bytes)
    80      opaque       voidpf        (8 bytes)
    88      data_type    int           (4 bytes)
    96      adler        uLong         (8 bytes, padded)
    104     reserved     uLong         (8 bytes)

Bun reference: bun/src/deps/zlib — vendored zlib, same API.
"""

import from "libz.so.1" {
    def inflateInit2_(
        strm: int, windowBits: int, version: str, stream_size: int
    ) -> int;  def inflate(strm: int, flush: int) -> int;  def inflateEnd(
        strm: int
    ) -> int;  def deflateInit2_(
        strm: int,
        level: int,
        method: int,
        windowBits: int,
        memLevel: int,
        strategy: int,
        version: str,
        stream_size: int
    ) -> int;  def deflate(strm: int, flush: int) -> int;  def deflateEnd(
        strm: int
    ) -> int;
    # uLong crc32(uLong crc, const Bytef *buf, uInt len);
    def crc32(crc: int, buf: int, buflen: int) -> int;
}

import from engine.src.ffi.libc { calloc, memcpy }
import from engine.src.runtime.mem {
    io_alloc,
    read_u32,
    read_u64,
    write_i32,
    write_i64
}
import from engine.src.runtime.jsstring { str_substr }

# ── zlib constants ────────────────────────────────────────────────────────────
glob:pub Z_OK: int = 0,
     Z_STREAM_END: int = 1,
     Z_NEED_DICT: int = 2,
     Z_BUF_ERROR: int = -5,
     Z_SYNC_FLUSH: int = 2,
     Z_FINISH: int = 4,
     WBITS_RAW: int = -15,
     WBITS_ZLIB: int = 15,
     WBITS_GZIP: int = 31,
     WBITS_AUTO: int = 47;

# windowBits values
# raw deflate (no header)
# zlib-wrapped deflate
# gzip (15 + 16)
# auto-detect gzip or zlib (15 + 32)
# z_stream field offsets (x86-64 LP64)
glob:priv _ZS_NEXT_IN: int = 0,
     _ZS_AVAIL_IN: int = 8,
     _ZS_NEXT_OUT: int = 24,
     _ZS_AVAIL_OUT: int = 32,
     _ZS_TOTAL_OUT: int = 40,
     _ZS_MSG: int = 48,
     _SIZEOF_Z_STREAM: int = 112,
     _ZLIB_VERSION: str = "1.3",
     _INIT_OUT_SIZE: int = 65536;

# Initial output buffer size — 64 KiB; grows if needed.
# ── Public API ────────────────────────────────────────────────────────────────

"""Decompress gzip-encoded data. `data_ptr` is a raw pointer to the
compressed bytes, `data_len` is the byte count.
Returns the decompressed string, or "" on error."""
def:pub zlib_inflate_gzip(data_ptr: int, data_len: int) -> str {
    return _inflate(data_ptr, data_len, WBITS_GZIP);
}

"""Decompress raw deflate data (no zlib/gzip header). Returns the
decompressed string, or "" on error."""
def:pub zlib_inflate_deflate(data_ptr: int, data_len: int) -> str {
    return _inflate(data_ptr, data_len, WBITS_RAW);
}

"""Decompress with auto-detection (gzip or deflate).
Returns the decompressed string, or "" on error."""
def:pub zlib_inflate_auto(data_ptr: int, data_len: int) -> str {
    return _inflate(data_ptr, data_len, WBITS_AUTO);
}

# ── Internal ──────────────────────────────────────────────────────────────────

"""Core inflate loop.  Allocates a z_stream on the C heap, feeds the
compressed data in, collects output chunks, and returns the concatenated
decompressed string.  Uses io_alloc for output buffers so results are
valid Jac str values (C-heap, zero-initialised via calloc — safe to cast
to str without GC conflict).

LIMITATION: Returns str, which is null-terminated in native Jac.  Any
null byte (0x00) in the decompressed output will silently truncate the
result.  This is acceptable for text/JSON HTTP response bodies, which
never contain embedded nulls.  Binary responses (images, PDFs, etc.)
would require a `-> int` pointer + length return pair instead.

NOT streaming: the entire compressed body is fed in one shot.  No
backpressure.  See PHASE6.md §6.14 for the streaming upgrade path."""
def:priv _inflate(data_ptr: int, data_len: int, wbits: int) -> str {
    if data_ptr == 0 or data_len == 0 {
        return "";
    }

    # Allocate and zero-init z_stream
    strm: int = calloc(1, _SIZEOF_Z_STREAM);
    if strm == 0 {
        return "";
    }

    # inflateInit2_(strm, wbits, version, sizeof)
    ret: int = inflateInit2_(strm, wbits, _ZLIB_VERSION, _SIZEOF_Z_STREAM);
    if ret != Z_OK {
        msg_ptr: int = read_u64(strm, _ZS_MSG);
        if msg_ptr != 0 {
            msg_s: str = msg_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
            print("zlib: inflateInit2 failed: " + msg_s);
        } else {
            print("zlib: inflateInit2 failed with code " + str(ret));
        }
        return "";
    }

    # Set input — data_ptr is a raw pointer (int), data_len is byte count
    write_i64(strm, _ZS_NEXT_IN, data_ptr);
    write_i32(strm, _ZS_AVAIL_IN, data_len);

    # Collect output pieces as (pointer, length) pairs
    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total_len: int = 0;

    done: bool = False;
    while not done {
        out_buf: int = io_alloc(_INIT_OUT_SIZE);
        write_i64(strm, _ZS_NEXT_OUT, out_buf);
        write_i32(strm, _ZS_AVAIL_OUT, _INIT_OUT_SIZE);

        ret = inflate(strm, Z_SYNC_FLUSH);

        if ret == Z_STREAM_END {
            done = True;
        } elif ret != Z_OK and ret != Z_BUF_ERROR {
            msg_ptr: int = read_u64(strm, _ZS_MSG);
            if msg_ptr != 0 {
                msg_s: str = msg_ptr;  # jac:ignore[E1001] pointer reinterpreted as str
                print("zlib: inflate error: " + msg_s);
            } else {
                print("zlib: inflate failed with code " + str(ret));
            }
            inflateEnd(strm);
            return "";
        }

        avail_out: int = read_u32(strm, _ZS_AVAIL_OUT);
        produced: int = _INIT_OUT_SIZE - avail_out;

        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total_len = total_len + produced;
        }

        avail_in: int = read_u32(strm, _ZS_AVAIL_IN);
        if avail_in == 0 and not done {
            # All input consumed but no Z_STREAM_END — for truncated streams
            done = True;
        }
    }

    inflateEnd(strm);

    if total_len == 0 {
        return "";
    }

    # Fast path: single piece — the output is already text, safe to cast to str
    if len(piece_ptrs) == 1 {
        p: str = piece_ptrs[0];  # jac:ignore[E1001] pointer reinterpreted as str
        if piece_lens[0] < _INIT_OUT_SIZE {
            return str_substr(p, 0, piece_lens[0]);
        }
        return p;
    }

    # Multi-piece: concatenate into single buffer
    result_buf: int = io_alloc(total_len + 1);
    offset: int = 0;
    i: int = 0;
    while i < len(piece_ptrs) {
        memcpy(result_buf + offset, piece_ptrs[i], piece_lens[i]);
        offset = offset + piece_lens[i];
        i = i + 1;
    }
    result: str = result_buf;  # jac:ignore[E1001] pointer reinterpret
    return str_substr(result, 0, total_len);
}

# ── Stateful streaming inflate (Phase 6.12 — async decompression) ─────────────

# Handle table: index 0 = sentinel (never valid), index i = z_stream* pointer
glob:priv _ZLIB_STREAMS: list[int] = [0];

"""Open a stateful inflate stream.

wbits controls the header format:
  WBITS_GZIP (31)  — gzip header
  WBITS_AUTO (47)  — auto-detect gzip or zlib
  WBITS_ZLIB (15)  — zlib header
  WBITS_RAW (-15)  — raw deflate, no header

Returns an integer handle (>= 1) on success or 0 on failure.
The handle must be passed back to zlib_stream_feed and zlib_stream_close."""
def:pub zlib_stream_open(wbits: int) -> int {
    strm: int = calloc(1, _SIZEOF_Z_STREAM);
    if strm == 0 {
        return 0;
    }
    ret: int = inflateInit2_(strm, wbits, _ZLIB_VERSION, _SIZEOF_Z_STREAM);
    if ret != Z_OK {
        return 0;
    }
    _ZLIB_STREAMS.append(strm);
    return len(_ZLIB_STREAMS) - 1;
}

"""Feed compressed bytes into an open inflate stream.

`handle`  — value returned by zlib_stream_open
`in_ptr`  — pointer to the compressed input bytes (C heap, calloc-allocated)
`in_len`  — byte count of the compressed input

Returns the decompressed string, "" if no output was produced yet, or
"" on error (the stream is implicitly closed on error — caller should
also call zlib_stream_close to clean up the handle slot).

NOTE (text-only limitation): the C pointer is cast to a Jac str so null
bytes in the decompressed output truncate the result.  For UTF-8 HTTP
bodies (JSON, HTML) this is acceptable."""
def:pub zlib_stream_feed(handle: int, in_ptr: int, in_len: int) -> str {
    if handle < 1 or handle >= len(_ZLIB_STREAMS) {
        return "";
    }
    strm: int = _ZLIB_STREAMS[handle];
    if strm == 0 {
        return "";
    }
    if in_ptr == 0 or in_len == 0 {
        return "";
    }

    write_i64(strm, _ZS_NEXT_IN, in_ptr);
    write_i32(strm, _ZS_AVAIL_IN, in_len);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total_len: int = 0;

    done: bool = False;
    while not done {
        out_buf: int = io_alloc(_INIT_OUT_SIZE);
        write_i64(strm, _ZS_NEXT_OUT, out_buf);
        write_i32(strm, _ZS_AVAIL_OUT, _INIT_OUT_SIZE);

        ret: int = inflate(strm, Z_SYNC_FLUSH);

        if ret == Z_STREAM_END {
            # Stream ended — mark handle as dead (keep slot but zero ptr)
            _ZLIB_STREAMS[handle] = 0;
            done = True;
        } elif ret != Z_OK and ret != Z_BUF_ERROR {
            _ZLIB_STREAMS[handle] = 0;
            return "";
        }

        avail_out: int = read_u32(strm, _ZS_AVAIL_OUT);
        produced: int = _INIT_OUT_SIZE - avail_out;

        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total_len = total_len + produced;
        }

        avail_in: int = read_u32(strm, _ZS_AVAIL_IN);
        if avail_in == 0 and not done {
            done = True;
        }
    }

    if total_len == 0 {
        return "";
    }

    # Fast path — single piece
    if len(piece_ptrs) == 1 {
        p: str = piece_ptrs[0];  # jac:ignore[E1001] pointer reinterpreted as str
        if piece_lens[0] < _INIT_OUT_SIZE {
            return str_substr(p, 0, piece_lens[0]);
        }
        return p;
    }

    # Multi-piece concatenation
    result_buf: int = io_alloc(total_len + 1);
    off: int = 0;
    j: int = 0;
    while j < len(piece_ptrs) {
        memcpy(result_buf + off, piece_ptrs[j], piece_lens[j]);
        off = off + piece_lens[j];
        j = j + 1;
    }
    result_s: str = result_buf;  # jac:ignore[E1001] pointer reinterpret
    return str_substr(result_s, 0, total_len);
}

"""Close a stateful inflate stream opened with zlib_stream_open.

Calls inflateEnd and frees the z_stream.  Safe to call on already-closed
handles (the slot value will be 0 — no double-free)."""
def:pub zlib_stream_close(handle: int) -> None {
    if handle < 1 or handle >= len(_ZLIB_STREAMS) {
        return;
    }
    strm: int = _ZLIB_STREAMS[handle];
    if strm == 0 {
        return;
    }
    inflateEnd(strm);
    _ZLIB_STREAMS[handle] = 0;
}

# ── deflate helper (for test servers and Protocol::compress) ─────────────────

# Temporary storage for deflate output pointer/len (single-threaded — safe)
glob:priv _ZLIB_DEFLATE_PTR: int = 0,
     _ZLIB_DEFLATE_LEN: int = 0,
     Z_DEFLATED: int = 8,
     Z_DEFAULT_COMPRESSION: int = -1,
     Z_DEFAULT_STRATEGY: int = 0,
     _ZS_DEFAULT_MEM_LEVEL: int = 8;

# zlib deflate constants
"""Compress `in_ptr[0..in_len]` using deflate into a freshly-allocated output
buffer.  The compressed result pointer is stored in _ZLIB_DEFLATE_PTR and
the byte count in _ZLIB_DEFLATE_LEN; retrieve them via zlib_deflate_ptr()
and zlib_deflate_len().  The caller is responsible for freeing the buffer
with free().

Returns Z_OK (0) on success, negative on error."""
def:pub zlib_compress_raw(in_ptr: int, in_len: int, wbits: int) -> int {
    strm: int = calloc(1, _SIZEOF_Z_STREAM);
    if strm == 0 {
        return 0 - 1;
    }
    ret: int = deflateInit2_(
        strm,
        Z_DEFAULT_COMPRESSION,
        Z_DEFLATED,
        wbits,
        _ZS_DEFAULT_MEM_LEVEL,
        Z_DEFAULT_STRATEGY,
        _ZLIB_VERSION,
        _SIZEOF_Z_STREAM
    );
    if ret != Z_OK {
        return ret;
    }

    # Maximum expansion: deflate can only expand ~0.1% + 10 bytes for small inputs.
    # Use 2× input size + 32 bytes to be safe.
    out_max: int = in_len + in_len + 32;
    if out_max < 64 {
        out_max = 64;
    }
    out_buf: int = calloc(1, out_max);
    if out_buf == 0 {
        deflateEnd(strm);
        return 0 - 1;
    }

    write_i64(strm, _ZS_NEXT_IN, in_ptr);
    write_i32(strm, _ZS_AVAIL_IN, in_len);
    write_i64(strm, _ZS_NEXT_OUT, out_buf);
    write_i32(strm, _ZS_AVAIL_OUT, out_max);

    ret2: int = deflate(strm, Z_FINISH);
    avail_out_after: int = read_u32(strm, _ZS_AVAIL_OUT);
    produced: int = out_max - avail_out_after;

    deflateEnd(strm);

    if ret2 != Z_STREAM_END {
        return 0 - 2;
    }

    _ZLIB_DEFLATE_PTR = out_buf;
    _ZLIB_DEFLATE_LEN = produced;
    return Z_OK;
}

"""Return the pointer to the most-recent zlib_compress_raw output buffer."""
def:pub zlib_deflate_ptr -> int {
    return _ZLIB_DEFLATE_PTR;
}

"""Return the byte length of the most-recent zlib_compress_raw output."""
def:pub zlib_deflate_len -> int {
    return _ZLIB_DEFLATE_LEN;
}

"""Store a binary output buffer for retrieval via zlib_deflate_ptr/len.
Used by brotli/zstd one-shot and streaming helpers so JS can reuse
__zlib.cptr()/clen()."""
def:pub zlib_store_output(ptr: int, length: int) {
    _ZLIB_DEFLATE_PTR = ptr;
    _ZLIB_DEFLATE_LEN = length;
}

"""Compute CRC-32 over `buf[0..len]` with initial value `seed`.
Matches Node's `zlib.crc32(data, value=0)` (libz crc32).

Note: libz's crc32(crc, Z_NULL, 0) returns the *initial* CRC (0), not `crc`.
For empty input we must return `seed` directly."""
def:pub zlib_crc32(seed: int, buf: int, length: int) -> int {
    if length <= 0 or buf == 0 {
        return seed;
    }
    return crc32(seed, buf, length);
}

# ── Generic inflate oneshot and stateful deflate streams ─────────────────────

"""One-shot decompress — generic wbits version exposed via __zlib.inflate.

Wraps the private _inflate helper so the dispatch layer can call it without
knowing which format (gzip, raw deflate, auto) is requested.

wbits:
  WBITS_GZIP (31)   — gzip header
  WBITS_RAW  (-15)  — raw deflate, no header
  WBITS_ZLIB (15)   — zlib header
  WBITS_AUTO (47)   — auto-detect gzip or zlib

Returns the decompressed bytes as a str (null-terminated — safe for
text/JSON bodies).  Returns "" on error."""
def:pub zlib_inflate_oneshot(data_ptr: int, data_len: int, wbits: int) -> str {
    return _inflate(data_ptr, data_len, wbits);
}

# Stateful deflate handle table (index 0 = sentinel, never valid).
glob:priv _ZLIB_DEFLATE_STREAMS: list[int] = [0];

"""Open a stateful deflate (compress) stream.

wbits controls the output format:
  WBITS_GZIP (31)   — gzip header
  WBITS_ZLIB (15)   — zlib header
  WBITS_RAW (-15)   — raw deflate, no header

level is the compression level: Z_DEFAULT_COMPRESSION (-1) or 1-9.

Returns an integer handle (>= 1) on success or 0 on failure.
Pass the handle to zlib_deflate_stream_feed and zlib_deflate_stream_close."""
def:pub zlib_deflate_stream_open(wbits: int, level: int) -> int {
    strm: int = calloc(1, _SIZEOF_Z_STREAM);
    if strm == 0 {
        return 0;
    }
    ret: int = deflateInit2_(
        strm,
        level,
        Z_DEFLATED,
        wbits,
        _ZS_DEFAULT_MEM_LEVEL,
        Z_DEFAULT_STRATEGY,
        _ZLIB_VERSION,
        _SIZEOF_Z_STREAM
    );
    if ret != Z_OK {
        return 0;
    }
    _ZLIB_DEFLATE_STREAMS.append(strm);
    return len(_ZLIB_DEFLATE_STREAMS) - 1;
}

"""Feed bytes into a stateful deflate stream and return the compressed output.

handle  — value returned by zlib_deflate_stream_open
in_ptr  — pointer to input bytes (C heap); 0 to flush without new input
in_len  — input byte count; 0 for a flush-only call
flush   — Z_NO_FLUSH (0), Z_SYNC_FLUSH (2), or Z_FINISH (4)

Returns the number of compressed bytes produced (0 if the compressor buffered
without output — normal for Z_NO_FLUSH with small inputs).  The output bytes
are stored in _ZLIB_DEFLATE_PTR / _ZLIB_DEFLATE_LEN; retrieve them with
zlib_deflate_ptr() and zlib_deflate_len().  This avoids null-byte truncation
that would occur if the compressed data were returned as a C str."""
def:pub zlib_deflate_stream_feed(
    handle: int, in_ptr: int, in_len: int, flush: int
) -> int {
    if handle < 1 or handle >= len(_ZLIB_DEFLATE_STREAMS) {
        return 0;
    }
    strm: int = _ZLIB_DEFLATE_STREAMS[handle];
    if strm == 0 {
        return 0;
    }

    write_i64(strm, _ZS_NEXT_IN, in_ptr);
    write_i32(strm, _ZS_AVAIL_IN, in_len);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total_len: int = 0;
    done: bool = False;

    while not done {
        out_buf: int = io_alloc(_INIT_OUT_SIZE);
        write_i64(strm, _ZS_NEXT_OUT, out_buf);
        write_i32(strm, _ZS_AVAIL_OUT, _INIT_OUT_SIZE);

        ret: int = deflate(strm, flush);

        if ret == Z_STREAM_END {
            _ZLIB_DEFLATE_STREAMS[handle] = 0;
            deflateEnd(strm);
            done = True;
        } elif ret != Z_OK and ret != Z_BUF_ERROR {
            _ZLIB_DEFLATE_STREAMS[handle] = 0;
            deflateEnd(strm);
            return 0;
        }

        avail_out: int = read_u32(strm, _ZS_AVAIL_OUT);
        produced: int = _INIT_OUT_SIZE - avail_out;
        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total_len = total_len + produced;
        }

        avail_in: int = read_u32(strm, _ZS_AVAIL_IN);
        avail_out2: int = read_u32(strm, _ZS_AVAIL_OUT);
        # Done when all input consumed and output buffer not completely full
        if avail_in == 0 and avail_out2 > 0 and not done {
            done = True;
        }
    }

    if total_len == 0 {
        _ZLIB_DEFLATE_PTR = 0;
        _ZLIB_DEFLATE_LEN = 0;
        return 0;
    }

    if len(piece_ptrs) == 1 {
        _ZLIB_DEFLATE_PTR = piece_ptrs[0];
        _ZLIB_DEFLATE_LEN = piece_lens[0];
        return piece_lens[0];
    }

    result_buf: int = io_alloc(total_len + 1);
    off: int = 0;
    k: int = 0;
    while k < len(piece_ptrs) {
        memcpy(result_buf + off, piece_ptrs[k], piece_lens[k]);
        off = off + piece_lens[k];
        k = k + 1;
    }
    _ZLIB_DEFLATE_PTR = result_buf;
    _ZLIB_DEFLATE_LEN = total_len;
    return total_len;
}

"""Close a stateful deflate stream opened by zlib_deflate_stream_open.

Safe to call on already-closed handles (no-op).  Do NOT use the handle
after calling this function."""
def:pub zlib_deflate_stream_close(handle: int) -> None {
    if handle < 1 or handle >= len(_ZLIB_DEFLATE_STREAMS) {
        return;
    }
    strm: int = _ZLIB_DEFLATE_STREAMS[handle];
    if strm == 0 {
        return;
    }
    deflateEnd(strm);
    _ZLIB_DEFLATE_STREAMS[handle] = 0;
}
