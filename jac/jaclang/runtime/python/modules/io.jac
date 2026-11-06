import from c {
    def PyType_GetModuleByDef(
        type: ptr[PyTypeObject], mod_def: ptr[PyModuleDef]
    ) -> ptr[PyObject];  def PyOS_FSPath(path: ptr[PyObject]) -> ptr[PyObject];  def PyFile_OpenCodeObject(
        path: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_GetConfig -> ptr[u8];  def strlen(s: ptr[u8]) -> u64;  def jacpy_stack_address(
        slots: &mut IOStack
    ) -> int;  obj IOStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject]();
    }  obj IOModuleState {
        has initialized: i32,
            unsupported_operation: ptr[PyObject],
            PyIOBase_Type: ptr[PyTypeObject],
            PyIncrementalNewlineDecoder_Type: ptr[PyTypeObject],
            PyRawIOBase_Type: ptr[PyTypeObject],
            PyBufferedIOBase_Type: ptr[PyTypeObject],
            PyBufferedRWPair_Type: ptr[PyTypeObject],
            PyBufferedRandom_Type: ptr[PyTypeObject],
            PyBufferedReader_Type: ptr[PyTypeObject],
            PyBufferedWriter_Type: ptr[PyTypeObject],
            PyBytesIOBuffer_Type: ptr[PyTypeObject],
            PyBytesIO_Type: ptr[PyTypeObject],
            PyFileIO_Type: ptr[PyTypeObject],
            PyStringIO_Type: ptr[PyTypeObject],
            PyTextIOBase_Type: ptr[PyTypeObject],
            PyTextIOWrapper_Type: ptr[PyTypeObject];
    }
}

glob DEFAULT_BUFFER_SIZE: Final[i64] = 131072,
     IO_STATE_SIZE: Final[i64] = 128,
     IO_STATE_TYPE_COUNT: Final[i64] = 14,
     PY_OFF_T_MAX: Final[i64] = 9223372036854775807,
     PY_OFF_T_MIN: Final[i64] = -9223372036854775807 - 1;

glob _IOBase_token = ClassToken(),
     FileIO_token = ClassToken(),
     BytesIO_token = ClassToken(),
     _BufferedIOBase_token = ClassToken(),
     _Buffered_token = ClassToken(),
     BufferedRWPair_token = ClassToken(),
     _TextIOBase_token = ClassToken();

def get_io_state(module: ptr[PyObject]) -> ptr[IOModuleState];

def get_io_state_by_cls(cls: ptr[PyObject]) -> ptr[IOModuleState];

def state_unsupported_slot(state: ptr[IOModuleState]) -> ptr[ptr[PyObject]];

def state_type_slot(state: ptr[IOModuleState], index: i64) -> ptr[ptr[PyObject]];

def find_io_state_by_def(type: ptr[PyTypeObject]) -> ptr[IOModuleState];

def io_call_noargs(obj_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject];

def io_call_onearg(
    obj_: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject];

def io_call_twoargs(
    obj_: ptr[PyObject],
    name: ptr[PyObject],
    first: ptr[PyObject],
    second: ptr[PyObject]
) -> ptr[PyObject];

def io_call_ssize(
    obj_: ptr[PyObject], name: ptr[PyObject], value: i64
) -> ptr[PyObject];

def io_call_function(
    callable: ptr[PyObject],
    first: ptr[PyObject],
    second: ptr[PyObject],
    third: ptr[PyObject],
    fourth: ptr[PyObject],
    nargs: i64
) -> ptr[PyObject];

def io_fast_size(args: ptr[ptr[PyObject]], nargs: i64) -> tuple[i32, i64];

def io_true -> ptr[PyObject];

def io_false -> ptr[PyObject];

def io_bool(value: bool) -> ptr[PyObject];

def io_select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition];

def io_select_properties(
    table: list[PropertyDefinition], names: list[str]
) -> list[PropertyDefinition];

