import from c {
    def memcpy(dest: ptr, src: ptr, n: u64) -> ptr;  def memmove(
        dest: ptr, src: ptr, n: u64
    ) -> ptr;  def memchr(source: ptr, value: i32, n: u64) -> ptr;  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def PyThread_acquire_lock_timed(
        lock: ptr, microseconds: i64, intr_flag: i32
    ) -> i32;  def _Py_FatalErrorFormat(func: ptr[u8], format: ptr[u8], *args: any);  def PyObject_ASCII(
        v: ptr[PyObject]
    ) -> ptr[PyObject];  def PyMemoryView_FromBuffer(
        info: ptr[Py_buffer]
    ) -> ptr[PyObject];  def PyBuffer_FillInfo(
        view: ptr[Py_buffer],
        exporter: ptr[PyObject],
        buf: ptr,
        length: i64,
        readonly: i32,
        flags: i32
    ) -> i32;  def jacpy_stack_address(slots: &mut IOStack) -> int;  obj buffered {
        has ob_base: _object,
            raw: ptr[PyObject],
            ok: i32,
            detached: i32,
            readable: i32,
            writable: i32,
            finalizing: i8,
            fast_closed_checks: i32,
            abs_pos: i64,
            buffer: ptr[u8],
            pos: i64,
            raw_pos: i64,
            read_end: i64,
            write_pos: i64,
            write_end: i64,
            lock: ptr,
            owner: u64,
            buffer_size: i64,
            buffer_mask: i64,
            dict: ptr[PyObject],
            weakreflist: ptr[PyObject];
    }  obj rwpair {
        has ob_base: _object,
            reader: ptr[PyObject],
            writer: ptr[PyObject],
            dict: ptr[PyObject],
            weakreflist: ptr[PyObject];
    }  obj BufferedOneCall {
        has call: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  obj BufferedFastCall {
        has call: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0;
    }  glob:priv bufferedwriter_write_glue: BufferedOneCall = BufferedOneCall(),
         buffered_readinto_glue: BufferedOneCall = BufferedOneCall(),
         buffered_readinto1_glue: BufferedOneCall = BufferedOneCall(),
         buffered_read_glue: BufferedFastCall = BufferedFastCall(),
         buffered_readline_glue: BufferedFastCall = BufferedFastCall();
}

glob BUFFERED_SIZE: Final[i64] = 152,
     BUFFERED_RAW: Final[i64] = 16,
     BUFFERED_FINALIZING: Final[i64] = 40,
     BUFFERED_DICT: Final[i64] = 136,
     BUFFERED_WEAKREFLIST: Final[i64] = 144,
     RWPAIR_SIZE: Final[i64] = 48,
     RWPAIR_READER: Final[i64] = 16,
     RWPAIR_WRITER: Final[i64] = 24,
     RWPAIR_DICT: Final[i64] = 32,
     RWPAIR_WEAKREFLIST: Final[i64] = 40;

def:priv buffered_record(op: ptr[PyObject]) -> ptr[buffered];

def:priv field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def:priv _bufferediobase_readinto_generic(
    self_: ptr[PyObject], buf: ptr, length: i64, readinto1: bool
) -> ptr[PyObject];

def _io__BufferedIOBase_readinto_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def _io__BufferedIOBase_readinto1_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def:priv bufferediobase_unsupported(
    state: ptr[IOModuleState], message: ptr[u8]
) -> ptr[PyObject];

def _io__BufferedIOBase_detach_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _io__BufferedIOBase_read_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject];

def _io__BufferedIOBase_read1_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject];

def _io__BufferedIOBase_write_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject];

def:priv _enter_buffered_busy(op: ptr[PyObject]) -> bool;

def:priv enter_buffered(op: ptr[PyObject]) -> bool;

def:priv leave_buffered(op: ptr[PyObject]);

def:priv check_initialized(op: ptr[PyObject]) -> bool;

def:priv is_closed(op: ptr[PyObject]) -> i32;

def:priv valid_read_buffer(op: ptr[PyObject]) -> bool;

def:priv valid_write_buffer(op: ptr[PyObject]) -> bool;

def:priv readahead(op: ptr[PyObject]) -> i64;

def:priv check_closed(op: ptr[PyObject], message: ptr[u8]) -> bool;

def:priv adjust_position(op: ptr[PyObject], new_pos: i64);

def:priv raw_offset(op: ptr[PyObject]) -> i64;

def:priv raw_tell(op: ptr[PyObject]) -> i64;

def:priv minus_last_block(op: ptr[PyObject], size: i64) -> i64;

def buffered_clear(op: ptr[PyObject]) -> i32;

def buffered_dealloc(op: ptr[PyObject]);

def _io__Buffered___sizeof___impl(op: ptr[PyObject]) -> ptr[PyObject];

def buffered_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def _io__Buffered__dealloc_warn_impl(
    op: ptr[PyObject], source: ptr[PyObject]
) -> ptr[PyObject];

def _io__Buffered_simple_flush_impl(op: ptr[PyObject]) -> ptr[PyObject];

def buffered_closed(op: ptr[PyObject]) -> i32;

def _io__Buffered_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_close_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_detach_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_readable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_writable_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_name_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_mode_get_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject];

def:priv _set_BlockingIOError(msg: ptr[u8], written: i64);

def:priv _buffered_check_blocking_error -> bool;

def:priv _buffered_raw_tell(op: ptr[PyObject]) -> i64;

def:priv _buffered_raw_seek(op: ptr[PyObject], target: i64, whence: i32) -> i64;

def:priv _buffered_init(op: ptr[PyObject]) -> i32;

def:priv buffered_flush_and_rewind_unlocked(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_flush_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_peek_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io__Buffered_read_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def _io__Buffered_read1_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def:priv _buffered_readinto_generic(
    op: ptr[PyObject], buf: ptr[u8], length: i64, readinto1: bool
) -> ptr[PyObject];

def _io__Buffered_readinto_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def _io__Buffered_readinto1_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def:priv readline_done(
    op: ptr[PyObject], chunks: ptr[PyObject], res: ptr[PyObject]
) -> ptr[PyObject];

def:priv _buffered_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject];

def _io__Buffered_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject];

def _io__Buffered_tell_impl(op: ptr[PyObject]) -> ptr[PyObject];

def _io__Buffered_seek_impl(
    op: ptr[PyObject], targetobj: ptr[PyObject], whence: i32
) -> ptr[PyObject];

def _io__Buffered_truncate_impl(
    op: ptr[PyObject], cls: ptr[PyObject], pos: ptr[PyObject]
) -> ptr[PyObject];

def buffered_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def buffered_repr(op: ptr[PyObject]) -> ptr[PyObject];

def:priv _bufferedreader_reset_buf(op: ptr[PyObject]);

def _io_BufferedReader___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32;

