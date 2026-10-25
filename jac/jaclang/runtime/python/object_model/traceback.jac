import from c {
    def _PyObject_CallMethod(
        obj_: ptr[PyObject], name: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PyObject_CallMethodFormat(
        tstate: ptr[PyThreadState], callable: ptr[PyObject], format: ptr[u8], *args: any
    ) -> ptr[PyObject];  def _PySys_GetOptionalAttr(
        name: ptr[PyObject], value: &mut ptr[PyObject]
    ) -> i32;  def _PyTokenizer_FindEncodingFilename(
        fd: i32, filename: ptr[PyObject]
    ) -> ptr[u8];  def PyGILState_GetThisThreadState -> ptr[PyThreadState];  def _PyGILState_GetInterpreterStateUnsafe -> ptr[
        u8
    ];  def PyInterpreterState_ThreadHead(interp: ptr[u8]) -> ptr[PyThreadState];  def PyThreadState_Next(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyThreadState];  def strrchr(text: ptr[u8], character: i32) -> ptr[u8];  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def strcpy(target: ptr[u8], source: ptr[u8]) -> ptr[u8];  def lseek(
        fd: i32, offset: i64, whence: i32
    ) -> i64;  def pthread_getname_np(thread: u64, name: ptr[u8], len: u64) -> i32;  def backtrace(
        buffer: ptr, size: i32
    ) -> i32;  obj TracebackStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0,
            w18: u64 = 0,
            w19: u64 = 0,
            w20: u64 = 0,
            w21: u64 = 0,
            w22: u64 = 0,
            w23: u64 = 0,
            w24: u64 = 0,
            w25: u64 = 0,
            w26: u64 = 0,
            w27: u64 = 0,
            w28: u64 = 0,
            w29: u64 = 0,
            w30: u64 = 0,
            w31: u64 = 0;
    }  def jacpy_stack_address(slots: &mut TracebackStack) -> int;  obj DlInfo {
        has dli_fname: ptr[u8] = ptr[u8](),
            dli_fbase: ptr = ptr(),
            dli_sname: ptr[u8] = ptr[u8](),
            dli_saddr: ptr = ptr();
    }  glob Py_hexdigits: ptr[u8]; glob:priv tb_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("__dir__"),
                 ml_meth=ptr(tb_dir),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         tb_memberlist: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("tb_frame"),
                 type_=_Py_T_OBJECT,
                 offset=PyTracebackObject_TB_FRAME,
                 flags=Py_READONLY | Py_AUDIT_READ
             ),
             PyMemberDef(
                 name=ptr[u8]("tb_lasti"),
                 type_=Py_T_INT,
                 offset=PyTracebackObject_TB_LASTI,
                 flags=Py_READONLY
             ),
             PyMemberDef()
         ],
         tb_getsetters: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("tb_next"),
                 get=traceback_tb_next_get,
                 set=traceback_tb_next_set
             ),
             PyGetSetDef(name=ptr[u8]("tb_lineno"), get=tb_lineno_get),
             PyGetSetDef()
         ]; glob PyTraceBack_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("traceback"),
             tp_basicsize=PyTracebackObject_SIZE,
             tp_dealloc=tb_dealloc,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8](
                 "traceback(tb_next, tb_frame, tb_lasti, tb_lineno)\n--\n\n"
                 "Create a new traceback object."
             ),
             tp_traverse=tb_traverse,
             tp_clear=tb_clear,
             tp_methods=addressof(tb_methods),
             tp_members=addressof(tb_memberlist),
             tp_getset=addressof(tb_getsetters),
             tp_new=tb_new
         );
}

glob:priv MAX_STRING_LENGTH: Final[i64] = 500,
     MAX_FRAME_DEPTH: Final[u32] = 100,
     MAX_NTHREADS: Final[u32] = 100,
     TB_RECURSIVE_CUTOFF: Final[i64] = 3,
     PyTraceBack_LIMIT: Final[i64] = 1000,
     LONG_MAX: Final[i64] = 0x7FFFFFFFFFFFFFFF,
     SEP: Final[u8] = 47,
     TRACEBACK_SOURCE_LINE_INDENT: Final[i32] = 4,
     BACKTRACE_SIZE: Final[i32] = 32;

glob:priv tb_new_signature = CallSignature(
         "traceback",
         ["tb_next", "tb_frame", "tb_lasti", "tb_lineno"],
         4,
         4,
         0,
         parser=PARSE_KEYWORDS
     );

def traceback_check(op: ptr[PyObject]) -> bool;

def tb_next_of(tb: ptr[PyObject]) -> ptr[PyObject];

def tb_slot(tb: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]];

def tb_frame_of(tb: ptr[PyObject]) -> ptr[PyObject];

def tb_int(tb: ptr[PyObject], offset: i64) -> i32;

def puts(fd: i32, text: ptr[u8]);

def tb_create_raw(
    next_tb: ptr[PyObject], frame: ptr[PyObject], lasti: i32, lineno: i32
) -> ptr[PyObject];

def tb_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def tb_new_bound(args: BoundArguments) -> ptr[PyObject];

def tb_new_impl(
    type: ptr[PyTypeObject],
    tb_next_in: ptr[PyObject],
    tb_frame: ptr[PyObject],
    tb_lasti: i32,
    tb_lineno: i32
) -> ptr[PyObject];

