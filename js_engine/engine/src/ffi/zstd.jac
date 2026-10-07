"""Zstd FFI bindings for Node.js zlib zstdCompress/Decompress APIs.

One-shot via ZSTD_compress / ZSTD_decompress.
Streaming via ZSTD_compressStream2 / ZSTD_decompressStream with
ZSTD_inBuffer / ZSTD_outBuffer structs (24 bytes each on x86-64):
    offset 0  void* src/dst
    offset 8  size_t size
    offset 16 size_t pos

System lib: libzstd.so.1. Output via zlib_store_output → __zlib.cptr()/clen().
"""

import from "/lib/x86_64-linux-gnu/libzstd.so.1" {
    def ZSTD_compress(
        dst: int, dstCapacity: int, src: int, srcSize: int, level: int
    ) -> int;  def ZSTD_decompress(
        dst: int, dstCapacity: int, src: int, compressedSize: int
    ) -> int;  def ZSTD_compressBound(srcSize: int) -> int;  def ZSTD_decompressBound(
        src: int, srcSize: int
    ) -> int;  def ZSTD_isError(code: int) -> int;  def ZSTD_createCCtx -> int;  def ZSTD_freeCCtx(
        cctx: int
    ) -> int;  def ZSTD_createDCtx -> int;  def ZSTD_freeDCtx(dctx: int) -> int;  def ZSTD_compressStream2(
        cctx: int, output: int, input: int, endOp: int
    ) -> int;  def ZSTD_decompressStream(dctx: int, output: int, input: int) -> int;  def ZSTD_CCtx_setParameter(
        cctx: int, param: int, value: int
    ) -> int;  def ZSTD_CStreamInSize -> int;  def ZSTD_CStreamOutSize -> int;  def ZSTD_DStreamOutSize -> int;
}

import from engine.src.ffi.libc { calloc, free, memcpy }
import from engine.src.runtime.mem { write_i64, read_u64 }
import from engine.src.ffi.zlib { zlib_store_output }

# ZSTD_EndDirective
glob:priv ZSTD_e_continue: int = 0,
     ZSTD_e_flush: int = 1,
     ZSTD_e_end: int = 2,
     ZSTD_c_compressionLevel: int = 100,
     ZSTD_DEFAULT_LEVEL: int = 3,
     _ZSTD_CHUNK: int = 65536,
     _ZB_PTR: int = 0,
     _ZB_SIZE: int = 8,
     _ZB_POS: int = 16,
     _ZB_SIZEOF: int = 24,
     _ZSTD_ENC: list[int] = [0],
     _ZSTD_DEC: list[int] = [0];

# ZSTD_c_compressionLevel

# ZSTD_inBuffer / ZSTD_outBuffer layout
def:priv _zb_set(buf: int, ptr: int, size: int, pos: int) {
    write_i64(buf, _ZB_PTR, ptr);
    write_i64(buf, _ZB_SIZE, size);
    write_i64(buf, _ZB_POS, pos);
}

def:priv _zb_pos(buf: int) -> int {
    return read_u64(buf, _ZB_POS);
}

"""One-shot zstd compress. level default 3. Returns 0 on success."""
def:pub zstd_compress_raw(in_ptr: int, in_len: int, level: int) -> int {
    lv: int = level;
    if lv == 0 {
        lv = ZSTD_DEFAULT_LEVEL;
    }
    bound: int = ZSTD_compressBound(in_len);
    if bound <= 0 {
        bound = in_len + in_len + 128;
    }
    out_buf: int = calloc(1, bound);
    if out_buf == 0 {
        return 0 - 1;
    }
    produced: int = ZSTD_compress(out_buf, bound, in_ptr, in_len, lv);
    if ZSTD_isError(produced) != 0 {
        free(out_buf);
        return 0 - 2;
    }
    zlib_store_output(out_buf, produced);
    return 0;
}

"""One-shot zstd decompress. max_out hint; 0 → use ZSTD_decompressBound or 4×."""
def:pub zstd_decompress_raw(in_ptr: int, in_len: int, max_out: int) -> int {
    out_cap: int = max_out;
    if out_cap <= 0 {
        out_cap = ZSTD_decompressBound(in_ptr, in_len);
        # ZSTD_CONTENTSIZE_ERROR / UNKNOWN are large sentinel values
        if out_cap <= 0 or out_cap > 268435456 {
            out_cap = in_len * 4;
            if out_cap < _ZSTD_CHUNK {
                out_cap = _ZSTD_CHUNK;
            }
        }
    }
    attempt: int = 0;
    while attempt < 6 {
        out_buf: int = calloc(1, out_cap);
        if out_buf == 0 {
            return 0 - 1;
        }
        produced: int = ZSTD_decompress(out_buf, out_cap, in_ptr, in_len);
        if ZSTD_isError(produced) == 0 {
            zlib_store_output(out_buf, produced);
            return 0;
        }
        free(out_buf);
        out_cap = out_cap * 2;
        attempt = attempt + 1;
    }
    return 0 - 2;
}

def:pub zstd_enc_open(level: int) -> int {
    cctx: int = ZSTD_createCCtx();
    if cctx == 0 {
        return 0;
    }
    lv: int = level;
    if lv == 0 {
        lv = ZSTD_DEFAULT_LEVEL;
    }
    ZSTD_CCtx_setParameter(cctx, ZSTD_c_compressionLevel, lv);
    _ZSTD_ENC.append(cctx);
    return len(_ZSTD_ENC) - 1;
}

