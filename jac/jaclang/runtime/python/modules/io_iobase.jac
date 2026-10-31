import from c {
    def PyObject_CallFinalizer(op_self: ptr[PyObject]);  def PyByteArray_FromStringAndSize(
        data: ptr[u8], size: i64
    ) -> ptr[PyObject];  def _PyFile_Flush(file: ptr[PyObject]) -> i32;  def memcpy(
        dest: ptr, src: ptr, n: u64
    ) -> ptr;  obj iobase {
        has ob_base: _object,
            dict: ptr[PyObject],
            weakreflist: ptr[PyObject];
    }
}

glob IOBASE_SIZE: Final[i64] = 32,
     IOBASE_DICT: Final[i64] = 16,
     IOBASE_WEAKREFLIST: Final[i64] = 24;

def:priv iobase_record(op: ptr[PyObject]) -> ptr[iobase];

def iobase_is_closed(self_: ptr[PyObject]) -> i32;

def iobase_unsupported(state: ptr[IOModuleState], message: ptr[u8]) -> ptr[PyObject];

def _io__IOBase_seek_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], offset: i32, whence: i32
) -> ptr[PyObject];

def _io__IOBase_tell_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def _io__IOBase_truncate_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: ptr[PyObject]
) -> ptr[PyObject];

def _io__IOBase_flush_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def iobase_closed_get(self_: ptr[PyObject], context: ptr) -> ptr[PyObject];

def iobase_check_closed(self_: ptr[PyObject]) -> i32;

import from c {
    def _PyIOBase_check_closed(
        self_: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        if iobase_check_closed(self_) != 0 {
            return NULL;
        }
        if args == io_true() {
            return Py_None;
        }
        return object_new_ref(Py_None);
    }
}

def iobase_check_seekable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def iobase_check_readable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def iobase_check_writable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyIOBase_cannot_pickle(
        self_: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("cannot pickle '%.100s' instances"),
            _PyType_Name(ptr[PyObject](object_type(self_)))
        );
        return NULL;
    }
}

def _io__IOBase_close_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def iobase_finalize(self_: ptr[PyObject]);

import from c {
    def _PyIOBase_finalize(self_: ptr[PyObject]) -> i32 {
        is_zombie = object_refcount(self_) == 0;
        if is_zombie {
            return PyObject_CallFinalizerFromDealloc(self_);
        }
        PyObject_CallFinalizer(self_);
        return 0;
    }
}

def iobase_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def iobase_clear(op: ptr[PyObject]) -> i32;

def iobase_dealloc(op: ptr[PyObject]);

def _io__IOBase_seekable_impl(self_: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyIOBase_check_seekable(
        state: ptr[IOModuleState], self_: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        res = io_call_noargs(self_, py_id(_Py_ID_seekable));
        if not res {
            return NULL;
        }
        if res != io_true() {
            object_decref(res);
            iobase_unsupported(state, ptr[u8]("File or stream is not seekable."));
            return NULL;
        }
        if args == io_true() {
            object_decref(res);
        }
        return res;
    }
}

def _io__IOBase_readable_impl(self_: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyIOBase_check_readable(
        state: ptr[IOModuleState], self_: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        res = io_call_noargs(self_, py_id(_Py_ID_readable));
        if not res {
            return NULL;
        }
        if res != io_true() {
            object_decref(res);
            iobase_unsupported(state, ptr[u8]("File or stream is not readable."));
            return NULL;
        }
        if args == io_true() {
            object_decref(res);
        }
        return res;
    }
}

def _io__IOBase_writable_impl(self_: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _PyIOBase_check_writable(
        state: ptr[IOModuleState], self_: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        res = io_call_noargs(self_, py_id(_Py_ID_writable));
        if not res {
            return NULL;
        }
        if res != io_true() {
            object_decref(res);
            iobase_unsupported(state, ptr[u8]("File or stream is not writable."));
            return NULL;
        }
        if args == io_true() {
            object_decref(res);
        }
        return res;
    }
}

