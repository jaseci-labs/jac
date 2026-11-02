import from c {
    def memcpy(dest: ptr, src: ptr, n: u64) -> ptr;  def memset(
        dest: ptr, value: i32, n: u64
    ) -> ptr;  def memchr(source: ptr, value: i32, n: u64) -> ptr;  def _PySys_GetSizeOf(
        o: ptr[PyObject]
    ) -> u64;  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        exporter: ptr[PyObject],
        buf: ptr,
        length: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def jacpy_stack_address(slots: &mut IOStack) -> int;  obj bytesio {
        has ob_base: _object,
            buf: ptr[PyObject],
            pos: i64,
            string_size: i64,
            dict: ptr[PyObject],
            weakreflist: ptr[PyObject],
            exports: i64;
    }  obj bytesiobuf {
        has ob_base: _object,
            source: ptr[PyObject];
    }  obj BytesIOFastCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }  obj BytesIOOneCall {
        has call: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  glob:priv bytesio_read_glue: BytesIOFastCall = BytesIOFastCall(),
         bytesio_read1_glue: BytesIOFastCall = BytesIOFastCall(),
         bytesio_readline_glue: BytesIOFastCall = BytesIOFastCall(),
         bytesio_readinto_glue: BytesIOOneCall = BytesIOOneCall();
}

glob BYTESIO_SIZE: Final[i64] = 64,
     BYTESIO_BUF: Final[i64] = 16,
     BYTESIO_DICT: Final[i64] = 40,
     BYTESIO_WEAKREFLIST: Final[i64] = 48,
     BYTESIOBUF_SIZE: Final[i64] = 24,
     BYTESIOBUF_SOURCE: Final[i64] = 16,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807;

def:priv bytesio_record(op: ptr[PyObject]) -> ptr[bytesio];

def:priv check_closed(op: ptr[PyObject]) -> bool;

def:priv check_exports(op: ptr[PyObject]) -> bool;

def:priv shared_buf(op: ptr[PyObject]) -> bool;

def:priv scan_eol_lock_held(op: ptr[PyObject], len: i64) -> i64;

def:priv unshare_buffer_lock_held(op: ptr[PyObject], size: i64) -> i32;

def:priv resize_buffer_lock_held(op: ptr[PyObject], size: u64) -> i32;

def:priv write_data_lock_held(op: ptr[PyObject], data: ptr, length: i64) -> i64;

def:priv write_bytes_lock_held(op: ptr[PyObject], b: ptr[PyObject]) -> i64;