"""Feed/flush zstd compressor. op: 0=continue, 1=flush, 2=end.
Returns bytes produced."""
def:pub zstd_enc_feed(handle: int, in_ptr: int, in_len: int, op: int) -> int {
    if handle < 1 or handle >= len(_ZSTD_ENC) {
        return 0;
    }
    cctx: int = _ZSTD_ENC[handle];
    if cctx == 0 {
        return 0;
    }

    in_buf: int = calloc(1, _ZB_SIZEOF);
    out_s: int = calloc(1, _ZB_SIZEOF);
    if in_buf == 0 or out_s == 0 {
        return 0;
    }
    _zb_set(in_buf, in_ptr, in_len, 0);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total: int = 0;
    end_op: int = op;
    if end_op < 0 {
        end_op = ZSTD_e_continue;
    }
    if end_op > 2 {
        end_op = ZSTD_e_end;
    }

    remaining: int = 1;
    while remaining != 0 or _zb_pos(in_buf) < in_len {
        out_buf: int = calloc(1, _ZSTD_CHUNK);
        if out_buf == 0 {
            break;
        }
        _zb_set(out_s, out_buf, _ZSTD_CHUNK, 0);
        remaining = ZSTD_compressStream2(cctx, out_s, in_buf, end_op);
        if ZSTD_isError(remaining) != 0 {
            free(out_buf);
            break;
        }
        produced: int = _zb_pos(out_s);
        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total = total + produced;
        } else {
            free(out_buf);
        }
        # For continue/flush: stop when input consumed and no more pending
        if end_op == ZSTD_e_continue {
            if _zb_pos(in_buf) >= in_len and remaining == 0 {
                break;
            }
            if _zb_pos(in_buf) >= in_len {
                break;
            }
        } elif end_op == ZSTD_e_flush {
            if remaining == 0 {
                break;
            }
        } else {
            # end: remaining==0 means fully flushed
            if remaining == 0 {
                break;
            }
        }
    }

    free(in_buf);
    free(out_s);

    if total == 0 {
        zlib_store_output(0, 0);
        return 0;
    }
    if len(piece_ptrs) == 1 {
        zlib_store_output(piece_ptrs[0], piece_lens[0]);
        return piece_lens[0];
    }
    result: int = calloc(1, total);
    off: int = 0;
    i: int = 0;
    while i < len(piece_ptrs) {
        memcpy(result + off, piece_ptrs[i], piece_lens[i]);
        free(piece_ptrs[i]);
        off = off + piece_lens[i];
        i = i + 1;
    }
    zlib_store_output(result, total);
    return total;
}

def:pub zstd_enc_close(handle: int) -> None {
    if handle < 1 or handle >= len(_ZSTD_ENC) {
        return;
    }
    cctx: int = _ZSTD_ENC[handle];
    if cctx == 0 {
        return;
    }
    ZSTD_freeCCtx(cctx);
    _ZSTD_ENC[handle] = 0;
}

def:pub zstd_dec_open -> int {
    dctx: int = ZSTD_createDCtx();
    if dctx == 0 {
        return 0;
    }
    _ZSTD_DEC.append(dctx);
    return len(_ZSTD_DEC) - 1;
}

def:pub zstd_dec_feed(handle: int, in_ptr: int, in_len: int) -> int {
    if handle < 1 or handle >= len(_ZSTD_DEC) {
        return 0;
    }
    dctx: int = _ZSTD_DEC[handle];
    if dctx == 0 {
        return 0;
    }

    in_buf: int = calloc(1, _ZB_SIZEOF);
    out_s: int = calloc(1, _ZB_SIZEOF);
    if in_buf == 0 or out_s == 0 {
        return 0;
    }
    _zb_set(in_buf, in_ptr, in_len, 0);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total: int = 0;

    loops: int = 0;
    while loops < 64 {
        out_buf: int = calloc(1, _ZSTD_CHUNK);
        if out_buf == 0 {
            break;
        }
        _zb_set(out_s, out_buf, _ZSTD_CHUNK, 0);
        hint: int = ZSTD_decompressStream(dctx, out_s, in_buf);
        if ZSTD_isError(hint) != 0 {
            free(out_buf);
            break;
        }
        produced: int = _zb_pos(out_s);
        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total = total + produced;
        } else {
            free(out_buf);
        }
        loops = loops + 1;
        # Done when input consumed and no more output pending (hint==0 means frame done)
        if _zb_pos(in_buf) >= in_len {
            if produced == 0 or hint == 0 {
                break;
            }
        }
    }

    free(in_buf);
    free(out_s);

    if total == 0 {
        zlib_store_output(0, 0);
        return 0;
    }
    if len(piece_ptrs) == 1 {
        zlib_store_output(piece_ptrs[0], piece_lens[0]);
        return piece_lens[0];
    }
    result: int = calloc(1, total);
    off: int = 0;
    i: int = 0;
    while i < len(piece_ptrs) {
        memcpy(result + off, piece_ptrs[i], piece_lens[i]);
        free(piece_ptrs[i]);
        off = off + piece_lens[i];
        i = i + 1;
    }
    zlib_store_output(result, total);
    return total;
}

def:pub zstd_dec_close(handle: int) -> None {
    if handle < 1 or handle >= len(_ZSTD_DEC) {
        return;
    }
    dctx: int = _ZSTD_DEC[handle];
    if dctx == 0 {
        return;
    }
    ZSTD_freeDCtx(dctx);
    _ZSTD_DEC[handle] = 0;
}