def io_fill_slots(
    slots: ptr[PyType_Slot],
    methods: list[MethodDefinition],
    getset: list[PropertyDefinition],
    doc: str = ""
) -> bool;

def:priv raw_mode(
    creating: bool, reading: bool, writing: bool, appending: bool, updating: bool
) -> ptr[u8];

def:priv bad_mode(modeobj: ptr[PyObject], unknown: bool) -> ptr[PyObject];

def:priv open_failed(
    result: ptr[PyObject], path_or_fd: ptr[PyObject], modeobj: ptr[PyObject]
) -> ptr[PyObject];

def _io_open_impl(
    module: ptr[PyObject],
    file: ptr[PyObject],
    mode: str,
    buffering: i32,
    encoding: ptr[u8],
    errors: ptr[u8],
    newline: ptr[u8],
    closefd: bool,
    opener: ptr[PyObject]
) -> ptr[PyObject];

def _io_text_encoding_impl(
    module: ptr[PyObject], encoding: ptr[PyObject], stacklevel: i32
) -> ptr[PyObject];

def _io_open_code_impl(module: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyNumber_AsOff_t(item: ptr[PyObject], err: ptr[PyObject]) -> i64 {
        value = _PyNumber_Index(item);
        if not value {
            return -1;
        }

        result = PyLong_AsSsize_t(value);
        if result != -1 {
            object_decref(value);
            return result;
        }
        runerr = PyErr_Occurred();
        if not runerr {
            object_decref(value);
            return result;
        }

        if PyErr_GivenExceptionMatches(runerr, PyExc_OverflowError) == 0 {
            object_decref(value);
            return result;
        }

        PyErr_Clear();

        if not err {
            if PyLong_IsNegative(value) == 1 {
                result = PY_OFF_T_MIN;
            } else {
                result = PY_OFF_T_MAX;
            }
        } else {
            PyErr_Format(
                err,
                ptr[u8]("cannot fit '%.200s' into an offset-sized integer"),
                object_type(item).view(1)[0].tp_name
            );
        }

        object_decref(value);
        return result;
    }  def _PyIO_trap_eintr -> i32 {
        if PyErr_ExceptionMatches(PyExc_OSError) == 0 {
            return 0;
        }
        exc = PyErr_GetRaisedException();
        myerrno = ptr[PyOSErrorObject](exc).view(1)[0].myerrno;
        if myerrno {
            overflow: i32 = 0;
            value = i32.wrap(PyLong_AsLongAndOverflow(myerrno, &mut overflow));
            PyErr_Clear();
            if value == EINTR {
                object_decref(exc);
                return 1;
            }
        }

        PyErr_SetRaisedException(exc);
        return 0;
    }
}

def iomodule_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def iomodule_clear(module: ptr[PyObject]) -> i32;

def iomodule_free(module: ptr);

def:priv add_type(
    module: ptr[PyObject],
    state: ptr[IOModuleState],
    index: i64,
    spec: ptr[PyType_Spec],
    base: ptr[PyTypeObject]
) -> bool;

def iomodule_exec(m: ptr[PyObject]) -> i32;

import from c {
    glob:priv iomodule_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(iomodule_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob _PyIO_Module: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("io"),
             m_doc=ptr[u8](
                 "The io module provides the Python interfaces to stream handling. The\nbuiltin open function is defined in this module.\n\nAt the top of the I/O hierarchy is the abstract base class IOBase. It\ndefines the basic interface to a stream. Note, however, that there is no\nseparation between reading and writing to streams; implementations are\nallowed to raise an OSError if they do not support a given operation.\n\nExtending IOBase is RawIOBase which deals simply with the reading and\nwriting of raw bytes to a stream. FileIO subclasses RawIOBase to provide\nan interface to OS files.\n\nBufferedIOBase deals with buffering on a raw byte stream (RawIOBase). Its\nsubclasses, BufferedWriter, BufferedReader, and BufferedRWPair buffer\nstreams that are readable, writable, and both respectively.\nBufferedRandom provides a buffered interface to random access\nstreams. BytesIO is a simple stream of in-memory bytes.\n\nAnother IOBase subclass, TextIOBase, deals with the encoding and decoding\nof streams into text. TextIOWrapper, which extends it, is a buffered text\ninterface to a buffered raw stream (`BufferedIOBase`). Finally, StringIO\nis an in-memory stream for text.\n\nArgument names are not part of the specification, and only the arguments\nof open() are intended to be used as keyword arguments.\n\ndata:\n\nDEFAULT_BUFFER_SIZE\n\n   An int containing the default buffer size used by the module's buffered\n   I/O classes.\n"
             ),
             m_size=IO_STATE_SIZE,
             m_slots=addressof(iomodule_slots)
         );
}