def tb_dir(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def traceback_tb_next_get(self_: ptr[PyObject], context: ptr) -> ptr[PyObject];

def tb_get_lineno(op: ptr[PyObject]) -> i32;

def tb_lineno_get(op: ptr[PyObject], ignored: ptr) -> ptr[PyObject];

def traceback_tb_next_set(
    self_: ptr[PyObject], value_in: ptr[PyObject], context: ptr
) -> i32;

def tb_dealloc(op: ptr[PyObject]);

def tb_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def tb_clear(op: ptr[PyObject]) -> i32;

def call_method_noargs(obj_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def _Py_FindSourceFile(
    filename: ptr[PyObject], namebuf: ptr[u8], namelen: i64, io: ptr[PyObject]
) -> ptr[PyObject];

def display_source_line(
    f: ptr[PyObject], filename: ptr[PyObject], lineno: i32, indent: i32
) -> tuple[i32, bool, i32, ptr[PyObject]];

def ignore_source_errors -> i32;

def tb_displayline(
    tb: ptr[PyObject],
    f: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    frame: ptr[PyObject],
    name: ptr[PyObject]
) -> i32;

def tb_print_line_repeated(f: ptr[PyObject], cnt_in: i64) -> i32;

def tb_printinternal(tb_in: ptr[PyObject], f: ptr[PyObject], limit: i64) -> i32;

def dump_hexadecimal(fd: i32, value_in: u64, width_in: i64, strip_zeros: bool);

def dump_pointer(fd: i32, address: ptr);

def dump_char(fd: i32, ch: u8);

def is_ulong_freed(value: u64) -> bool;

def frame_safe_get_code(f: ptr[u8]) -> ptr[PyObject];

def frame_safe_get_lasti(f: ptr[u8]) -> i32;

def dump_frame(fd: i32, frame: ptr[u8]) -> i32;

def tstate_thread_id(tstate: ptr[PyThreadState]) -> u64;

def tstate_is_freed(tstate: ptr[PyThreadState]) -> bool;

def dump_traceback(fd: i32, tstate: ptr[PyThreadState], write_header: bool);

def write_thread_name(fd: i32, tstate: ptr[PyThreadState]);

def write_thread_id(fd: i32, tstate: ptr[PyThreadState], is_current: bool);

def backtrace_symbol(fd: i32, address: ptr);

import from c {
    def _PyTraceBack_FromFrame(
        tb_next: ptr[PyObject], frame: ptr[PyObject]
    ) -> ptr[PyObject] {
        iframe = ptr[ptr[u8]](ptr[u8](frame) + PyFrameObject_F_FRAME).view(1)[0];
        addr = i32.wrap(i64(iframe_lasti(iframe)) * 2);
        return tb_create_raw(tb_next, frame, addr, i32(-1));
    }  def PyTraceBack_Here(frame: ptr[PyObject]) -> i32 {
        exc = PyErr_GetRaisedException();
        tb = PyException_GetTraceback(exc);
        newtb = _PyTraceBack_FromFrame(tb, frame);
        object_xdecref(tb);
        if not newtb {
            _PyErr_ChainExceptions1(exc);
            return i32(-1);
        }
        PyException_SetTraceback(exc, newtb);
        object_xdecref(newtb);
        PyErr_SetRaisedException(exc);
        return i32(0);
    }  def _PyTraceback_Add(funcname: ptr[u8], filename: ptr[u8], lineno: i32) {
        tstate = thread_state();

        exc = _PyErr_GetRaisedException(tstate);
        globals = PyDict_New();
        if not globals {
            _PyErr_ChainExceptions1(exc);
            return;
        }
        code = PyCode_NewEmpty(filename, funcname, lineno);
        if not code {
            object_decref(globals);
            _PyErr_ChainExceptions1(exc);
            return;
        }
        frame = PyFrame_New(ptr[u8](tstate), code, globals, NULL);
        object_decref(globals);
        object_decref(code);
        if not frame {
            _PyErr_ChainExceptions1(exc);
            return;
        }
        ptr[i32](ptr[u8](frame) + PyFrameObject_LINENO).view(1)[0] = lineno;
        _PyErr_SetRaisedException(tstate, exc);
        PyTraceBack_Here(frame);
        object_decref(frame);
    }  def _Py_WriteIndent(indent_in: i32, f: ptr[PyObject]) -> i32 {
        spaces = ptr[u8]("          ");
        indent = indent_in;
        while indent > i32(0) {
            text = spaces;
            if indent < i32(10) {
                text = spaces + (10 - i64(indent));
            }
            if PyFile_WriteString(text, f) < i32(0) {
                return i32(-1);
            }
            indent -= i32(10);
        }
        return i32(0);
    }  def _Py_DisplaySourceLine(
        f: ptr[PyObject],
        filename: ptr[PyObject],
        lineno: i32,
        indent: i32,
        truncation: ptr[i32],
        line: ptr[ptr[PyObject]]
    ) -> i32 {
        (rc, has_truncation, truncated, source_line) = display_source_line(
            f, filename, lineno, indent
        );
        if line {
            if source_line {
                line.view(1)[0] = source_line;
            }
        } else {
            object_xdecref(source_line);
        }
        if truncation and has_truncation {
            truncation.view(1)[0] = truncated;
        }
        return rc;
    }  def _PyTraceBack_Print(
        v: ptr[PyObject], header: ptr[u8], f: ptr[PyObject]
    ) -> i32 {
        limit: i64 = PyTraceBack_LIMIT;
        if not v {
            return i32(0);
        }
        if not traceback_check(v) {
            PyErr_BadInternalCall();
            return i32(-1);
        }
        limitv = NULL;
        if _PySys_GetOptionalAttrString(ptr[u8]("tracebacklimit"), &mut limitv)
            < i32(0) {
            return i32(-1);
        } elif limitv and long_check(limitv) {
            overflow = i32(0);
            limit = PyLong_AsLongAndOverflow(limitv, &mut overflow);
            if overflow > i32(0) {
                limit = LONG_MAX;
            } elif limit <= 0 {
                object_decref(limitv);
                return i32(0);
            }
        }
        object_xdecref(limitv);
        if PyFile_WriteString(header, f) < i32(0) {
            return i32(-1);
        }
        if tb_printinternal(v, f, limit) < i32(0) {
            return i32(-1);
        }
        return i32(0);
    }  def PyTraceBack_Print(v: ptr[PyObject], f: ptr[PyObject]) -> i32 {
        return _PyTraceBack_Print(
            v, ptr[u8]("Traceback (most recent call last):\n"), f
        );
    }  def _Py_DumpDecimal(fd: i32, value_in: u64) {
        slots: own TracebackStack = TracebackStack();
        buffer = ptr[u8](jacpy_stack_address(&mut slots));

        end = buffer + 20;
        p = end;
        p.view(1)[0] = u8(0);
        value = value_in;
        while True {
            p = p - 1;
            p.view(1)[0] = u8(48) + u8(value % u64(10));
            value = value // u64(10);
            if value == u64(0) {
                break;
            }
        }
        _Py_write_noraise(fd, ptr(p), u64(int(end) - int(p)));
    }  def _Py_DumpHexadecimal(fd: i32, value: u64, width: i64) {
        dump_hexadecimal(fd, value, width, False);
    }  def _Py_DumpASCII(fd: i32, text: ptr[PyObject]) {
        if not unicode_check(text) {
            return;
        }
        size = uo_length(text);
        kind = uo_kind(text);
        data = ptr[u8]();
        if uo_is_compact(text) {
            data = uo_compact_data(text);
        } else {
            data = uo_data_any(text);
            if not data {
                return;
            }
        }
        truncated = False;
        if MAX_STRING_LENGTH < size {
            size = MAX_STRING_LENGTH;
            truncated = True;
        }
        need_escape = True;

        if uo_is_ascii(text) {
            need_escape = False;
            i: i64 = 0;
            while i < size {
                byte = (data + i).view(1)[0];
                if not (u8(32) <= byte and byte <= u8(126)) {
                    need_escape = True;
                    break;
                }
                i += 1;
            }
            if not need_escape {
                _Py_write_noraise(fd, ptr(data), u64(size));
            }
        }
        if need_escape {
            j: i64 = 0;
            while j < size {
                ch = ch_read(kind, data, j);
                if u32(32) <= ch and ch <= u32(126) {
                    dump_char(fd, u8(ch));
                } elif ch <= u32(0xff) {
                    puts(fd, ptr[u8]("\\x"));
                    _Py_DumpHexadecimal(fd, u64(ch), 2);
                } elif ch <= u32(0xffff) {
                    puts(fd, ptr[u8]("\\u"));
                    _Py_DumpHexadecimal(fd, u64(ch), 4);
                } else {
                    puts(fd, ptr[u8]("\\U"));
                    _Py_DumpHexadecimal(fd, u64(ch), 8);
                }
                j += 1;
            }
        }
        if truncated {
            puts(fd, ptr[u8]("..."));
        }
    }  def _Py_DumpTraceback(fd: i32, tstate: ptr[PyThreadState]) {
        dump_traceback(fd, tstate, True);
    }  def _Py_DumpTracebackThreads(
        fd: i32, interp_in: ptr[u8], current_tstate_in: ptr[PyThreadState]
    ) -> ptr[u8] {
        current_tstate = current_tstate_in;
        interp = interp_in;
        if not current_tstate {
            current_tstate = PyGILState_GetThisThreadState();
        }
        if current_tstate and tstate_is_freed(current_tstate) {
            return ptr[u8]("tstate is freed");
        }
        if not interp {
            if not current_tstate {
                interp = _PyGILState_GetInterpreterStateUnsafe();
                if not interp {
                    return ptr[u8]("unable to get the interpreter state");
                }
            } else {
                interp = ptr[ptr[u8]](
                    ptr[u8](current_tstate) + PyThreadState_INTERP
                ).view(
                    1
                )[0];
            }
        }
        if is_ptr_freed(u64.wrap(int(interp))) {
            return ptr[u8]("interp is freed");
        }

        tstate = PyInterpreterState_ThreadHead(interp);
        if not tstate {
            return ptr[u8]("unable to get the thread head state");
        }

        nthreads = u32(0);
        while True {
            if nthreads != u32(0) {
                puts(fd, ptr[u8]("\n"));
            }
            if nthreads >= MAX_NTHREADS {
                puts(fd, ptr[u8]("...\n"));
                break;
            }
            if tstate_is_freed(tstate) {
                puts(fd, ptr[u8]("<freed thread state>\n"));
                break;
            }
            write_thread_id(fd, tstate, tstate == current_tstate);
            if tstate == current_tstate {
                tinterp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[
                    0
                ];
                collecting = ptr[i32](
                    tinterp + PyInterpreterState_GC + _gc_runtime_state_COLLECTING
                ).view(
                    1
                )[0];
                if collecting != i32(0) {
                    puts(fd, ptr[u8]("  Garbage-collecting\n"));
                }
            }
            dump_traceback(fd, tstate, False);
            tstate = PyThreadState_Next(tstate);
            nthreads = nthreads + u32(1);
            if not tstate {
                break;
            }
        }
        return ptr[u8]();
    }  def _Py_backtrace_symbols_fd(fd: i32, array: ptr[ptr], size: i64) {
        i: i64 = 0;
        while i < size {
            backtrace_symbol(fd, (array + i).view(1)[0]);
            i += 1;
        }
    }  def _Py_DumpStack(fd: i32) {
        puts(fd, ptr[u8]("Current thread's C stack trace (most recent call first):\n"));
        slots: own TracebackStack = TracebackStack();
        callstack = ptr[ptr](jacpy_stack_address(&mut slots));
        frames = backtrace(ptr(callstack), BACKTRACE_SIZE);
        if frames == i32(0) {
            puts(fd, ptr[u8]("  <system returned no stack trace>\n"));
            return;
        }
        _Py_backtrace_symbols_fd(fd, callstack, i64(frames));
        if frames == BACKTRACE_SIZE {
            puts(fd, ptr[u8]("  <truncated rest of calls>\n"));
        }
    }  def _Py_InitDumpStack {
        slots: own TracebackStack = TracebackStack();
        backtrace(ptr(jacpy_stack_address(&mut slots)), i32(1));
    }  def _Py_DumpTraceback_Init {
        return;
    }
}

impl traceback_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyTraceBack_Type));
}

