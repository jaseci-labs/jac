glob:priv CR: i32 = 13,
     LF: i32 = 10,
     EOF: i32 = -1;

import from c {
    obj FILE;  obj OpenCodeHook {
        has call: Callable[[ptr[PyObject], ptr], ptr[PyObject]] = 0;
    }  def flockfile(stream: ptr[FILE]);  def funlockfile(stream: ptr[FILE]);  def getc_unlocked(
        stream: ptr[FILE]
    ) -> i32;  def ungetc(c: i32, stream: ptr[FILE]) -> i32;  def isatty(
        fd: i32
    ) -> i32;  glob:priv stdprinter_methods: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(stdprinter_noop),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("flush"),
                 ml_meth=ptr(stdprinter_noop),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("fileno"),
                 ml_meth=ptr(stdprinter_fileno),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isatty"),
                 ml_meth=ptr(stdprinter_isatty),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("write"),
                 ml_meth=ptr(stdprinter_write),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]("")
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         stdprinter_getsetlist: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("closed"),
                 get=get_closed,
                 doc=ptr[u8]("True if the file is closed")
             ),
             PyGetSetDef(
                 name=ptr[u8]("encoding"),
                 get=get_encoding,
                 doc=ptr[u8]("Encoding of the file")
             ),
             PyGetSetDef(
                 name=ptr[u8]("mode"),
                 get=get_mode,
                 doc=ptr[u8]("String giving the file mode")
             ),
             PyGetSetDef()
         ]; glob PyStdPrinter_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("stderrprinter"),
             tp_basicsize=PyStdPrinter_Object_SIZE,
             tp_repr=stdprinter_repr,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_DISALLOW_INSTANTIATION,
             tp_methods=addressof(stdprinter_methods),
             tp_getset=addressof(stdprinter_getsetlist),
             tp_alloc=PyType_GenericAlloc,
             tp_free=PyObject_Free
         );
}

def py_bool(value: bool) -> ptr[PyObject];