def:priv _bufferedreader_raw_read(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64;

def:priv _bufferedreader_fill_buffer(op: ptr[PyObject]) -> i64;

def:priv read_all_done(
    res: ptr[PyObject], data: ptr[PyObject], tmp: ptr[PyObject], chunks: ptr[PyObject]
) -> ptr[PyObject];

def:priv _bufferedreader_read_all(op: ptr[PyObject]) -> ptr[PyObject];

def:priv _bufferedreader_read_fast(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def:priv _bufferedreader_read_generic(op: ptr[PyObject], n: i64) -> ptr[PyObject];

def:priv _bufferedreader_peek_unlocked(op: ptr[PyObject]) -> ptr[PyObject];

def:priv _bufferedwriter_reset_buf(op: ptr[PyObject]);

def _io_BufferedWriter___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32;

def:priv _bufferedwriter_raw_write(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64;

def:priv _bufferedwriter_flush_unlocked(op: ptr[PyObject]) -> ptr[PyObject];

def:priv bufferedwriter_write_data(
    op: ptr[PyObject], buf: ptr[u8], length: i64
) -> ptr[PyObject];

def _io_BufferedWriter_write_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject];

def:priv rwpair_record(op: ptr[PyObject]) -> ptr[rwpair];

def _io_BufferedRWPair___init___impl(
    op: ptr[PyObject], reader: ptr[PyObject], writer: ptr[PyObject], buffer_size: i64
) -> i32;

def bufferedrwpair_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def bufferedrwpair_clear(op: ptr[PyObject]) -> i32;

def bufferedrwpair_dealloc(op: ptr[PyObject]);

def:priv _forward_call(
    target: ptr[PyObject], name: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def bufferedrwpair_read(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_peek(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_read1(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_readinto(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_readinto1(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_write(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_flush(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_readable(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_writable(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_close(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_isatty(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def bufferedrwpair_closed_get(op: ptr[PyObject], dummy: ptr) -> ptr[PyObject];

def _io_BufferedRandom___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32;

def bufferedwriter_write_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def buffered_readinto_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def buffered_readinto1_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def buffered_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def buffered_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

import from c {
    glob:priv bufferediobase_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bufferediobase_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io._BufferedIOBase"),
             basicsize=0,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bufferediobase_slots)
         ); glob:priv bufferedreader_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("raw"),
                 type_=_Py_T_OBJECT,
                 offset=BUFFERED_RAW,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("_finalizing"),
                 type_=Py_T_BOOL,
                 offset=BUFFERED_FINALIZING,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         bufferedreader_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(buffered_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(buffered_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(buffered_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(buffered_clear)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(buffered_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(bufferedreader_members))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_BufferedReader___init___init)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bufferedreader_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.BufferedReader"),
             basicsize=i32(BUFFERED_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bufferedreader_slots)
         ); glob:priv bufferedwriter_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("raw"),
                 type_=_Py_T_OBJECT,
                 offset=BUFFERED_RAW,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("_finalizing"),
                 type_=Py_T_BOOL,
                 offset=BUFFERED_FINALIZING,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         bufferedwriter_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(buffered_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(buffered_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(buffered_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(buffered_clear)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(bufferedwriter_members))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_BufferedWriter___init___init)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bufferedwriter_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.BufferedWriter"),
             basicsize=i32(BUFFERED_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bufferedwriter_slots)
         ); glob:priv bufferedrwpair_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("read"),
                 ml_meth=ptr(bufferedrwpair_read),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("peek"),
                 ml_meth=ptr(bufferedrwpair_peek),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("read1"),
                 ml_meth=ptr(bufferedrwpair_read1),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("readinto"),
                 ml_meth=ptr(bufferedrwpair_readinto),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("readinto1"),
                 ml_meth=ptr(bufferedrwpair_readinto1),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("write"),
                 ml_meth=ptr(bufferedrwpair_write),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("flush"),
                 ml_meth=ptr(bufferedrwpair_flush),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("readable"),
                 ml_meth=ptr(bufferedrwpair_readable),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("writable"),
                 ml_meth=ptr(bufferedrwpair_writable),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(bufferedrwpair_close),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isatty"),
                 ml_meth=ptr(bufferedrwpair_isatty),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         bufferedrwpair_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=RWPAIR_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=RWPAIR_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         bufferedrwpair_getset: list[PyGetSetDef] = [
             PyGetSetDef(name=ptr[u8]("closed"), get=bufferedrwpair_closed_get),
             PyGetSetDef()
         ],
         bufferedrwpair_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(bufferedrwpair_dealloc)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(bufferedrwpair_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(bufferedrwpair_clear)),
             PyType_Slot(
                 slot=Py_tp_methods, pfunc=ptr(addressof(bufferedrwpair_methods))
             ),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(bufferedrwpair_members))
             ),
             PyType_Slot(
                 slot=Py_tp_getset, pfunc=ptr(addressof(bufferedrwpair_getset))
             ),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_BufferedRWPair___init___init)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bufferedrwpair_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.BufferedRWPair"),
             basicsize=i32(RWPAIR_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bufferedrwpair_slots)
         ); glob:priv bufferedrandom_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("raw"),
                 type_=_Py_T_OBJECT,
                 offset=BUFFERED_RAW,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("_finalizing"),
                 type_=Py_T_BOOL,
                 offset=BUFFERED_FINALIZING,
                 flags=0
             ),
             PyMemberDef(
                 name=ptr[u8]("__weaklistoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_WEAKREFLIST,
                 flags=Py_READONLY
             ),
             PyMemberDef(
                 name=ptr[u8]("__dictoffset__"),
                 type_=Py_T_PYSSIZET,
                 offset=BUFFERED_DICT,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         bufferedrandom_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(buffered_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(buffered_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(buffered_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(buffered_clear)),
             PyType_Slot(slot=Py_tp_iternext, pfunc=ptr(buffered_iternext)),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(
                 slot=Py_tp_members, pfunc=ptr(addressof(bufferedrandom_members))
             ),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(_io_BufferedRandom___init___init)),
             PyType_Slot(slot=Py_tp_token, pfunc=ptr()),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob bufferedrandom_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_io.BufferedRandom"),
             basicsize=i32(BUFFERED_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(bufferedrandom_slots)
         );
}

def:priv buffered_methods(names: list[str]) -> list[MethodDefinition];

def install_buffered_tables -> bool;

impl buffered_record(op: ptr[PyObject]) -> ptr[buffered] {
    return ptr[buffered](op);
}

impl field_slot(op: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](op) + offset);
}

impl _bufferediobase_readinto_generic(
    self_: ptr[PyObject], buf: ptr, length: i64, readinto1: bool
) -> ptr[PyObject] {
    attr = py_id(_Py_ID_read1) if readinto1 else py_id(_Py_ID_read);
    data = io_call_ssize(self_, attr, length);
    if not data {
        return NULL;
    }

    if not bytes_check(data) {
        object_decref(data);
        PyErr_SetString(PyExc_TypeError, ptr[u8]("read() should return bytes"));
        return NULL;
    }

    len = object_size(data);
    if len > length {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("read() returned too much data: %zd bytes requested, %zd returned"),
            length,
            len
        );
        object_decref(data);
        return NULL;
    }
    memcpy(buf, ptr(bytes_data(data)), u64(len));

    object_decref(data);

    return PyLong_FromSsize_t(len);
}

impl _io__BufferedIOBase_readinto_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return _bufferediobase_readinto_generic(
        self_, buffer.address(), buffer.size(), False
    );
}

impl _io__BufferedIOBase_readinto1_impl(
    self_: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return _bufferediobase_readinto_generic(
        self_, buffer.address(), buffer.size(), True
    );
}

impl bufferediobase_unsupported(
    state: ptr[IOModuleState], message: ptr[u8]
) -> ptr[PyObject] {
    PyErr_SetString(state.view(1)[0].unsupported_operation, message);
    return NULL;
}

impl _io__BufferedIOBase_detach_impl(
    self_: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    return bufferediobase_unsupported(get_io_state_by_cls(cls), ptr[u8]("detach"));
}

impl _io__BufferedIOBase_read_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject] {
    return bufferediobase_unsupported(get_io_state_by_cls(cls), ptr[u8]("read"));
}

impl _io__BufferedIOBase_read1_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], size: i32
) -> ptr[PyObject] {
    return bufferediobase_unsupported(get_io_state_by_cls(cls), ptr[u8]("read1"));
}

impl _io__BufferedIOBase_write_impl(
    self_: ptr[PyObject], cls: ptr[PyObject], b: ptr[PyObject]
) -> ptr[PyObject] {
    return bufferediobase_unsupported(get_io_state_by_cls(cls), ptr[u8]("write"));
}

impl _enter_buffered_busy(op: ptr[PyObject]) -> bool {
    self_ = buffered_record(op).view(1);
    if self_[0].owner == PyThread_get_thread_ident() {
        PyErr_Format(PyExc_RuntimeError, ptr[u8]("reentrant call inside %R"), op);
        return False;
    }
    interp = current_interp();
    relax_locking = _Py_IsInterpreterFinalizing(ptr[PyInterpreterState](interp)) != 0;
    st: i32 = 0;
    thread = PyEval_SaveThread();
    if not relax_locking {
        st = PyThread_acquire_lock(self_[0].lock, 1);
    } else {
        st = PyThread_acquire_lock_timed(self_[0].lock, 1000000, 0);
    }
    PyEval_RestoreThread(thread);
    if relax_locking and st != PY_LOCK_ACQUIRED {
        ascii = PyObject_ASCII(op);
        text = ptr[u8]("<ascii(self) failed>");
        if ascii {
            text = PyUnicode_AsUTF8(ascii);
        }
        _Py_FatalErrorFormat(
            ptr[u8]("_enter_buffered_busy"),
            ptr[u8](
                "could not acquire lock for %s at interpreter shutdown, possibly due to daemon threads"
            ),
            text
        );
    }
    return True;
}

impl enter_buffered(op: ptr[PyObject]) -> bool {
    self_ = buffered_record(op).view(1);
    if PyThread_acquire_lock(self_[0].lock, 0) == 0 {
        if not _enter_buffered_busy(op) {
            return False;
        }
    }
    self_[0].owner = PyThread_get_thread_ident();
    return True;
}

impl leave_buffered(op: ptr[PyObject]) {
    self_ = buffered_record(op).view(1);
    self_[0].owner = 0;
    PyThread_release_lock(self_[0].lock);
}

impl check_initialized(op: ptr[PyObject]) -> bool {
    self_ = buffered_record(op).view(1);
    if self_[0].ok <= 0 {
        if self_[0].detached != 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("raw stream has been detached"));
        } else {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("I/O operation on uninitialized object")
            );
        }
        return False;
    }
    return True;
}

impl is_closed(op: ptr[PyObject]) -> i32 {
    self_ = buffered_record(op).view(1);
    if not self_[0].buffer {
        return 1;
    }
    if self_[0].fast_closed_checks != 0 {
        return _PyFileIO_closed(self_[0].raw);
    }
    return buffered_closed(op);
}

impl valid_read_buffer(op: ptr[PyObject]) -> bool {
    self_ = buffered_record(op).view(1);
    return self_[0].readable != 0 and self_[0].read_end != -1;
}

impl valid_write_buffer(op: ptr[PyObject]) -> bool {
    self_ = buffered_record(op).view(1);
    return self_[0].writable != 0 and self_[0].write_end != -1;
}

impl readahead(op: ptr[PyObject]) -> i64 {
    self_ = buffered_record(op).view(1);
    if self_[0].readable != 0 and valid_read_buffer(op) {
        return self_[0].read_end - self_[0].pos;
    }
    return 0;
}

impl check_closed(op: ptr[PyObject], message: ptr[u8]) -> bool {
    if is_closed(op) != 0 and readahead(op) == 0 {
        PyErr_SetString(PyExc_ValueError, message);
        return False;
    }
    return True;
}

impl adjust_position(op: ptr[PyObject], new_pos: i64) {
    self_ = buffered_record(op).view(1);
    self_[0].pos = new_pos;
    if valid_read_buffer(op) and self_[0].read_end < self_[0].pos {
        self_[0].read_end = self_[0].pos;
    }
}

impl raw_offset(op: ptr[PyObject]) -> i64 {
    self_ = buffered_record(op).view(1);
    if (valid_read_buffer(op) or valid_write_buffer(op)) and self_[0].raw_pos >= 0 {
        return self_[0].raw_pos - self_[0].pos;
    }
    return 0;
}

impl raw_tell(op: ptr[PyObject]) -> i64 {
    abs_pos = buffered_record(op).view(1)[0].abs_pos;
    if abs_pos != -1 {
        return abs_pos;
    }
    return _buffered_raw_tell(op);
}

impl minus_last_block(op: ptr[PyObject], size: i64) -> i64 {
    self_ = buffered_record(op).view(1);
    if self_[0].buffer_mask != 0 {
        return size & ~self_[0].buffer_mask;
    }
    return self_[0].buffer_size * (size // self_[0].buffer_size);
}

impl buffered_clear(op: ptr[PyObject]) -> i32 {
    buffered_record(op).view(1)[0].ok = 0;
    py_clear(field_slot(op, BUFFERED_RAW));
    py_clear(field_slot(op, BUFFERED_DICT));
    return 0;
}

impl buffered_dealloc(op: ptr[PyObject]) {
    self_ = buffered_record(op).view(1);
    tp = object_type(op);
    self_[0].finalizing = 1;
    if _PyIOBase_finalize(op) < 0 {
        return;
    }
    object_gc_untrack(op);
    self_[0].ok = 0;
    if self_[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    if self_[0].buffer {
        PyMem_Free(ptr(self_[0].buffer));
        self_[0].buffer = ptr[u8]();
    }
    if self_[0].lock {
        PyThread_free_lock(self_[0].lock);
        self_[0].lock = ptr();
    }
    buffered_clear(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl _io__Buffered___sizeof___impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res = u64(object_type(op).view(1)[0].tp_basicsize);
    if self_[0].buffer {
        res += u64(self_[0].buffer_size);
    }
    return PyLong_FromSize_t(res);
}

impl buffered_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = buffered_record(op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].raw, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(self_[0].dict, visitor, arg);
}

impl _io__Buffered__dealloc_warn_impl(
    op: ptr[PyObject], source: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    if self_[0].ok != 0 and self_[0].raw {
        r = io_call_onearg(self_[0].raw, py_id(_Py_ID__dealloc_warn), source);
        if r {
            object_decref(r);
        } else {
            PyErr_Clear();
        }
    }
    return object_new_ref(Py_None);
}

impl _io__Buffered_simple_flush_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_flush));
}