impl tb_next_of(tb: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](tb) + PyTracebackObject_TB_NEXT).view(1)[0];
}

impl tb_slot(tb: ptr[PyObject], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](tb) + offset);
}

impl tb_frame_of(tb: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](tb) + PyTracebackObject_TB_FRAME).view(1)[0];
}

impl tb_int(tb: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](tb) + offset).view(1)[0];
}

impl puts(fd: i32, text: ptr[u8]) {
    _Py_write_noraise(fd, ptr(text), strlen(text));
}

impl tb_create_raw(
    next_tb: ptr[PyObject], frame: ptr[PyObject], lasti: i32, lineno: i32
) -> ptr[PyObject] {
    if (next_tb and not traceback_check(next_tb))
        or not frame
        or not object_is_type(frame, ptr[PyTypeObject](addressof(PyFrame_Type))) {
        PyErr_BadInternalCall();
        return NULL;
    }
    tb = _PyObject_GC_New(ptr[PyObject](addressof(PyTraceBack_Type)));
    if tb {
        tb_slot(tb, PyTracebackObject_TB_NEXT).view(1)[0] = object_xnewref(next_tb);
        tb_slot(tb, PyTracebackObject_TB_FRAME).view(1)[0] = object_xnewref(frame);
        ptr[i32](ptr[u8](tb) + PyTracebackObject_TB_LASTI).view(1)[0] = lasti;
        ptr[i32](ptr[u8](tb) + PyTracebackObject_TB_LINENO).view(1)[0] = lineno;
        object_gc_track(tb);
    }
    return tb;
}