impl get_io_state(module: ptr[PyObject]) -> ptr[IOModuleState] {
    return ptr[IOModuleState](ptr[PyModuleObject](module).view(1)[0].md_state);
}

impl get_io_state_by_cls(cls: ptr[PyObject]) -> ptr[IOModuleState] {
    return get_io_state(ptr[PyHeapTypeObject](cls).view(1)[0].ht_module);
}

impl state_unsupported_slot(state: ptr[IOModuleState]) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](state) + 8);
}

impl state_type_slot(state: ptr[IOModuleState], index: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](state) + 16 + 8 * index);
}

impl find_io_state_by_def(type: ptr[PyTypeObject]) -> ptr[IOModuleState] {
    module = PyType_GetModuleByDef(type, ptr[PyModuleDef](addressof(_PyIO_Module)));
    return get_io_state(module);
}

impl io_call_noargs(obj_: ptr[PyObject], name: ptr[PyObject]) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(1)[0] = obj_;
    return PyObject_VectorcallMethod(
        name, stack, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl io_call_onearg(
    obj_: ptr[PyObject], name: ptr[PyObject], arg: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(2)[0] = obj_;
    stack.view(2)[1] = arg;
    return PyObject_VectorcallMethod(
        name, stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl io_call_twoargs(
    obj_: ptr[PyObject],
    name: ptr[PyObject],
    first: ptr[PyObject],
    second: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(3)[0] = obj_;
    stack.view(3)[1] = first;
    stack.view(3)[2] = second;
    return PyObject_VectorcallMethod(
        name, stack, u64(3) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl io_call_ssize(
    obj_: ptr[PyObject], name: ptr[PyObject], value: i64
) -> ptr[PyObject] {
    arg = PyLong_FromSsize_t(value);
    if not arg {
        return NULL;
    }
    res = io_call_onearg(obj_, name, arg);
    object_decref(arg);
    return res;
}

impl io_call_function(
    callable: ptr[PyObject],
    first: ptr[PyObject],
    second: ptr[PyObject],
    third: ptr[PyObject],
    fourth: ptr[PyObject],
    nargs: i64
) -> ptr[PyObject] {
    slots: own IOStack = IOStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    view = stack.view(5);
    view[1] = first;
    view[2] = second;
    view[3] = third;
    view[4] = fourth;
    return PyObject_Vectorcall(
        callable, stack + 1, u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
    );
}

impl io_fast_size(args: ptr[ptr[PyObject]], nargs: i64) -> tuple[i32, i64] {
    if nargs == 0 {
        return (i32(1), i64(-1));
    }
    if nargs == 1 {
        arg = args.view(1)[0];
        if arg == Py_None {
            return (i32(1), i64(-1));
        }
        if jacpy_is_exact_long(arg) != 0 {
            size = PyNumber_AsSsize_t(arg, PyExc_OverflowError);
            if size == -1 and PyErr_Occurred() {
                return (i32(-1), i64(0));
            }
            return (i32(1), size);
        }
    }
    return (i32(0), i64(0));
}

impl io_true -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct));
}

impl io_false -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

impl io_bool(value: bool) -> ptr[PyObject] {
    if value {
        return io_true();
    }
    return io_false();
}

impl io_select_methods(
    table: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in names {
        wanted = name;
        remaining = 0;
        if name.endswith("#2") {
            wanted = name[:-2];
            remaining = 1;
        }
        for method in table {
            if method.name == wanted {
                if remaining == 0 {
                    selected.append(method);
                    break;
                }
                remaining -= 1;
            }
        }
    }
    return selected;
}

impl io_select_properties(
    table: list[PropertyDefinition], names: list[str]
) -> list[PropertyDefinition] {
    selected: list[PropertyDefinition] = [];
    for name in names {
        for prop in table {
            if prop.name == name {
                selected.append(prop);
                break;
            }
        }
    }
    return selected;
}

impl io_fill_slots(
    slots: ptr[PyType_Slot],
    methods: list[MethodDefinition],
    getset: list[PropertyDefinition],
    doc: str = ""
) -> bool {
    index = 0;
    while (slots + index).view(1)[0].slot != 0 {
        slot = (slots + index).view(1);
        if slot[0].slot == Py_tp_methods and not slot[0].pfunc {
            table = method_table(methods);
            if not table {
                return False;
            }
            slot[0].pfunc = ptr(table);
        } elif slot[0].slot == Py_tp_getset and not slot[0].pfunc {
            records = getset_table(getset);
            if not records {
                return False;
            }
            slot[0].pfunc = ptr(records);
        } elif slot[0].slot == Py_tp_doc and not slot[0].pfunc and doc {
            text = c_string_copy(doc);
            if not text {
                PyErr_NoMemory();
                return False;
            }
            slot[0].pfunc = ptr(text);
        }
        index += 1;
    }
    return True;
}

impl raw_mode(
    creating: bool, reading: bool, writing: bool, appending: bool, updating: bool
) -> ptr[u8] {
    if creating {
        return ptr[u8]("x+") if updating else ptr[u8]("x");
    }
    if reading {
        return ptr[u8]("r+") if updating else ptr[u8]("r");
    }
    if writing {
        return ptr[u8]("w+") if updating else ptr[u8]("w");
    }
    if appending {
        return ptr[u8]("a+") if updating else ptr[u8]("a");
    }
    return ptr[u8]("+") if updating else ptr[u8]("");
}

impl bad_mode(modeobj: ptr[PyObject], unknown: bool) -> ptr[PyObject] {
    if unknown {
        return PyErr_Format(PyExc_ValueError, ptr[u8]("unknown mode: '%U'"), modeobj);
    }
    return PyErr_Format(PyExc_ValueError, ptr[u8]("invalid mode: '%U'"), modeobj);
}

impl open_failed(
    result: ptr[PyObject], path_or_fd: ptr[PyObject], modeobj: ptr[PyObject]
) -> ptr[PyObject] {
    if result {
        exc = PyErr_GetRaisedException();
        close_result = io_call_noargs(result, py_id(_Py_ID_close));
        _PyErr_ChainExceptions1(exc);
        object_xdecref(close_result);
        object_decref(result);
    }
    object_xdecref(path_or_fd);
    object_xdecref(modeobj);
    return NULL;
}

impl _io_open_impl(
    module: ptr[PyObject],
    file: ptr[PyObject],
    mode: str,
    buffering: i32,
    encoding: ptr[u8],
    errors: ptr[u8],
    newline: ptr[u8],
    closefd: bool,
    opener: ptr[PyObject]
) -> ptr[PyObject] {
    creating = False;
    reading = False;
    writing = False;
    appending = False;
    updating = False;
    text = False;
    binary = False;
    isatty: i32 = 0;
    line_buffering = False;
    result: ptr[PyObject] = NULL;
    path_or_fd: ptr[PyObject] = NULL;
    modeobj: ptr[PyObject] = NULL;

    is_number = PyNumber_Check(file) != 0;
    if is_number {
        path_or_fd = object_new_ref(file);
    } else {
        path_or_fd = PyOS_FSPath(file);
        if not path_or_fd {
            return NULL;
        }
    }

    if not is_number
        and not unicode_check(path_or_fd)
        and not bytes_check(path_or_fd) {
        PyErr_Format(PyExc_TypeError, ptr[u8]("invalid file: %R"), file);
        return open_failed(result, path_or_fd, modeobj);
    }

    modeobj = jacpy_unicode_from_text(mode);
    if not modeobj {
        return open_failed(result, path_or_fd, modeobj);
    }
    cmode = PyUnicode_AsUTF8(modeobj);
    if not cmode {
        return open_failed(result, path_or_fd, modeobj);
    }
    length = i64(strlen(cmode));
    i: i64 = 0;
    while i < length {
        c = cmode.view(length)[i];
        if c == u8(120) {
            creating = True;
        } elif c == u8(114) {
            reading = True;
        } elif c == u8(119) {
            writing = True;
        } elif c == u8(97) {
            appending = True;
        } elif c == u8(43) {
            updating = True;
        } elif c == u8(116) {
            text = True;
        } elif c == u8(98) {
            binary = True;
        } else {
            bad_mode(modeobj, False);
            return open_failed(result, path_or_fd, modeobj);
        }

        j = i + 1;
        while j < length {
            if cmode.view(length)[j] == c {
                bad_mode(modeobj, False);
                return open_failed(result, path_or_fd, modeobj);
            }
            j += 1;
        }
        i += 1;
    }

    if text and binary {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("can't have text and binary mode at once")
        );
        return open_failed(result, path_or_fd, modeobj);
    }

    chosen = 0;
    if creating {
        chosen += 1;
    }
    if reading {
        chosen += 1;
    }
    if writing {
        chosen += 1;
    }
    if appending {
        chosen += 1;
    }
    if chosen > 1 {
        PyErr_SetString(
            PyExc_ValueError,
            ptr[u8]("must have exactly one of create/read/write/append mode")
        );
        return open_failed(result, path_or_fd, modeobj);
    }

    if binary and encoding {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("binary mode doesn't take an encoding argument")
        );
        return open_failed(result, path_or_fd, modeobj);
    }

    if binary and errors {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("binary mode doesn't take an errors argument")
        );
        return open_failed(result, path_or_fd, modeobj);
    }

    if binary and newline {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("binary mode doesn't take a newline argument")
        );
        return open_failed(result, path_or_fd, modeobj);
    }

    if binary and buffering == 1 {
        if PyErr_WarnEx(
            PyExc_RuntimeWarning,
            ptr[u8](
                "line buffering (buffering=1) isn't supported in binary mode, the default buffer size will be used"
            ),
            1
        )
            < 0 {
            return open_failed(result, path_or_fd, modeobj);
        }
    }

    state = get_io_state(module).view(1);
    rawmode = PyUnicode_FromString(
        raw_mode(creating, reading, writing, appending, updating)
    );
    if not rawmode {
        return open_failed(result, path_or_fd, modeobj);
    }
    raw = io_call_function(
        ptr[PyObject](state[0].PyFileIO_Type),
        path_or_fd,
        rawmode,
        io_bool(closefd),
        opener,
        4
    );
    object_decref(rawmode);

    if not raw {
        return open_failed(result, path_or_fd, modeobj);
    }
    result = raw;

    object_decref(path_or_fd);
    path_or_fd = NULL;

    if buffering < 0 {
        res = io_call_noargs(raw, py_id(_Py_ID__isatty_open_only));
        if not res {
            return open_failed(result, path_or_fd, modeobj);
        }
        isatty = PyObject_IsTrue(res);
        object_decref(res);
        if isatty < 0 {
            return open_failed(result, path_or_fd, modeobj);
        }
    }

    if buffering == 1 or isatty != 0 {
        buffering = -1;
        line_buffering = True;
    } else {
        line_buffering = False;
    }

    if buffering < 0 {
        blksize_obj = PyObject_GetAttr(raw, py_id(_Py_ID__blksize));
        if not blksize_obj {
            return open_failed(result, path_or_fd, modeobj);
        }
        blksize = PyLong_AsLong(blksize_obj);
        object_decref(blksize_obj);
        buffering = i32.wrap(blksize);
        if buffering == -1 and PyErr_Occurred() {
            return open_failed(result, path_or_fd, modeobj);
        }
        clipped = i64(buffering);
        if clipped > 8192 * 1024 {
            clipped = 8192 * 1024;
        }
        if clipped < DEFAULT_BUFFER_SIZE {
            clipped = DEFAULT_BUFFER_SIZE;
        }
        buffering = i32(clipped);
    }
    if buffering < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("invalid buffering size"));
        return open_failed(result, path_or_fd, modeobj);
    }

    if buffering == 0 {
        if not binary {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("can't have unbuffered text I/O")
            );
            return open_failed(result, path_or_fd, modeobj);
        }
        object_decref(modeobj);
        return result;
    }

    buffered_class: ptr[PyObject] = NULL;
    if updating {
        buffered_class = ptr[PyObject](state[0].PyBufferedRandom_Type);
    } elif creating or writing or appending {
        buffered_class = ptr[PyObject](state[0].PyBufferedWriter_Type);
    } elif reading {
        buffered_class = ptr[PyObject](state[0].PyBufferedReader_Type);
    } else {
        bad_mode(modeobj, True);
        return open_failed(result, path_or_fd, modeobj);
    }
    size_obj = PyLong_FromLong(i64(buffering));
    if not size_obj {
        return open_failed(result, path_or_fd, modeobj);
    }
    buffer = io_call_function(buffered_class, raw, size_obj, NULL, NULL, 2);
    object_decref(size_obj);
    if not buffer {
        return open_failed(result, path_or_fd, modeobj);
    }
    result = buffer;
    object_decref(raw);

    if binary {
        object_decref(modeobj);
        return result;
    }

    wrapper = PyObject_CallFunction(
        ptr[PyObject](state[0].PyTextIOWrapper_Type),
        "OsssO",
        buffer,
        encoding,
        errors,
        newline,
        io_bool(line_buffering)
    );
    if not wrapper {
        return open_failed(result, path_or_fd, modeobj);
    }
    result = wrapper;
    object_decref(buffer);

    if PyObject_SetAttr(wrapper, py_id(_Py_ID_mode), modeobj) < 0 {
        return open_failed(result, path_or_fd, modeobj);
    }
    object_decref(modeobj);
    return result;
}

