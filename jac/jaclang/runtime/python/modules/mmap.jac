import from c {
    def close(fd: i32) -> i32;  def munmap(address: ptr, length: u64) -> i32;  def mmap(
        address: ptr, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> ptr;  def msync(address: ptr, length: u64, flags: i32) -> i32;  def madvise(
        address: ptr, length: u64, advice: i32
    ) -> i32;  def ftruncate(fd: i32, length: i64) -> i32;  def memchr(
        address: ptr, character: i32, count: u64
    ) -> ptr;  def memmove(target: ptr, source: ptr, count: u64) -> ptr;  def sysconf(
        name: i32
    ) -> i64;
}
import from c { def fcntl(fd: i32, command: i32, *args: any) -> i32;  }

glob PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF;

glob:priv ACCESS_DEFAULT: int = 0,
     ACCESS_READ: int = 1,
     ACCESS_WRITE: int = 2,
     ACCESS_COPY: int = 3,
     ACCESS_NAMES: list[str] = [
         "ACCESS_DEFAULT",
         "ACCESS_READ",
         "ACCESS_WRITE",
         "ACCESS_COPY"
     ],
     S_IFMT: int = 0o170000,
     S_IFREG: int = 0o100000,
     PyBUF_SIMPLE: i32 = 0;

glob mmap_token = ClassToken();

obj MmapState(NativeState) {
    has data: ptr[u8] = ptr[u8](),
        size: i64 = 0,
        pos: i64 = 0,
        offset: i64 = 0,
        exports: i64 = 0,
        fd: i32 = -1,
        trackfd: bool = True,
        flags: i32 = 0,
        access: int = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

def mmap_of(instance: ptr[PyObject]) -> (MmapState | None);

def:priv valid(state: MmapState) -> bool;

def:priv open_state(instance: ptr[PyObject]) -> (MmapState | None);

def:priv os_error -> ptr[PyObject];

def:priv as_ssize(value: ptr[PyObject]) -> i64;

def:priv failed(value: i64) -> bool;

def:priv release_mapping(state: MmapState);

def mmap_release(instance: ptr[PyObject]);

def mmap_mmap_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def:priv bytes_at(address: ptr[u8], count: i64) -> ptr[PyObject];

def mmap_mmap_read_byte_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap_readline_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap_read_impl(receiver: ptr[PyObject], num_bytes: i64) -> ptr[PyObject];

def:priv gfind(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start_obj: ptr[PyObject],
    end_obj: ptr[PyObject],
    reverse: bool
) -> ptr[PyObject];

def mmap_mmap_find_impl(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start: ptr[PyObject],
    end: ptr[PyObject]
) -> ptr[PyObject];

def mmap_mmap_rfind_impl(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start: ptr[PyObject],
    end: ptr[PyObject]
) -> ptr[PyObject];

def:priv is_writable(state: MmapState) -> bool;

def:priv is_resizeable(state: MmapState) -> bool;

def mmap_mmap_write_impl(
    receiver: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject];

def mmap_mmap_write_byte_impl(receiver: ptr[PyObject], value: u8) -> ptr[PyObject];

def mmap_mmap_size_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap_resize_impl(receiver: ptr[PyObject], new_size: i64) -> ptr[PyObject];

def mmap_mmap_tell_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap_flush_impl(
    receiver: ptr[PyObject], offset: i64, size_obj: ptr[PyObject]
) -> ptr[PyObject];

def mmap_mmap_seek_impl(receiver: ptr[PyObject], dist: i64, how: i32) -> ptr[PyObject];

def mmap_mmap_seekable_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap_move_impl(
    receiver: ptr[PyObject], dest: i64, src: i64, cnt: i64
) -> ptr[PyObject];

def mmap_closed_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject];

def mmap_mmap___enter___impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap___exit___impl(
    receiver: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    traceback: ptr[PyObject]
) -> ptr[PyObject];

def mmap_repr(instance: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap___sizeof___impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def mmap_mmap__protect_impl(
    receiver: ptr[PyObject], flNewProtect: u32, start: i64, length: i64
) -> ptr[PyObject];

def mmap_mmap_madvise_impl(
    receiver: ptr[PyObject], option: i32, start: i64, length_obj: ptr[PyObject]
) -> ptr[PyObject];

def mmap_getbuffer(instance: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def mmap_releasebuffer(instance: ptr[PyObject], view: ptr[Py_buffer]);

def mmap_length(instance: ptr[PyObject]) -> i64;

def mmap_item(instance: ptr[PyObject], i: i64) -> ptr[PyObject];

def mmap_subscript(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject];

def mmap_ass_item(instance: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32;

def mmap_ass_subscript(
    instance: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def:priv audit_new(fd: i32, map_size: i64, access: int, offset: i64) -> bool;

def mmap_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def page_size -> i64;

impl MmapState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl MmapState.clear {}

impl mmap_of(instance: ptr[PyObject]) -> (MmapState | None) {
    if jacpy_binding_native_present(instance, mmap_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, mmap_token.handle);
        if isinstance(state, MmapState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "mmap state is unavailable");
    return None;
}

impl valid(state: MmapState) -> bool {
    if state.data.is_null() {
        object_error(PyExc_ValueError, "mmap closed or invalid");
        return False;
    }
    return True;
}

impl open_state(instance: ptr[PyObject]) -> (MmapState | None) {
    state = mmap_of(instance);
    if state is None or not valid(state) {
        return None;
    }
    return state;
}

impl os_error -> ptr[PyObject] {
    PyErr_SetFromErrno(PyExc_OSError);
    return NULL;
}

impl as_ssize(value: ptr[PyObject]) -> i64 {
    index = _PyNumber_Index(value);
    if not index {
        return -1;
    }
    result = PyLong_AsSsize_t(index);
    jacpy_release(index);
    return result;
}

impl failed(value: i64) -> bool {
    return value == -1 and bool(PyErr_Occurred());
}

impl release_mapping(state: MmapState) {
    fd = state.fd;
    data = state.data;
    state.fd = i32(-1);
    state.data = ptr[u8]();
    thread = PyEval_SaveThread();
    if fd >= 0 {
        close(fd);
    }
    if not data.is_null() {
        munmap(ptr(data), u64(state.size));
    }
    PyEval_RestoreThread(thread);
}

impl mmap_release(instance: ptr[PyObject]) {
    if jacpy_binding_native_present(instance, mmap_token.handle) != 0 {
        state = mmap_of(instance);
        if state is not None {
            release_mapping(state);
        }
    }
}

impl mmap_mmap_close_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = mmap_of(receiver);
    if state is None {
        return NULL;
    }
    if state.exports > 0 {
        object_error(PyExc_BufferError, "cannot close exported pointers exist");
        return NULL;
    }
    release_mapping(state);
    return Py_NewRef(borrowed_none());
}

impl bytes_at(address: ptr[u8], count: i64) -> ptr[PyObject] {
    return jacpy_bytes_from_memory(ptr(address), count);
}

impl mmap_mmap_read_byte_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    if state.pos >= state.size {
        object_error(PyExc_ValueError, "read byte out of range");
        return NULL;
    }
    dest = (state.data + state.pos).view(1)[0];
    state.pos += 1;
    return PyLong_FromLong(i64(dest));
}

impl mmap_mmap_readline_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    remaining = state.size - state.pos if state.pos < state.size else i64(0);
    if remaining == 0 {
        return bytes_at(state.data, 0);
    }
    start = state.data + state.pos;
    eol = ptr[u8](memchr(ptr(start), i32(10), u64(remaining)));
    if eol.is_null() {
        eol = state.data + state.size;
    } else {
        eol += 1;
    }
    length = eol - start;
    result = bytes_at(start, length);
    if result {
        state.pos += length;
    }
    return result;
}

impl mmap_mmap_read_impl(receiver: ptr[PyObject], num_bytes: i64) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }

    remaining = state.size - state.pos if state.pos < state.size else i64(0);
    count = num_bytes;
    if count < 0 or count > remaining {
        count = remaining;
    }
    result = bytes_at(state.data + state.pos, count);
    if result {
        state.pos += count;
    }
    return result;
}