impl tb_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke(tb_new_signature, args, kwargs, tb_new_bound, ptr[PyObject](type));
}

impl tb_new_bound(args: BoundArguments) -> ptr[PyObject] {
    tb_next = args.values[0];
    tb_frame = args.values[1];
    if not object_type_check(tb_frame, ptr[PyTypeObject](addressof(PyFrame_Type))) {
        _PyArg_BadArgument(
            ptr[u8]("traceback"),
            ptr[u8]("argument 'tb_frame'"),
            ptr[u8]("frame"),
            tb_frame
        );
        return NULL;
    }
    tb_lasti = PyLong_AsInt(args.values[2]);
    if tb_lasti == i32(-1) and PyErr_Occurred() {
        return NULL;
    }
    tb_lineno = PyLong_AsInt(args.values[3]);
    if tb_lineno == i32(-1) and PyErr_Occurred() {
        return NULL;
    }
    return tb_new_impl(
        ptr[PyTypeObject](args.context), tb_next, tb_frame, tb_lasti, tb_lineno
    );
}

impl tb_new_impl(
    type: ptr[PyTypeObject],
    tb_next_in: ptr[PyObject],
    tb_frame: ptr[PyObject],
    tb_lasti: i32,
    tb_lineno: i32
) -> ptr[PyObject] {
    tb_next = tb_next_in;
    if tb_next == Py_None {
        tb_next = NULL;
    } elif not traceback_check(tb_next) {
        return PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("expected traceback object or None, got '%s'"),
            object_type(tb_next).view(1)[0].tp_name
        );
    }
    return tb_create_raw(tb_next, tb_frame, tb_lasti, tb_lineno);
}

impl tb_dir(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue(
        ptr[u8]("[ssss]"),
        ptr[u8]("tb_frame"),
        ptr[u8]("tb_next"),
        ptr[u8]("tb_lasti"),
        ptr[u8]("tb_lineno")
    );
}

impl traceback_tb_next_get(self_: ptr[PyObject], context: ptr) -> ptr[PyObject] {
    ret = tb_next_of(self_);
    if not ret {
        ret = Py_None;
    }
    return object_new_ref(ret);
}

impl tb_get_lineno(op: ptr[PyObject]) -> i32 {
    frame = ptr[ptr[u8]](ptr[u8](tb_frame_of(op)) + PyFrameObject_F_FRAME).view(1)[0];
    return PyCode_Addr2Line(iframe_code(frame), tb_int(op, PyTracebackObject_TB_LASTI));
}