import from c {
    def PyFile_FromFd(
        fd: i32,
        name: ptr[u8],
        mode: ptr[u8],
        buffering: i32,
        encoding: ptr[u8],
        errors: ptr[u8],
        newline: ptr[u8],
        closefd: i32
    ) -> ptr[PyObject] {
        open = PyImport_ImportModuleAttrString("_io", "open");
        if not open {
            return NULL;
        }
        stream = PyObject_CallFunction(
            open,
            "isisssO",
            fd,
            mode,
            buffering,
            encoding,
            errors,
            newline,
            py_bool(closefd != 0)
        );
        jacpy_release(open);

        return stream;
    }  def PyFile_GetLine(f: ptr[PyObject], n: i32) -> ptr[PyObject] {
        if not f {
            PyErr_BadInternalCall();
            return NULL;
        }
        result = NULL;
        if n <= 0 {
            result = PyObject_CallMethod(f, "readline", ptr[u8]());
        } else {
            result = PyObject_CallMethod(f, "readline", "i", n);
        }
        if result and jacpy_is_bytes(result) == 0 and jacpy_is_unicode(result) == 0 {
            jacpy_release(result);
            result = NULL;
            PyErr_SetString(PyExc_TypeError, "object.readline() returned non-string");
        }
        if n < 0 and result and jacpy_is_bytes(result) != 0 {
            length = PyBytes_Size(result);
            if length == 0 {
                jacpy_release(result);
                result = NULL;
                PyErr_SetString(PyExc_EOFError, "EOF when reading a line");
            } elif (ptr[u8](jacpy_bytes_address(result)) + (length - 1)).view(1)[0]
                == u8(10) {
                _PyBytes_Resize(&mut result, length - 1);
            }
        }
        if n < 0 and result and jacpy_is_unicode(result) != 0 {
            length = PyUnicode_GetLength(result);
            if length == 0 {
                jacpy_release(result);
                result = NULL;
                PyErr_SetString(PyExc_EOFError, "EOF when reading a line");
            } elif PyUnicode_ReadChar(result, length - 1) == u32(10) {
                stripped = PyUnicode_Substring(result, 0, length - 1);
                jacpy_release(result);
                result = stripped;
            }
        }
        return result;
    }  def PyFile_WriteObject(v: ptr[PyObject], f: ptr[PyObject], flags: i32) -> i32 {
        if not f {
            PyErr_SetString(PyExc_TypeError, "writeobject with NULL file");
            return i32(-1);
        }
        writer = PyObject_GetAttrString(f, ptr[u8]("write"));
        if not writer {
            return i32(-1);
        }
        value = PyObject_Str(v) if (flags & Py_PRINT_RAW) != 0 else PyObject_Repr(v);
        if not value {
            jacpy_release(writer);
            return i32(-1);
        }
        result = PyObject_CallOneArg(writer, value);
        jacpy_release(value);
        jacpy_release(writer);
        if not result {
            return i32(-1);
        }
        jacpy_release(result);
        return i32(0);
    }  def PyFile_WriteString(s: ptr[u8], f: ptr[PyObject]) -> i32 {
        if not f {
            if not PyErr_Occurred() {
                PyErr_SetString(PyExc_SystemError, "null file for PyFile_WriteString");
            }
            return i32(-1);
        }
        if PyErr_Occurred() {
            return i32(-1);
        }
        v = PyUnicode_FromString(s);
        if not v {
            return i32(-1);
        }
        err = PyFile_WriteObject(v, f, Py_PRINT_RAW);
        jacpy_release(v);
        return err;
    }  def PyObject_AsFileDescriptor(o: ptr[PyObject]) -> i32 {
        fd = i32(0);
        if jacpy_is_long(o) != 0 {
            if bool_check(o)
                and PyErr_WarnEx(
                    PyExc_RuntimeWarning, "bool is used as a file descriptor", 1
                )
                    != 0 {
                return i32(-1);
            }
            fd = PyLong_AsInt(o);
        } else {
            meth = NULL;
            if PyObject_GetOptionalAttrString(o, ptr[u8]("fileno"), &mut meth) < 0 {
                return i32(-1);
            }
            if not meth {
                PyErr_SetString(
                    PyExc_TypeError,
                    "argument must be an int, or have a fileno() method."
                );
                return i32(-1);
            }
            fno = PyObject_CallNoArgs(meth);
            jacpy_release(meth);
            if not fno {
                return i32(-1);
            }
            if jacpy_is_long(fno) == 0 {
                PyErr_SetString(PyExc_TypeError, "fileno() returned a non-integer");
                jacpy_release(fno);
                return i32(-1);
            }
            fd = PyLong_AsInt(fno);
            jacpy_release(fno);
        }
        if fd == -1 and PyErr_Occurred() {
            return i32(-1);
        }
        if fd < 0 {
            PyErr_Format(
                PyExc_ValueError,
                "file descriptor cannot be a negative integer (%i)",
                fd
            );
            return i32(-1);
        }
        return fd;
    }  def _PyLong_FileDescriptor_Converter(o: ptr[PyObject], _ptr: ptr) -> i32 {
        return i32(0) if PyObject_AsFileDescriptor(o) == -1 else i32(1);
    }  def _Py_UniversalNewlineFgetsWithSize(
        buf: ptr[u8], n: i32, stream: ptr[FILE], fobj: ptr[PyObject], size: ptr[u64]
    ) -> ptr[u8] {
        (line, length) = universal_newline_fgets(buf, n, stream, fobj);
        if line {
            size.view(1)[0] = length;
        }
        return line;
    }  def Py_UniversalNewlineFgets(
        buf: ptr[u8], n: i32, stream: ptr[FILE], fobj: ptr[PyObject]
    ) -> ptr[u8] {
        (line, _) = universal_newline_fgets(buf, n, stream, fobj);
        return line;
    }  def PyFile_NewStdPrinter(fd: i32) -> ptr[PyObject] {
        if fd != jacpy_stdio_fileno(1) and fd != jacpy_stdio_fileno(2) {
            return NULL;
        }
        op = _PyObject_New(ptr[PyObject](addressof(PyStdPrinter_Type)));
        if op {
            printer_of(op).view(1)[0].fd = fd;
        }
        return op;
    }  def PyFile_SetOpenCodeHook(hook: ptr, user_data: ptr) -> i32 {
        if Py_IsInitialized() != 0 and PySys_AuditTuple("setopencodehook", NULL) < 0 {
            return i32(-1);
        }
        if jacpy_open_code_hook().view(1)[0] {
            if Py_IsInitialized() != 0 {
                PyErr_SetString(
                    PyExc_SystemError, "failed to change existing open_code hook"
                );
            }
            return i32(-1);
        }
        jacpy_open_code_hook().view(1)[0] = hook;
        jacpy_open_code_userdata().view(1)[0] = user_data;
        return i32(0);
    }  def PyFile_OpenCodeObject(path: ptr[PyObject]) -> ptr[PyObject] {
        if jacpy_is_unicode(path) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                "'path' must be 'str', not '%.200s'",
                ptr[_object](path).view(1)[0].ob_type.view(1)[0].tp_name
            );
            return NULL;
        }
        hook = jacpy_open_code_hook().view(1)[0];
        if hook {
            call = ptr[OpenCodeHook](
                __thread_local_block("jac_object_model_file_open_code_call", 8)
            );
            call.view(1)[0].call = int(hook);
            return call.view(1)[0].call(path, jacpy_open_code_userdata().view(1)[0]);
        }
        f = NULL;
        open = PyImport_ImportModuleAttrString("_io", "open");
        if open {
            f = PyObject_CallFunction(open, "Os", path, ptr[u8]("rb"));
            jacpy_release(open);
        }
        return f;
    }  def PyFile_OpenCode(utf8path: ptr[u8]) -> ptr[PyObject] {
        pathobj = PyUnicode_FromString(utf8path);
        if not pathobj {
            return NULL;
        }
        f = PyFile_OpenCodeObject(pathobj);
        jacpy_release(pathobj);
        return f;
    }  def _PyFile_Flush(file: ptr[PyObject]) -> i32 {
        tmp = PyObject_CallMethod(file, "flush", ptr[u8]());
        if not tmp {
            return i32(-1);
        }
        jacpy_release(tmp);
        return i32(0);
    }
}