impl gfind(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start_obj: ptr[PyObject],
    end_obj: ptr[PyObject],
    reverse: bool
) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    start = state.pos;
    end = state.size;
    if start_obj != borrowed_none() {
        start = as_ssize(start_obj);
        if failed(start) {
            return NULL;
        }
        if end_obj != borrowed_none() {
            end = as_ssize(end_obj);
            if failed(end) {
                return NULL;
            }
        }
    }
    if start < 0 {
        start += state.size;
    }
    if start < 0 {
        start = 0;
    } elif start > state.size {
        start = state.size;
    }
    if end < 0 {
        end += state.size;
    }
    if end < 0 {
        end = 0;
    } elif end > state.size {
        end = state.size;
    }

    if not valid(state) {
        return NULL;
    }
    if end < start {
        return PyLong_FromSsize_t(-1);
    }
    haystack = ptr(state.data + start);
    index = _PyBytes_ReverseFind(
        haystack, end - start, view.address(), view.size(), start
    )
        if reverse
        else _PyBytes_Find(haystack, end - start, view.address(), view.size(), start);
    return PyLong_FromSsize_t(index);
}

impl mmap_mmap_find_impl(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start: ptr[PyObject],
    end: ptr[PyObject]
) -> ptr[PyObject] {
    return gfind(receiver, view, start, end, False);
}