def iobase_enter(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def iobase_exit(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def _io__IOBase_fileno_impl(self_: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def _io__IOBase_isatty_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def:priv readline_failed(peek: ptr[PyObject], buffer: ptr[PyObject]) -> ptr[PyObject];

def _io__IOBase_readline_impl(self_: ptr[PyObject], limit: i64) -> ptr[PyObject];

def iobase_iter(self_: ptr[PyObject]) -> ptr[PyObject];

def iobase_iternext(self_: ptr[PyObject]) -> ptr[PyObject];

def _io__IOBase_readlines_impl(self_: ptr[PyObject], hint: i64) -> ptr[PyObject];

def _io__IOBase_writelines_impl(
    self_: ptr[PyObject], lines: ptr[PyObject]
) -> ptr[PyObject];

def _io__RawIOBase_read_impl(self_: ptr[PyObject], n: i64) -> ptr[PyObject];

def _io__RawIOBase_readall_impl(self_: ptr[PyObject]) -> ptr[PyObject];

def rawiobase_readinto(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def rawiobase_write(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv iobase_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("__dict__"), get=PyObject_GenericGetDict),
             PyGetSetDef(name=ptr[u8]("closed"), get=iobase_closed_get),
             PyGetSetDef()
         ],
         iobase_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=IOBASE_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=IOBASE_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         iobase_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(iobase_dealloc)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(iobase_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(iobase_clear)),
             PyType_Slot(slot=Py_tp_iter, pfunc=ptr(iobase_iter)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(iobase_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(iobase_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(iobase_getset))),
             PyType_Slot(slot=Py_tp_finalize, pfunc=ptr(iobase_finalize)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob iobase_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io._IOBase"),
             basicsize=i32(IOBASE_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(iobase_slots)
         ); glob:priv rawiobase_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob rawiobase_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io._RawIOBase"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(rawiobase_slots)
         );
}

def install_iobase_tables -> bool;

impl iobase_record(op: ptr[PyObject]) -> ptr[iobase] {
    return ptr[iobase](op);
}

impl iobase_is_closed(self_: ptr[PyObject]) -> i32 {
    return PyObject_HasAttrWithError(self_, py_id(_Py_ID___IOBase_closed));
}

impl iobase_unsupported(state: ptr[IOModuleState], message: ptr[u8]) -> ptr[PyObject] {
    PyErr_SetString(state.view(1)[0].unsupported_operation, message);
    return NULL;
}

impl _io__IOBase_seek_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], offset: i32, whence: i32
) -> ptr[PyObject] {
    state = get_io_state_by_cls(cls);
    return iobase_unsupported(state, ptr[u8]("seek"));
}

impl _io__IOBase_tell_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return io_call_twoargs(self_, py_id(_Py_ID_seek), long_zero(), long_one());
}

impl _io__IOBase_truncate_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_io_state_by_cls(cls);
    return iobase_unsupported(state, ptr[u8]("truncate"));
}

impl _io__IOBase_flush_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    closed = iobase_is_closed(self_);
    if closed == 0 {
        return object_new_ref(Py_None);
    }
    if closed > 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file."));
    }
    return NULL;
}

impl iobase_closed_get(self_: ptr[PyObject], context: ptr) -> ptr[PyObject] {
    closed = iobase_is_closed(self_);
    if closed < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(closed));
}

impl iobase_check_closed(self_: ptr[PyObject]) -> i32 {
    res: ptr[PyObject] = NULL;

    closed = PyObject_GetOptionalAttr(self_, py_id(_Py_ID_closed), &mut res);
    if closed > 0 {
        closed = PyObject_IsTrue(res);
        object_decref(res);
        if closed > 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file."));
            return -1;
        }
    }
    return closed;
}

impl iobase_check_seekable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = find_io_state_by_def(object_type(self_));
    return _PyIOBase_check_seekable(state, self_, args);
}

impl iobase_check_readable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = find_io_state_by_def(object_type(self_));
    return _PyIOBase_check_readable(state, self_, args);
}

impl iobase_check_writable(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    state = find_io_state_by_def(object_type(self_));
    return _PyIOBase_check_writable(state, self_, args);
}

