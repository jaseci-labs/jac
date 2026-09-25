"""bzip2 compressor and decompressor objects.

Derived from CPython 3.14.6 Modules/_bz2module.c; see ../LICENSE.cpython.
libbzip2 keeps a pointer to its bz_stream, so each stream is pinned. The
library runs with the GIL released; only the allocator callbacks run there.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyErr_NoMemory,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyMem_Realloc,
    PyObject,
    PyThreadState,
    PyThread_acquire_lock,
    PyThread_allocate_lock,
    PyThread_free_lock,
    PyThread_release_lock,
    jacpy_buffer_new,
    jacpy_distance,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.output_buffer { BlocksOutputBuffer, Cursor }
import from bz2 {
    obj bz_stream {
        has next_in: ptr[u8] = ptr[u8](),
            avail_in: u32 = 0,
            total_in_lo32: u32 = 0,
            total_in_hi32: u32 = 0,
            next_out: ptr[u8] = ptr[u8](),
            avail_out: u32 = 0,
            total_out_lo32: u32 = 0,
            total_out_hi32: u32 = 0,
            state: ptr = ptr(),
            bzalloc: Callable[[ptr, i32, i32], ptr] = 0,
            bzfree: Callable[[ptr, ptr], None] = 0,
            opaque: ptr = ptr();
    }  def BZ2_bzCompressInit(
        strm: &mut Pinned[bz_stream],
        blockSize100k: i32,
        verbosity: i32,
        workFactor: i32
    ) -> i32;  def BZ2_bzCompress(strm: &mut Pinned[bz_stream], action: i32) -> i32;  def BZ2_bzCompressEnd(
        strm: &mut Pinned[bz_stream]
    ) -> i32;  def BZ2_bzDecompressInit(
        strm: &mut Pinned[bz_stream], verbosity: i32, small: i32
    ) -> i32;  def BZ2_bzDecompress(strm: &mut Pinned[bz_stream]) -> i32;  def BZ2_bzDecompressEnd(
        strm: &mut Pinned[bz_stream]
    ) -> i32;
}

glob:pub BZ2Compressor_token = ClassToken(),
     BZ2Decompressor_token = ClassToken();

glob:priv BZ_RUN: i32 = 0,
     BZ_FINISH: i32 = 2,
     BZ_OK: i32 = 0,
     BZ_RUN_OK: i32 = 1,
     BZ_FLUSH_OK: i32 = 2,
     BZ_FINISH_OK: i32 = 3,
     BZ_STREAM_END: i32 = 4,
     BZ_SEQUENCE_ERROR: i32 = -1,
     BZ_PARAM_ERROR: i32 = -2,
     BZ_MEM_ERROR: i32 = -3,
     BZ_DATA_ERROR: i32 = -4,
     BZ_DATA_ERROR_MAGIC: i32 = -5,
     BZ_IO_ERROR: i32 = -6,
     BZ_UNEXPECTED_EOF: i32 = -7,
     BZ_CONFIG_ERROR: i32 = -9,
     UINT_MAX: i64 = 0xFFFFFFFF,
     SSIZE_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

def:priv bz2_malloc(context: ptr, items: i32, size: i32) -> ptr {
    if items < 0 or size < 0 {
        return ptr();
    }
    if size != 0 and i64(items) > SSIZE_MAX // i64(size) {
        return ptr();
    }
    return PyMem_RawMalloc(u64(items) * u64(size));
}

def:priv bz2_free(context: ptr, address: ptr) {
    PyMem_RawFree(address);
}

# catch_bz2_error(): True when the status is a failure and an error is set.
def:priv catch_bz2_error(status: i32) -> bool {
    if status in [BZ_OK, BZ_RUN_OK, BZ_FLUSH_OK, BZ_FINISH_OK, BZ_STREAM_END] {
        return False;
    }
    if status == BZ_CONFIG_ERROR {
        object_error("SystemError", "libbzip2 was not compiled correctly");
    } elif status == BZ_PARAM_ERROR {
        object_error(
            "ValueError", "Internal error - invalid parameters passed to libbzip2"
        );
    } elif status == BZ_MEM_ERROR {
        PyErr_NoMemory();
    } elif status == BZ_DATA_ERROR or status == BZ_DATA_ERROR_MAGIC {
        object_error("OSError", "Invalid data stream");
    } elif status == BZ_IO_ERROR {
        object_error("OSError", "Unknown I/O error");
    } elif status == BZ_UNEXPECTED_EOF {
        object_error(
            "EOFError",
            "Compressed file ended before the logical end-of-stream was detected"
        );
    } elif status == BZ_SEQUENCE_ERROR {
        object_error(
            "RuntimeError",
            "Internal error - Invalid sequence of commands sent to libbzip2"
        );
    } else {
        object_error("OSError", f"Unrecognized error from libbzip2: {status}");
    }
    return True;
}

def:priv lock_acquire(lock: ptr) {
    if PyThread_acquire_lock(lock, 0) == 0 {
        thread = PyEval_SaveThread();
        PyThread_acquire_lock(lock, 1);
        PyEval_RestoreThread(thread);
    }
}

def:priv sync_out(bzs: &mut Pinned[bz_stream], cursor: Cursor) {
    bzs.value.next_out = cursor.next_out;
    bzs.value.avail_out = u32(
        cursor.avail_out if cursor.avail_out < UINT_MAX else UINT_MAX
    );
}

obj CompressorState(NativeState) {
    has bzs: Pinned[bz_stream],
        flushed: bool = False,
        lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        BZ2_bzCompressEnd(&mut self.bzs);
        if self.lock {
            PyThread_free_lock(self.lock);
        }
    }
}

def:priv compress(
    state: CompressorState, data: ptr, length: i64, action: i32
) -> ptr[PyObject] {
    buffer = BlocksOutputBuffer();
    cursor = Cursor();
    if buffer.init_and_grow(-1, cursor) < 0 {
        buffer.discard();
        return NULL;
    }
    sync_out(&mut state.bzs, cursor);
    state.bzs.value.next_in = ptr[u8](data);
    state.bzs.value.avail_in = 0;
    remains = length;
    while True {
        if state.bzs.value.avail_in == 0 and remains > 0 {
            chunk = remains if remains < UINT_MAX else UINT_MAX;
            state.bzs.value.avail_in = u32(chunk);
            remains -= chunk;
        }
        if action == BZ_RUN and state.bzs.value.avail_in == 0 {
            break;
        }
        if state.bzs.value.avail_out == 0 {
            cursor = Cursor(avail_out=0);
            if buffer.grow(cursor) < 0 {
                buffer.discard();
                return NULL;
            }
            sync_out(&mut state.bzs, cursor);
        }
        thread = PyEval_SaveThread();
        status = BZ2_bzCompress(&mut state.bzs, action);
        PyEval_RestoreThread(thread);
        if catch_bz2_error(status) {
            buffer.discard();
            return NULL;
        }
        if action == BZ_FINISH and status == BZ_STREAM_END {
            break;
        }
    }
    return buffer.finish(i64(state.bzs.value.avail_out));
}

def:priv compressor_of(instance: ptr[PyObject]) -> CompressorState | None {
    if jacpy_binding_native_present(instance, BZ2Compressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, BZ2Compressor_token.handle);
        if isinstance(state, CompressorState) {
            return state;
        }
    }
    object_error("SystemError", "BZ2Compressor state is unavailable");
    return None;
}

def _bz2_BZ2Compressor_compress_impl(
    receiver: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    lock_acquire(state.lock);
    result = NULL;
    if state.flushed {
        object_error("ValueError", "Compressor has been flushed");
    } else {
        result = compress(state, data.address(), data.size(), BZ_RUN);
    }
    PyThread_release_lock(state.lock);
    return result;
}

def _bz2_BZ2Compressor_flush_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = compressor_of(receiver);
    if state is None {
        return NULL;
    }
    lock_acquire(state.lock);
    result = NULL;
    if state.flushed {
        object_error("ValueError", "Repeated call to flush()");
    } else {
        state.flushed = True;
        result = compress(state, ptr(), 0, BZ_FINISH);
    }
    PyThread_release_lock(state.lock);
    return result;
}

def _bz2_BZ2Compressor_impl(type: ptr[PyObject], compresslevel: i32) -> ptr[PyObject] {
    if not (1 <= compresslevel and compresslevel <= 9) {
        object_error("ValueError", "compresslevel must be between 1 and 9");
        return NULL;
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    lock = PyThread_allocate_lock();
    if not lock {
        jacpy_release(instance);
        object_error("MemoryError", "Unable to allocate lock");
        return NULL;
    }
    state = CompressorState(
        bzs=pin(bz_stream(bzalloc=bz2_malloc, bzfree=bz2_free)), lock=lock
    );
    if jacpy_binding_native_set(instance, BZ2Compressor_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    if catch_bz2_error(BZ2_bzCompressInit(&mut state.bzs, compresslevel, 0, 0)) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

obj DecompressorState(NativeState) {
    has bzs: Pinned[bz_stream],
        bzerror: i32 = 0,
        eof: bool = False,
        unused_data: ptr[PyObject] = NULL,
        needs_input: bool = True,
        input_buffer: ptr = ptr(),
        input_buffer_size: i64 = 0,
        bzs_avail_in_real: i64 = 0,
        lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        PyMem_Free(self.input_buffer);
        BZ2_bzDecompressEnd(&mut self.bzs);
        jacpy_release(self.unused_data);
        if self.lock {
            PyThread_free_lock(self.lock);
        }
    }
}

def decompressor_of(instance: ptr[PyObject]) -> DecompressorState | None {
    if jacpy_binding_native_present(instance, BZ2Decompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, BZ2Decompressor_token.handle);
        if isinstance(state, DecompressorState) {
            return state;
        }
    }
    object_error("SystemError", "BZ2Decompressor state is unavailable");
    return None;
}

def:priv decompress_buf(state: DecompressorState, max_length: i64) -> ptr[PyObject] {
    buffer = BlocksOutputBuffer();
    cursor = Cursor();
    if buffer.init_and_grow(max_length, cursor) < 0 {
        buffer.discard();
        return NULL;
    }
    sync_out(&mut state.bzs, cursor);
    while True {
        chunk = state.bzs_avail_in_real
            if state.bzs_avail_in_real < UINT_MAX
            else UINT_MAX;
        state.bzs.value.avail_in = u32(chunk);
        state.bzs_avail_in_real -= chunk;
        thread = PyEval_SaveThread();
        status = BZ2_bzDecompress(&mut state.bzs);
        PyEval_RestoreThread(thread);
        state.bzs_avail_in_real += i64(state.bzs.value.avail_in);
        if catch_bz2_error(status) {
            state.bzerror = status;
            state.needs_input = False;
            buffer.discard();
            return NULL;
        }
        if status == BZ_STREAM_END {
            state.eof = True;
            break;
        } elif state.bzs_avail_in_real == 0 {
            break;
        } elif state.bzs.value.avail_out == 0 {
            if buffer.data_size(0) == max_length {
                break;
            }
            cursor = Cursor(avail_out=0);
            if buffer.grow(cursor) < 0 {
                buffer.discard();
                return NULL;
            }
            sync_out(&mut state.bzs, cursor);
        }
    }
    return buffer.finish(i64(state.bzs.value.avail_out));
}

def:priv decompress(
    state: DecompressorState, data: ptr, length: i64, max_length: i64
) -> ptr[PyObject] {
    in_use = False;
    if not state.bzs.value.next_in.is_null() {
        buffer_end = jacpy_offset(state.input_buffer, state.input_buffer_size);
        avail_now = jacpy_distance(
            buffer_end, jacpy_offset(state.bzs.value.next_in, state.bzs_avail_in_real)
        );
        avail_total = state.input_buffer_size - state.bzs_avail_in_real;
        if avail_total < length {
            offset = jacpy_distance(state.bzs.value.next_in, state.input_buffer);
            new_size = state.input_buffer_size + length - avail_now;
            grown = PyMem_Realloc(state.input_buffer, u64(new_size));
            if not grown {
                PyErr_NoMemory();
                return NULL;
            }
            state.input_buffer = grown;
            state.input_buffer_size = new_size;
            state.bzs.value.next_in = ptr[u8](jacpy_offset(grown, offset));
        } elif avail_now < length {
            jacpy_memory_move(
                state.input_buffer, state.bzs.value.next_in, state.bzs_avail_in_real
            );
            state.bzs.value.next_in = ptr[u8](state.input_buffer);
        }
        jacpy_memory_copy(
            jacpy_offset(state.bzs.value.next_in, state.bzs_avail_in_real), data, length
        );
        state.bzs_avail_in_real += length;
        in_use = True;
    } else {
        state.bzs.value.next_in = ptr[u8](data);
        state.bzs_avail_in_real = length;
    }
    result = decompress_buf(state, max_length);
    if not result {
        state.bzs.value.next_in = ptr[u8]();
        return NULL;
    }
    if state.eof {
        state.needs_input = False;
        if state.bzs_avail_in_real > 0 {
            unused = jacpy_buffer_new(state.bzs_avail_in_real);
            if not unused {
                state.bzs.value.next_in = ptr[u8]();
                jacpy_release(result);
                return NULL;
            }
            jacpy_memory_copy(
                PyBytes_AsString(unused),
                state.bzs.value.next_in,
                state.bzs_avail_in_real
            );
            jacpy_release(state.unused_data);
            state.unused_data = unused;
        }
    } elif state.bzs_avail_in_real == 0 {
        state.bzs.value.next_in = ptr[u8]();
        state.needs_input = True;
    } else {
        state.needs_input = False;
        if not in_use {
            if state.input_buffer
                and state.input_buffer_size < state.bzs_avail_in_real {
                PyMem_Free(state.input_buffer);
                state.input_buffer = ptr();
            }
            if not state.input_buffer {
                state.input_buffer = PyMem_Malloc(u64(state.bzs_avail_in_real));
                if not state.input_buffer {
                    PyErr_NoMemory();
                    state.bzs.value.next_in = ptr[u8]();
                    jacpy_release(result);
                    return NULL;
                }
                state.input_buffer_size = state.bzs_avail_in_real;
            }
            jacpy_memory_copy(
                state.input_buffer, state.bzs.value.next_in, state.bzs_avail_in_real
            );
            state.bzs.value.next_in = ptr[u8](state.input_buffer);
        }
    }
    return result;
}

def _bz2_BZ2Decompressor_decompress_impl(
    receiver: ptr[PyObject], data: BufferArgument, max_length: i64
) -> ptr[PyObject] {
    state = decompressor_of(receiver);
    if state is None {
        return NULL;
    }
    lock_acquire(state.lock);
    result = NULL;
    if state.eof {
        object_error("EOFError", "End of stream already reached");
    } elif state.bzerror != 0 {
        object_error("ValueError", "Decompressor is unusable after a previous error");
    } else {
        result = decompress(state, data.address(), data.size(), max_length);
    }
    PyThread_release_lock(state.lock);
    return result;
}

def _bz2_BZ2Decompressor_impl(type: ptr[PyObject]) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    lock = PyThread_allocate_lock();
    if not lock {
        jacpy_release(instance);
        object_error("MemoryError", "Unable to allocate lock");
        return NULL;
    }
    state = DecompressorState(
        bzs=pin(bz_stream()), lock=lock, unused_data=jacpy_buffer_new(0)
    );
    if not state.unused_data
        or jacpy_binding_native_set(instance, BZ2Decompressor_token.handle, state)
            < 0 {
        jacpy_release(instance);
        return NULL;
    }
    if catch_bz2_error(BZ2_bzDecompressInit(&mut state.bzs, 0, 0)) {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}