impl tb_lineno_get(op: ptr[PyObject], ignored: ptr) -> ptr[PyObject] {
    lineno = tb_int(op, PyTracebackObject_TB_LINENO);
    if lineno == i32(-1) {
        lineno = tb_get_lineno(op);
        if lineno < i32(0) {
            return object_new_ref(Py_None);
        }
    }
    return PyLong_FromLong(i64(lineno));
}

impl traceback_tb_next_set(
    self_: ptr[PyObject], value_in: ptr[PyObject], context: ptr
) -> i32 {
    value = value_in;
    if not value {
        PyErr_Format(PyExc_TypeError, ptr[u8]("can't delete tb_next attribute"));
        return i32(-1);
    }

    if value == Py_None {
        value = NULL;
    } elif not traceback_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("expected traceback object, got '%s'"),
            object_type(value).view(1)[0].tp_name
        );
        return i32(-1);
    }

    cursor = value;
    object_xincref(cursor);
    while cursor {
        if cursor == self_ {
            PyErr_Format(PyExc_ValueError, ptr[u8]("traceback loop detected"));
            object_decref(cursor);
            return i32(-1);
        }
        next_tb = tb_next_of(cursor);
        object_xincref(next_tb);
        old = cursor;
        cursor = next_tb;
        object_decref(old);
    }
    slot = tb_slot(self_, PyTracebackObject_TB_NEXT);
    old_next = slot.view(1)[0];
    slot.view(1)[0] = object_xnewref(value);
    object_xdecref(old_next);
    return i32(0);
}

impl tb_dealloc(op: ptr[PyObject]) {
    object_gc_untrack(op);
    object_xdecref(tb_next_of(op));
    object_xdecref(tb_frame_of(op));
    PyObject_GC_Del(ptr(op));
}

impl tb_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    vret = visit_reference(tb_next_of(op), visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    vret = visit_reference(tb_frame_of(op), visitor, arg);
    if vret != i32(0) {
        return vret;
    }
    return i32(0);
}

impl tb_clear(op: ptr[PyObject]) -> i32 {
    slot = tb_slot(op, PyTracebackObject_TB_NEXT);
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
    slot = tb_slot(op, PyTracebackObject_TB_FRAME);
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
    return i32(0);
}