impl buffered_closed(op: ptr[PyObject]) -> i32 {
    if not check_initialized(op) {
        return -1;
    }
    res = PyObject_GetAttr(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_closed));
    if not res {
        return -1;
    }
    closed = PyObject_IsTrue(res);
    object_decref(res);
    return closed;
}

impl _io__Buffered_closed_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return PyObject_GetAttr(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_closed));
}

impl _io__Buffered_close_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }
    if not enter_buffered(op) {
        return NULL;
    }

    r = buffered_closed(op);
    if r < 0 {
        leave_buffered(op);
        return res;
    }
    if r > 0 {
        res = object_new_ref(Py_None);
        leave_buffered(op);
        return res;
    }

    if self_[0].finalizing != 0 {
        warned = _io__Buffered__dealloc_warn_impl(op, op);
        if warned {
            object_decref(warned);
        } else {
            PyErr_Clear();
        }
    }

    leave_buffered(op);
    r = _PyFile_Flush(op);
    if not enter_buffered(op) {
        return NULL;
    }
    exc: ptr[PyObject] = NULL;
    if r < 0 {
        exc = PyErr_GetRaisedException();
    }

    res = io_call_noargs(self_[0].raw, py_id(_Py_ID_close));

    if self_[0].buffer {
        PyMem_Free(ptr(self_[0].buffer));
        self_[0].buffer = ptr[u8]();
    }

    if exc {
        _PyErr_ChainExceptions1(exc);
        object_xdecref(res);
        res = NULL;
    }

    self_[0].read_end = 0;
    self_[0].pos = 0;

    leave_buffered(op);
    return res;
}

impl _io__Buffered_detach_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    if not check_initialized(op) {
        return NULL;
    }
    if _PyFile_Flush(op) < 0 {
        return NULL;
    }
    raw = self_[0].raw;
    self_[0].raw = NULL;
    self_[0].detached = 1;
    self_[0].ok = 0;
    return raw;
}

impl _io__Buffered_seekable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_seekable));
}

impl _io__Buffered_readable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_readable));
}

impl _io__Buffered_writable_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_writable));
}

impl _io__Buffered_name_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return PyObject_GetAttr(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_name));
}

impl _io__Buffered_mode_get_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return PyObject_GetAttr(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_mode));
}

impl _io__Buffered_fileno_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_fileno));
}

impl _io__Buffered_isatty_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return io_call_noargs(buffered_record(op).view(1)[0].raw, py_id(_Py_ID_isatty));
}

impl _set_BlockingIOError(msg: ptr[u8], written: i64) {
    PyErr_Clear();
    err = PyObject_CallFunction(
        PyExc_BlockingIOError, "isn", i32.wrap(jacpy_errno()), msg, written
    );
    if err {
        PyErr_SetObject(PyExc_BlockingIOError, err);
    }
    object_xdecref(err);
}

impl _buffered_check_blocking_error -> bool {
    exc = PyErr_GetRaisedException();
    if not exc or PyErr_GivenExceptionMatches(exc, PyExc_BlockingIOError) == 0 {
        PyErr_SetRaisedException(exc);
        return False;
    }
    PyErr_SetRaisedException(exc);
    return True;
}

impl _buffered_raw_tell(op: ptr[PyObject]) -> i64 {
    self_ = buffered_record(op).view(1);
    res = io_call_noargs(self_[0].raw, py_id(_Py_ID_tell));
    if not res {
        return -1;
    }
    n = PyNumber_AsOff_t(res, PyExc_ValueError);
    object_decref(res);
    if n < 0 {
        if not PyErr_Occurred() {
            PyErr_Format(
                PyExc_OSError, ptr[u8]("Raw stream returned invalid position %zd"), n
            );
        }
        return -1;
    }
    self_[0].abs_pos = n;
    return n;
}

impl _buffered_raw_seek(op: ptr[PyObject], target: i64, whence: i32) -> i64 {
    self_ = buffered_record(op).view(1);
    posobj = PyLong_FromSsize_t(target);
    if not posobj {
        return -1;
    }
    whenceobj = PyLong_FromLong(i64(whence));
    if not whenceobj {
        object_decref(posobj);
        return -1;
    }
    res = io_call_twoargs(self_[0].raw, py_id(_Py_ID_seek), posobj, whenceobj);
    object_decref(posobj);
    object_decref(whenceobj);
    if not res {
        return -1;
    }
    n = PyNumber_AsOff_t(res, PyExc_ValueError);
    object_decref(res);
    if n < 0 {
        if not PyErr_Occurred() {
            PyErr_Format(
                PyExc_OSError, ptr[u8]("Raw stream returned invalid position %zd"), n
            );
        }
        return -1;
    }
    self_[0].abs_pos = n;
    return n;
}