def bytesio_get_closed(op: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def _io_BytesIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_flush_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_getbuffer_impl(op: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_getvalue_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject];

def:priv read_bytes_lock_held(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_BytesIO_read_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_BytesIO_read1_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_BytesIO_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_BytesIO_readlines_impl(op: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def:priv readinto_lock_held(op: ptr[PyObject], buf: ptr, length: i64) -> ptr[PyObject];

def _io_BytesIO_readinto_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def _io_BytesIO_truncate_impl(op: ptr[PyObject], size: ptr[PyObject]) -> ptr[PyObject];

def bytesio_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_seek_impl(op: ptr[PyObject], pos: i64, whence: i32) -> ptr[PyObject];

def _io_BytesIO_write_impl(op: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def _io_BytesIO_writelines_impl(
    op: ptr[PyObject], lines: ptr[PyObject]
) -> ptr[PyObject];

def _io_BytesIO_close_impl(op: ptr[PyObject]) -> ptr[PyObject];

def bytesio_getstate(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bytesio_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject];

def bytesio_dealloc(op: ptr[PyObject]);

def bytesio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def _io_BytesIO___init___impl(op: ptr[PyObject], initvalue: ptr[PyObject]) -> i32;

def bytesio_sizeof(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bytesio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def bytesio_clear(op: ptr[PyObject]) -> i32;

def bytesiobuf_getbuffer(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def bytesiobuf_releasebuffer(op: ptr[PyObject], view: ptr[Py_buffer]);

def bytesiobuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def bytesiobuf_dealloc(op: ptr[PyObject]);

def bytesio_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytesio_read1_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytesio_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def bytesio_readinto_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

import from c {
    glob:priv bytesio_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("closed"),
                 get=bytesio_get_closed,
                 doc=ptr[u8]("True if the file is closed.")
             ),
             PyGetSetDef()
         ],
         bytesio_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BYTESIO_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BYTESIO_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         bytesio_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(bytesio_dealloc)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(bytesio_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(bytesio_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(PyObject_SelfIter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(bytesio_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(bytesio_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(bytesio_getsetlist))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_BytesIO___init___init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(bytesio_new)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bytesio_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.BytesIO"),
             basicsize=i32(BYTESIO_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bytesio_slots)
         ); glob:priv bytesiobuf_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(bytesiobuf_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(bytesiobuf_traverse)),
             PyType_Slot(slot=Py_bf_getbuffer, pfunc=ptr(bytesiobuf_getbuffer)),
             PyType_Slot(slot=Py_bf_releasebuffer, pfunc=ptr(bytesiobuf_releasebuffer)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bytesiobuf_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io._BytesIOBuffer"),
             basicsize=i32(BYTESIOBUF_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
             ),
             slots=addressof(bytesiobuf_slots)
         );
}

def install_bytesio_tables -> bool;

impl bytesio_record(op: ptr[PyObject]) -> ptr[bytesio] {
    return ptr[bytesio](op);
}

impl check_closed(op: ptr[PyObject]) -> bool {
    if not bytesio_record(op).view(1)[0].buf {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file."));
        return True;
    }
    return False;
}

impl check_exports(op: ptr[PyObject]) -> bool {
    if bytesio_record(op).view(1)[0].exports > 0 {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("Existing exports of data: object cannot be re-sized")
        );
        return True;
    }
    return False;
}

impl shared_buf(op: ptr[PyObject]) -> bool {
    return object_refcount(bytesio_record(op).view(1)[0].buf) != 1;
}

impl scan_eol_lock_held(op: ptr[PyObject], len: i64) -> i64 {
    self_ = bytesio_record(op).view(1);
    if self_[0].pos >= self_[0].string_size {
        return 0;
    }

    maxlen = self_[0].string_size - self_[0].pos;
    if len < 0 or len > maxlen {
        len = maxlen;
    }

    if len != 0 {
        start = bytes_data(self_[0].buf) + self_[0].pos;
        n = ptr[u8](memchr(ptr(start), 10, u64(len)));
        if n {
            len = i64(int(n) - int(start)) + 1;
        }
    }
    return len;
}

impl unshare_buffer_lock_held(op: ptr[PyObject], size: i64) -> i32 {
    self_ = bytesio_record(op).view(1);
    new_buf = PyBytes_FromStringAndSize(ptr[u8](), size);
    if not new_buf {
        return -1;
    }
    memcpy(
        ptr(bytes_data(new_buf)),
        ptr(bytes_data(self_[0].buf)),
        u64(self_[0].string_size)
    );
    old = self_[0].buf;
    self_[0].buf = new_buf;
    object_decref(old);
    return 0;
}

impl resize_buffer_lock_held(op: ptr[PyObject], size: u64) -> i32 {
    self_ = bytesio_record(op).view(1);

    alloc = u64(object_size(self_[0].buf));

    if size > u64(PY_SSIZE_T_MAX) {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("new buffer size too large"));
        return -1;
    }

    if size < alloc // 2 {
        alloc = size + 1;
    } elif size < alloc {
        return 0;
    } elif f64(size) <= f64(alloc) * 1.125 {
        alloc = size + (size >> 3) + (u64(3) if size < 9 else u64(6));
    } else {
        alloc = size + 1;
    }

    if shared_buf(op) {
        if unshare_buffer_lock_held(op, i64(alloc)) < 0 {
            return -1;
        }
    } else {
        buf = self_[0].buf;
        status = _PyBytes_Resize(&mut buf, i64(alloc));
        self_[0].buf = buf;
        if status < 0 {
            return -1;
        }
    }

    return 0;
}

impl write_data_lock_held(op: ptr[PyObject], data: ptr, length: i64) -> i64 {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) or check_exports(op) {
        return -1;
    }

    if length == 0 {
        return 0;
    }

    endpos = u64(self_[0].pos) + u64(length);
    if endpos > u64(object_size(self_[0].buf)) {
        if resize_buffer_lock_held(op, endpos) < 0 {
            return -1;
        }
    } elif shared_buf(op) {
        wanted = endpos;
        if u64(self_[0].string_size) > wanted {
            wanted = u64(self_[0].string_size);
        }
        if unshare_buffer_lock_held(op, i64(wanted)) < 0 {
            return -1;
        }
    }

    if self_[0].pos > self_[0].string_size {
        memset(
            ptr(bytes_data(self_[0].buf) + self_[0].string_size),
            0,
            u64(self_[0].pos - self_[0].string_size)
        );
    }

    memcpy(ptr(bytes_data(self_[0].buf) + self_[0].pos), data, u64(length));
    self_[0].pos = i64(endpos);

    if u64(self_[0].string_size) < endpos {
        self_[0].string_size = i64(endpos);
    }

    return length;
}

impl write_bytes_lock_held(op: ptr[PyObject], b: ptr[PyObject]) -> i64 {
    slots: own IOStack = IOStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(b, view, PyBUF_ND) < 0 {
        return -1;
    }
    len = write_data_lock_held(op, view.view(1)[0].buf, view.view(1)[0].length);
    PyBuffer_Release(view);
    return len;
}

impl bytesio_get_closed(op: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    if not bytesio_record(op).view(1)[0].buf {
        return io_true();
    }
    return io_false();
}

impl _io_BytesIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_BytesIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_BytesIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_BytesIO_flush_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl _io_BytesIO_getbuffer_impl(
    op: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_io_state_by_cls(cls);
    type = state.view(1)[0].PyBytesIOBuffer_Type;

    if check_closed(op) {
        return NULL;
    }

    buf = type.view(1)[0].tp_alloc(type, 0);
    if not buf {
        return NULL;
    }
    ptr[bytesiobuf](buf).view(1)[0].source = object_new_ref(op);
    view = PyMemoryView_FromObject(buf);
    object_decref(buf);
    return view;
}

impl _io_BytesIO_getvalue_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) {
        return NULL;
    }
    if self_[0].string_size <= 1 or self_[0].exports > 0 {
        return PyBytes_FromStringAndSize(
            bytes_data(self_[0].buf), self_[0].string_size
        );
    }

    if self_[0].string_size != object_size(self_[0].buf) {
        if shared_buf(op) {
            if unshare_buffer_lock_held(op, self_[0].string_size) < 0 {
                return NULL;
            }
        } else {
            buf = self_[0].buf;
            status = _PyBytes_Resize(&mut buf, self_[0].string_size);
            self_[0].buf = buf;
            if status < 0 {
                return NULL;
            }
        }
    }
    return object_new_ref(self_[0].buf);
}

impl _io_BytesIO_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return object_new_ref(io_false());
}