impl call_method_noargs(obj_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    slots: own TracebackStack = TracebackStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = obj_;
    return PyObject_VectorcallMethod(
        name, stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl _Py_FindSourceFile(
    filename: ptr[PyObject], namebuf: ptr[u8], namelen: i64, io: ptr[PyObject]
) -> ptr[PyObject] {
    filebytes = PyUnicode_EncodeFSDefault(filename);
    if not filebytes {
        PyErr_Clear();
        return NULL;
    }
    filepath = PyBytes_AsString(filebytes);

    tail = strrchr(filepath, i32(SEP));
    if not tail {
        tail = filepath;
    } else {
        tail = tail + 1;
    }
    taillen = i64(strlen(tail));
    tstate = thread_state();
    syspath = NULL;
    open_fn = NULL;
    result = NULL;
    if _PySys_GetOptionalAttr(py_id(_Py_ID_path), &mut syspath) < i32(0) {
        PyErr_Clear();
    } elif syspath and list_check(syspath) {
        npath = PyList_Size(syspath);
        open_fn = PyObject_GetAttr(io, py_id(_Py_ID_open));
        if open_fn {
            i: i64 = 0;
            while i < npath {
                v = PyList_GetItem(syspath, i);
                i += 1;
                if not v {
                    PyErr_Clear();
                    break;
                }
                if not unicode_check(v) {
                    continue;
                }
                path = PyUnicode_EncodeFSDefault(v);
                if not path {
                    PyErr_Clear();
                    continue;
                }
                length = object_size(path);
                if length + 1 + taillen >= namelen - 1 {
                    object_decref(path);

                    continue;
                }
                strcpy(namebuf, PyBytes_AsString(path));
                object_decref(path);
                if i64(strlen(namebuf)) != length {
                    continue;
                }
                if length > 0 and (namebuf + length - 1).view(1)[0] != SEP {
                    (namebuf + length).view(1)[0] = SEP;
                    length += 1;
                }
                strcpy(namebuf + length, tail);
                binary = _PyObject_CallMethodFormat(
                    tstate, open_fn, ptr[u8]("ss"), namebuf, ptr[u8]("rb")
                );
                if binary {
                    result = binary;
                    break;
                }
                PyErr_Clear();
            }
        }
    }
    object_xdecref(open_fn);
    object_xdecref(syspath);
    object_decref(filebytes);
    return result;
}

impl display_source_line(
    f: ptr[PyObject], filename: ptr[PyObject], lineno: i32, indent: i32
) -> tuple[i32, bool, i32, ptr[PyObject]] {
    if not filename {
        return (i32(0), False, i32(0), NULL);
    }

    if uo_read_char(filename, 0) == u32(60) {
        length = unicode_length(filename);
        if length > 0 and uo_read_char(filename, length - 1) == u32(62) {
            return (i32(0), False, i32(0), NULL);
        }
    }
    io = PyImport_ImportModule(ptr[u8]("io"));
    if not io {
        return (i32(-1), False, i32(0), NULL);
    }
    binary = _PyObject_CallMethod(
        io, py_id(_Py_ID_open), ptr[u8]("Os"), filename, ptr[u8]("rb")
    );
    if not binary {
        PyErr_Clear();
        buf = ptr[u8](PyMem_Malloc(u64(MAXPATHLEN + 1)));
        if buf {
            binary = _Py_FindSourceFile(filename, buf, MAXPATHLEN + 1, io);
            PyMem_Free(ptr(buf));
        } else {
            PyErr_NoMemory();
        }
        if not binary {
            object_decref(io);
            return (i32(-1), False, i32(0), NULL);
        }
    }

    fd = PyObject_AsFileDescriptor(binary);
    if fd < i32(0) {
        object_decref(io);
        object_decref(binary);
        return (i32(0), False, i32(0), NULL);
    }
    found_encoding = _PyTokenizer_FindEncodingFilename(fd, filename);
    if not found_encoding {
        PyErr_Clear();
    }
    encoding = found_encoding or ptr[u8]("utf-8");

    if lseek(fd, 0, SEEK_SET) == -1 {
        object_decref(io);
        object_decref(binary);
        PyMem_Free(ptr(found_encoding));
        return (i32(0), False, i32(0), NULL);
    }
    fob = _PyObject_CallMethod(
        io, py_id(_Py_ID_TextIOWrapper), ptr[u8]("Os"), binary, encoding
    );
    object_decref(io);
    PyMem_Free(ptr(found_encoding));
    if not fob {
        PyErr_Clear();
        res = call_method_noargs(binary, py_id(_Py_ID_close));
        object_decref(binary);
        if res {
            object_decref(res);
        } else {
            PyErr_Clear();
        }
        return (i32(0), False, i32(0), NULL);
    }
    object_decref(binary);

    lineobj = NULL;
    i = i32(0);
    while i < lineno {
        object_xdecref(lineobj);
        lineobj = PyFile_GetLine(fob, i32(-1));
        if not lineobj {
            PyErr_Clear();
            break;
        }
        i += i32(1);
    }
    res = call_method_noargs(fob, py_id(_Py_ID_close));
    if res {
        object_decref(res);
    } else {
        PyErr_Clear();
    }
    object_decref(fob);
    if not lineobj or not unicode_check(lineobj) {
        object_xdecref(lineobj);
        return (i32(-1), False, i32(0), NULL);
    }
    line = object_new_ref(lineobj);

    n = unicode_length(lineobj);
    k: i64 = 0;
    while k < n {
        ch = uo_read_char(lineobj, k);
        if ch != u32(32) and ch != u32(9) and ch != u32(12) {
            break;
        }
        k += 1;
    }
    if k != 0 {
        truncated = PyUnicode_Substring(lineobj, k, unicode_length(lineobj));
        if truncated {
            old = lineobj;
            lineobj = truncated;
            object_decref(old);
        } else {
            PyErr_Clear();
        }
    }
    truncation = i32.wrap(k - i64(indent));

    if _Py_WriteIndent(indent, f) < i32(0)
        or PyFile_WriteObject(lineobj, f, Py_PRINT_RAW) < i32(0)
        or PyFile_WriteString(ptr[u8]("\n"), f) < i32(0) {
        object_decref(lineobj);
        return (i32(-1), True, truncation, line);
    }
    object_decref(lineobj);
    return (i32(0), True, truncation, line);
}

impl ignore_source_errors -> i32 {
    if PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_KeyboardInterrupt) != i32(0) {
            return i32(-1);
        }
        PyErr_Clear();
    }
    return i32(0);
}

impl tb_displayline(
    tb: ptr[PyObject],
    f: ptr[PyObject],
    filename: ptr[PyObject],
    lineno: i32,
    frame: ptr[PyObject],
    name: ptr[PyObject]
) -> i32 {
    if not filename or not name {
        return i32(-1);
    }
    line = PyUnicode_FromFormat(
        "  File \"%U\", line %d, in %U\n", filename, lineno, name
    );
    if not line {
        return i32(-1);
    }
    res = PyFile_WriteObject(line, f, Py_PRINT_RAW);
    object_decref(line);
    if res < i32(0) {
        return i32(-1);
    }
    err = i32(0);
    (rc, _has_truncation, _truncation, source_line) = display_source_line(
        f, filename, lineno, TRACEBACK_SOURCE_LINE_INDENT
    );
    if rc != i32(0) or not source_line {
        err = ignore_source_errors();
    }
    object_xdecref(source_line);
    return err;
}

impl tb_print_line_repeated(f: ptr[PyObject], cnt_in: i64) -> i32 {
    cnt = cnt_in - TB_RECURSIVE_CUTOFF;
    line = NULL;
    if cnt > 1 {
        line = PyUnicode_FromFormat("  [Previous line repeated %ld more times]\n", cnt);
    } else {
        line = PyUnicode_FromFormat("  [Previous line repeated %ld more time]\n", cnt);
    }
    if not line {
        return i32(-1);
    }
    err = PyFile_WriteObject(line, f, Py_PRINT_RAW);
    object_decref(line);
    return err;
}

