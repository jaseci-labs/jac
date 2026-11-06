import from c {
    def memcpy(dest: ptr, src: ptr, n: u64) -> ptr;  def memset(
        dest: ptr, value: i32, n: u64
    ) -> ptr;  def PyUnicode_Replace(
        str_obj: ptr[PyObject],
        substr: ptr[PyObject],
        replstr: ptr[PyObject],
        maxcount: i64
    ) -> ptr[PyObject];  def PyUnicode_AsUCS4(
        string: ptr[PyObject], target: ptr[u32], targetsize: i64, copy_null: i32
    ) -> ptr[u32];  def PyUnicode_AsUCS4Copy(string: ptr[PyObject]) -> ptr[u32];  def _PyUnicodeWriter_WriteStr(
        writer: ptr[UnicodeWriter], str_obj: ptr[PyObject]
    ) -> i32;  def jacpy_stack_address(slots: &mut IOStack) -> int;  obj stringio {
        has ob_base: _object,
            buf: ptr[u32],
            pos: i64,
            string_size: i64,
            buf_size: u64,
            state: i32,
            writer: ptr[PyUnicodeWriter],
            ok: i8,
            closed: i8,
            readuniversal: i8,
            readtranslate: i8,
            decoder: ptr[PyObject],
            readnl: ptr[PyObject],
            writenl: ptr[PyObject],
            dict: ptr[PyObject],
            weakreflist: ptr[PyObject],
            module_state: ptr[IOModuleState];
    }  obj StringIOFastCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }  glob:priv stringio_read_glue: StringIOFastCall = StringIOFastCall(),
         stringio_readline_glue: StringIOFastCall = StringIOFastCall();
}

glob STRINGIO_SIZE: Final[i64] = 120,
     STRINGIO_DECODER: Final[i64] = 72,
     STRINGIO_READNL: Final[i64] = 80,
     STRINGIO_WRITENL: Final[i64] = 88,
     STRINGIO_DICT: Final[i64] = 96,
     STRINGIO_WEAKREFLIST: Final[i64] = 104,
     UCS4_KIND: Final[i32] = 4,
     STATE_REALIZED: Final[i32] = 1,
     STATE_ACCUMULATING: Final[i32] = 2,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     PY_SIZE_MAX: Final[u64] = 18446744073709551615;

def:priv stringio_record(op: ptr[PyObject]) -> ptr[stringio];

def:priv field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def:priv check_initialized(op: ptr[PyObject]) -> bool;

def:priv check_open(op: ptr[PyObject]) -> bool;

def self_pos(op: ptr[PyObject]) -> i64;

def:priv resize_buffer(op: ptr[PyObject], size: u64) -> i32;

def:priv make_intermediate(op: ptr[PyObject]) -> ptr[PyObject];

def:priv realize(op: ptr[PyObject]) -> i32;

def:priv write_str(op: ptr[PyObject], obj_: ptr[PyObject]) -> i64;

def _io_StringIO_getvalue_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_read_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def:priv _stringio_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject];

def _io_StringIO_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def stringio_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_truncate_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io_StringIO_seek_impl(op: ptr[PyObject], pos: i64, whence: i32) -> ptr[PyObject];

def _io_StringIO_write_impl(op: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_close_impl(op: ptr[PyObject]) -> ptr[PyObject];

def stringio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def stringio_clear(op: ptr[PyObject]) -> i32;

def stringio_dealloc(op: ptr[PyObject]);

def stringio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def _io_StringIO___init___impl(
    op: ptr[PyObject], value: ptr[PyObject], newline_obj: ptr[PyObject]
) -> i32;

def _io_StringIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO___getstate___impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO___setstate___impl(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject];

def _io_StringIO_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_line_buffering_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io_StringIO_newlines_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def stringio_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def stringio_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

import from c {
    glob:priv stringio_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=STRINGIO_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=STRINGIO_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         stringio_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(stringio_dealloc)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(stringio_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(stringio_clear)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(stringio_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(stringio_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_StringIO___init___init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(stringio_new)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob stringio_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.StringIO"),
             basicsize=i32(STRINGIO_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(stringio_slots)
         );
}

def install_stringio_tables -> bool;

impl stringio_record(op: ptr[PyObject]) -> ptr[stringio] {
    return ptr[stringio](op);
}

impl field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset);
}

impl check_initialized(op: ptr[PyObject]) -> bool {
    if stringio_record(op).view(1)[0].ok <= 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("I/O operation on uninitialized object")
        );
        return False;
    }
    return True;
}