impl _buffered_init(op: ptr[PyObject]) -> i32 {
    self_ = buffered_record(op).view(1);
    if self_[0].buffer_size <= 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("buffer size must be strictly positive")
        );
        return -1;
    }
    if self_[0].buffer {
        PyMem_Free(ptr(self_[0].buffer));
    }
    self_[0].buffer = ptr[u8](PyMem_Malloc(u64(self_[0].buffer_size)));
    if not self_[0].buffer {
        PyErr_NoMemory();
        return -1;
    }
    if self_[0].lock {
        PyThread_free_lock(self_[0].lock);
    }
    self_[0].lock = PyThread_allocate_lock();
    if not self_[0].lock {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("can't allocate read lock"));
        return -1;
    }
    self_[0].owner = 0;

    n = self_[0].buffer_size - 1;
    while (n & 1) != 0 {
        n >>= 1;
    }
    if n == 0 {
        self_[0].buffer_mask = self_[0].buffer_size - 1;
    } else {
        self_[0].buffer_mask = 0;
    }
    if _buffered_raw_tell(op) == -1 {
        PyErr_Clear();
    }
    return 0;
}

impl buffered_flush_and_rewind_unlocked(op: ptr[PyObject]) -> ptr[PyObject] {
    res = _bufferedwriter_flush_unlocked(op);
    if not res {
        return NULL;
    }
    object_decref(res);

    if buffered_record(op).view(1)[0].readable != 0 {
        n = _buffered_raw_seek(op, -raw_offset(op), 1);
        _bufferedreader_reset_buf(op);
        if n == -1 {
            return NULL;
        }
    }
    return object_new_ref(Py_None);
}

impl _io__Buffered_flush_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    if not check_closed(op, ptr[u8]("flush of closed file")) {
        return NULL;
    }

    if not enter_buffered(op) {
        return NULL;
    }
    res = buffered_flush_and_rewind_unlocked(op);
    leave_buffered(op);

    return res;
}

impl _io__Buffered_peek_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }
    if not check_closed(op, ptr[u8]("peek of closed file")) {
        return NULL;
    }

    if not enter_buffered(op) {
        return NULL;
    }

    if buffered_record(op).view(1)[0].writable != 0 {
        res = buffered_flush_and_rewind_unlocked(op);
        if not res {
            leave_buffered(op);
            return NULL;
        }
        object_decref(res);
    }
    res = _bufferedreader_peek_unlocked(op);

    leave_buffered(op);
    return res;
}

impl _io__Buffered_read_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }
    if n < -1 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("read length must be non-negative or -1")
        );
        return NULL;
    }

    if not check_closed(op, ptr[u8]("read of closed file")) {
        return NULL;
    }

    if n == -1 {
        if not enter_buffered(op) {
            return NULL;
        }
        res = _bufferedreader_read_all(op);
    } else {
        res = _bufferedreader_read_fast(op, n);
        if res != Py_None {
            return res;
        }
        object_decref(res);
        if not enter_buffered(op) {
            return NULL;
        }
        res = _bufferedreader_read_generic(op, n);
    }

    leave_buffered(op);
    return res;
}

impl _io__Buffered_read1_impl(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);

    if not check_initialized(op) {
        return NULL;
    }
    if n < 0 {
        n = self_[0].buffer_size;
    }

    if not check_closed(op, ptr[u8]("read of closed file")) {
        return NULL;
    }

    if n == 0 {
        return PyBytes_FromStringAndSize(ptr[u8](), 0);
    }

    have = readahead(op);
    if have > 0 {
        if have < n {
            n = have;
        }
        return _bufferedreader_read_fast(op, n);
    }
    res = PyBytes_FromStringAndSize(ptr[u8](), n);
    if not res {
        return NULL;
    }
    if not enter_buffered(op) {
        object_decref(res);
        return NULL;
    }

    if self_[0].writable != 0 {
        flushed = buffered_flush_and_rewind_unlocked(op);
        if not flushed {
            leave_buffered(op);
            object_decref(res);
            return NULL;
        }
        object_decref(flushed);
    }
    _bufferedreader_reset_buf(op);
    r = _bufferedreader_raw_read(op, bytes_data(res), n);
    leave_buffered(op);
    if r == -1 {
        object_decref(res);
        return NULL;
    }
    if r == -2 {
        r = 0;
    }
    if n > r {
        _PyBytes_Resize(&mut res, r);
    }
    return res;
}

impl _buffered_readinto_generic(
    op: ptr[PyObject], buf: ptr[u8], length: i64, readinto1: bool
) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    written: i64 = 0;
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }
    if not check_closed(op, ptr[u8]("readinto of closed file")) {
        return NULL;
    }

    n = readahead(op);
    if n > 0 {
        if n >= length {
            memcpy(ptr(buf), ptr(self_[0].buffer + self_[0].pos), u64(length));
            self_[0].pos += length;
            return PyLong_FromSsize_t(length);
        }
        memcpy(ptr(buf), ptr(self_[0].buffer + self_[0].pos), u64(n));
        self_[0].pos += n;
        written = n;
    }

    if not enter_buffered(op) {
        return NULL;
    }

    if self_[0].writable != 0 {
        res = buffered_flush_and_rewind_unlocked(op);
        if not res {
            leave_buffered(op);
            return NULL;
        }
        object_decref(res);
        res = NULL;
    }

    _bufferedreader_reset_buf(op);
    self_[0].pos = 0;

    remaining = length - written;
    while remaining > 0 {
        if remaining > self_[0].buffer_size {
            n = _bufferedreader_raw_read(op, buf + written, remaining);
        } elif not (readinto1 and written != 0) {
            n = _bufferedreader_fill_buffer(op);
            if n > 0 {
                if n > remaining {
                    n = remaining;
                }
                memcpy(ptr(buf + written), ptr(self_[0].buffer + self_[0].pos), u64(n));
                self_[0].pos += n;

                written += n;
                remaining -= n;
                continue;
            }
        } else {
            n = 0;
        }

        if n == 0 or (n == -2 and written > 0) {
            break;
        }
        if n < 0 {
            if n == -2 {
                res = object_new_ref(Py_None);
            }
            leave_buffered(op);
            return res;
        }

        if readinto1 {
            written += n;
            break;
        }
        written += n;
        remaining -= n;
    }
    res = PyLong_FromSsize_t(written);

    leave_buffered(op);
    return res;
}

impl _io__Buffered_readinto_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return _buffered_readinto_generic(
        op, ptr[u8](buffer.address()), buffer.size(), False
    );
}

impl _io__Buffered_readinto1_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return _buffered_readinto_generic(
        op, ptr[u8](buffer.address()), buffer.size(), True
    );
}

impl readline_done(
    op: ptr[PyObject], chunks: ptr[PyObject], res: ptr[PyObject]
) -> ptr[PyObject] {
    leave_buffered(op);
    object_xdecref(chunks);
    return res;
}

impl _buffered_readline(op: ptr[PyObject], limit: i64) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;
    chunks: ptr[PyObject] = NULL;

    if not check_closed(op, ptr[u8]("readline of closed file")) {
        return NULL;
    }

    n = readahead(op);
    if limit >= 0 and n > limit {
        n = limit;
    }
    start = self_[0].buffer + self_[0].pos;
    s = ptr[u8](memchr(ptr(start), 10, u64(n)));
    if s {
        line_len = i64(int(s) - int(start)) + 1;
        res = PyBytes_FromStringAndSize(start, line_len);
        if res {
            self_[0].pos += line_len;
        }
        return res;
    }
    if n == limit {
        res = PyBytes_FromStringAndSize(start, n);
        if res {
            self_[0].pos += n;
        }
        return res;
    }

    if not enter_buffered(op) {
        return NULL;
    }

    chunks = PyList_New(0);
    if not chunks {
        return readline_done(op, chunks, NULL);
    }
    if n > 0 {
        res = PyBytes_FromStringAndSize(start, n);
        if not res {
            return readline_done(op, chunks, NULL);
        }
        if PyList_Append(chunks, res) < 0 {
            object_decref(res);
            return readline_done(op, chunks, NULL);
        }
        object_decref(res);
        res = NULL;
        self_[0].pos += n;
        if limit >= 0 {
            limit -= n;
        }
    }
    if self_[0].writable != 0 {
        r = buffered_flush_and_rewind_unlocked(op);
        if not r {
            return readline_done(op, chunks, NULL);
        }
        object_decref(r);
    }

    found = False;
    while True {
        _bufferedreader_reset_buf(op);
        n = _bufferedreader_fill_buffer(op);
        if n == -1 {
            return readline_done(op, chunks, NULL);
        }
        if n <= 0 {
            break;
        }
        if limit >= 0 and n > limit {
            n = limit;
        }
        start = self_[0].buffer;
        i: i64 = 0;
        while i < n {
            c = start.view(n)[i];
            i += 1;
            if c == u8(10) {
                res = PyBytes_FromStringAndSize(start, i);
                if not res {
                    return readline_done(op, chunks, NULL);
                }
                self_[0].pos = i;
                found = True;
                break;
            }
        }
        if found {
            break;
        }
        res = PyBytes_FromStringAndSize(start, n);
        if not res {
            return readline_done(op, chunks, NULL);
        }
        if n == limit {
            self_[0].pos = n;
            break;
        }
        if PyList_Append(chunks, res) < 0 {
            object_decref(res);
            return readline_done(op, chunks, NULL);
        }
        object_decref(res);
        res = NULL;
        if limit >= 0 {
            limit -= n;
        }
    }
    if res and PyList_Append(chunks, res) < 0 {
        object_decref(res);
        return readline_done(op, chunks, NULL);
    }
    joined = PyBytes_Join(bytes_get_empty(), chunks);
    object_xdecref(res);
    return readline_done(op, chunks, joined);
}