impl tb_printinternal(tb_in: ptr[PyObject], f: ptr[PyObject], limit: i64) -> i32 {
    tb = tb_in;
    depth: i64 = 0;
    last_file = NULL;
    last_line = i32(-1);
    last_name = NULL;
    cnt: i64 = 0;
    tb1 = tb;
    while tb1 {
        depth += 1;
        tb1 = tb_next_of(tb1);
    }
    while tb and depth > limit {
        depth -= 1;
        tb = tb_next_of(tb);
    }
    while tb {
        code = PyFrame_GetCode(tb_frame_of(tb));
        co_filename = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_FILENAME).view(1)[
            0
        ];
        co_name = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_NAME).view(1)[0];
        tb_lineno = tb_int(tb, PyTracebackObject_TB_LINENO);
        if tb_lineno == i32(-1) {
            tb_lineno = tb_get_lineno(tb);
        }
        if not last_file
            or co_filename != last_file
            or last_line == i32(-1)
            or tb_lineno != last_line
            or not last_name
            or co_name != last_name {
            if cnt > TB_RECURSIVE_CUTOFF {
                if tb_print_line_repeated(f, cnt) < i32(0) {
                    object_xdecref(code);
                    return i32(-1);
                }
            }
            last_file = co_filename;
            last_line = tb_lineno;
            last_name = co_name;
            cnt = 0;
        }
        cnt += 1;
        if cnt <= TB_RECURSIVE_CUTOFF {
            if tb_displayline(tb, f, co_filename, tb_lineno, tb_frame_of(tb), co_name)
                < i32(0) {
                object_xdecref(code);
                return i32(-1);
            }
            if PyErr_CheckSignals() < i32(0) {
                object_xdecref(code);
                return i32(-1);
            }
        }
        object_decref(code);
        tb = tb_next_of(tb);
    }
    if cnt > TB_RECURSIVE_CUTOFF {
        if tb_print_line_repeated(f, cnt) < i32(0) {
            return i32(-1);
        }
    }
    return i32(0);
}

impl dump_hexadecimal(fd: i32, value_in: u64, width_in: i64, strip_zeros: bool) {
    slots: own TracebackStack = TracebackStack();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));

    size: i64 = 16;
    width = width_in;
    if width > size {
        width = size;
    }

    value = value_in;
    end = buffer + size;
    p = end;
    p.view(1)[0] = u8(0);
    while True {
        p = p - 1;
        p.view(1)[0] = (addressof(Py_hexdigits).view(1)[0] + i64(value & u64(15))).view(
            1
        )[0];
        value = value >> u64(4);
        if not (i64(int(end) - int(p)) < width or value != u64(0)) {
            break;
        }
    }
    size = i64(int(end) - int(p));
    if strip_zeros {
        while p.view(1)[0] == u8(48) and size >= 2 {
            p = p + 1;
            size -= 1;
        }
    }
    _Py_write_noraise(fd, ptr(p), u64(size));
}

impl dump_pointer(fd: i32, address: ptr) {
    puts(fd, ptr[u8]("0x"));
    dump_hexadecimal(fd, u64.wrap(int(address)), 8, True);
}

impl dump_char(fd: i32, ch: u8) {
    slots: own TracebackStack = TracebackStack();
    buf = ptr[u8](jacpy_stack_address(&mut slots));
    buf.view(1)[0] = ch;
    _Py_write_noraise(fd, ptr(buf), u64(1));
}

impl is_ulong_freed(value: u64) -> bool {
    return value == u64(0)
        or value == u64(0xCDCDCDCDCDCDCDCD)
        or value == u64(0xDDDDDDDDDDDDDDDD)
        or value == u64(0xFDFDFDFDFDFDFDFD)
        or value == u64(0xFFFFFFFFFFFFFFFF);
}

impl frame_safe_get_code(f: ptr[u8]) -> ptr[PyObject] {
    if not iframe_object(f, _PyInterpreterFrame_F_GLOBALS)
        or not iframe_object(f, _PyInterpreterFrame_F_BUILTINS) {
        return NULL;
    }
    bits = ptr[u64](f + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0];
    if stackref_is_null(bits) {
        return NULL;
    }
    if is_ptr_freed(bits) {
        return NULL;
    }
    executable = stackref_borrow(bits);
    if _PyObject_IsFreed(executable) != i32(0) {
        return NULL;
    }
    if not object_is_type(executable, ptr[PyTypeObject](addressof(PyCode_Type))) {
        return NULL;
    }
    return executable;
}

impl frame_safe_get_lasti(f: ptr[u8]) -> i32 {
    co = frame_safe_get_code(f);
    if not co {
        return i32(-1);
    }
    bytecode = ptr[u8](co) + PyCodeObject_CODE_ADAPTIVE;
    units = i32.wrap((int(iframe_instr_ptr(f)) - int(bytecode)) // 2);
    return i32.wrap(i64(units) * 2);
}

impl dump_frame(fd: i32, frame: ptr[u8]) -> i32 {
    if iframe_owner(frame) == FRAME_OWNED_BY_INTERPRETER {
        return i32(0);
    }
    code = frame_safe_get_code(frame);
    if not code {
        return i32(-1);
    }
    res = i32(0);
    puts(fd, ptr[u8]("  File "));
    co_filename = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_FILENAME).view(1)[0];
    if co_filename and unicode_check(co_filename) {
        puts(fd, ptr[u8]("\""));
        _Py_DumpASCII(fd, co_filename);
        puts(fd, ptr[u8]("\""));
    } else {
        puts(fd, ptr[u8]("???"));
        res = i32(-1);
    }
    puts(fd, ptr[u8](", line "));
    lasti = frame_safe_get_lasti(frame);
    lineno = i32(-1);
    if lasti >= i32(0) {
        lineno = _PyCode_SafeAddr2Line(code, lasti);
    }
    if lineno >= i32(0) {
        _Py_DumpDecimal(fd, u64(lineno));
    } else {
        puts(fd, ptr[u8]("???"));
        res = i32(-1);
    }
    puts(fd, ptr[u8](" in "));
    co_name = ptr[ptr[PyObject]](ptr[u8](code) + PyCodeObject_NAME).view(1)[0];
    if co_name and unicode_check(co_name) {
        _Py_DumpASCII(fd, co_name);
    } else {
        puts(fd, ptr[u8]("???"));
        res = i32(-1);
    }
    puts(fd, ptr[u8]("\n"));
    return res;
}

