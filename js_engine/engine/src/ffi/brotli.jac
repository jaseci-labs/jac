"""Brotli FFI bindings for Node.js zlib brotliCompress/Decompress APIs.

One-shot via BrotliEncoderCompress / BrotliDecoderDecompress.
Streaming via BrotliEncoderCompressStream / BrotliDecoderDecompressStream.

System libs: libbrotlienc.so.1 + libbrotlidec.so.1 (already installed).
Output buffers are published through zlib_store_output for __zlib.cptr()/clen().
"""

import from "/lib/x86_64-linux-gnu/libbrotlienc.so.1" {
    def BrotliEncoderMaxCompressedSize(input_size: int) -> int;  def BrotliEncoderCompress(
        quality: int,
        lgwin: int,
        mode: int,
        input_size: int,
        input_buffer: int,
        encoded_size: int,
        encoded_buffer: int
    ) -> int;  def BrotliEncoderCreateInstance(
        alloc_func: int, free_func: int, opaque: int
    ) -> int;  def BrotliEncoderDestroyInstance(state: int) -> None;  def BrotliEncoderSetParameter(
        state: int, param: int, value: int
    ) -> int;  def BrotliEncoderCompressStream(
        state: int,
        op: int,
        available_in: int,
        next_in: int,
        available_out: int,
        next_out: int,
        total_out: int
    ) -> int;  def BrotliEncoderHasMoreOutput(state: int) -> int;  def BrotliEncoderTakeOutput(
        state: int, size: int
    ) -> int;  def BrotliEncoderIsFinished(state: int) -> int;
}

import from "/lib/x86_64-linux-gnu/libbrotlidec.so.1" {
    def BrotliDecoderDecompress(
        encoded_size: int, encoded_buffer: int, decoded_size: int, decoded_buffer: int
    ) -> int;  def BrotliDecoderCreateInstance(
        alloc_func: int, free_func: int, opaque: int
    ) -> int;  def BrotliDecoderDestroyInstance(state: int) -> None;  def BrotliDecoderDecompressStream(
        state: int,
        available_in: int,
        next_in: int,
        available_out: int,
        next_out: int,
        total_out: int
    ) -> int;  def BrotliDecoderHasMoreOutput(state: int) -> int;  def BrotliDecoderTakeOutput(
        state: int, size: int
    ) -> int;
}

import from engine.src.ffi.libc { calloc, free, memcpy }
import from engine.src.runtime.mem { write_i64, read_u64, read_u32 }
import from engine.src.ffi.zlib { zlib_store_output }

# BrotliEncoderParameter / Operation / Mode
glob:priv BROTLI_PARAM_MODE: int = 0,
     BROTLI_PARAM_QUALITY: int = 1,
     BROTLI_PARAM_LGWIN: int = 3,
     BROTLI_OPERATION_PROCESS: int = 0,
     BROTLI_OPERATION_FLUSH: int = 1,
     BROTLI_OPERATION_FINISH: int = 2,
     BROTLI_MODE_GENERIC: int = 0,
     BROTLI_DEFAULT_QUALITY: int = 11,
     BROTLI_DEFAULT_WINDOW: int = 22,
     BROTLI_DECODER_RESULT_SUCCESS: int = 1,
     BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT: int = 2,
     BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT: int = 3,
     _BROTLI_STREAM_CHUNK: int = 65536,
     _BROTLI_ENC: list[int] = [0],
     _BROTLI_DEC: list[int] = [0];

