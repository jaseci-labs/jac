"""zlib compression: one-shot functions, stream objects and checksums.

Derived from CPython 3.14.6 Modules/zlibmodule.c; see ../LICENSE.cpython.
The z_stream is a C-layout record the library keeps a pointer to between
calls, so every stream is pinned. zlib runs with the GIL released; only its
allocator callbacks, which touch no Python object, run in that window.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBytes_Size,
    PyErr_NoMemory,
    PyErr_SetNone,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyLong_FromUnsignedLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyMem_Realloc,
    PyObject,
    PyObject_CheckBuffer,
    PyThreadState,
    PyThread_acquire_lock,
    PyThread_allocate_lock,
    PyThread_free_lock,
    PyThread_release_lock,
    PyType_GetModule,
    Py_NewRef,
    Py_TYPE,
    _PyBytes_Resize,
    jacpy_buffer_acquire,
    jacpy_buffer_address,
    jacpy_buffer_length,
    jacpy_buffer_new,
    jacpy_buffer_release,
    jacpy_distance,
    jacpy_fs_text,
    jacpy_memory_copy,
    jacpy_memory_move,
    jacpy_offset,
    jacpy_release
}
import from jaclang.runtime.python.capi { object_error, text_value }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_state_get,
    jacpy_binding_visit
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.output_buffer { BlocksOutputBuffer, Cursor }
import from z {
    obj z_stream {
        has next_in: ptr[u8] = ptr[u8](),
            avail_in: u32 = 0,
            total_in: u64 = 0,
            next_out: ptr[u8] = ptr[u8](),
            avail_out: u32 = 0,
            total_out: u64 = 0,
            msg: ptr[u8] = ptr[u8](),
            state: ptr = ptr(),
            zalloc: Callable[[ptr, u32, u32], ptr] = 0,
            zfree: Callable[[ptr, ptr], None] = 0,
            opaque: ptr = ptr(),
            data_type: i32 = 0,
            adler: u64 = 0,
            reserved: u64 = 0;
    }  def deflateInit2_(
        strm: &mut Pinned[z_stream],
        level: i32,
        method: i32,
        windowBits: i32,
        memLevel: i32,
        strategy: i32,
        version: str,
        stream_size: i32
    ) -> i32;  def inflateInit2_(
        strm: &mut Pinned[z_stream], windowBits: i32, version: str, stream_size: i32
    ) -> i32;  def deflate(strm: &mut Pinned[z_stream], flush: i32) -> i32;  def inflate(
        strm: &mut Pinned[z_stream], flush: i32
    ) -> i32;  def deflateEnd(strm: &mut Pinned[z_stream]) -> i32;  def inflateEnd(
        strm: &mut Pinned[z_stream]
    ) -> i32;  def deflateSetDictionary(
        strm: &mut Pinned[z_stream], dictionary: ptr, length: u32
    ) -> i32;  def inflateSetDictionary(
        strm: &mut Pinned[z_stream], dictionary: ptr, length: u32
    ) -> i32;  def deflateCopy(
        dest: &mut Pinned[z_stream], source: &mut Pinned[z_stream]
    ) -> i32;  def inflateCopy(
        dest: &mut Pinned[z_stream], source: &mut Pinned[z_stream]
    ) -> i32;  def adler32(adler: u64, buf: ptr, length: u32) -> u64;  def crc32(
        crc: u64, buf: ptr, length: u32
    ) -> u64;  def zlibVersion -> ptr[u8];
}

glob MAX_WBITS: i32 = 15,
     DEFLATED: i32 = 8,
     DEF_MEM_LEVEL: i32 = 8,
     DEF_BUF_SIZE: i64 = 16 * 1024,
     Z_NO_COMPRESSION: i32 = 0,
     Z_BEST_SPEED: i32 = 1,
     Z_BEST_COMPRESSION: i32 = 9,
     Z_DEFAULT_COMPRESSION: i32 = -1,
     Z_FILTERED: i32 = 1,
     Z_HUFFMAN_ONLY: i32 = 2,
     Z_RLE: i32 = 3,
     Z_FIXED: i32 = 4,
     Z_DEFAULT_STRATEGY: i32 = 0,
     Z_NO_FLUSH: i32 = 0,
     Z_PARTIAL_FLUSH: i32 = 1,
     Z_SYNC_FLUSH: i32 = 2,
     Z_FULL_FLUSH: i32 = 3,
     Z_FINISH: i32 = 4,
     Z_BLOCK: i32 = 5,
     Z_TREES: i32 = 6,
     ZLIB_VERSION: str = "1.3.1",
     Compress_token = ClassToken(),
     Decompress_token = ClassToken(),
     ZlibDecompressor_token = ClassToken();

# Module state slots, in the order the binding fills them.
glob COMPRESS_TYPE: int = 0,
     DECOMPRESS_TYPE: int = 1,
     DECOMPRESSOR_TYPE: int = 2,
     ZLIB_ERROR: int = 3;

glob:priv Z_OK: i32 = 0,
     Z_STREAM_END: i32 = 1,
     Z_NEED_DICT: i32 = 2,
     Z_STREAM_ERROR: i32 = -2,
     Z_DATA_ERROR: i32 = -3,
     Z_MEM_ERROR: i32 = -4,
     Z_BUF_ERROR: i32 = -5,
     Z_VERSION_ERROR: i32 = -6,
     Z_STREAM_SIZE: i32 = 112,
     UINT_MAX: i64 = 0xFFFFFFFF,
     SSIZE_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     DEF_MAX_INITIAL_BUF_SIZE: i64 = 16 * 1024 * 1024,
     CRC_CHUNK_SIZE: i64 = 0x40000000;

# zlib's allocator hooks; they run with the GIL released, like CPython's.
def:priv zlib_malloc(opaque: ptr, items: u32, size: u32) -> ptr {
    if size != 0 and i64(items) > SSIZE_MAX // i64(size) {
        return ptr();
    }
    return PyMem_RawMalloc(u64(items) * u64(size));
}

def:priv zlib_free(opaque: ptr, address: ptr) {
    PyMem_RawFree(address);
}

def:priv new_stream -> Pinned[z_stream] {
    return pin(z_stream(zalloc=zlib_malloc, zfree=zlib_free));
}

def:priv deflate_init(
    zst: &mut Pinned[z_stream],
    level: i32,
    method: i32,
    wbits: i32,
    memLevel: i32,
    strategy: i32
) -> i32 {
    return deflateInit2_(
        zst, level, method, wbits, memLevel, strategy, ZLIB_VERSION, Z_STREAM_SIZE
    );
}

def:priv inflate_init(zst: &mut Pinned[z_stream], wbits: i32) -> i32 {
    return inflateInit2_(zst, wbits, ZLIB_VERSION, Z_STREAM_SIZE);
}

def:priv zlib_error(module: ptr[PyObject], message: ptr[u8], err: i32, context: str) {
    detail = "";
    if err == Z_VERSION_ERROR {
        detail = "library version mismatch";
    } elif not message.is_null() {
        text = jacpy_fs_text(message);
        if text {
            detail = text_value(text)[:200];
            jacpy_release(text);
        }
    } elif err == Z_BUF_ERROR {
        detail = "incomplete or truncated stream";
    } elif err == Z_STREAM_ERROR {
        detail = "inconsistent stream state";
    } elif err == Z_DATA_ERROR {
        detail = "invalid input data";
    }
    error = jacpy_binding_state_get(module, ZLIB_ERROR);
    PyErr_SetString(
        error,
        f"Error {err} {context}: {detail}" if detail else f"Error {err} {context}"
    );
}

def:priv zlib_error_message(module: ptr[PyObject], message: str) {
    PyErr_SetString(jacpy_binding_state_get(module, ZLIB_ERROR), message);
}

# Feed at most UINT_MAX bytes per call, keeping the rest for later rounds.
def:priv arrange_input(zst: &mut Pinned[z_stream], remains: i64) -> i64 {
    chunk = remains if remains < UINT_MAX else UINT_MAX;
    zst.value.avail_in = u32(chunk);
    return remains - chunk;
}

def:priv release_gil -> ptr[PyThreadState] {
    return PyEval_SaveThread();
}

# The codec's cursor lives in the z_stream; the buffer tracks blocks.
def:priv sync_out(zst: &mut Pinned[z_stream], cursor: Cursor) {
    zst.value.next_out = cursor.next_out;
    zst.value.avail_out = u32(
        cursor.avail_out if cursor.avail_out < UINT_MAX else UINT_MAX
    );
}

def:priv grow(buffer: BlocksOutputBuffer, zst: &mut Pinned[z_stream]) -> bool {
    cursor = Cursor(avail_out=i64(zst.value.avail_out));
    if buffer.grow(cursor) < 0 {
        return False;
    }
    sync_out(zst, cursor);
    return True;
}

# A UINT32 window sliding over one large first block (decompress/flush).
obj Window {
    has left: i64 = 0,
        next: ptr[u8] = ptr[u8]();
}

def:priv window_init(
    buffer: BlocksOutputBuffer, window: Window, size: i64, zst: &mut Pinned[z_stream]
) -> bool {
    cursor = Cursor();
    allocated = buffer.init_with_size(size, cursor);
    if allocated < 0 {
        return False;
    }
    visible = allocated if allocated < UINT_MAX else UINT_MAX;
    zst.value.next_out = cursor.next_out;
    zst.value.avail_out = u32(visible);
    window.left = allocated - visible;
    window.next = ptr[u8](jacpy_offset(cursor.next_out, visible));
    return True;
}

def:priv window_grow(
    buffer: BlocksOutputBuffer, window: Window, zst: &mut Pinned[z_stream]
) -> bool {
    if zst.value.avail_out != 0 {
        object_error("SystemError", "*avail_out != 0 in OutputBuffer_WindowGrow().");
        return False;
    }
    if window.left > 0 {
        visible = window.left if window.left < UINT_MAX else UINT_MAX;
        zst.value.next_out = window.next;
        zst.value.avail_out = u32(visible);
        window.left -= visible;
        window.next = ptr[u8](jacpy_offset(window.next, visible));
        return True;
    }
    return grow(buffer, zst);
}

def:priv window_finish(
    buffer: BlocksOutputBuffer, window: Window, zst: &mut Pinned[z_stream]
) -> ptr[PyObject] {
    return buffer.finish(i64(zst.value.avail_out) + window.left);
}

def:priv start_output(
    buffer: BlocksOutputBuffer, max_length: i64, zst: &mut Pinned[z_stream]
) -> bool {
    cursor = Cursor();
    if buffer.init_and_grow(max_length, cursor) < 0 {
        return False;
    }
    sync_out(zst, cursor);
    return True;
}

def zlib_compress_impl(
    module: ptr[PyObject], data: BufferArgument, level: i32, wbits: i32
) -> ptr[PyObject] {
    buffer = BlocksOutputBuffer();
    zst = new_stream();
    if not start_output(buffer, -1, &mut zst) {
        buffer.discard();
        return NULL;
    }
    zst.value.next_in = ptr[u8](data.address());
    remains = data.size();
    err = deflate_init(
        &mut zst, level, DEFLATED, wbits, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY
    );
    if err == Z_MEM_ERROR {
        object_error("MemoryError", "Out of memory while compressing data");
    } elif err == Z_STREAM_ERROR {
        zlib_error_message(module, "Bad compression level");
    } elif err != Z_OK {
        deflateEnd(&mut zst);
        zlib_error(module, zst.value.msg, err, "while compressing data");
    }
    if err != Z_OK {
        buffer.discard();
        return NULL;
    }
    flush = Z_NO_FLUSH;
    while flush != Z_FINISH {
        remains = arrange_input(&mut zst, remains);
        flush = Z_FINISH if remains == 0 else Z_NO_FLUSH;
        while True {
            if zst.value.avail_out == 0 and not grow(buffer, &mut zst) {
                deflateEnd(&mut zst);
                buffer.discard();
                return NULL;
            }
            thread = release_gil();
            err = deflate(&mut zst, flush);
            PyEval_RestoreThread(thread);
            if err == Z_STREAM_ERROR {
                deflateEnd(&mut zst);
                zlib_error(module, zst.value.msg, err, "while compressing data");
                buffer.discard();
                return NULL;
            }
            if zst.value.avail_out != 0 {
                break;
            }
        }
    }
    err = deflateEnd(&mut zst);
    if err != Z_OK {
        zlib_error(module, zst.value.msg, err, "while finishing compression");
        buffer.discard();
        return NULL;
    }
    return buffer.finish(i64(zst.value.avail_out));
}

def zlib_decompress_impl(
    module: ptr[PyObject], data: BufferArgument, wbits: i32, bufsize: i64
) -> ptr[PyObject] {
    if bufsize < 0 {
        object_error("ValueError", "bufsize must be non-negative");
        return NULL;
    }
    size = 1 if bufsize == 0 else bufsize;
    buffer = BlocksOutputBuffer();
    window = Window();
    zst = new_stream();
    if not window_init(buffer, window, size, &mut zst) {
        buffer.discard();
        return NULL;
    }
    zst.value.next_in = ptr[u8](data.address());
    remains = data.size();
    err = inflate_init(&mut zst, wbits);
    if err == Z_MEM_ERROR {
        object_error("MemoryError", "Out of memory while decompressing data");
        buffer.discard();
        return NULL;
    } elif err != Z_OK {
        inflateEnd(&mut zst);
        zlib_error(module, zst.value.msg, err, "while preparing to decompress data");
        buffer.discard();
        return NULL;
    }
    while True {
        remains = arrange_input(&mut zst, remains);
        flush = Z_FINISH if remains == 0 else Z_NO_FLUSH;
        while True {
            if zst.value.avail_out == 0 and not window_grow(buffer, window, &mut zst) {
                inflateEnd(&mut zst);
                buffer.discard();
                return NULL;
            }
            thread = release_gil();
            err = inflate(&mut zst, flush);
            PyEval_RestoreThread(thread);
            if err == Z_MEM_ERROR {
                inflateEnd(&mut zst);
                object_error("MemoryError", "Out of memory while decompressing data");
                buffer.discard();
                return NULL;
            }
            if err != Z_OK and err != Z_BUF_ERROR and err != Z_STREAM_END {
                inflateEnd(&mut zst);
                zlib_error(module, zst.value.msg, err, "while decompressing data");
                buffer.discard();
                return NULL;
            }
            if zst.value.avail_out != 0 {
                break;
            }
        }
        if err == Z_STREAM_END or remains == 0 {
            break;
        }
    }
    if err != Z_STREAM_END {
        inflateEnd(&mut zst);
        zlib_error(module, zst.value.msg, err, "while decompressing data");
        buffer.discard();
        return NULL;
    }
    err = inflateEnd(&mut zst);
    if err != Z_OK {
        zlib_error(module, zst.value.msg, err, "while finishing decompression");
        buffer.discard();
        return NULL;
    }
    return window_finish(buffer, window, &mut zst);
}

# The native state behind zlib.Compress and zlib.Decompress objects.
obj ZlibStream(NativeState) {
    has zst: Pinned[z_stream],
        deflating: bool,
        unused_data: ptr[PyObject] = NULL,
        unconsumed_tail: ptr[PyObject] = NULL,
        zdict: ptr[PyObject] = NULL,
        eof: bool = False,
        is_initialised: bool = False,
        lock: ptr = ptr();

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return jacpy_binding_visit(self.zdict, visitor, context);
    }

    def clear {
        jacpy_release(self.zdict);
        self.zdict = NULL;
    }

    def enter {
        if PyThread_acquire_lock(self.lock, 0) == 0 {
            thread = release_gil();
            PyThread_acquire_lock(self.lock, 1);
            PyEval_RestoreThread(thread);
        }
    }

    def leave {
        PyThread_release_lock(self.lock);
    }

    def drop {
        if self.is_initialised {
            if self.deflating {
                deflateEnd(&mut self.zst);
            } else {
                inflateEnd(&mut self.zst);
            }
        }
        if self.lock {
            PyThread_free_lock(self.lock);
        }
        jacpy_release(self.unused_data);
        jacpy_release(self.unconsumed_tail);
        jacpy_release(self.zdict);
    }
}

def:priv empty_bytes -> ptr[PyObject] {
    return jacpy_buffer_new(0);
}

# newcompobject(): a fresh instance of the module's Compress or Decompress type.
def:priv new_stream_object(
    module: ptr[PyObject], slot: int, token: ClassToken, deflating: bool
) -> tuple[ptr[PyObject], ZlibStream | None] {
    instance = jacpy_binding_allocate(jacpy_binding_state_get(module, slot));
    if not instance {
        return (NULL, None);
    }
    lock = PyThread_allocate_lock();
    if not lock {
        jacpy_release(instance);
        object_error("MemoryError", "Unable to allocate lock");
        return (NULL, None);
    }
    stream = ZlibStream(
        zst=new_stream(),
        deflating=deflating,
        unused_data=empty_bytes(),
        unconsumed_tail=empty_bytes(),
        lock=lock
    );
    if not stream.unused_data
        or not stream.unconsumed_tail
        or jacpy_binding_native_set(instance, token.handle, stream) < 0 {
        jacpy_release(instance);
        return (NULL, None);
    }
    return (instance, stream);
}

def:priv stream_of(instance: ptr[PyObject], token: ClassToken) -> ZlibStream | None {
    if jacpy_binding_native_present(instance, token.handle) != 0 {
        state = jacpy_binding_native_get(instance, token.handle);
        if isinstance(state, ZlibStream) {
            return state;
        }
    }
    object_error("SystemError", "zlib stream state is unavailable");
    return None;
}

def zlib_compressobj_impl(
    module: ptr[PyObject],
    level: i32,
    method: i32,
    wbits: i32,
    memLevel: i32,
    strategy: i32,
    zdict: BufferArgument
) -> ptr[PyObject] {
    if bool(zdict.view) and zdict.size() > UINT_MAX {
        object_error("OverflowError", "zdict length does not fit in an unsigned int");
        return NULL;
    }
    (instance, stream) = new_stream_object(module, COMPRESS_TYPE, Compress_token, True);
    if stream is None {
        return NULL;
    }
    err = deflate_init(&mut stream.zst, level, method, wbits, memLevel, strategy);
    if err == Z_OK {
        stream.is_initialised = True;
        if not bool(zdict.view) {
            return instance;
        }
        err = deflateSetDictionary(&mut stream.zst, zdict.address(), u32(zdict.size()));
        if err == Z_OK {
            return instance;
        }
        object_error(
            "ValueError",
            "Invalid dictionary" if err == Z_STREAM_ERROR else "deflateSetDictionary()"
        );
    } elif err == Z_MEM_ERROR {
        object_error("MemoryError", "Can't allocate memory for compression object");
    } elif err == Z_STREAM_ERROR {
        object_error("ValueError", "Invalid initialization option");
    } else {
        zlib_error(
            module, stream.zst.value.msg, err, "while creating compression object"
        );
    }
    jacpy_release(instance);
    return NULL;
}

def:priv set_inflate_zdict(
    module: ptr[PyObject], zst: &mut Pinned[z_stream], zdict: ptr[PyObject]
) -> bool {
    view = BufferArgument();
    if not view.acquire(zdict) {
        return False;
    }
    if view.size() > UINT_MAX {
        object_error("OverflowError", "zdict length does not fit in an unsigned int");
        return False;
    }
    err = inflateSetDictionary(zst, view.address(), u32(view.size()));
    if err != Z_OK {
        zlib_error(module, zst.value.msg, err, "while setting zdict");
        return False;
    }
    return True;
}

def zlib_decompressobj_impl(
    module: ptr[PyObject], wbits: i32, zdict: ptr[PyObject]
) -> ptr[PyObject] {
    if zdict and PyObject_CheckBuffer(zdict) == 0 {
        object_error("TypeError", "zdict argument must support the buffer protocol");
        return NULL;
    }
    (instance, stream) = new_stream_object(
        module, DECOMPRESS_TYPE, Decompress_token, False
    );
    if stream is None {
        return NULL;
    }
    if zdict {
        stream.zdict = Py_NewRef(zdict);
    }
    err = inflate_init(&mut stream.zst, wbits);
    if err == Z_OK {
        stream.is_initialised = True;
        if stream.zdict
            and wbits < 0
            and not set_inflate_zdict(module, &mut stream.zst, stream.zdict) {
            jacpy_release(instance);
            return NULL;
        }
        return instance;
    }
    if err == Z_STREAM_ERROR {
        object_error("ValueError", "Invalid initialization option");
    } elif err == Z_MEM_ERROR {
        object_error("MemoryError", "Can't allocate memory for decompression object");
    } else {
        zlib_error(
            module, stream.zst.value.msg, err, "while creating decompression object"
        );
    }
    jacpy_release(instance);
    return NULL;
}

def zlib_Compress_compress_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    stream = stream_of(receiver, Compress_token);
    if stream is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    buffer = BlocksOutputBuffer();
    stream.enter();
    stream.zst.value.next_in = ptr[u8](data.address());
    remains = data.size();
    result = NULL;
    failed = not start_output(buffer, -1, &mut stream.zst);
    while not failed {
        remains = arrange_input(&mut stream.zst, remains);
        while not failed {
            if stream.zst.value.avail_out == 0 and not grow(buffer, &mut stream.zst) {
                failed = True;
                break;
            }
            thread = release_gil();
            err = deflate(&mut stream.zst, Z_NO_FLUSH);
            PyEval_RestoreThread(thread);
            if err == Z_STREAM_ERROR {
                zlib_error(module, stream.zst.value.msg, err, "while compressing data");
                failed = True;
            } elif stream.zst.value.avail_out != 0 {
                break;
            }
        }
        if remains == 0 {
            break;
        }
    }
    if not failed {
        result = buffer.finish(i64(stream.zst.value.avail_out));
    } else {
        buffer.discard();
    }
    stream.leave();
    return result;
}

# save_unconsumed_input(): bytes past the stream end, and input not yet read.
def:priv save_unconsumed(
    stream: ZlibStream, data_start: ptr, data_length: i64, err: i32
) -> bool {
    data_end = jacpy_offset(data_start, data_length);
    if err == Z_STREAM_END and stream.zst.value.avail_in > 0 {
        old_size = PyBytes_Size(stream.unused_data);
        left_size = jacpy_distance(data_end, stream.zst.value.next_in);
        if left_size > SSIZE_MAX - old_size {
            PyErr_NoMemory();
            return False;
        }
        joined = jacpy_buffer_new(old_size + left_size);
        if not joined {
            return False;
        }
        target: ptr = PyBytes_AsString(joined);
        jacpy_memory_copy(target, PyBytes_AsString(stream.unused_data), old_size);
        jacpy_memory_copy(
            jacpy_offset(target, old_size), stream.zst.value.next_in, left_size
        );
        jacpy_release(stream.unused_data);
        stream.unused_data = joined;
        stream.zst.value.avail_in = 0;
    }
    if stream.zst.value.avail_in > 0 or PyBytes_Size(stream.unconsumed_tail) > 0 {
        left_size = jacpy_distance(data_end, stream.zst.value.next_in);
        tail = jacpy_buffer_new(left_size);
        if not tail {
            return False;
        }
        jacpy_memory_copy(PyBytes_AsString(tail), stream.zst.value.next_in, left_size);
        jacpy_release(stream.unconsumed_tail);
        stream.unconsumed_tail = tail;
    }
    return True;
}

def zlib_Decompress_decompress_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], data: BufferArgument, max_length: i64
) -> ptr[PyObject] {
    stream = stream_of(receiver, Decompress_token);
    if stream is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    if not module {
        return NULL;
    }
    if max_length < 0 {
        object_error("ValueError", "max_length must be non-negative");
        return NULL;
    }
    limit = -1 if max_length == 0 else max_length;
    buffer = BlocksOutputBuffer();
    stream.enter();
    stream.zst.value.next_in = ptr[u8](data.address());
    remains = data.size();
    err = Z_OK;
    failed = not start_output(buffer, limit, &mut stream.zst);
    reached_limit = False;
    while not failed and not reached_limit {
        remains = arrange_input(&mut stream.zst, remains);
        while True {
            if stream.zst.value.avail_out == 0 {
                if buffer.data_size(i64(stream.zst.value.avail_out)) == limit {
                    reached_limit = True;
                    break;
                }
                if not grow(buffer, &mut stream.zst) {
                    failed = True;
                    break;
                }
            }
            thread = release_gil();
            err = inflate(&mut stream.zst, Z_SYNC_FLUSH);
            PyEval_RestoreThread(thread);
            if err != Z_OK and err != Z_BUF_ERROR and err != Z_STREAM_END {
                if err == Z_NEED_DICT and stream.zdict {
                    if not set_inflate_zdict(module, &mut stream.zst, stream.zdict) {
                        failed = True;
                        break;
                    }
                } else {
                    reached_limit = True;
                    break;
                }
            }
            if stream.zst.value.avail_out != 0 and err != Z_NEED_DICT {
                break;
            }
        }
        if err == Z_STREAM_END or remains == 0 {
            break;
        }
    }
    result = NULL;
    if not failed and save_unconsumed(stream, data.address(), data.size(), err) {
        if err == Z_STREAM_END {
            stream.eof = True;
        }
        if err != Z_OK and err != Z_BUF_ERROR and err != Z_STREAM_END {
            zlib_error(module, stream.zst.value.msg, err, "while decompressing data");
        } else {
            result = buffer.finish(i64(stream.zst.value.avail_out));
        }
    }
    if not result {
        buffer.discard();
    }
    stream.leave();
    return result;
}

def zlib_Compress_flush_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], mode: i32
) -> ptr[PyObject] {
    if mode == Z_NO_FLUSH {
        return empty_bytes();
    }
    stream = stream_of(receiver, Compress_token);
    if stream is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    buffer = BlocksOutputBuffer();
    stream.enter();
    stream.zst.value.avail_in = 0;
    result = NULL;
    err = Z_OK;
    failed = not start_output(buffer, -1, &mut stream.zst);
    while not failed {
        if stream.zst.value.avail_out == 0 and not grow(buffer, &mut stream.zst) {
            failed = True;
            break;
        }
        thread = release_gil();
        err = deflate(&mut stream.zst, mode);
        PyEval_RestoreThread(thread);
        if err == Z_STREAM_ERROR {
            zlib_error(module, stream.zst.value.msg, err, "while flushing");
            failed = True;
        } elif stream.zst.value.avail_out != 0 {
            break;
        }
    }
    if not failed {
        if err == Z_STREAM_END and mode == Z_FINISH {
            err = deflateEnd(&mut stream.zst);
            if err != Z_OK {
                zlib_error(
                    module, stream.zst.value.msg, err, "while finishing compression"
                );
                failed = True;
            } else {
                stream.is_initialised = False;
            }
        } elif err != Z_OK and err != Z_BUF_ERROR {
            zlib_error(module, stream.zst.value.msg, err, "while flushing");
            failed = True;
        }
    }
    if failed {
        buffer.discard();
    } else {
        result = buffer.finish(i64(stream.zst.value.avail_out));
    }
    stream.leave();
    return result;
}

def:priv copy_stream(
    receiver: ptr[PyObject], cls: ptr[PyObject], deflating: bool
) -> ptr[PyObject] {
    token = Compress_token if deflating else Decompress_token;
    stream = stream_of(receiver, token);
    if stream is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    (instance, copy) = new_stream_object(
        module, COMPRESS_TYPE if deflating else DECOMPRESS_TYPE, token, deflating
    );
    if copy is None {
        return NULL;
    }
    stream.enter();
    err = deflateCopy(&mut copy.zst, &mut stream.zst)
        if deflating
        else inflateCopy(&mut copy.zst, &mut stream.zst);
    kind = "compression" if deflating else "decompression";
    if err == Z_OK {
        jacpy_release(copy.unused_data);
        copy.unused_data = Py_NewRef(stream.unused_data);
        jacpy_release(copy.unconsumed_tail);
        copy.unconsumed_tail = Py_NewRef(stream.unconsumed_tail);
        copy.zdict = Py_NewRef(stream.zdict) if stream.zdict else NULL;
        copy.eof = stream.eof;
        copy.is_initialised = True;
        stream.leave();
        return instance;
    }
    if err == Z_STREAM_ERROR {
        object_error("ValueError", "Inconsistent stream state");
    } elif err == Z_MEM_ERROR {
        object_error("MemoryError", f"Can't allocate memory for {kind} object");
    } else {
        zlib_error(module, stream.zst.value.msg, err, f"while copying {kind} object");
    }
    stream.leave();
    jacpy_release(instance);
    return NULL;
}

def zlib_Compress_copy_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, True);
}

def zlib_Compress___copy___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, True);
}

def zlib_Compress___deepcopy___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, True);
}

def zlib_Decompress_copy_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, False);
}

def zlib_Decompress___copy___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, False);
}

def zlib_Decompress___deepcopy___impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], memo: ptr[PyObject]
) -> ptr[PyObject] {
    return copy_stream(receiver, cls, False);
}

def zlib_Decompress_flush_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], length: i64
) -> ptr[PyObject] {
    stream = stream_of(receiver, Decompress_token);
    if stream is None {
        return NULL;
    }
    module = PyType_GetModule(cls);
    if not module {
        return NULL;
    }
    if length <= 0 {
        object_error("ValueError", "length must be greater than zero");
        return NULL;
    }
    stream.enter();
    tail = BufferArgument();
    if not tail.acquire(stream.unconsumed_tail) {
        stream.leave();
        return NULL;
    }
    stream.zst.value.next_in = ptr[u8](tail.address());
    remains = tail.size();
    buffer = BlocksOutputBuffer();
    window = Window();
    err = Z_OK;
    failed = not window_init(buffer, window, length, &mut stream.zst);
    stopped = False;
    while not failed and not stopped {
        remains = arrange_input(&mut stream.zst, remains);
        flush = Z_FINISH if remains == 0 else Z_NO_FLUSH;
        while True {
            if stream.zst.value.avail_out == 0
                and not window_grow(buffer, window, &mut stream.zst) {
                failed = True;
                break;
            }
            thread = release_gil();
            err = inflate(&mut stream.zst, flush);
            PyEval_RestoreThread(thread);
            if err != Z_OK and err != Z_BUF_ERROR and err != Z_STREAM_END {
                stopped = True;
                break;
            }
            if stream.zst.value.avail_out != 0 and err != Z_NEED_DICT {
                break;
            }
        }
        if err == Z_STREAM_END or remains == 0 {
            break;
        }
    }
    result = NULL;
    if not failed and save_unconsumed(stream, tail.address(), tail.size(), err) {
        ok = True;
        if err == Z_STREAM_END {
            stream.eof = True;
            stream.is_initialised = False;
            err = inflateEnd(&mut stream.zst);
            if err != Z_OK {
                zlib_error(
                    module, stream.zst.value.msg, err, "while finishing decompression"
                );
                ok = False;
            }
        }
        if ok {
            result = window_finish(buffer, window, &mut stream.zst);
        }
    }
    if not result {
        buffer.discard();
    }
    tail.close();
    stream.leave();
    return result;
}

# ZlibDecompressor: a single-object stream with its own input buffer.
obj ZlibDecompressorState(NativeState) {
    has zst: Pinned[z_stream],
        zdict: ptr[PyObject] = NULL,
        lock: ptr = ptr(),
        unused_data: ptr[PyObject] = NULL,
        input_buffer: ptr = ptr(),
        input_buffer_size: i64 = 0,
        avail_in_real: i64 = 0,
        is_initialised: bool = False,
        eof: bool = False,
        needs_input: bool = True;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return jacpy_binding_visit(self.zdict, visitor, context);
    }

    def clear {
        jacpy_release(self.zdict);
        self.zdict = NULL;
    }

    def drop {
        if self.lock {
            PyThread_free_lock(self.lock);
        }
        if self.is_initialised {
            inflateEnd(&mut self.zst);
        }
        PyMem_Free(self.input_buffer);
        jacpy_release(self.unused_data);
        jacpy_release(self.zdict);
    }
}

def:priv decompressor_of(instance: ptr[PyObject]) -> ZlibDecompressorState | None {
    if jacpy_binding_native_present(instance, ZlibDecompressor_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, ZlibDecompressor_token.handle);
        if isinstance(state, ZlibDecompressorState) {
            return state;
        }
    }
    object_error("SystemError", "zlib decompressor state is unavailable");
    return None;
}

# tp_new: _ZlibDecompressor(wbits=15, zdict=b'').
def zlib_decompressor_new(
    cls: ptr[PyObject], wbits: i32, zdict: ptr[PyObject]
) -> ptr[PyObject] {
    module = PyType_GetModule(cls);
    instance = jacpy_binding_allocate(cls);
    if not instance {
        return NULL;
    }
    state = ZlibDecompressorState(
        zst=new_stream(),
        zdict=Py_NewRef(zdict) if zdict else NULL,
        unused_data=empty_bytes()
    );
    if not state.unused_data {
        jacpy_release(instance);
        return NULL;
    }
    state.lock = PyThread_allocate_lock();
    if not state.lock {
        jacpy_release(instance);
        object_error("MemoryError", "Unable to allocate lock");
        return NULL;
    }
    if jacpy_binding_native_set(instance, ZlibDecompressor_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    err = inflate_init(&mut state.zst, wbits);
    if err == Z_OK {
        state.is_initialised = True;
        if state.zdict
            and wbits < 0
            and not set_inflate_zdict(module, &mut state.zst, state.zdict) {
            jacpy_release(instance);
            return NULL;
        }
        return instance;
    }
    if err == Z_STREAM_ERROR {
        object_error("ValueError", "Invalid initialization option");
    } elif err == Z_MEM_ERROR {
        object_error("MemoryError", "Can't allocate memory for decompression object");
    } else {
        zlib_error(
            module, state.zst.value.msg, err, "while creating decompression object"
        );
    }
    jacpy_release(instance);
    return NULL;
}

# arrange_output_buffer_with_maximum(): one growable bytes result. Returns the
# (possibly reallocated) result and its length; -1 on failure, -2 at the limit.
def:priv arrange_output(
    state: ZlibDecompressorState, result: ptr[PyObject], length: i64, limit: i64
) -> tuple[ptr[PyObject], i64] {
    occupied: i64 = 0;
    current = result;
    if not current {
        current = jacpy_buffer_new(length);
        if not current {
            return (NULL, -1);
        }
    } else {
        occupied = jacpy_distance(state.zst.value.next_out, PyBytes_AsString(current));
        if length == occupied {
            if length == limit {
                return (current, -2);
            }
            grown = length << 1 if length <= (limit >> 1) else limit;
            if _PyBytes_Resize(&mut current, grown) < 0 {
                return (NULL, -1);
            }
            length = grown;
        }
    }
    room = length - occupied;
    state.zst.value.avail_out = u32(room if room < UINT_MAX else UINT_MAX);
    state.zst.value.next_out = ptr[u8](
        jacpy_offset(PyBytes_AsString(current), occupied)
    );
    return (current, length);
}

def:priv decompress_buf(
    state: ZlibDecompressorState, module: ptr[PyObject], max_length: i64
) -> ptr[PyObject] {
    result = NULL;
    limit = SSIZE_MAX;
    size = DEF_BUF_SIZE;
    if max_length >= 0 and max_length != SSIZE_MAX {
        limit = max_length;
        size = max_length
            if max_length <= DEF_MAX_INITIAL_BUF_SIZE
            else DEF_MAX_INITIAL_BUF_SIZE;
    }
    err = Z_OK;
    while True {
        state.avail_in_real = arrange_input(&mut state.zst, state.avail_in_real);
        while True {
            (result, size) = arrange_output(state, result, size, limit);
            if size == -1 {
                object_error(
                    "MemoryError", "Insufficient memory for buffer allocation"
                );
                jacpy_release(result);
                return NULL;
            }
            if size == -2 {
                break;
            }
            thread = release_gil();
            err = inflate(&mut state.zst, Z_SYNC_FLUSH);
            PyEval_RestoreThread(thread);
            if err == Z_NEED_DICT {
                jacpy_release(result);
                return NULL;
            }
            if state.zst.value.avail_out != 0 {
                break;
            }
        }
        if err == Z_STREAM_END or state.avail_in_real == 0 {
            break;
        }
    }
    if err == Z_STREAM_END {
        state.eof = True;
        state.is_initialised = False;
        err = inflateEnd(&mut state.zst);
        if err != Z_OK {
            zlib_error(
                module, state.zst.value.msg, err, "while finishing decompression"
            );
            jacpy_release(result);
            return NULL;
        }
    } elif err != Z_OK and err != Z_BUF_ERROR {
        zlib_error(module, state.zst.value.msg, err, "while decompressing data");
        jacpy_release(result);
        return NULL;
    }
    state.avail_in_real += i64(state.zst.value.avail_in);
    if _PyBytes_Resize(
        &mut result, jacpy_distance(state.zst.value.next_out, PyBytes_AsString(result))
    )
        != 0 {
        return NULL;
    }
    return result;
}

def:priv decompress_input(
    state: ZlibDecompressorState,
    module: ptr[PyObject],
    data: ptr,
    length: i64,
    max_length: i64
) -> ptr[PyObject] {
    in_use = False;
    if not state.zst.value.next_in.is_null() {
        buffer_end = jacpy_offset(state.input_buffer, state.input_buffer_size);
        avail_now = jacpy_distance(
            buffer_end, jacpy_offset(state.zst.value.next_in, state.avail_in_real)
        );
        avail_total = state.input_buffer_size - state.avail_in_real;
        if avail_total < length {
            offset = jacpy_distance(state.zst.value.next_in, state.input_buffer);
            new_size = state.input_buffer_size + length - avail_now;
            grown = PyMem_Realloc(state.input_buffer, u64(new_size));
            if not grown {
                PyErr_NoMemory();
                return NULL;
            }
            state.input_buffer = grown;
            state.input_buffer_size = new_size;
            state.zst.value.next_in = ptr[u8](jacpy_offset(grown, offset));
        } elif avail_now < length {
            jacpy_memory_move(
                state.input_buffer, state.zst.value.next_in, state.avail_in_real
            );
            state.zst.value.next_in = ptr[u8](state.input_buffer);
        }
        jacpy_memory_copy(
            jacpy_offset(state.zst.value.next_in, state.avail_in_real), data, length
        );
        state.avail_in_real += length;
        in_use = True;
    } else {
        state.zst.value.next_in = ptr[u8](data);
        state.avail_in_real = length;
    }
    result = decompress_buf(state, module, max_length);
    if not result {
        state.zst.value.next_in = ptr[u8]();
        return NULL;
    }
    if state.eof {
        state.needs_input = False;
        if state.avail_in_real > 0 {
            unused = jacpy_buffer_new(state.avail_in_real);
            if not unused {
                state.zst.value.next_in = ptr[u8]();
                jacpy_release(result);
                return NULL;
            }
            jacpy_memory_copy(
                PyBytes_AsString(unused), state.zst.value.next_in, state.avail_in_real
            );
            jacpy_release(state.unused_data);
            state.unused_data = unused;
        }
    } elif state.avail_in_real == 0 {
        state.zst.value.next_in = ptr[u8]();
        state.needs_input = True;
    } else {
        state.needs_input = False;
        if not in_use {
            if state.input_buffer and state.input_buffer_size < state.avail_in_real {
                PyMem_Free(state.input_buffer);
                state.input_buffer = ptr();
            }
            if not state.input_buffer {
                state.input_buffer = PyMem_Malloc(u64(state.avail_in_real));
                if not state.input_buffer {
                    PyErr_NoMemory();
                    state.zst.value.next_in = ptr[u8]();
                    jacpy_release(result);
                    return NULL;
                }
                state.input_buffer_size = state.avail_in_real;
            }
            jacpy_memory_copy(
                state.input_buffer, state.zst.value.next_in, state.avail_in_real
            );
            state.zst.value.next_in = ptr[u8](state.input_buffer);
        }
    }
    return result;
}

def zlib_ZlibDecompressor_decompress_impl(
    receiver: ptr[PyObject], data: BufferArgument, max_length: i64
) -> ptr[PyObject] {
    state = decompressor_of(receiver);
    if state is None {
        return NULL;
    }
    lock = state.lock;
    if PyThread_acquire_lock(lock, 0) == 0 {
        thread = release_gil();
        PyThread_acquire_lock(lock, 1);
        PyEval_RestoreThread(thread);
    }
    result = NULL;
    if state.eof {
        object_error("EOFError", "End of stream already reached");
    } else {
        result = decompress_input(
            state,
            PyType_GetModule(Py_TYPE(receiver)),
            data.address(),
            data.size(),
            max_length
        );
    }
    PyThread_release_lock(lock);
    return result;
}

def zlib_adler32_impl(
    module: ptr[PyObject], data: BufferArgument, value_: u32
) -> ptr[PyObject] {
    checksum = u64(value_);
    position = data.address();
    remains = data.size();
    thread = release_gil() if remains > 1024 * 5 else ptr[PyThreadState]();
    while remains > UINT_MAX {
        checksum = adler32(checksum, position, u32(UINT_MAX));
        position = jacpy_offset(position, UINT_MAX);
        remains -= UINT_MAX;
    }
    checksum = adler32(checksum, position, u32(remains));
    if thread {
        PyEval_RestoreThread(thread);
    }
    return PyLong_FromUnsignedLong(checksum & u64(0xFFFFFFFF));
}

def zlib_crc32_impl(module: ptr[PyObject], data: BufferArgument, value_: u32) -> u32 {
    checksum = u64(value_);
    position = data.address();
    remains = data.size();
    thread = release_gil() if remains > 1024 * 5 else ptr[PyThreadState]();
    while remains > CRC_CHUNK_SIZE {
        checksum = crc32(checksum, position, u32(CRC_CHUNK_SIZE));
        position = jacpy_offset(position, CRC_CHUNK_SIZE);
        remains -= CRC_CHUNK_SIZE;
    }
    checksum = crc32(checksum, position, u32(remains));
    if thread {
        PyEval_RestoreThread(thread);
    }
    return u32(checksum & u64(0xFFFFFFFF));
}

def runtime_version -> ptr[PyObject] {
    return jacpy_fs_text(zlibVersion());
}