impl check_open(op: ptr[PyObject]) -> bool {
    if stringio_record(op).view(1)[0].closed != 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("I/O operation on closed file"));
        return False;
    }
    return True;
}

impl self_pos(op: ptr[PyObject]) -> i64 {
    return stringio_record(op).view(1)[0].pos;
}

impl resize_buffer(op: ptr[PyObject], size: u64) -> i32 {
    self_ = stringio_record(op).view(1);

    alloc = self_[0].buf_size;

    size = size + 1;

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

    if alloc > PY_SIZE_MAX // 4 {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("new buffer size too large"));
        return -1;
    }
    new_buf = ptr[u32](PyMem_Realloc(ptr(self_[0].buf), alloc * 4));
    if not new_buf {
        PyErr_NoMemory();
        return -1;
    }
    self_[0].buf_size = alloc;
    self_[0].buf = new_buf;

    return 0;
}

impl make_intermediate(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    intermediate = PyUnicodeWriter_Finish(self_[0].writer);
    self_[0].writer = ptr[PyUnicodeWriter]();
    self_[0].state = STATE_REALIZED;
    if not intermediate {
        return NULL;
    }

    self_[0].writer = PyUnicodeWriter_Create(0);
    if not self_[0].writer {
        object_decref(intermediate);
        return NULL;
    }
    if PyUnicodeWriter_WriteStr(self_[0].writer, intermediate) != 0 {
        object_decref(intermediate);
        return NULL;
    }
    self_[0].state = STATE_ACCUMULATING;
    return intermediate;
}

impl realize(op: ptr[PyObject]) -> i32 {
    self_ = stringio_record(op).view(1);
    if self_[0].state == STATE_REALIZED {
        return 0;
    }
    self_[0].state = STATE_REALIZED;
    intermediate = PyUnicodeWriter_Finish(self_[0].writer);
    self_[0].writer = ptr[PyUnicodeWriter]();
    if not intermediate {
        return -1;
    }

    len = unicode_length(intermediate);
    if resize_buffer(op, u64(len)) < 0 {
        object_decref(intermediate);
        return -1;
    }
    if not PyUnicode_AsUCS4(intermediate, self_[0].buf, len, 0) {
        object_decref(intermediate);
        return -1;
    }

    object_decref(intermediate);
    return 0;
}

impl write_str(op: ptr[PyObject], obj_: ptr[PyObject]) -> i64 {
    self_ = stringio_record(op).view(1);
    decoded: ptr[PyObject] = NULL;

    if self_[0].decoder {
        decoded = _PyIncrementalNewlineDecoder_decode(self_[0].decoder, obj_, 1);
    } else {
        decoded = object_new_ref(obj_);
    }
    if self_[0].writenl {
        translated = PyUnicode_Replace(decoded, latin1_char(10), self_[0].writenl, -1);
        object_decref(decoded);
        decoded = translated;
    }
    if not decoded {
        return -1;
    }

    len = unicode_length(decoded);

    if self_[0].pos > PY_SSIZE_T_MAX - len {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("new position too large"));
        object_decref(decoded);
        return -1;
    }

    if self_[0].state == STATE_ACCUMULATING {
        if self_[0].string_size == self_[0].pos {
            if _PyUnicodeWriter_WriteStr(ptr[UnicodeWriter](self_[0].writer), decoded)
                != 0 {
                object_decref(decoded);
                return -1;
            }
            self_[0].pos += len;
            if self_[0].string_size < self_[0].pos {
                self_[0].string_size = self_[0].pos;
            }
            object_decref(decoded);
            return 0;
        }
        if realize(op) != 0 {
            object_decref(decoded);
            return -1;
        }
    }

    if self_[0].pos + len > self_[0].string_size {
        if resize_buffer(op, u64(self_[0].pos + len)) < 0 {
            object_decref(decoded);
            return -1;
        }
    }

    if self_[0].pos > self_[0].string_size {
        memset(
            ptr(self_[0].buf + self_[0].string_size),
            0,
            u64(self_[0].pos - self_[0].string_size) * 4
        );
    }

    if not PyUnicode_AsUCS4(
        decoded, self_[0].buf + self_[0].pos, i64(self_[0].buf_size) - self_[0].pos, 0
    ) {
        object_decref(decoded);
        return -1;
    }

    self_[0].pos += len;
    if self_[0].string_size < self_[0].pos {
        self_[0].string_size = self_[0].pos;
    }

    object_decref(decoded);
    return 0;
}