impl tstate_thread_id(tstate: ptr[PyThreadState]) -> u64 {
    return ptr[u64](ptr[u8](tstate) + PyThreadState_THREAD_ID).view(1)[0];
}

impl tstate_is_freed(tstate: ptr[PyThreadState]) -> bool {
    if is_ptr_freed(u64.wrap(int(tstate))) {
        return True;
    }
    interp = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
    if is_ptr_freed(u64.wrap(int(interp))) {
        return True;
    }
    if is_ulong_freed(tstate_thread_id(tstate)) {
        return True;
    }
    return False;
}

impl dump_traceback(fd: i32, tstate: ptr[PyThreadState], write_header: bool) {
    if write_header {
        puts(fd, ptr[u8]("Stack (most recent call first):\n"));
    }
    if tstate_is_freed(tstate) {
        puts(fd, ptr[u8]("  <freed thread state>\n"));
        return;
    }
    frame = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
    if not frame {
        puts(fd, ptr[u8]("  <no Python frame>\n"));
        return;
    }
    depth = u32(0);
    while True {
        if MAX_FRAME_DEPTH <= depth {
            if MAX_FRAME_DEPTH < depth {
                puts(fd, ptr[u8]("plus "));
                _Py_DumpDecimal(fd, u64(depth));
                puts(fd, ptr[u8](" frames\n"));
            }
            break;
        }
        if is_ptr_freed(u64.wrap(int(frame))) {
            puts(fd, ptr[u8]("  <freed frame>\n"));
            break;
        }

        previous = iframe_previous(frame);
        if dump_frame(fd, frame) < i32(0) {
            puts(fd, ptr[u8]("  <invalid frame>\n"));
            break;
        }
        frame = previous;
        if not frame {
            break;
        }
        depth = depth + u32(1);
    }
}

impl write_thread_name(fd: i32, tstate: ptr[PyThreadState]) {
    slots: own TracebackStack = TracebackStack();
    name = ptr[u8](jacpy_stack_address(&mut slots));
    rc = pthread_getname_np(tstate_thread_id(tstate), name, u64(100));
    if rc == i32(0) {
        length = strlen(name);
        if length != u64(0) {
            puts(fd, ptr[u8](" ["));
            _Py_write_noraise(fd, ptr(name), length);
            puts(fd, ptr[u8]("]"));
        }
    }
}

impl write_thread_id(fd: i32, tstate: ptr[PyThreadState], is_current: bool) {
    if is_current {
        puts(fd, ptr[u8]("Current thread 0x"));
    } else {
        puts(fd, ptr[u8]("Thread 0x"));
    }
    _Py_DumpHexadecimal(fd, tstate_thread_id(tstate), 16);
    if not is_ulong_freed(tstate_thread_id(tstate)) {
        write_thread_name(fd, tstate);
    }
    puts(fd, ptr[u8](" (most recent call first):\n"));
}

impl backtrace_symbol(fd: i32, address: ptr) {
    slots: own TracebackStack = TracebackStack();
    info = ptr[DlInfo](jacpy_stack_address(&mut slots));
    status = symbol_info(address, ptr[u8](info), ptr[u8](info) + 64);
    if status == i32(0)
        or not info.view(1)[0].dli_fname
        or info.view(1)[0].dli_fname.view(1)[0] == u8(0) {
        puts(fd, ptr[u8]("  Binary file '<unknown>' ["));
        dump_pointer(fd, address);
        puts(fd, ptr[u8]("]\n"));
        return;
    }
    if not info.view(1)[0].dli_sname {
        info.view(1)[0].dli_saddr = info.view(1)[0].dli_fbase;
    }
    if not info.view(1)[0].dli_sname and not info.view(1)[0].dli_saddr {
        puts(fd, ptr[u8]("  Binary file \""));
        puts(fd, info.view(1)[0].dli_fname);
        puts(fd, ptr[u8]("\" ["));
        dump_pointer(fd, address);
        puts(fd, ptr[u8]("]\n"));
        return;
    }
    sign = u8(43);
    offset: i64 = 0;
    saddr = int(info.view(1)[0].dli_saddr);
    if int(address) >= saddr {
        offset = i64(int(address) - saddr);
    } else {
        sign = u8(45);
        offset = i64(saddr - int(address));
    }
    symbol_name = info.view(1)[0].dli_sname or ptr[u8]("");
    puts(fd, ptr[u8]("  Binary file \""));
    puts(fd, info.view(1)[0].dli_fname);
    puts(fd, ptr[u8]("\", at "));
    puts(fd, symbol_name);
    dump_char(fd, sign);
    puts(fd, ptr[u8]("0x"));
    dump_hexadecimal(fd, u64.wrap(offset), 8, True);
    puts(fd, ptr[u8](" ["));
    dump_pointer(fd, address);
    puts(fd, ptr[u8]("]\n"));
}