# Handle tables: index 0 sentinel. Values are encoder/decoder state pointers.
"""One-shot brotli compress. quality typically 0-11 (default 11).
Returns 0 on success (output in zlib_store_output), negative on error."""
def:pub brotli_compress_raw(in_ptr: int, in_len: int, quality: int) -> int {
    q: int = quality;
    if q < 0 {
        q = BROTLI_DEFAULT_QUALITY;
    }
    if q > 11 {
        q = 11;
    }
    max_out: int = BrotliEncoderMaxCompressedSize(in_len);
    if max_out <= 0 {
        max_out = in_len + in_len + 1024;
    }
    if max_out < 64 {
        max_out = 64;
    }
    out_buf: int = calloc(1, max_out);
    if out_buf == 0 {
        return 0 - 1;
    }
    size_slot: int = calloc(1, 8);
    if size_slot == 0 {
        free(out_buf);
        return 0 - 1;
    }
    write_i64(size_slot, 0, max_out);
    ok: int = BrotliEncoderCompress(
        q,
        BROTLI_DEFAULT_WINDOW,
        BROTLI_MODE_GENERIC,
        in_len,
        in_ptr,
        size_slot,
        out_buf
    );
    produced: int = read_u64(size_slot, 0);
    free(size_slot);
    if ok == 0 {
        free(out_buf);
        return 0 - 2;
    }
    zlib_store_output(out_buf, produced);
    return 0;
}

"""One-shot brotli decompress.
max_out is a hint for the output buffer; if 0, uses 4× input (min 64KiB).
Returns 0 on success, negative on error."""
def:pub brotli_decompress_raw(in_ptr: int, in_len: int, max_out: int) -> int {
    out_cap: int = max_out;
    if out_cap <= 0 {
        out_cap = in_len * 4;
        if out_cap < _BROTLI_STREAM_CHUNK {
            out_cap = _BROTLI_STREAM_CHUNK;
        }
    }
    # Grow loop for undersized guesses
    attempt: int = 0;
    while attempt < 6 {
        out_buf: int = calloc(1, out_cap);
        if out_buf == 0 {
            return 0 - 1;
        }
        size_slot: int = calloc(1, 8);
        if size_slot == 0 {
            free(out_buf);
            return 0 - 1;
        }
        write_i64(size_slot, 0, out_cap);
        rc: int = BrotliDecoderDecompress(in_len, in_ptr, size_slot, out_buf);
        produced: int = read_u64(size_slot, 0);
        free(size_slot);
        if rc == BROTLI_DECODER_RESULT_SUCCESS {
            zlib_store_output(out_buf, produced);
            return 0;
        }
        free(out_buf);
        out_cap = out_cap * 2;
        attempt = attempt + 1;
    }
    return 0 - 2;
}

"""Open a streaming brotli encoder. quality: 0-11 (default 11)."""
def:pub brotli_enc_open(quality: int) -> int {
    state: int = BrotliEncoderCreateInstance(0, 0, 0);
    if state == 0 {
        return 0;
    }
    q: int = quality;
    if q < 0 {
        q = BROTLI_DEFAULT_QUALITY;
    }
    if q > 11 {
        q = 11;
    }
    BrotliEncoderSetParameter(state, BROTLI_PARAM_QUALITY, q);
    BrotliEncoderSetParameter(state, BROTLI_PARAM_LGWIN, BROTLI_DEFAULT_WINDOW);
    BrotliEncoderSetParameter(state, BROTLI_PARAM_MODE, BROTLI_MODE_GENERIC);
    _BROTLI_ENC.append(state);
    return len(_BROTLI_ENC) - 1;
}