impl _io__Buffered_readline_impl(op: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    return _buffered_readline(op, size);
}

impl _io__Buffered_tell_impl(op: ptr[PyObject]) -> ptr[PyObject] {
    if not check_initialized(op) {
        return NULL;
    }
    pos = _buffered_raw_tell(op);
    if pos == -1 {
        return NULL;
    }
    pos -= raw_offset(op);

    if pos < 0 {
        pos = 0;
    }

    return PyLong_FromSsize_t(pos);
}

impl _io__Buffered_seek_impl(
    op: ptr[PyObject], targetobj: ptr[PyObject], whence: i32
) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }

    if (whence < 0 or whence > 2)
        and i64(whence) != SEEK_HOLE
        and i64(whence) != SEEK_DATA {
        PyErr_Format(PyExc_ValueError, ptr[u8]("whence value %d unsupported"), whence);
        return NULL;
    }

    if not check_closed(op, ptr[u8]("seek of closed file")) {
        return NULL;
    }

    state = find_io_state_by_def(object_type(op));
    if not _PyIOBase_check_seekable(state, self_[0].raw, io_true()) {
        return NULL;
    }

    target = PyNumber_AsOff_t(targetobj, PyExc_ValueError);
    if target == -1 and PyErr_Occurred() {
        return NULL;
    }

    if (whence == 0 or whence == 1) and self_[0].readable != 0 {
        current = raw_tell(op);
        avail = readahead(op);
        if avail > 0 {
            offset: i64 = 0;
            if whence == 0 {
                offset = target - (current - raw_offset(op));
            } else {
                offset = target;
            }
            if offset >= -self_[0].pos and offset <= avail {
                self_[0].pos += offset;

                if current - avail + offset < 0 {
                    return PyLong_FromSsize_t(0);
                }

                return PyLong_FromSsize_t(current - avail + offset);
            }
        }
    }

    if not enter_buffered(op) {
        return NULL;
    }

    if self_[0].writable != 0 {
        res = _bufferedwriter_flush_unlocked(op);
        if not res {
            leave_buffered(op);
            return NULL;
        }
        object_decref(res);
        res = NULL;
    }

    if whence == 1 {
        target -= raw_offset(op);
    }
    n = _buffered_raw_seek(op, target, whence);
    if n == -1 {
        leave_buffered(op);
        return NULL;
    }
    self_[0].raw_pos = -1;
    res = PyLong_FromSsize_t(n);
    if res and self_[0].readable != 0 {
        _bufferedreader_reset_buf(op);
    }

    leave_buffered(op);
    return res;
}

impl _io__Buffered_truncate_impl(
    op: ptr[PyObject], cls: ptr[PyObject], pos: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }
    if not check_closed(op, ptr[u8]("truncate of closed file")) {
        return NULL;
    }
    if self_[0].writable == 0 {
        return bufferediobase_unsupported(
            get_io_state_by_cls(cls), ptr[u8]("truncate")
        );
    }
    if not enter_buffered(op) {
        return NULL;
    }

    res = buffered_flush_and_rewind_unlocked(op);
    if not res {
        leave_buffered(op);
        return NULL;
    }
    object_decref(res);

    res = io_call_onearg(self_[0].raw, py_id(_Py_ID_truncate), pos);
    if not res {
        leave_buffered(op);
        return NULL;
    }

    if _buffered_raw_tell(op) == -1 {
        PyErr_Clear();
    }

    leave_buffered(op);
    return res;
}

impl buffered_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    line: ptr[PyObject] = NULL;

    if not check_initialized(op) {
        return NULL;
    }

    state = find_io_state_by_def(object_type(op)).view(1);
    tp = object_type(op);
    if tp == state[0].PyBufferedReader_Type or tp == state[0].PyBufferedRandom_Type {
        line = _buffered_readline(op, -1);
    } else {
        line = io_call_noargs(op, py_id(_Py_ID_readline));
        if line and not bytes_check(line) {
            PyErr_Format(
                PyExc_OSError,
                ptr[u8]("readline() should have returned a bytes object, not '%.200s'"),
                object_type(line).view(1)[0].tp_name
            );
            object_decref(line);
            return NULL;
        }
    }

    if not line {
        return NULL;
    }

    if object_size(line) == 0 {
        object_decref(line);
        return NULL;
    }

    return line;
}

impl buffered_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    nameobj: ptr[PyObject] = NULL;
    res: ptr[PyObject] = NULL;

    type_name = object_type(op).view(1)[0].tp_name;
    if PyObject_GetOptionalAttr(op, py_id(_Py_ID_name), &mut nameobj) < 0 {
        if PyErr_ExceptionMatches(PyExc_ValueError) == 0 {
            return NULL;
        }

        PyErr_Clear();
    }
    if not nameobj {
        res = PyUnicode_FromFormat("<%s>", type_name);
    } else {
        status = Py_ReprEnter(op);
        if status == 0 {
            res = PyUnicode_FromFormat("<%s name=%R>", type_name, nameobj);
            Py_ReprLeave(op);
        } elif status > 0 {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8]("reentrant call inside %s.__repr__"),
                type_name
            );
        }
        object_decref(nameobj);
    }
    return res;
}

impl _bufferedreader_reset_buf(op: ptr[PyObject]) {
    buffered_record(op).view(1)[0].read_end = -1;
}

impl _io_BufferedReader___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32 {
    self_ = buffered_record(op).view(1);
    self_[0].ok = 0;
    self_[0].detached = 0;

    state = find_io_state_by_def(object_type(op));
    if not _PyIOBase_check_readable(state, raw, io_true()) {
        return -1;
    }

    py_xsetref(field_slot(op, BUFFERED_RAW), object_new_ref(raw));
    self_[0].buffer_size = buffer_size;
    self_[0].readable = 1;
    self_[0].writable = 0;

    if _buffered_init(op) < 0 {
        return -1;
    }
    _bufferedreader_reset_buf(op);

    fast = object_is_type(op, state.view(1)[0].PyBufferedReader_Type)
        and object_is_type(raw, state.view(1)[0].PyFileIO_Type);
    self_[0].fast_closed_checks = i32(1) if fast else i32(0);

    self_[0].ok = 1;
    return 0;
}