impl _io_BytesIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }
    return PyLong_FromSsize_t(bytesio_record(op).view(1)[0].pos);
}

impl read_bytes_lock_held(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if size > 1
        and self_[0].pos == 0
        and size == object_size(self_[0].buf)
        and self_[0].exports == 0 {
        self_[0].pos += size;
        return object_new_ref(self_[0].buf);
    }

    if size == 0 {
        return PyBytes_FromStringAndSize(ptr[u8](), 0);
    }

    output = bytes_data(self_[0].buf) + self_[0].pos;
    self_[0].pos += size;
    return PyBytes_FromStringAndSize(output, size);
}

impl _io_BytesIO_read_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) {
        return NULL;
    }

    n = self_[0].string_size - self_[0].pos;
    if size < 0 or size > n {
        size = n;
        if size < 0 {
            size = 0;
        }
    }

    return read_bytes_lock_held(op, size);
}

impl _io_BytesIO_read1_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    return _io_BytesIO_read_impl(op, size);
}

impl _io_BytesIO_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }

    n = scan_eol_lock_held(op, size);

    return read_bytes_lock_held(op, n);
}

impl _io_BytesIO_readlines_impl(
    op: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    maxsize: i64 = -1;

    if check_closed(op) {
        return NULL;
    }

    if long_check(arg) {
        maxsize = PyLong_AsSsize_t(arg);
        if maxsize == -1 and PyErr_Occurred() {
            return NULL;
        }
    } elif arg == Py_None {
        maxsize = -1;
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("integer argument expected, got '%s'"),
            object_type(arg).view(1)[0].tp_name
        );
        return NULL;
    }

    size: i64 = 0;
    result = PyList_New(0);
    if not result {
        return NULL;
    }

    output = bytes_data(self_[0].buf) + self_[0].pos;
    n = scan_eol_lock_held(op, -1);
    while n != 0 {
        self_[0].pos += n;
        line = PyBytes_FromStringAndSize(output, n);
        if not line {
            object_decref(result);
            return NULL;
        }
        if PyList_Append(result, line) == -1 {
            object_decref(line);
            object_decref(result);
            return NULL;
        }
        object_decref(line);
        size += n;
        if maxsize > 0 and size >= maxsize {
            break;
        }
        output = output + n;
        n = scan_eol_lock_held(op, -1);
    }
    return result;
}