impl _io__IOBase_close_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    closed = iobase_is_closed(self_);
    if closed < 0 {
        return NULL;
    }
    if closed != 0 {
        return object_new_ref(Py_None);
    }

    rc1 = _PyFile_Flush(self_);
    exc = PyErr_GetRaisedException();
    rc2 = PyObject_SetAttr(self_, py_id(_Py_ID___IOBase_closed), io_true());
    _PyErr_ChainExceptions1(exc);
    if rc1 < 0 or rc2 < 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl iobase_finalize(self_: ptr[PyObject]) {
    res: ptr[PyObject] = NULL;
    closed: i32 = 0;

    exc = PyErr_GetRaisedException();

    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID_closed), &mut res) <= 0 {
        PyErr_Clear();
        closed = -1;
    } else {
        closed = PyObject_IsTrue(res);
        object_decref(res);
        if closed == -1 {
            PyErr_Clear();
        }
    }
    if closed == 0 {
        if PyObject_SetAttr(self_, py_id(_Py_ID__finalizing), io_true()) != 0 {
            PyErr_Clear();
        }
        res = io_call_noargs(self_, py_id(_Py_ID_close));
        if not res {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while finalizing file %R"), self_
            );
        } else {
            object_decref(res);
        }
    }

    PyErr_SetRaisedException(exc);
}

impl iobase_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(iobase_record(op).view(1)[0].dict, visitor, arg);
}

impl iobase_clear(op: ptr[PyObject]) -> i32 {
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + IOBASE_DICT));
    return 0;
}

impl iobase_dealloc(op: ptr[PyObject]) {
    if _PyIOBase_finalize(op) < 0 {
        if type_has_feature(object_type(op), Py_TPFLAGS_HEAPTYPE) {
            object_incref(ptr[PyObject](object_type(op)));
        }
        return;
    }
    tp = object_type(op);
    object_gc_untrack(op);
    if iobase_record(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    py_clear(ptr[ptr[PyObject]](ptr[u8](op) + IOBASE_DICT));
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl _io__IOBase_seekable_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(io_false());
}

impl _io__IOBase_readable_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(io_false());
}

impl _io__IOBase_writable_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(io_false());
}

impl iobase_enter(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if iobase_check_closed(self_) != 0 {
        return NULL;
    }
    return object_new_ref(self_);
}

impl iobase_exit(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return io_call_noargs(self_, py_id(_Py_ID_close));
}

impl _io__IOBase_fileno_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_io_state_by_cls(cls);
    return iobase_unsupported(state, ptr[u8]("fileno"));
}

impl _io__IOBase_isatty_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    if iobase_check_closed(self_) != 0 {
        return NULL;
    }
    return object_new_ref(io_false());
}

impl readline_failed(peek: ptr[PyObject], buffer: ptr[PyObject]) -> ptr[PyObject] {
    object_xdecref(peek);
    object_decref(buffer);
    return NULL;
}

impl _io__IOBase_readline_impl(self_: ptr[PyObject], limit: i64) -> ptr[PyObject] {
    peek: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(self_, py_id(_Py_ID_peek), &mut peek) < 0 {
        return NULL;
    }

    buffer = PyByteArray_FromStringAndSize(ptr[u8](), 0);
    if not buffer {
        object_xdecref(peek);
        return NULL;
    }