impl mmap_mmap_rfind_impl(
    receiver: ptr[PyObject],
    view: BufferArgument,
    start: ptr[PyObject],
    end: ptr[PyObject]
) -> ptr[PyObject] {
    return gfind(receiver, view, start, end, True);
}

impl is_writable(state: MmapState) -> bool {
    if state.access != ACCESS_READ {
        return True;
    }
    object_error(PyExc_TypeError, "mmap can't modify a readonly memory map.");
    return False;
}

impl is_resizeable(state: MmapState) -> bool {
    if state.exports > 0 {
        object_error(
            PyExc_BufferError, "mmap can't resize with extant buffers exported."
        );
        return False;
    }
    if not state.trackfd {
        object_error(PyExc_ValueError, "mmap can't resize with trackfd=False.");
        return False;
    }
    if state.access == ACCESS_WRITE or state.access == ACCESS_DEFAULT {
        return True;
    }
    object_error(
        PyExc_TypeError, "mmap can't resize a readonly or copy-on-write memory map."
    );
    return False;
}

impl mmap_mmap_write_impl(
    receiver: ptr[PyObject], data: BufferArgument
) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None or not is_writable(state) {
        return NULL;
    }
    length = data.size();
    if state.pos > state.size or state.size - state.pos < length {
        object_error(PyExc_ValueError, "data out of range");
        return NULL;
    }
    if not valid(state) {
        return NULL;
    }
    memmove(ptr(state.data + state.pos), data.address(), u64(length));
    state.pos += length;
    return PyLong_FromSsize_t(length);
}

impl mmap_mmap_write_byte_impl(receiver: ptr[PyObject], value: u8) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None or not is_writable(state) {
        return NULL;
    }
    if state.pos >= state.size {
        object_error(PyExc_ValueError, "write byte out of range");
        return NULL;
    }
    (state.data + state.pos).view(1)[0] = value;
    state.pos += 1;
    return Py_NewRef(borrowed_none());
}

impl mmap_mmap_size_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    status = _Py_stat_struct();
    if _Py_fstat(state.fd, &mut status) == -1 {
        return NULL;
    }
    return PyLong_FromSsize_t(status.st_size);
}