impl _io_StringIO_getvalue_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    if self_[0].state == STATE_ACCUMULATING {
        return make_intermediate(op);
    }
    return PyUnicode_FromKindAndData(
        UCS4_KIND, ptr(self_[0].buf), self_[0].string_size
    );
}

impl _io_StringIO_tell_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    return PyLong_FromSsize_t(stringio_record(op).view(1)[0].pos);
}

impl _io_StringIO_read_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }

    n = self_[0].string_size - self_[0].pos;
    if size < 0 or size > n {
        size = n;
        if size < 0 {
            size = 0;
        }
    }

    if self_[0].state == STATE_ACCUMULATING and self_[0].pos == 0 and size == n {
        result = make_intermediate(op);
        self_[0].pos = self_[0].string_size;
        return result;
    }

    if realize(op) < 0 {
        return NULL;
    }
    output = self_[0].buf + self_[0].pos;
    self_[0].pos += size;
    return PyUnicode_FromKindAndData(UCS4_KIND, ptr(output), size);
}

impl _stringio_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);

    if self_[0].pos >= self_[0].string_size {
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }

    start = self_[0].buf + self_[0].pos;
    if limit < 0 or limit > self_[0].string_size - self_[0].pos {
        limit = self_[0].string_size - self_[0].pos;
    }

    end = start + limit;
    old_char = end.view(1)[0];
    end.view(1)[0] = u32(0);
    slots: own IOStack = IOStack();
    consumed = ptr[i64](jacpy_stack_address(&mut slots));
    len = _PyIO_find_line_ending(
        i32(self_[0].readtranslate),
        i32(self_[0].readuniversal),
        self_[0].readnl,
        UCS4_KIND,
        ptr[u8](start),
        ptr[u8](end),
        consumed
    );
    end.view(1)[0] = old_char;

    if len < 0 {
        len = limit;
    }
    self_[0].pos += len;
    return PyUnicode_FromKindAndData(UCS4_KIND, ptr(start), len);
}

impl _io_StringIO_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    if realize(op) < 0 {
        return NULL;
    }

    return _stringio_readline(op, size);
}

impl stringio_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    line: ptr[PyObject] = NULL;

    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    if realize(op) < 0 {
        return NULL;
    }

    if object_is_type(op, self_[0].module_state.view(1)[0].PyStringIO_Type) {
        line = _stringio_readline(op, -1);
    } else {
        line = io_call_noargs(op, py_id(_Py_ID_readline));
        if line and not unicode_check(line) {
            PyErr_Format(
                PyExc_OSError,
                ptr[u8]("readline() should have returned a str object, not '%.200s'"),
                object_type(line).view(1)[0].tp_name
            );
            object_decref(line);
            return NULL;
        }
    }

    if not line {
        return NULL;
    }

    if unicode_length(line) == 0 {
        object_decref(line);
        return NULL;
    }

    return line;
}

impl _io_StringIO_truncate_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }

    if size < 0 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("Negative size value %zd"), size);
        return NULL;
    }

    if size < self_[0].string_size {
        if realize(op) < 0 {
            return NULL;
        }
        if resize_buffer(op, u64(size)) < 0 {
            return NULL;
        }
        self_[0].string_size = size;
    }

    return PyLong_FromSsize_t(size);
}

impl _io_StringIO_seek_impl(op: ptr[PyObject], pos: i64, whence: i32) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }

    if whence != 0 and whence != 1 and whence != 2 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("Invalid whence (%i, should be 0, 1 or 2)"),
            whence
        );
        return NULL;
    } elif pos < 0 and whence == 0 {
        PyErr_Format(PyExc_ValueError, ptr[u8]("Negative seek position %zd"), pos);
        return NULL;
    } elif whence != 0 and pos != 0 {
        PyErr_SetString(PyExc_OSError, ptr[u8]("Can't do nonzero cur-relative seeks"));
        return NULL;
    }

    if whence == 1 {
        pos = self_[0].pos;
    } elif whence == 2 {
        pos = self_[0].string_size;
    }

    self_[0].pos = pos;

    return PyLong_FromSsize_t(self_[0].pos);
}

impl _io_StringIO_write_impl(op: ptr[PyObject], obj_: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    if not unicode_check(obj_) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("string argument expected, got '%s'"),
            object_type(obj_).view(1)[0].tp_name
        );
        return NULL;
    }
    if not check_open(op) {
        return NULL;
    }
    size = unicode_length(obj_);

    if size > 0 and write_str(op, obj_) < 0 {
        return NULL;
    }

    return PyLong_FromSsize_t(size);
}