def universal_newline_fgets(
    buf: ptr[u8], n: i32, stream: ptr[FILE], fobj: ptr[PyObject]
) -> tuple[ptr[u8], u64];

def printer_of(op: ptr[PyObject]) -> ptr[PyStdPrinter_Object];

def stdprinter_write(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def stdprinter_fileno(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def stdprinter_repr(op: ptr[PyObject]) -> ptr[PyObject];

def stdprinter_noop(_op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def stdprinter_isatty(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject];

def get_closed(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def get_mode(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

def get_encoding(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject];

impl py_bool(value: bool) -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct))
        if value
        else ptr[PyObject](addressof(_Py_FalseStruct));
}

impl universal_newline_fgets(
    buf: ptr[u8], n: i32, stream: ptr[FILE], fobj: ptr[PyObject]
) -> tuple[ptr[u8], u64] {
    p = buf;
    if fobj {
        jacpy_set_errno(ENXIO);
        return (ptr[u8](), u64(0));
    }
    flockfile(stream);
    remaining = n - 1;
    while remaining > 0 {
        c = getc_unlocked(stream);
        if c == EOF {
            break;
        }
        if c == CR {
            c = getc_unlocked(stream);
            if c != LF {
                ungetc(c, stream);
                c = LF;
            }
        }
        p.view(1)[0] = u8.wrap(c);
        p += 1;
        if c == LF {
            break;
        }
        remaining -= 1;
    }
    funlockfile(stream);
    p.view(1)[0] = u8(0);
    if p == buf {
        return (ptr[u8](), u64(0));
    }
    return (buf, u64(p - buf));
}

impl printer_of(op: ptr[PyObject]) -> ptr[PyStdPrinter_Object] {
    return ptr[PyStdPrinter_Object](op);
}

impl stdprinter_write(op: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    fd = printer_of(op).view(1)[0].fd;
    if fd < 0 {
        return Py_NewRef(Py_None);
    }
    unicode = NULL;
    if PyArg_ParseTuple(args, ptr[u8]("U"), &mut unicode) == 0 {
        return NULL;
    }
    size = i64(0);
    text = PyUnicode_AsUTF8AndSize(unicode, &mut size);
    data = ptr(text);
    encoded = NULL;
    if not text {
        PyErr_Clear();
        encoded = _PyUnicode_AsUTF8String(unicode, ptr[u8]("backslashreplace"));
        if not encoded {
            return NULL;
        }
        data = jacpy_bytes_address(encoded);
        size = PyBytes_Size(encoded);
    }
    written = _Py_write(fd, data, u64(size));
    err = jacpy_errno();
    jacpy_release(encoded);
    if written == -1 {
        if err == EAGAIN {
            PyErr_Clear();
            return Py_NewRef(Py_None);
        }
        return NULL;
    }
    return PyLong_FromSsize_t(written);
}

impl stdprinter_fileno(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(printer_of(op).view(1)[0].fd));
}

impl stdprinter_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_FromFormat(
        "<stdprinter(fd=%d) object at %p>", printer_of(op).view(1)[0].fd, op
    );
}

impl stdprinter_noop(_op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

impl stdprinter_isatty(op: ptr[PyObject], _unused: ptr[PyObject]) -> ptr[PyObject] {
    fd = printer_of(op).view(1)[0].fd;
    if fd < 0 {
        return py_bool(False);
    }
    state = PyEval_SaveThread();
    result = isatty(fd);
    PyEval_RestoreThread(state);
    return PyBool_FromLong(i64(result));
}

impl get_closed(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return py_bool(False);
}

impl get_mode(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return PyUnicode_FromString(ptr[u8]("w"));
}

impl get_encoding(_op: ptr[PyObject], _closure: ptr) -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}