impl mmap_mmap_resize_impl(receiver: ptr[PyObject], new_size: i64) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None or not is_resizeable(state) {
        return NULL;
    }
    if new_size < 0 or PY_SSIZE_T_MAX - new_size < state.offset {
        object_error(PyExc_ValueError, "new size out of range");
        return NULL;
    }
    if not HAS_MREMAP {
        object_error(PyExc_SystemError, "mmap: resizing not available--no mremap()");
        return NULL;
    }
    if REFUSES_SHARED_ANONYMOUS_GROWTH
        and state.fd == -1
        and (int(state.flags) & MAP_PRIVATE) == 0
        and new_size > state.size {
        object_error(
            PyExc_ValueError, "mmap: can't expand a shared anonymous mapping on Linux"
        );
        return NULL;
    }
    if state.fd != -1 and ftruncate(state.fd, state.offset + new_size) == -1 {
        return os_error();
    }
    newmap = mremap(
        ptr(state.data), u64(state.size), u64(new_size), i32(MREMAP_MAYMOVE)
    );
    if int(newmap) == -1 {
        return os_error();
    }
    state.data = ptr[u8](newmap);
    state.size = new_size;
    return Py_NewRef(borrowed_none());
}

impl mmap_mmap_tell_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromSize_t(u64(state.pos));
}

impl mmap_mmap_flush_impl(
    receiver: ptr[PyObject], offset: i64, size_obj: ptr[PyObject]
) -> ptr[PyObject] {
    state = mmap_of(receiver);
    if state is None {
        return NULL;
    }
    size = state.size;
    if not valid(state) {
        return NULL;
    }
    if size_obj != borrowed_none() {
        size = as_ssize(size_obj);
        if failed(size) {
            return NULL;
        }
    }
    if size < 0 or offset < 0 or state.size - offset < size {
        object_error(PyExc_ValueError, "flush values out of range");
        return NULL;
    }
    if state.access == ACCESS_READ or state.access == ACCESS_COPY {
        return Py_NewRef(borrowed_none());
    }
    if msync(ptr(state.data + offset), u64(size), i32(MS_SYNC)) == -1 {
        return os_error();
    }
    return Py_NewRef(borrowed_none());
}

impl mmap_mmap_seek_impl(
    receiver: ptr[PyObject], dist: i64, how: i32
) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    where: i64 = 0;
    if how == 0 {
        where = dist;
    } elif how == 1 {
        if PY_SSIZE_T_MAX - state.pos < dist {
            object_error(PyExc_ValueError, "seek out of range");
            return NULL;
        }
        where = state.pos + dist;
    } elif how == 2 {
        if PY_SSIZE_T_MAX - state.size < dist {
            object_error(PyExc_ValueError, "seek out of range");
            return NULL;
        }
        where = state.size + dist;
    } else {
        object_error(PyExc_ValueError, "unknown seek type");
        return NULL;
    }
    if where > state.size or where < 0 {
        object_error(PyExc_ValueError, "seek out of range");
        return NULL;
    }
    state.pos = where;
    return PyLong_FromSsize_t(state.pos);
}

impl mmap_mmap_seekable_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(borrowed_true());
}

impl mmap_mmap_move_impl(
    receiver: ptr[PyObject], dest: i64, src: i64, cnt: i64
) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None or not is_writable(state) {
        return NULL;
    }
    if dest < 0
        or src < 0
        or cnt < 0
        or state.size - dest < cnt
        or state.size - src < cnt {
        object_error(PyExc_ValueError, "source, destination, or count out of range");
        return NULL;
    }
    memmove(ptr(state.data + dest), ptr(state.data + src), u64(cnt));
    return Py_NewRef(borrowed_none());
}

impl mmap_closed_get(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    state = mmap_of(instance);
    if state is None {
        return NULL;
    }
    return Py_NewRef(borrowed_true() if state.data.is_null() else borrowed_false());
}

impl mmap_mmap___enter___impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    return Py_NewRef(receiver);
}

impl mmap_mmap___exit___impl(
    receiver: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    traceback: ptr[PyObject]
) -> ptr[PyObject] {
    return mmap_mmap_close_impl(receiver);
}

impl mmap_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    state = mmap_of(instance);
    if state is None {
        return NULL;
    }
    name = type_name(instance);
    if state.data.is_null() {
        return jacpy_unicode_from_text(f"<{name} closed=True>");
    }
    return jacpy_unicode_from_text(
        f"<{name} closed=False, access={ACCESS_NAMES[state.access]}, length={state.size}, pos={state.pos}, offset={state.offset}>"
    );
}