impl _io_StringIO_close_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    self_[0].closed = 1;

    if resize_buffer(op, 0) < 0 {
        return NULL;
    }
    PyUnicodeWriter_Discard(self_[0].writer);
    self_[0].writer = ptr[PyUnicodeWriter]();
    py_clear(field_slot(op, STRINGIO_READNL));
    py_clear(field_slot(op, STRINGIO_WRITENL));
    py_clear(field_slot(op, STRINGIO_DECODER));
    return object_new_ref(Py_None);
}

impl stringio_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = stringio_record(op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].readnl, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].writenl, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].decoder, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(self_[0].dict, visitor, arg);
}

impl stringio_clear(op: ptr[PyObject]) -> i32 {
    py_clear(field_slot(op, STRINGIO_READNL));
    py_clear(field_slot(op, STRINGIO_WRITENL));
    py_clear(field_slot(op, STRINGIO_DECODER));
    py_clear(field_slot(op, STRINGIO_DICT));
    return 0;
}

impl stringio_dealloc(op: ptr[PyObject]) {
    self_ = stringio_record(op).view(1);
    tp = object_type(op);
    object_gc_untrack(op);
    self_[0].ok = 0;
    if self_[0].buf {
        PyMem_Free(ptr(self_[0].buf));
        self_[0].buf = ptr[u32]();
    }
    PyUnicodeWriter_Discard(self_[0].writer);
    stringio_clear(op);
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl stringio_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if not op {
        return NULL;
    }

    buf = ptr[u32](PyMem_Malloc(0));
    stringio_record(op).view(1)[0].buf = buf;
    if not buf {
        object_decref(op);
        return PyErr_NoMemory();
    }

    return op;
}

impl _io_StringIO___init___impl(
    op: ptr[PyObject], value: ptr[PyObject], newline_obj: ptr[PyObject]
) -> i32 {
    self_ = stringio_record(op).view(1);
    newline = ptr[u8]("\n");
    value_len: i64 = 0;

    if newline_obj == Py_None {
        newline = ptr[u8]();
    } elif newline_obj {
        if not unicode_check(newline_obj) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("newline must be str or None, not %.200s"),
                object_type(newline_obj).view(1)[0].tp_name
            );
            return -1;
        }
        newline = PyUnicode_AsUTF8(newline_obj);
        if not newline {
            return -1;
        }
    }

    if newline and newline.view(1)[0] != u8(0) {
        legal = False;
        first = newline.view(1)[0];
        if first == u8(10) {
            legal = newline.view(2)[1] == u8(0);
        } elif first == u8(13) {
            second = newline.view(2)[1];
            legal = second == u8(0)
                or (second == u8(10) and newline.view(3)[2] == u8(0));
        }
        if not legal {
            PyErr_Format(
                PyExc_ValueError, ptr[u8]("illegal newline value: %R"), newline_obj
            );
            return -1;
        }
    }
    if value and value != Py_None and not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("initial_value must be str or None, not %.200s"),
            object_type(value).view(1)[0].tp_name
        );
        return -1;
    }

    self_[0].ok = 0;

    PyUnicodeWriter_Discard(self_[0].writer);
    self_[0].writer = ptr[PyUnicodeWriter]();
    py_clear(field_slot(op, STRINGIO_READNL));
    py_clear(field_slot(op, STRINGIO_WRITENL));
    py_clear(field_slot(op, STRINGIO_DECODER));

    if newline {
        self_[0].readnl = PyUnicode_FromString(newline);
        if not self_[0].readnl {
            return -1;
        }
    }
    universal = not newline or newline.view(1)[0] == u8(0);
    self_[0].readuniversal = i8(1) if universal else i8(0);
    self_[0].readtranslate = i8(1) if not newline else i8(0);

    if newline and newline.view(1)[0] == u8(13) {
        self_[0].writenl = object_new_ref(self_[0].readnl);
    }

    module_state = find_io_state_by_def(object_type(op));
    if self_[0].readuniversal != 0 {
        self_[0].decoder = io_call_function(
            ptr[PyObject](module_state.view(1)[0].PyIncrementalNewlineDecoder_Type),
            Py_None,
            io_bool(self_[0].readtranslate != 0),
            NULL,
            NULL,
            2
        );
        if not self_[0].decoder {
            return -1;
        }
    }

    self_[0].string_size = 0;
    if value and value != Py_None {
        value_len = PyUnicode_GetLength(value);
    } else {
        value_len = 0;
    }
    if value_len > 0 {
        if resize_buffer(op, 0) < 0 {
            return -1;
        }
        self_[0].state = STATE_REALIZED;
        self_[0].pos = 0;
        if write_str(op, value) < 0 {
            return -1;
        }
    } else {
        if resize_buffer(op, 0) < 0 {
            return -1;
        }
        self_[0].writer = PyUnicodeWriter_Create(0);
        if not self_[0].writer {
            return -1;
        }
        self_[0].state = STATE_ACCUMULATING;
    }
    self_[0].pos = 0;
    self_[0].module_state = module_state;
    self_[0].closed = 0;
    self_[0].ok = 1;
    return 0;
}