impl readinto_lock_held(op: ptr[PyObject], buf: ptr, length: i64) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) {
        return NULL;
    }

    len = length;
    n = self_[0].string_size - self_[0].pos;
    if len > n {
        len = n;
        if len < 0 {
            return PyLong_FromSsize_t(0);
        }
    }

    memcpy(buf, ptr(bytes_data(self_[0].buf) + self_[0].pos), u64(len));
    self_[0].pos += len;

    return PyLong_FromSsize_t(len);
}

impl _io_BytesIO_readinto_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return readinto_lock_held(op, buffer.address(), buffer.size());
}

impl _io_BytesIO_truncate_impl(
    op: ptr[PyObject], size: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) {
        return NULL;
    }
    if check_exports(op) {
        return NULL;
    }

    new_size: i64 = 0;
    if size == Py_None {
        new_size = self_[0].pos;
    } else {
        new_size = PyLong_AsLong(size);
        if new_size == -1 and PyErr_Occurred() {
            return NULL;
        }
        if new_size < 0 {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("negative size value %zd"), new_size
            );
            return NULL;
        }
    }

    if new_size < self_[0].string_size {
        self_[0].string_size = new_size;
        if resize_buffer_lock_held(op, u64(new_size)) < 0 {
            return NULL;
        }
    }

    return PyLong_FromSsize_t(new_size);
}

impl bytesio_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }

    n = scan_eol_lock_held(op, -1);

    if n == 0 {
        return NULL;
    }

    return read_bytes_lock_held(op, n);
}

impl _io_BytesIO_seek_impl(op: ptr[PyObject], pos: i64, whence: i32) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    if check_closed(op) {
        return NULL;
    }

    if pos < 0 and whence == 0 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("negative seek value %zd"), pos);
        return NULL;
    }

    if whence == 1 {
        if pos > PY_SSIZE_T_MAX - self_[0].pos {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("new position too large"));
            return NULL;
        }
        pos += self_[0].pos;
    } elif whence == 2 {
        if pos > PY_SSIZE_T_MAX - self_[0].string_size {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("new position too large"));
            return NULL;
        }
        pos += self_[0].string_size;
    } elif whence != 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("invalid whence (%i, should be 0, 1 or 2)"),
            whence
        );
        return NULL;
    }

    if pos < 0 {
        pos = 0;
    }
    self_[0].pos = pos;

    return PyLong_FromSsize_t(self_[0].pos);
}

impl _io_BytesIO_write_impl(op: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    n = write_bytes_lock_held(op, b);
    if n >= 0 {
        return PyLong_FromSsize_t(n);
    }
    return NULL;
}

impl _io_BytesIO_writelines_impl(
    op: ptr[PyObject], lines: ptr[PyObject]
) -> ptr[PyObject] {
    if check_closed(op) {
        return NULL;
    }

    it = PyObject_GetIter(lines);
    if not it {
        return NULL;
    }

    item = PyIter_Next(it);
    while item {
        ret = write_bytes_lock_held(op, item);
        object_decref(item);
        if ret < 0 {
            object_decref(it);
            return NULL;
        }
        item = PyIter_Next(it);
    }
    object_decref(it);

    if PyErr_Occurred() {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl _io_BytesIO_close_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if check_exports(op) {
        return NULL;
    }
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_BUF));
    return object_new_ref(Py_None);
}