impl _io_text_encoding_impl(
    module: ptr[PyObject], encoding: ptr[PyObject], stacklevel: i32
) -> ptr[PyObject] {
    if not encoding or encoding == Py_None {
        if ptr[i32](_Py_GetConfig() + PyConfig_WARN_DEFAULT_ENCODING).view(1)[0] != 0 {
            if PyErr_WarnEx(
                PyExc_EncodingWarning,
                ptr[u8]("'encoding' argument not specified"),
                i64(stacklevel)
            )
                != 0 {
                return NULL;
            }
        }
        utf8_mode = ptr[i32](
            ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_PRECONFIG_UTF8_MODE
        ).view(
            1
        )[0];
        if utf8_mode != 0 {
            encoding = py_id(_Py_STR_utf_8);
        } else {
            encoding = py_id(_Py_ID_locale);
        }
    }
    return object_new_ref(encoding);
}

impl _io_open_code_impl(module: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    return PyFile_OpenCodeObject(path);
}

impl iomodule_traverse(module: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = get_io_state(module);
    status = visit_reference(state.view(1)[0].unsupported_operation, visitor, arg);
    if status != 0 {
        return status;
    }
    for index in range(IO_STATE_TYPE_COUNT) {
        status = visit_reference(
            state_type_slot(state, index).view(1)[0], visitor, arg
        );
        if status != 0 {
            return status;
        }
    }
    return 0;
}