    while limit < 0 or object_size(buffer) < limit {
        nreadahead: i64 = 1;

        if peek {
            readahead = PyObject_CallOneArg(peek, long_one());
            if not readahead {
                if _PyIO_trap_eintr() != 0 {
                    continue;
                }
                return readline_failed(peek, buffer);
            }
            if not bytes_check(readahead) {
                PyErr_Format(
                    PyExc_OSError,
                    ptr[u8]("peek() should have returned a bytes object, not '%.200s'"),
                    object_type(readahead).view(1)[0].tp_name
                );
                object_decref(readahead);
                return readline_failed(peek, buffer);
            }
            available = object_size(readahead);
            if available > 0 {
                n: i64 = 0;
                buf = bytes_data(readahead);
                if limit >= 0 {
                    while True {
                        if n >= available or n >= limit {
                            break;
                        }
                        c = buf.view(available)[n];
                        n += 1;
                        if c == u8(10) {
                            break;
                        }
                    }
                } else {
                    while True {
                        if n >= available {
                            break;
                        }
                        c = buf.view(available)[n];
                        n += 1;
                        if c == u8(10) {
                            break;
                        }
                    }
                }
                nreadahead = n;
            }
            object_decref(readahead);
        }

        b = io_call_ssize(self_, py_id(_Py_ID_read), nreadahead);
        if not b {
            if _PyIO_trap_eintr() != 0 {
                continue;
            }
            return readline_failed(peek, buffer);
        }
        if not bytes_check(b) {
            PyErr_Format(
                PyExc_OSError,
                ptr[u8]("read() should have returned a bytes object, not '%.200s'"),
                object_type(b).view(1)[0].tp_name
            );
            object_decref(b);
            return readline_failed(peek, buffer);
        }
        got = object_size(b);
        if got == 0 {
            object_decref(b);
            break;
        }

        old_size = object_size(buffer);
        if PyByteArray_Resize(buffer, old_size + got) < 0 {
            object_decref(b);
            return readline_failed(peek, buffer);
        }
        data = PyByteArray_AsString(buffer);
        memcpy(ptr(data + old_size), ptr(bytes_data(b)), u64(got));

        object_decref(b);

        size = object_size(buffer);
        if data.view(size)[size - 1] == u8(10) {
            break;
        }
    }

    result = PyBytes_FromStringAndSize(
        PyByteArray_AsString(buffer), object_size(buffer)
    );
    object_xdecref(peek);
    object_decref(buffer);
    return result;
}

impl iobase_iter(self_: ptr[PyObject]) -> ptr[PyObject] {
    if iobase_check_closed(self_) != 0 {
        return NULL;
    }
    return object_new_ref(self_);
}

impl iobase_iternext(self_: ptr[PyObject]) -> ptr[PyObject] {
    line = io_call_noargs(self_, py_id(_Py_ID_readline));
    if not line {
        return NULL;
    }
    if PyObject_Size(line) <= 0 {
        object_decref(line);
        return NULL;
    }
    return line;
}

impl _io__IOBase_readlines_impl(self_: ptr[PyObject], hint: i64) -> ptr[PyObject] {
    length: i64 = 0;

    result = PyList_New(0);
    if not result {
        return NULL;
    }

    if hint <= 0 {
        ret = io_call_onearg(result, py_id(_Py_ID_extend), self_);
        if not ret {
            object_decref(result);
            return NULL;
        }
        object_decref(ret);
        return result;
    }

    it = PyObject_GetIter(self_);
    if not it {
        object_decref(result);
        return NULL;
    }

    while True {
        line = PyIter_Next(it);
        if not line {
            if PyErr_Occurred() {
                object_decref(it);
                object_decref(result);
                return NULL;
            }

            break;
        }

        if PyList_Append(result, line) < 0 {
            object_decref(line);
            object_decref(it);
            object_decref(result);
            return NULL;
        }
        line_length = PyObject_Size(line);
        object_decref(line);
        if line_length < 0 {
            object_decref(it);
            object_decref(result);
            return NULL;
        }
        if line_length > hint - length {
            break;
        }
        length += line_length;
    }

    object_decref(it);
    return result;
}

impl _io__IOBase_writelines_impl(
    self_: ptr[PyObject], lines: ptr[PyObject]
) -> ptr[PyObject] {
    if iobase_check_closed(self_) != 0 {
        return NULL;
    }

    iter = PyObject_GetIter(lines);
    if not iter {
        return NULL;
    }

    while True {
        line = PyIter_Next(iter);
        if not line {
            if PyErr_Occurred() {
                object_decref(iter);
                return NULL;
            }

            break;
        }

        res: ptr[PyObject] = NULL;
        while True {
            res = io_call_onearg(self_, py_id(_Py_ID_write), line);
            if res or _PyIO_trap_eintr() == 0 {
                break;
            }
        }
        object_decref(line);
        if not res {
            object_decref(iter);
            return NULL;
        }
        object_decref(res);
    }
    object_decref(iter);
    return object_new_ref(Py_None);
}

impl _io__RawIOBase_read_impl(self_: ptr[PyObject], n: i64) -> ptr[PyObject] {
    if n < 0 {
        return io_call_noargs(self_, py_id(_Py_ID_readall));
    }