impl mmap_mmap___sizeof___impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "mmap.__sizeof__ is Windows-only");
    return NULL;
}

impl mmap_mmap__protect_impl(
    receiver: ptr[PyObject], flNewProtect: u32, start: i64, length: i64
) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "mmap._protect is Windows-only");
    return NULL;
}

impl mmap_mmap_madvise_impl(
    receiver: ptr[PyObject], option: i32, start: i64, length_obj: ptr[PyObject]
) -> ptr[PyObject] {
    state = open_state(receiver);
    if state is None {
        return NULL;
    }
    length: i64 = 0;
    if length_obj == borrowed_none() {
        length = state.size;
    } else {
        length = as_ssize(length_obj);
        if failed(length) {
            return NULL;
        }
    }
    if start < 0 or start >= state.size {
        object_error(PyExc_ValueError, "madvise start out of bounds");
        return NULL;
    }
    if length < 0 {
        object_error(PyExc_ValueError, "madvise length invalid");
        return NULL;
    }
    if PY_SSIZE_T_MAX - start < length {
        object_error(PyExc_OverflowError, "madvise length too large");
        return NULL;
    }
    if start + length > state.size {
        length = state.size - start;
    }
    if not valid(state) {
        return NULL;
    }
    if madvise(ptr(state.data + start), u64(length), option) != 0 {
        return os_error();
    }
    return Py_NewRef(borrowed_none());
}

impl mmap_getbuffer(instance: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    state = open_state(instance);
    if state is None {
        return i32(-1);
    }
    layout = BufferLayout(
        address=ptr(state.data),
        count=state.size,
        itemsize=1,
        readonly=i64(state.access == ACCESS_READ)
    );
    status = jacpy_binding_buffer_fill(view, instance, layout, "B", flags);
    if status == 0 {
        state.exports += 1;
    }
    return status;
}

impl mmap_releasebuffer(instance: ptr[PyObject], view: ptr[Py_buffer]) {
    state = mmap_of(instance);
    if state is not None {
        state.exports -= 1;
    }
    jacpy_binding_buffer_dispose(view);
}

impl mmap_length(instance: ptr[PyObject]) -> i64 {
    state = open_state(instance);
    if state is None {
        return -1;
    }
    return state.size;
}

impl mmap_item(instance: ptr[PyObject], i: i64) -> ptr[PyObject] {
    state = open_state(instance);
    if state is None {
        return NULL;
    }
    if i < 0 or i >= state.size {
        object_error(PyExc_IndexError, "mmap index out of range");
        return NULL;
    }
    return bytes_at(state.data + i, 1);
}

impl mmap_subscript(instance: ptr[PyObject], item: ptr[PyObject]) -> ptr[PyObject] {
    state = open_state(instance);
    if state is None {
        return NULL;
    }
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if failed(i) {
            return NULL;
        }
        if i < 0 {
            i += state.size;
        }
        if i < 0 or i >= state.size {
            object_error(PyExc_IndexError, "mmap index out of range");
            return NULL;
        }
        if not valid(state) {
            return NULL;
        }
        return PyLong_FromLong(i64((state.data + i).view(1)[0]));
    }
    if jacpy_is_slice(item) != 0 {
        bounds = jacpy_slice_unpack(item);
        if bounds.valid == 0 {
            return NULL;
        }
        bounds = jacpy_slice_adjust(state.size, bounds);
        slicelen = bounds.count;
        if not valid(state) {
            return NULL;
        }
        if slicelen <= 0 {
            return bytes_at(state.data, 0);
        }
        if bounds.step == 1 {
            return bytes_at(state.data + bounds.start, slicelen);
        }
        result_buf = ptr[u8](PyMem_Malloc(u64(slicelen)));
        if result_buf.is_null() {
            return PyErr_NoMemory();
        }

        target = result_buf.view(int(slicelen));
        for i in range(int(slicelen)) {
            target[i] = (state.data + (bounds.start + i * bounds.step)).view(1)[0];
        }
        result = bytes_at(result_buf, slicelen);
        PyMem_Free(ptr(result_buf));
        return result;
    }
    object_error(PyExc_TypeError, "mmap indices must be integers");
    return NULL;
}