impl iomodule_clear(module: ptr[PyObject]) -> i32 {
    state = get_io_state(module);
    py_clear(state_unsupported_slot(state));
    for index in range(IO_STATE_TYPE_COUNT) {
        py_clear(state_type_slot(state, index));
    }
    return 0;
}

impl iomodule_free(module: ptr) {
    iomodule_clear(ptr[PyObject](module));
}

impl add_type(
    module: ptr[PyObject],
    state: ptr[IOModuleState],
    index: i64,
    spec: ptr[PyType_Spec],
    base: ptr[PyTypeObject]
) -> bool {
    type = PyType_FromModuleAndSpec(module, spec, ptr[PyObject](base));
    state_type_slot(state, index).view(1)[0] = type;
    if not type {
        return False;
    }
    return PyModule_AddType(module, type) >= 0;
}

impl iomodule_exec(m: ptr[PyObject]) -> i32 {
    state = get_io_state(m);
    st = state.view(1);

    if PyModule_AddIntConstant(m, ptr[u8]("DEFAULT_BUFFER_SIZE"), DEFAULT_BUFFER_SIZE)
        < 0 {
        return -1;
    }

    st[0].unsupported_operation = PyObject_CallFunction(
        ptr[PyObject](addressof(PyType_Type)),
        "s(OO){}",
        ptr[u8]("UnsupportedOperation"),
        PyExc_OSError,
        PyExc_ValueError
    );
    if not st[0].unsupported_operation {
        return -1;
    }
    if PyObject_SetAttrString(
        st[0].unsupported_operation, ptr[u8]("__module__"), py_id(_Py_ID_io)
    )
        < 0 {
        return -1;
    }
    if PyModule_AddObjectRef(
        m, ptr[u8]("UnsupportedOperation"), st[0].unsupported_operation
    )
        < 0 {
        return -1;
    }