    b = PyByteArray_FromStringAndSize(ptr[u8](), n);
    if not b {
        return NULL;
    }

    res = io_call_onearg(self_, py_id(_Py_ID_readinto), b);
    if not res or res == Py_None {
        object_decref(b);
        return res;
    }

    bytes_filled = PyNumber_AsSsize_t(res, PyExc_ValueError);
    object_decref(res);
    if bytes_filled == -1 and PyErr_Occurred() {
        object_decref(b);
        return NULL;
    }

    if bytes_filled < 0 or bytes_filled > n {
        object_decref(b);
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("readinto returned %zd outside buffer size %zd"),
            bytes_filled,
            n
        );
        return NULL;
    }

    res = PyBytes_FromStringAndSize(PyByteArray_AsString(b), bytes_filled);
    object_decref(b);
    return res;
}

impl _io__RawIOBase_readall_impl(self_: ptr[PyObject]) -> ptr[PyObject] {
    chunks = PyList_New(0);
    if not chunks {
        return NULL;
    }

    while True {
        data = io_call_ssize(self_, py_id(_Py_ID_read), DEFAULT_BUFFER_SIZE);
        if not data {
            if _PyIO_trap_eintr() != 0 {
                continue;
            }
            object_decref(chunks);
            return NULL;
        }
        if data == Py_None {
            if object_size(chunks) == 0 {
                object_decref(chunks);
                return data;
            }
            object_decref(data);
            break;
        }
        if not bytes_check(data) {
            object_decref(chunks);
            object_decref(data);
            PyErr_SetString(PyExc_TypeError, ptr[u8]("read() should return bytes"));
            return NULL;
        }
        if object_size(data) == 0 {
            object_decref(data);
            break;
        }
        r = PyList_Append(chunks, data);
        object_decref(data);
        if r < 0 {
            object_decref(chunks);
            return NULL;
        }
    }
    result = PyBytes_Join(bytes_get_empty(), chunks);
    object_decref(chunks);
    return result;
}

impl rawiobase_readinto(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetNone(PyExc_NotImplementedError);
    return NULL;
}

impl rawiobase_write(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetNone(PyExc_NotImplementedError);
    return NULL;
}

impl install_iobase_tables -> bool {
    methods = io_select_methods(
        _IOBase_methods,
        [
            "seek",
            "tell",
            "truncate",
            "flush",
            "close",
            "seekable",
            "readable",
            "writable"
        ]
    );
    methods.append(
        MethodDefinition(
            "_checkClosed",
            MethodCallbacks(positional=_PyIOBase_check_closed),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "_checkSeekable",
            MethodCallbacks(positional=iobase_check_seekable),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "_checkReadable",
            MethodCallbacks(positional=iobase_check_readable),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "_checkWritable",
            MethodCallbacks(positional=iobase_check_writable),
            "",
            i64(METH_NOARGS)
        )
    );
    methods.extend(io_select_methods(_IOBase_methods, ["fileno", "isatty"]));
    methods.append(
        MethodDefinition(
            "__enter__", MethodCallbacks(positional=iobase_enter), "", i64(METH_NOARGS)
        )
    );
    methods.append(
        MethodDefinition(
            "__exit__", MethodCallbacks(positional=iobase_exit), "", i64(METH_VARARGS)
        )
    );
    methods.extend(
        io_select_methods(_IOBase_methods, ["readline", "readlines", "writelines"])
    );
    _IOBase_token.handle = ptr(addressof(iobase_spec));
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(iobase_slots)), methods, [], iobase_doc
    ) {
        return False;
    }

    raw_methods = io_select_methods(_RawIOBase_methods, ["read", "readall"]);
    raw_methods.append(
        MethodDefinition(
            "readinto",
            MethodCallbacks(positional=rawiobase_readinto),
            "",
            i64(METH_VARARGS)
        )
    );
    raw_methods.append(
        MethodDefinition(
            "write", MethodCallbacks(positional=rawiobase_write), "", i64(METH_VARARGS)
        )
    );
    return io_fill_slots(
        ptr[PyType_Slot](addressof(rawiobase_slots)), raw_methods, [], rawiobase_doc
    );
}