"""Feed/flush a brotli encoder stream.
op: 0=PROCESS, 1=FLUSH, 2=FINISH.
Returns bytes produced (in zlib_store_output), or 0 if none."""
def:pub brotli_enc_feed(handle: int, in_ptr: int, in_len: int, op: int) -> int {
    if handle < 1 or handle >= len(_BROTLI_ENC) {
        return 0;
    }
    state: int = _BROTLI_ENC[handle];
    if state == 0 {
        return 0;
    }

    avail_in_s: int = calloc(1, 8);
    next_in_s: int = calloc(1, 8);
    avail_out_s: int = calloc(1, 8);
    next_out_s: int = calloc(1, 8);
    if avail_in_s == 0 or next_in_s == 0 or avail_out_s == 0 or next_out_s == 0 {
        return 0;
    }
    write_i64(avail_in_s, 0, in_len);
    write_i64(next_in_s, 0, in_ptr);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total: int = 0;
    done: bool = False;

    while not done {
        out_buf: int = calloc(1, _BROTLI_STREAM_CHUNK);
        if out_buf == 0 {
            break;
        }
        write_i64(avail_out_s, 0, _BROTLI_STREAM_CHUNK);
        write_i64(next_out_s, 0, out_buf);
        ok: int = BrotliEncoderCompressStream(
            state, op, avail_in_s, next_in_s, avail_out_s, next_out_s, 0
        );
        produced: int = _BROTLI_STREAM_CHUNK - read_u64(avail_out_s, 0);
        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total = total + produced;
        } else {
            free(out_buf);
        }
        if ok == 0 {
            done = True;
        } elif read_u64(avail_in_s, 0) == 0 and read_u64(avail_out_s, 0) > 0 {
            # Input consumed and output buffer not full — done for this call
            # unless encoder still has more (finish path).
            if op == BROTLI_OPERATION_FINISH {
                if BrotliEncoderIsFinished(state) != 0
                    or BrotliEncoderHasMoreOutput(state) == 0 {
                    done = True;
                }
            } else {
                done = True;
            }
        }
    }

    free(avail_in_s);
    free(next_in_s);
    free(avail_out_s);
    free(next_out_s);

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

def:pub brotli_enc_close(handle: int) -> None {
    if handle < 1 or handle >= len(_BROTLI_ENC) {
        return;
    }
    state: int = _BROTLI_ENC[handle];
    if state == 0 {
        return;
    }
    BrotliEncoderDestroyInstance(state);
    _BROTLI_ENC[handle] = 0;
}

def:pub brotli_dec_open -> int {
    state: int = BrotliDecoderCreateInstance(0, 0, 0);
    if state == 0 {
        return 0;
    }
    _BROTLI_DEC.append(state);
    return len(_BROTLI_DEC) - 1;
}

"""Feed a brotli decoder stream. Returns bytes produced."""
def:pub brotli_dec_feed(handle: int, in_ptr: int, in_len: int) -> int {
    if handle < 1 or handle >= len(_BROTLI_DEC) {
        return 0;
    }
    state: int = _BROTLI_DEC[handle];
    if state == 0 {
        return 0;
    }

    avail_in_s: int = calloc(1, 8);
    next_in_s: int = calloc(1, 8);
    avail_out_s: int = calloc(1, 8);
    next_out_s: int = calloc(1, 8);
    if avail_in_s == 0 or next_in_s == 0 or avail_out_s == 0 or next_out_s == 0 {
        return 0;
    }
    write_i64(avail_in_s, 0, in_len);
    write_i64(next_in_s, 0, in_ptr);

    piece_ptrs: list[int] = [];
    piece_lens: list[int] = [];
    total: int = 0;
    done: bool = False;

    while not done {
        out_buf: int = calloc(1, _BROTLI_STREAM_CHUNK);
        if out_buf == 0 {
            break;
        }
        write_i64(avail_out_s, 0, _BROTLI_STREAM_CHUNK);
        write_i64(next_out_s, 0, out_buf);
        rc: int = BrotliDecoderDecompressStream(
            state, avail_in_s, next_in_s, avail_out_s, next_out_s, 0
        );
        produced: int = _BROTLI_STREAM_CHUNK - read_u64(avail_out_s, 0);
        if produced > 0 {
            piece_ptrs.append(out_buf);
            piece_lens.append(produced);
            total = total + produced;
        } else {
            free(out_buf);
        }
        if rc == BROTLI_DECODER_RESULT_SUCCESS {
            done = True;
        } elif rc == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT {
            # loop for more output
        } elif rc == BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT {
            done = True;
        } else {
            # error
            done = True;
        }
    }

    free(avail_in_s);
    free(next_in_s);
    free(avail_out_s);
    free(next_out_s);

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

def:pub brotli_dec_close(handle: int) -> None {
    if handle < 1 or handle >= len(_BROTLI_DEC) {
        return;
    }
    state: int = _BROTLI_DEC[handle];
    if state == 0 {
        return;
    }
    BrotliDecoderDestroyInstance(state);
    _BROTLI_DEC[handle] = 0;
}