    if PyModule_AddObjectRef(m, ptr[u8]("BlockingIOError"), PyExc_BlockingIOError)
        < 0 {
        return -1;
    }

    if not add_type(m, state, 1, addressof(nldecoder_spec), ptr[PyTypeObject]())
        or not add_type(m, state, 8, addressof(bytesiobuf_spec), ptr[PyTypeObject]())
        or not add_type(m, state, 0, addressof(iobase_spec), ptr[PyTypeObject]()) {
        return -1;
    }

    if not add_type(m, state, 12, addressof(textiobase_spec), st[0].PyIOBase_Type)
        or not add_type(
            m, state, 3, addressof(bufferediobase_spec), st[0].PyIOBase_Type
        )
        or not add_type(m, state, 2, addressof(rawiobase_spec), st[0].PyIOBase_Type) {
        return -1;
    }

    if not add_type(m, state, 9, addressof(bytesio_spec), st[0].PyBufferedIOBase_Type)
        or not add_type(
            m, state, 7, addressof(bufferedwriter_spec), st[0].PyBufferedIOBase_Type
        )
        or not add_type(
            m, state, 6, addressof(bufferedreader_spec), st[0].PyBufferedIOBase_Type
        )
        or not add_type(
            m, state, 4, addressof(bufferedrwpair_spec), st[0].PyBufferedIOBase_Type
        )
        or not add_type(
            m, state, 5, addressof(bufferedrandom_spec), st[0].PyBufferedIOBase_Type
        ) {
        return -1;
    }

    if not add_type(m, state, 10, addressof(fileio_spec), st[0].PyRawIOBase_Type) {
        return -1;
    }

    if not add_type(m, state, 11, addressof(stringio_spec), st[0].PyTextIOBase_Type)
        or not add_type(
            m, state, 13, addressof(textiowrapper_spec), st[0].PyTextIOBase_Type
        ) {
        return -1;
    }
    return 0;
}