impl bytesio_getstate(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    initvalue = _io_BytesIO_getvalue_impl(op);
    dict: ptr[PyObject] = NULL;

    if not initvalue {
        return NULL;
    }
    if not self_[0].dict {
        dict = object_new_ref(Py_None);
    } else {
        dict = PyDict_Copy(self_[0].dict);
        if not dict {
            object_decref(initvalue);
            return NULL;
        }
    }

    state = Py_BuildValue(ptr[u8]("(OnN)"), initvalue, self_[0].pos, dict);
    object_decref(initvalue);
    return state;
}

impl bytesio_setstate(op: ptr[PyObject], state: ptr[PyObject]) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);

    if not tuple_check(state) or object_size(state) < 3 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s.__setstate__ argument should be 3-tuple, got %.200s"),
            object_type(op).view(1)[0].tp_name,
            object_type(state).view(1)[0].tp_name
        );
        return NULL;
    }
    if check_exports(op) {
        return NULL;
    }

    self_[0].string_size = 0;
    self_[0].pos = 0;

    result = _io_BytesIO_write_impl(op, tuple_get_item(state, 0));
    if not result {
        return NULL;
    }
    object_decref(result);

    position_obj = tuple_get_item(state, 1);
    if not long_check(position_obj) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("second item of state must be an integer, not %.200s"),
            object_type(position_obj).view(1)[0].tp_name
        );
        return NULL;
    }
    pos = PyLong_AsSsize_t(position_obj);
    if pos == -1 and PyErr_Occurred() {
        return NULL;
    }
    if pos < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("position value cannot be negative"));
        return NULL;
    }
    self_[0].pos = pos;

    dict = tuple_get_item(state, 2);
    if dict != Py_None {
        if not dict_check(dict) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("third item of state should be a dict, got a %.200s"),
                object_type(dict).view(1)[0].tp_name
            );
            return NULL;
        }
        if self_[0].dict {
            if PyDict_Update(self_[0].dict, dict) < 0 {
                return NULL;
            }
        } else {
            self_[0].dict = object_new_ref(dict);
        }
    }

    return object_new_ref(Py_None);
}

impl bytesio_dealloc(op: ptr[PyObject]) {
    self_ = bytesio_record(op).view(1);
    tp = object_type(op);
    object_gc_untrack(op);
    if self_[0].exports > 0 {
        PyErr_SetString(
            PyExc_SystemError,
            ptr[u8]("deallocated BytesIO object has exported buffers")
        );
        PyErr_Print();
    }
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_BUF));
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_DICT));
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl bytesio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        return NULL;
    }

    buf = PyBytes_FromStringAndSize(ptr[u8](), 0);
    bytesio_record(op).view(1)[0].buf = buf;
    if not buf {
        object_decref(op);
        return PyErr_NoMemory();
    }

    return op;
}

impl _io_BytesIO___init___impl(op: ptr[PyObject], initvalue: ptr[PyObject]) -> i32 {
    self_ = bytesio_record(op).view(1);

    self_[0].string_size = 0;
    self_[0].pos = 0;

    if self_[0].exports > 0 {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("Existing exports of data: object cannot be re-sized")
        );
        return -1;
    }
    if initvalue and initvalue != Py_None {
        if object_is_type(initvalue, ptr[PyTypeObject](addressof(PyBytes_Type))) {
            py_xsetref(
                ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_BUF), object_new_ref(initvalue)
            );
            self_[0].string_size = object_size(initvalue);
        } else {
            res = _io_BytesIO_write_impl(op, initvalue);
            if not res {
                return -1;
            }
            object_decref(res);
            self_[0].pos = 0;
        }
    }

    return 0;
}