impl _io_StringIO_readable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_StringIO_writable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_StringIO_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    return object_new_ref(io_true());
}

impl _io_StringIO___getstate___impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    initvalue = _io_StringIO_getvalue_impl(op);
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

    readnl = self_[0].readnl;
    if not readnl {
        readnl = Py_None;
    }
    state = Py_BuildValue(ptr[u8]("(OOnN)"), initvalue, readnl, self_[0].pos, dict);
    object_decref(initvalue);
    return state;
}

impl _io_StringIO___setstate___impl(
    op: ptr[PyObject], state: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = stringio_record(op).view(1);
    if not check_open(op) {
        return NULL;
    }

    if not tuple_check(state) or object_size(state) < 4 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("%.200s.__setstate__ argument should be 4-tuple, got %.200s"),
            object_type(op).view(1)[0].tp_name,
            object_type(state).view(1)[0].tp_name
        );
        return NULL;
    }

    initarg = PyTuple_GetSlice(state, 0, 2);
    if not initarg {
        return NULL;
    }
    if _io_StringIO___init___init(op, initarg, NULL) < 0 {
        object_decref(initarg);
        return NULL;
    }
    object_decref(initarg);

    item = tuple_get_item(state, 0);
    if unicode_check(item) {
        buf = PyUnicode_AsUCS4Copy(item);
        if not buf {
            return NULL;
        }
        bufsize = unicode_length(item);

        if resize_buffer(op, u64(bufsize)) < 0 {
            PyMem_Free(ptr(buf));
            return NULL;
        }
        memcpy(ptr(self_[0].buf), ptr(buf), u64(bufsize) * 4);
        PyMem_Free(ptr(buf));
        self_[0].string_size = bufsize;
    } else {
        self_[0].string_size = 0;
    }

    position_obj = tuple_get_item(state, 2);
    if not long_check(position_obj) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("third item of state must be an integer, got %.200s"),
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

    dict = tuple_get_item(state, 3);
    if dict != Py_None {
        if not dict_check(dict) {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("fourth item of state should be a dict, got a %.200s"),
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

impl _io_StringIO_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return PyBool_FromLong(i64(stringio_record(op).view(1)[0].closed));
}

impl _io_StringIO_line_buffering_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    return object_new_ref(io_false());
}

impl _io_StringIO_newlines_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    decoder = stringio_record(op).view(1)[0].decoder;
    if not check_initialized(op) or not check_open(op) {
        return NULL;
    }
    if not decoder {
        return object_new_ref(Py_None);
    }
    return PyObject_GetAttr(decoder, py_id(_Py_ID_newlines));
}

impl stringio_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_StringIO_read_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(stringio_read_glue).view(1)[0].call(receiver, args, nargs);
}

impl stringio_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io_StringIO_readline_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(stringio_readline_glue).view(1)[0].call(receiver, args, nargs);
}

impl install_stringio_tables -> bool {
    methods: list[MethodDefinition] = [];
    for method in io_select_methods(
        StringIO_methods,
        [
            "close",
            "getvalue",
            "read",
            "readline",
            "tell",
            "truncate",
            "seek",
            "write",
            "seekable",
            "readable",
            "writable",
            "__getstate__",
            "__setstate__"
        ]
    ) {
        callbacks = method.callbacks;
        if method.name == "read" {
            addressof(stringio_read_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=stringio_read_fast);
        } elif method.name == "readline" {
            addressof(stringio_readline_glue).view(1)[0].call = method.callbacks.fast;
            callbacks = MethodCallbacks(fast=stringio_readline_fast);
        }
        methods.append(
            MethodDefinition(method.name, callbacks, method.doc, method.flags)
        );
    }
    getset = io_select_properties(
        StringIO_getset, ["closed", "newlines", "line_buffering"]
    );
    return io_fill_slots(
        ptr[PyType_Slot](addressof(stringio_slots)), methods, getset, StringIO_doc
    );
}