impl mmap_ass_item(instance: ptr[PyObject], i: i64, v: ptr[PyObject]) -> i32 {
    state = open_state(instance);
    if state is None {
        return i32(-1);
    }
    if i < 0 or i >= state.size {
        object_error(PyExc_IndexError, "mmap index out of range");
        return i32(-1);
    }
    if not v {
        object_error(PyExc_TypeError, "mmap object doesn't support item deletion");
        return i32(-1);
    }
    if jacpy_is_bytes(v) == 0 or jacpy_bytes_length(v) != 1 {
        object_error(PyExc_IndexError, "mmap assignment must be length-1 bytes()");
        return i32(-1);
    }
    if not is_writable(state) {
        return i32(-1);
    }
    (state.data + i).view(1)[0] = PyBytes_AsString(v).view(1)[0];
    return i32(0);
}

impl mmap_ass_subscript(
    instance: ptr[PyObject], item: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    state = open_state(instance);
    if state is None or not is_writable(state) {
        return i32(-1);
    }
    if PyIndex_Check(item) != 0 {
        i = PyNumber_AsSsize_t(item, PyExc_IndexError);
        if failed(i) {
            return i32(-1);
        }
        if i < 0 {
            i += state.size;
        }
        if i < 0 or i >= state.size {
            object_error(PyExc_IndexError, "mmap index out of range");
            return i32(-1);
        }
        if not value {
            object_error(PyExc_TypeError, "mmap doesn't support item deletion");
            return i32(-1);
        }
        if PyIndex_Check(value) == 0 {
            object_error(PyExc_TypeError, "mmap item value must be an int");
            return i32(-1);
        }
        v = PyNumber_AsSsize_t(value, PyExc_TypeError);
        if failed(v) {
            return i32(-1);
        }
        if v < 0 or v > 255 {
            object_error(PyExc_ValueError, "mmap item value must be in range(0, 256)");
            return i32(-1);
        }
        if not valid(state) {
            return i32(-1);
        }
        (state.data + i).view(1)[0] = u8(v);
        return i32(0);
    }
    if jacpy_is_slice(item) != 0 {
        bounds = jacpy_slice_unpack(item);
        if bounds.valid == 0 {
            return i32(-1);
        }
        bounds = jacpy_slice_adjust(state.size, bounds);
        slicelen = bounds.count;
        if not value {
            object_error(PyExc_TypeError, "mmap object doesn't support slice deletion");
            return i32(-1);
        }
        source = BufferArgument();
        if not source.acquire(value) {
            return i32(-1);
        }
        if source.size() != slicelen {
            object_error(PyExc_IndexError, "mmap slice assignment is wrong size");
            return i32(-1);
        }
        if not valid(state) {
            return i32(-1);
        }
        if slicelen == 0 {
            return i32(0);
        }
        if bounds.step == 1 {
            memmove(ptr(state.data + bounds.start), source.address(), u64(slicelen));
            return i32(0);
        }
        incoming = ptr[u8](source.address()).view(int(slicelen));
        for i in range(int(slicelen)) {
            (state.data + (bounds.start + i * bounds.step)).view(1)[0] = incoming[i];
        }
        return i32(0);
    }
    object_error(PyExc_TypeError, "mmap indices must be integer");
    return i32(-1);
}

impl audit_new(fd: i32, map_size: i64, access: int, offset: i64) -> bool {
    arguments = owned_tuple(
        [
            PyLong_FromLong(i64(fd)),
            PyLong_FromSsize_t(map_size),
            PyLong_FromLong(i64(access)),
            PyLong_FromLong(offset)
        ]
    );
    if not arguments {
        return False;
    }
    status = PySys_AuditTuple(ptr[u8]("mmap.__new__"), arguments);
    jacpy_release(arguments);
    return status >= 0;
}