impl _bufferedreader_raw_read(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64 {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;

    slots: own IOStack = IOStack();
    buf = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyBuffer_FillInfo(buf, NULL, ptr(start), len, 0, PyBUF_ND | PyBUF_WRITABLE)
        == -1 {
        return -1;
    }
    memobj = PyMemoryView_FromBuffer(buf);
    if not memobj {
        return -1;
    }

    while True {
        res = io_call_onearg(self_[0].raw, py_id(_Py_ID_readinto), memobj);
        if res or _PyIO_trap_eintr() == 0 {
            break;
        }
    }
    object_decref(memobj);
    if not res {
        return -1;
    }
    if res == Py_None {
        object_decref(res);
        return -2;
    }
    n = PyNumber_AsSsize_t(res, PyExc_ValueError);
    object_decref(res);

    if n == -1 and PyErr_Occurred() {
        _PyErr_FormatFromCause(PyExc_OSError, ptr[u8]("raw readinto() failed"));
        return -1;
    }

    if n < 0 or n > len {
        PyErr_Format(
            PyExc_OSError,
            ptr[u8](
                "raw readinto() returned invalid length %zd (should have been between 0 and %zd)"
            ),
            n,
            len
        );
        return -1;
    }
    if n > 0 and self_[0].abs_pos != -1 {
        self_[0].abs_pos += n;
    }
    return n;
}

impl _bufferedreader_fill_buffer(op: ptr[PyObject]) -> i64 {
    self_ = buffered_record(op).view(1);
    start: i64 = 0;
    if valid_read_buffer(op) {
        start = self_[0].read_end;
    }
    len = self_[0].buffer_size - start;
    n = _bufferedreader_raw_read(op, self_[0].buffer + start, len);
    if n <= 0 {
        return n;
    }
    self_[0].read_end = start + n;
    self_[0].raw_pos = start + n;
    return n;
}

impl read_all_done(
    res: ptr[PyObject], data: ptr[PyObject], tmp: ptr[PyObject], chunks: ptr[PyObject]
) -> ptr[PyObject] {
    object_xincref(res);
    object_xdecref(data);
    object_xdecref(tmp);
    object_xdecref(chunks);
    return res;
}

impl _bufferedreader_read_all(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    data: ptr[PyObject] = NULL;
    tmp: ptr[PyObject] = NULL;
    chunks: ptr[PyObject] = NULL;
    readall: ptr[PyObject] = NULL;

    current_size = readahead(op);
    if current_size != 0 {
        data = PyBytes_FromStringAndSize(self_[0].buffer + self_[0].pos, current_size);
        if not data {
            return NULL;
        }
        self_[0].pos += current_size;
    }

    if self_[0].writable != 0 {
        tmp = buffered_flush_and_rewind_unlocked(op);
        if not tmp {
            return read_all_done(NULL, data, tmp, chunks);
        }
        object_decref(tmp);
        tmp = NULL;
    }
    _bufferedreader_reset_buf(op);

    if PyObject_GetOptionalAttr(self_[0].raw, py_id(_Py_ID_readall), &mut readall)
        < 0 {
        return read_all_done(NULL, data, tmp, chunks);
    }
    if readall {
        tmp = PyObject_CallNoArgs(readall);
        object_decref(readall);
        if not tmp {
            return read_all_done(NULL, data, tmp, chunks);
        }
        if tmp != Py_None and not bytes_check(tmp) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("readall() should return bytes"));
            return read_all_done(NULL, data, tmp, chunks);
        }
        if current_size == 0 {
            return read_all_done(tmp, data, tmp, chunks);
        }
        if tmp != Py_None {
            PyBytes_Concat(&mut data, tmp);
        }
        return read_all_done(data, data, tmp, chunks);
    }

    chunks = PyList_New(0);
    if not chunks {
        return read_all_done(NULL, data, tmp, chunks);
    }

    while True {
        if data {
            if PyList_Append(chunks, data) < 0 {
                return read_all_done(NULL, data, tmp, chunks);
            }
            object_decref(data);
            data = NULL;
        }

        data = io_call_noargs(self_[0].raw, py_id(_Py_ID_read));
        if not data {
            return read_all_done(NULL, data, tmp, chunks);
        }
        if data != Py_None and not bytes_check(data) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("read() should return bytes"));
            return read_all_done(NULL, data, tmp, chunks);
        }
        if data == Py_None or object_size(data) == 0 {
            if current_size == 0 {
                return read_all_done(data, data, tmp, chunks);
            }
            tmp = PyBytes_Join(bytes_get_empty(), chunks);
            return read_all_done(tmp, data, tmp, chunks);
        }
        current_size += object_size(data);
        if self_[0].abs_pos != -1 {
            self_[0].abs_pos += object_size(data);
        }
    }
    return NULL;
}

impl _bufferedreader_read_fast(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    current_size = readahead(op);
    if n <= current_size {
        res = PyBytes_FromStringAndSize(self_[0].buffer + self_[0].pos, n);
        if res {
            self_[0].pos += n;
        }
        return res;
    }
    return object_new_ref(Py_None);
}

impl _bufferedreader_read_generic(op: ptr[PyObject], n: i64) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);

    current_size = readahead(op);
    if n <= current_size {
        return _bufferedreader_read_fast(op, n);
    }

    res = PyBytes_FromStringAndSize(ptr[u8](), n);
    if not res {
        return NULL;
    }
    out = bytes_data(res);
    remaining = n;
    written: i64 = 0;
    if current_size > 0 {
        memcpy(ptr(out), ptr(self_[0].buffer + self_[0].pos), u64(current_size));
        remaining -= current_size;
        written += current_size;
        self_[0].pos += current_size;
    }

    if self_[0].writable != 0 {
        flushed = buffered_flush_and_rewind_unlocked(op);
        if not flushed {
            object_decref(res);
            return NULL;
        }
        object_decref(flushed);
    }
    _bufferedreader_reset_buf(op);
    while remaining > 0 {
        r = minus_last_block(op, remaining);
        if r == 0 {
            break;
        }
        r = _bufferedreader_raw_read(op, out + written, r);
        if r == -1 {
            object_decref(res);
            return NULL;
        }
        if r == 0 or r == -2 {
            if r == 0 or written > 0 {
                if _PyBytes_Resize(&mut res, written) != 0 {
                    return NULL;
                }
                return res;
            }
            object_decref(res);
            return object_new_ref(Py_None);
        }
        remaining -= r;
        written += r;
    }
    self_[0].pos = 0;
    self_[0].raw_pos = 0;
    self_[0].read_end = 0;

    while remaining > 0 and self_[0].read_end < self_[0].buffer_size {
        r = _bufferedreader_fill_buffer(op);
        if r == -1 {
            object_decref(res);
            return NULL;
        }
        if r == 0 or r == -2 {
            if r == 0 or written > 0 {
                if _PyBytes_Resize(&mut res, written) != 0 {
                    return NULL;
                }
                return res;
            }
            object_decref(res);
            return object_new_ref(Py_None);
        }
        if remaining > r {
            memcpy(ptr(out + written), ptr(self_[0].buffer + self_[0].pos), u64(r));
            written += r;
            self_[0].pos += r;
            remaining -= r;
        } elif remaining > 0 {
            memcpy(
                ptr(out + written), ptr(self_[0].buffer + self_[0].pos), u64(remaining)
            );
            written += remaining;
            self_[0].pos += remaining;
            remaining = 0;
        }
        if remaining == 0 {
            break;
        }
    }

    return res;
}

impl _bufferedreader_peek_unlocked(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);

    have = readahead(op);

    if have > 0 {
        return PyBytes_FromStringAndSize(self_[0].buffer + self_[0].pos, have);
    }

    _bufferedreader_reset_buf(op);
    r = _bufferedreader_fill_buffer(op);
    if r == -1 {
        return NULL;
    }
    if r == -2 {
        r = 0;
    }
    self_[0].pos = 0;
    return PyBytes_FromStringAndSize(self_[0].buffer, r);
}

impl _bufferedwriter_reset_buf(op: ptr[PyObject]) {
    self_ = buffered_record(op).view(1);
    self_[0].write_pos = 0;
    self_[0].write_end = -1;
}

impl _io_BufferedWriter___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32 {
    self_ = buffered_record(op).view(1);
    self_[0].ok = 0;
    self_[0].detached = 0;

    state = find_io_state_by_def(object_type(op));
    if not _PyIOBase_check_writable(state, raw, io_true()) {
        return -1;
    }

    py_xsetref(field_slot(op, BUFFERED_RAW), object_new_ref(raw));
    self_[0].readable = 0;
    self_[0].writable = 1;

    self_[0].buffer_size = buffer_size;
    if _buffered_init(op) < 0 {
        return -1;
    }
    _bufferedwriter_reset_buf(op);
    self_[0].pos = 0;

    fast = object_is_type(op, state.view(1)[0].PyBufferedWriter_Type)
        and object_is_type(raw, state.view(1)[0].PyFileIO_Type);
    self_[0].fast_closed_checks = i32(1) if fast else i32(0);

    self_[0].ok = 1;
    return 0;
}

impl _bufferedwriter_raw_write(op: ptr[PyObject], start: ptr[u8], len: i64) -> i64 {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;
    errnum: i64 = 0;

    slots: own IOStack = IOStack();
    buf = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyBuffer_FillInfo(buf, NULL, ptr(start), len, 1, PyBUF_ND) == -1 {
        return -1;
    }
    memobj = PyMemoryView_FromBuffer(buf);
    if not memobj {
        return -1;
    }

    while True {
        jacpy_set_errno(0);
        res = io_call_onearg(self_[0].raw, py_id(_Py_ID_write), memobj);
        errnum = jacpy_errno();
        if res or _PyIO_trap_eintr() == 0 {
            break;
        }
    }
    object_decref(memobj);
    if not res {
        return -1;
    }
    if res == Py_None {
        object_decref(res);
        jacpy_set_errno(errnum);
        return -2;
    }
    n = PyNumber_AsSsize_t(res, PyExc_ValueError);
    object_decref(res);
    if n < 0 or n > len {
        PyErr_Format(
            PyExc_OSError,
            ptr[u8](
                "raw write() returned invalid length %zd (should have been between 0 and %zd)"
            ),
            n,
            len
        );
        return -1;
    }
    if n > 0 and self_[0].abs_pos != -1 {
        self_[0].abs_pos += n;
    }
    return n;
}