impl bytesio_sizeof(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    self_ = bytesio_record(op).view(1);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    if self_[0].buf and not shared_buf(op) {
        s = _PySys_GetSizeOf(self_[0].buf);
        if s == u64.wrap(-1) {
            return NULL;
        }
        res += s;
    }
    return PyLong_FromSize_t(res);
}

impl bytesio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = bytesio_record(op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].dict, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(self_[0].buf, visitor, arg);
}

impl bytesio_clear(op: ptr[PyObject]) -> i32 {
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_DICT));
    if bytesio_record(op).view(1)[0].exports == 0 {
        py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIO_BUF));
    }
    return 0;
}

impl bytesiobuf_getbuffer(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    if not view {
        PyErr_SetString(
            PyExc_BufferError,
            ptr[u8]("bytesiobuf_getbuffer: view==NULL argument is obsolete")
        );
        return -1;
    }
    source = ptr[bytesiobuf](op).view(1)[0].source;
    b = bytesio_record(source).view(1);

    if b[0].exports == 0 and shared_buf(source) {
        if unshare_buffer_lock_held(source, b[0].string_size) < 0 {
            return -1;
        }
    }

    PyBuffer_FillInfo(view, op, ptr(bytes_data(b[0].buf)), b[0].string_size, 0, flags);
    b[0].exports += 1;
    return 0;
}

impl bytesiobuf_releasebuffer(op: ptr[PyObject], view: ptr[Py_buffer]) {
    source = ptr[bytesiobuf](op).view(1)[0].source;
    bytesio_record(source).view(1)[0].exports -= 1;
}

impl bytesiobuf_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(ptr[bytesiobuf](op).view(1)[0].source, visitor, arg);
}

impl bytesiobuf_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);

    PyObject_GC_UnTrack(ptr(op));
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + BYTESIOBUF_SOURCE));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl bytesio_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_BytesIO_read_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(bytesio_read_glue).view(1)[0].call(receiver, args, nargs);
}

impl bytesio_read1_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_BytesIO_read_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(bytesio_read1_glue).view(1)[0].call(receiver, args, nargs);
}

impl bytesio_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_BytesIO_readline_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(bytesio_readline_glue).view(1)[0].call(receiver, args, nargs);
}

impl bytesio_readinto_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(arg, view, PyBUF_WRITABLE) == 0 {
        res = readinto_lock_held(receiver, view.view(1)[0].buf, view.view(1)[0].length);
        PyBuffer_Release(view);
        return res;
    }
    PyErr_Clear();
    return addressof(bytesio_readinto_glue).view(1)[0].call(receiver, arg);
}

impl install_bytesio_tables -> bool {
    methods: list[MethodDefinition] = [];
    for method in io_select_methods(
        BytesIO_methods,
        [
            "readable",
            "seekable",
            "writable",
            "close",
            "flush",
            "isatty",
            "tell",
            "write",
            "writelines",
            "read1",
            "readinto",
            "readline",
            "readlines",
            "read",
            "getbuffer",
            "getvalue",
            "seek",
            "truncate"
        ]
    ) {
        callbacks = method.callbacks;
        if method.name == "read" {
            addressof(bytesio_read_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=bytesio_read_fast);
        } elif method.name == "read1" {
            addressof(bytesio_read1_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=bytesio_read1_fast);
        } elif method.name == "readline" {
            addressof(bytesio_readline_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=bytesio_readline_fast);
        } elif method.name == "readinto" {
            addressof(bytesio_readinto_glue).view(1)[0].call = method.callbacks.positional;
            callbacks = MethodCallbacks(positional=bytesio_readinto_fast);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    methods.append(
        MethodDefinition(
            "__getstate__",
            MethodCallbacks(positional=bytesio_getstate),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "__setstate__",
            MethodCallbacks(positional=bytesio_setstate),
            "",
            i64(METH_O)
        )
    );
    methods.append(
        MethodDefinition(
            "__sizeof__",
            MethodCallbacks(positional=bytesio_sizeof),
            "",
            i64(METH_NOARGS)
        )
    );
    BytesIO_token.handle = ptr(addressof(bytesio_spec));
    return io_fill_slots(
        ptr[PyType_Slot](addressof(bytesio_slots)), methods, [], BytesIO_doc
    );
}