impl mmap_new(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    values: list[ArgumentValue] = [];
    try {
        values = ArgumentFormat().parse_keywords(
            args,
            kwargs,
            "in|iiiL$p",
            ["fileno", "length", "flags", "prot", "access", "offset", "trackfd"]
        );
    } except boundary_failure {
        return NULL;
    }
    fd = i32(values[0].signed);
    map_size = values[1].signed;
    flags = int(values[2].signed) if values[2].given else int(MAP_SHARED);
    prot = int(values[3].signed) if values[3].given else int(PROT_WRITE | PROT_READ);
    access = int(values[4].signed) if values[4].given else ACCESS_DEFAULT;
    offset = values[5].signed if values[5].given else i64(0);
    trackfd = values[6].flag if values[6].given else True;
    if map_size < 0 {
        object_error(PyExc_OverflowError, "memory mapped length must be positive");
        return NULL;
    }
    if offset < 0 {
        object_error(PyExc_OverflowError, "memory mapped offset must be positive");
        return NULL;
    }
    if access != ACCESS_DEFAULT
        and (flags != MAP_SHARED or prot != int(PROT_WRITE | PROT_READ)) {
        object_error(
            PyExc_ValueError, "mmap can't specify both access and flags, prot."
        );
        return NULL;
    }
    if access == ACCESS_READ {
        flags = int(MAP_SHARED);
        prot = int(PROT_READ);
    } elif access == ACCESS_WRITE {
        flags = int(MAP_SHARED);
        prot = int(PROT_READ | PROT_WRITE);
    } elif access == ACCESS_COPY {
        flags = int(MAP_PRIVATE);
        prot = int(PROT_READ | PROT_WRITE);
    } elif access == ACCESS_DEFAULT {
        if (prot & PROT_READ) != 0 and (prot & PROT_WRITE) != 0 {
            access = ACCESS_DEFAULT;
        } elif (prot & PROT_WRITE) != 0 {
            access = ACCESS_WRITE;
        } else {
            access = ACCESS_READ;
        }
    } else {
        object_error(PyExc_ValueError, "mmap invalid access parameter.");
        return NULL;
    }
    if not audit_new(fd, map_size, access, offset) {
        return NULL;
    }

    if FULLFSYNC_BEFORE_MAP and fd != -1 {
        fcntl(fd, i32(F_FULLFSYNC));
    }
    status = _Py_stat_struct();
    fstat_result: i32 = -1;
    if fd != -1 {
        thread = PyEval_SaveThread();
        fstat_result = _Py_fstat_noraise(fd, &mut status);
        PyEval_RestoreThread(thread);
    }
    if fd != -1 and fstat_result == 0 and (int(status.st_mode) & S_IFMT) == S_IFREG {
        file_size = status.st_size;
        if map_size == 0 {
            if file_size == 0 {
                object_error(PyExc_ValueError, "cannot mmap an empty file");
                return NULL;
            }
            if offset >= file_size {
                object_error(PyExc_ValueError, "mmap offset is greater than file size");
                return NULL;
            }
            map_size = file_size - offset;
        } elif offset > file_size or file_size - offset < map_size {
            object_error(PyExc_ValueError, "mmap length is greater than file size");
            return NULL;
        }
    }
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = MmapState(size=map_size, offset=offset, trackfd=trackfd);
    if jacpy_binding_native_set(instance, mmap_token.handle, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    if fd == -1 {
        state.fd = i32(-1);
        flags = flags | int(MAP_ANONYMOUS);
    } elif trackfd {
        state.fd = _Py_dup(fd);
        if state.fd == -1 {
            jacpy_release(instance);
            return NULL;
        }
    } else {
        state.fd = i32(-1);
    }
    state.flags = i32(flags);
    thread = PyEval_SaveThread();
    data = mmap(ptr(), u64(map_size), i32(prot), i32(flags), fd, offset);
    PyEval_RestoreThread(thread);
    saved_errno = jacpy_errno();
    if int(data) == -1 {
        jacpy_release(instance);
        jacpy_set_errno(saved_errno);
        return os_error();
    }
    state.data = ptr[u8](data);
    state.access = access;
    return instance;
}

impl page_size -> i64 {
    return sysconf(i32(_SC_PAGESIZE));
}