impl _bufferedwriter_flush_unlocked(op: ptr[PyObject]) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);

    if valid_write_buffer(op) and self_[0].write_pos != self_[0].write_end {
        rewind = raw_offset(op) + (self_[0].pos - self_[0].write_pos);
        if rewind != 0 {
            n = _buffered_raw_seek(op, -rewind, 1);
            if n < 0 {
                return NULL;
            }
            self_[0].raw_pos -= rewind;
        }
        while self_[0].write_pos < self_[0].write_end {
            n = _bufferedwriter_raw_write(
                op,
                self_[0].buffer + self_[0].write_pos,
                self_[0].write_end - self_[0].write_pos
            );
            if n == -1 {
                return NULL;
            } elif n == -2 {
                _set_BlockingIOError(
                    ptr[u8]("write could not complete without blocking"), 0
                );
                return NULL;
            }
            self_[0].write_pos += n;
            self_[0].raw_pos = self_[0].write_pos;

            if PyErr_CheckSignals() < 0 {
                return NULL;
            }
        }
    }

    _bufferedwriter_reset_buf(op);
    return object_new_ref(Py_None);
}

impl bufferedwriter_write_data(
    op: ptr[PyObject], buf: ptr[u8], length: i64
) -> ptr[PyObject] {
    self_ = buffered_record(op).view(1);
    res: ptr[PyObject] = NULL;
    written: i64 = 0;

    if not check_initialized(op) {
        return NULL;
    }

    if not enter_buffered(op) {
        return NULL;
    }

    if is_closed(op) != 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("write to closed file"));
        leave_buffered(op);
        return NULL;
    }

    if not valid_read_buffer(op) and not valid_write_buffer(op) {
        self_[0].pos = 0;
        self_[0].raw_pos = 0;
    }
    avail = self_[0].buffer_size - self_[0].pos;
    if length <= avail and length < self_[0].buffer_size {
        memcpy(ptr(self_[0].buffer + self_[0].pos), ptr(buf), u64(length));
        if not valid_write_buffer(op) or self_[0].write_pos > self_[0].pos {
            self_[0].write_pos = self_[0].pos;
        }
        adjust_position(op, self_[0].pos + length);
        if self_[0].pos > self_[0].write_end {
            self_[0].write_end = self_[0].pos;
        }
        res = PyLong_FromSsize_t(length);
        leave_buffered(op);
        return res;
    }

    res = _bufferedwriter_flush_unlocked(op);
    if not res {
        if not _buffered_check_blocking_error() {
            leave_buffered(op);
            return NULL;
        }
        if self_[0].readable != 0 {
            _bufferedreader_reset_buf(op);
        }

        memmove(
            ptr(self_[0].buffer),
            ptr(self_[0].buffer + self_[0].write_pos),
            u64(self_[0].write_end - self_[0].write_pos)
        );
        self_[0].write_end -= self_[0].write_pos;
        self_[0].raw_pos -= self_[0].write_pos;
        self_[0].pos -= self_[0].write_pos;
        self_[0].write_pos = 0;
        avail = self_[0].buffer_size - self_[0].write_end;
        if length <= avail {
            PyErr_Clear();
            memcpy(ptr(self_[0].buffer + self_[0].write_end), ptr(buf), u64(length));
            self_[0].write_end += length;
            self_[0].pos += length;
            res = PyLong_FromSsize_t(length);
            leave_buffered(op);
            return res;
        }

        memcpy(ptr(self_[0].buffer + self_[0].write_end), ptr(buf), u64(avail));
        self_[0].write_end += avail;
        self_[0].pos += avail;

        _set_BlockingIOError(
            ptr[u8]("write could not complete without blocking"), avail
        );
        leave_buffered(op);
        return NULL;
    }
    object_decref(res);
    res = NULL;

    offset = raw_offset(op);
    if offset != 0 {
        if _buffered_raw_seek(op, -offset, 1) < 0 {
            leave_buffered(op);
            return NULL;
        }
        self_[0].raw_pos -= offset;
    }

    remaining = length;
    written = 0;
    while remaining >= self_[0].buffer_size {
        n = _bufferedwriter_raw_write(op, buf + written, length - written);
        if n == -1 {
            leave_buffered(op);
            return NULL;
        } elif n == -2 {
            if remaining > self_[0].buffer_size {
                memcpy(
                    ptr(self_[0].buffer), ptr(buf + written), u64(self_[0].buffer_size)
                );
                self_[0].raw_pos = 0;
                adjust_position(op, self_[0].buffer_size);
                self_[0].write_end = self_[0].buffer_size;
                written += self_[0].buffer_size;
                _set_BlockingIOError(
                    ptr[u8]("write could not complete without blocking"), written
                );
                leave_buffered(op);
                return NULL;
            }
            PyErr_Clear();
            break;
        }
        written += n;
        remaining -= n;

        if PyErr_CheckSignals() < 0 {
            leave_buffered(op);
            return NULL;
        }
    }
    if self_[0].readable != 0 {
        _bufferedreader_reset_buf(op);
    }
    if remaining > 0 {
        memcpy(ptr(self_[0].buffer), ptr(buf + written), u64(remaining));
        written += remaining;
    }
    self_[0].write_pos = 0;

    self_[0].write_end = remaining;
    adjust_position(op, remaining);
    self_[0].raw_pos = 0;

    res = PyLong_FromSsize_t(written);
    leave_buffered(op);
    return res;
}

impl _io_BufferedWriter_write_impl(
    op: ptr[PyObject], buffer: BufferArgument
) -> ptr[PyObject] {
    return bufferedwriter_write_data(op, ptr[u8](buffer.address()), buffer.size());
}

impl rwpair_record(op: ptr[PyObject]) -> ptr[rwpair] {
    return ptr[rwpair](op);
}

impl _io_BufferedRWPair___init___impl(
    op: ptr[PyObject], reader: ptr[PyObject], writer: ptr[PyObject], buffer_size: i64
) -> i32 {
    self_ = rwpair_record(op).view(1);
    state = find_io_state_by_def(object_type(op));
    if not _PyIOBase_check_readable(state, reader, io_true()) {
        return -1;
    }
    if not _PyIOBase_check_writable(state, writer, io_true()) {
        return -1;
    }

    size_obj = PyLong_FromSsize_t(buffer_size);
    if not size_obj {
        return -1;
    }
    self_[0].reader = io_call_function(
        ptr[PyObject](state.view(1)[0].PyBufferedReader_Type),
        reader,
        size_obj,
        NULL,
        NULL,
        2
    );
    if not self_[0].reader {
        object_decref(size_obj);
        return -1;
    }

    self_[0].writer = io_call_function(
        ptr[PyObject](state.view(1)[0].PyBufferedWriter_Type),
        writer,
        size_obj,
        NULL,
        NULL,
        2
    );
    object_decref(size_obj);
    if not self_[0].writer {
        py_clear(field_slot(op, RWPAIR_READER));
        return -1;
    }

    return 0;
}

impl bufferedrwpair_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = rwpair_record(op).view(1);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].dict, visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_[0].reader, visitor, arg);
    if status != 0 {
        return status;
    }
    return visit_reference(self_[0].writer, visitor, arg);
}

impl bufferedrwpair_clear(op: ptr[PyObject]) -> i32 {
    py_clear(field_slot(op, RWPAIR_READER));
    py_clear(field_slot(op, RWPAIR_WRITER));
    py_clear(field_slot(op, RWPAIR_DICT));
    return 0;
}

impl bufferedrwpair_dealloc(op: ptr[PyObject]) {
    tp = object_type(op);
    object_gc_untrack(op);
    if rwpair_record(op).view(1)[0].weakreflist {
        PyObject_ClearWeakRefs(op);
    }
    bufferedrwpair_clear(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl _forward_call(
    target: ptr[PyObject], name: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    if not target {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("I/O operation on uninitialized object")
        );
        return NULL;
    }

    func = PyObject_GetAttr(target, name);
    if not func {
        PyErr_SetObject(PyExc_AttributeError, name);
        return NULL;
    }

    ret = PyObject_CallObject(func, args);
    object_decref(func);
    return ret;
}

impl bufferedrwpair_read(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_read), args);
}

impl bufferedrwpair_peek(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_peek), args);
}

impl bufferedrwpair_read1(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_read1), args
    );
}

impl bufferedrwpair_readinto(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_readinto), args
    );
}

impl bufferedrwpair_readinto1(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_readinto1), args
    );
}

impl bufferedrwpair_write(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].writer, py_id(_Py_ID_write), args
    );
}

impl bufferedrwpair_flush(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].writer, py_id(_Py_ID_flush), NULL
    );
}

impl bufferedrwpair_readable(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].reader, py_id(_Py_ID_readable), NULL
    );
}

impl bufferedrwpair_writable(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return _forward_call(
        rwpair_record(op).view(1)[0].writer, py_id(_Py_ID_writable), NULL
    );
}

impl bufferedrwpair_close(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    self_ = rwpair_record(op).view(1);
    exc: ptr[PyObject] = NULL;
    ret = _forward_call(self_[0].writer, py_id(_Py_ID_close), NULL);
    if not ret {
        exc = PyErr_GetRaisedException();
    } else {
        object_decref(ret);
    }
    ret = _forward_call(self_[0].reader, py_id(_Py_ID_close), NULL);
    if exc {
        _PyErr_ChainExceptions1(exc);
        object_xdecref(ret);
        ret = NULL;
    }
    return ret;
}

impl bufferedrwpair_isatty(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    self_ = rwpair_record(op).view(1);
    ret = _forward_call(self_[0].writer, py_id(_Py_ID_isatty), NULL);

    if ret != io_false() {
        return ret;
    }
    object_decref(ret);

    return _forward_call(self_[0].reader, py_id(_Py_ID_isatty), NULL);
}

impl bufferedrwpair_closed_get(op: ptr[PyObject], dummy: ptr) -> ptr[PyObject] {
    writer = rwpair_record(op).view(1)[0].writer;
    if not writer {
        PyErr_SetString(
            PyExc_RuntimeError,
            ptr[u8]("the BufferedRWPair object is being garbage-collected")
        );
        return NULL;
    }
    return PyObject_GetAttr(writer, py_id(_Py_ID_closed));
}

impl _io_BufferedRandom___init___impl(
    op: ptr[PyObject], raw: ptr[PyObject], buffer_size: i64
) -> i32 {
    self_ = buffered_record(op).view(1);
    self_[0].ok = 0;
    self_[0].detached = 0;

    state = find_io_state_by_def(object_type(op));
    if not _PyIOBase_check_seekable(state, raw, io_true()) {
        return -1;
    }
    if not _PyIOBase_check_readable(state, raw, io_true()) {
        return -1;
    }
    if not _PyIOBase_check_writable(state, raw, io_true()) {
        return -1;
    }

    py_xsetref(field_slot(op, BUFFERED_RAW), object_new_ref(raw));
    self_[0].buffer_size = buffer_size;
    self_[0].readable = 1;
    self_[0].writable = 1;

    if _buffered_init(op) < 0 {
        return -1;
    }
    _bufferedreader_reset_buf(op);
    _bufferedwriter_reset_buf(op);
    self_[0].pos = 0;

    fast = object_is_type(op, state.view(1)[0].PyBufferedRandom_Type)
        and object_is_type(raw, state.view(1)[0].PyFileIO_Type);
    self_[0].fast_closed_checks = i32(1) if fast else i32(0);

    self_[0].ok = 1;
    return 0;
}

impl bufferedwriter_write_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(arg, view, PyBUF_SIMPLE) == 0 {
        res = bufferedwriter_write_data(
            receiver, ptr[u8](view.view(1)[0].buf), view.view(1)[0].length
        );
        PyBuffer_Release(view);
        return res;
    }
    PyErr_Clear();
    return addressof(bufferedwriter_write_glue).view(1)[0].call(receiver, arg);
}

impl buffered_readinto_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(arg, view, PyBUF_WRITABLE) == 0 {
        res = _buffered_readinto_generic(
            receiver, ptr[u8](view.view(1)[0].buf), view.view(1)[0].length, False
        );
        PyBuffer_Release(view);
        return res;
    }
    PyErr_Clear();
    return addressof(buffered_readinto_glue).view(1)[0].call(receiver, arg);
}

impl buffered_readinto1_fast(
    receiver: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    view = ptr[Py_buffer](jacpy_stack_address(&mut slots));
    if PyObject_GetBuffer(arg, view, PyBUF_WRITABLE) == 0 {
        res = _buffered_readinto_generic(
            receiver, ptr[u8](view.view(1)[0].buf), view.view(1)[0].length, True
        );
        PyBuffer_Release(view);
        return res;
    }
    PyErr_Clear();
    return addressof(buffered_readinto1_glue).view(1)[0].call(receiver, arg);
}

impl buffered_read_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io__Buffered_read_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(buffered_read_glue).view(1)[0].call(receiver, args, nargs);
}

impl buffered_readline_fast(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    (status, size) = io_fast_size(args, nargs);
    if status > 0 {
        return _io__Buffered_readline_impl(receiver, size);
    }
    if status < 0 {
        return NULL;
    }
    return addressof(buffered_readline_glue).view(1)[0].call(receiver, args, nargs);
}

impl buffered_methods(names: list[str]) -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    for name in names {
        selected = io_select_methods(
            BufferedWriter_methods if name == "write" else _Buffered_methods, [name]
        );
        for method in selected {
            callbacks = method.callbacks;
            if method.name == "write" {
                addressof(bufferedwriter_write_glue).view(1)[0].call = method.callbacks.positional;
                callbacks = MethodCallbacks(positional=bufferedwriter_write_fast);
            } elif method.name == "readinto" {
                addressof(buffered_readinto_glue).view(1)[0].call = method.callbacks.positional;
                callbacks = MethodCallbacks(positional=buffered_readinto_fast);
            } elif method.name == "readinto1" {
                addressof(buffered_readinto1_glue).view(1)[0].call = method.callbacks.positional;
                callbacks = MethodCallbacks(positional=buffered_readinto1_fast);
            } elif method.name == "read" {
                addressof(buffered_read_glue).view(1)[0].call = method.callbacks.fast;
                callbacks = MethodCallbacks(fast=buffered_read_fast);
            } elif method.name == "readline" {
                addressof(buffered_readline_glue).view(1)[0].call = method.callbacks.fast;
                callbacks = MethodCallbacks(fast=buffered_readline_fast);
            }
            methods.append(
                MethodDefinition(method.name, callbacks, method.doc, method.flags)
            );
        }
    }
    methods.append(
        MethodDefinition(
            "__getstate__",
            MethodCallbacks(positional=_PyIOBase_cannot_pickle),
            "",
            i64(METH_NOARGS)
        )
    );
    return methods;
}

impl install_buffered_tables -> bool {
    base_methods = io_select_methods(
        _BufferedIOBase_methods,
        ["detach", "read", "read1", "readinto", "readinto1", "write"]
    );
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(bufferediobase_slots)),
        base_methods,
        [],
        bufferediobase_doc
    ) {
        return False;
    }
    getset = io_select_properties(_Buffered_getset, ["closed", "name", "mode"]);
    reader_methods = buffered_methods(
        [
            "detach",
            "flush",
            "close",
            "seekable",
            "readable",
            "fileno",
            "isatty",
            "_dealloc_warn",
            "read",
            "peek",
            "read1",
            "readinto",
            "readinto1",
            "readline",
            "seek",
            "tell",
            "truncate",
            "__sizeof__"
        ]
    );
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(bufferedreader_slots)),
        reader_methods,
        getset,
        BufferedReader_doc
    ) {
        return False;
    }
    writer_methods = buffered_methods(
        [
            "close",
            "detach",
            "seekable",
            "writable",
            "fileno",
            "isatty",
            "_dealloc_warn",
            "write",
            "truncate",
            "flush#2",
            "seek",
            "tell",
            "__sizeof__"
        ]
    );
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(bufferedwriter_slots)),
        writer_methods,
        getset,
        BufferedWriter_doc
    ) {
        return False;
    }
    random_methods = buffered_methods(
        [
            "close",
            "detach",
            "seekable",
            "readable",
            "writable",
            "fileno",
            "isatty",
            "_dealloc_warn",
            "flush#2",
            "seek",
            "tell",
            "truncate",
            "read",
            "read1",
            "readinto",
            "readinto1",
            "readline",
            "peek",
            "write",
            "__sizeof__"
        ]
    );
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(bufferedrandom_slots)),
        random_methods,
        getset,
        BufferedRandom_doc
    ) {
        return False;
    }
    if not io_fill_slots(
        ptr[PyType_Slot](addressof(bufferedrwpair_slots)), [], [], BufferedRWPair_doc
    ) {
        return False;
    }
    _BufferedIOBase_token.handle = ptr(addressof(bufferediobase_spec));
    _Buffered_token.handle = ptr(addressof(bufferedreader_spec));
    _Buffered_token.share(ptr(addressof(bufferedreader_spec)));
    _Buffered_token.share(ptr(addressof(bufferedwriter_spec)));
    _Buffered_token.share(ptr(addressof(bufferedrandom_spec)));
    BufferedRWPair_token.handle = ptr(addressof(bufferedrwpair_spec));
    return True;
}
