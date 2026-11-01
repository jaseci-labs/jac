import from c {
    def _Py_Get_Getpath_CodeObject -> ptr[PyObject];  def jacpy_getpath_macro(
        which: i64
    ) -> ptr[u8];  def PyStatus_Error(err_msg: ptr[u8]) -> PyStatus;  def PyStatus_NoMemory -> PyStatus;  def _PyPathConfig_ReadGlobal(
        config: ptr[u8]
    ) -> PyStatus;  def _PyPathConfig_GetGlobalModuleSearchPath -> ptr[i32];  def _PyConfig_AsDict(
        config: ptr[u8]
    ) -> ptr[PyObject];  def _PyConfig_FromDict(
        config: ptr[u8], dct: ptr[PyObject]
    ) -> i32;  def PyEval_EvalCode(
        co: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
    ) -> ptr[PyObject];  def PyEval_GetBuiltins -> ptr[PyObject];  def Py_Initialize;  def Py_DecodeLocale(
        arg: ptr[u8], wlen: ptr[u64]
    ) -> ptr[i32];  def _Py_abspath(path: ptr[i32], abspath_p: ptr[ptr[i32]]) -> i32;  def _Py_normpath(
        path: ptr[i32], size: i64
    ) -> ptr[i32];  def _Py_isabs(path: ptr[i32]) -> i32;  def _Py_wstat(
        path: ptr[i32], buf: &mut _Py_stat_struct
    ) -> i32;  def _Py_add_relfile(
        dirname: ptr[i32], relfile: ptr[i32], bufsize: u64
    ) -> i32;  def _Py_join_relfile(dirname: ptr[i32], relfile: ptr[i32]) -> ptr[i32];  def _Py_wfopen(
        path: ptr[i32], mode: ptr[i32]
    ) -> ptr[FILE];  def _Py_wreadlink(
        path: ptr[i32], buf: ptr[i32], buflen: u64
    ) -> i32;  def _Py_DecodeUTF8_surrogateescape(
        arg: ptr[u8], arglen: i64, wlen: ptr[u64]
    ) -> ptr[i32];  def _PyMem_RawWcsdup(text: ptr[i32]) -> ptr[i32];  def wcscmp(
        left: ptr[i32], right: ptr[i32]
    ) -> i32;  def wcscpy(target: ptr[i32], source: ptr[i32]) -> ptr[i32];  def wcschr(
        text: ptr[i32], c: i32
    ) -> ptr[i32];  def wcsrchr(text: ptr[i32], c: i32) -> ptr[i32];  def fread(
        buffer: ptr, size: u64, count: u64, stream: ptr[FILE]
    ) -> u64;  def fclose(stream: ptr[FILE]) -> i32;  def fprintf(
        stream: ptr, format: ptr[u8], *args: any
    ) -> i32;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def getenv(
        name: ptr[u8]
    ) -> ptr[u8];  def unsetenv(name: ptr[u8]) -> i32;  def dladdr(
        address: ptr, info: ptr
    ) -> i32;  def jacpy_stdio_stream(stream: i32) -> ptr;  obj GetpathStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0;
    }  def jacpy_stack_address(slots: &mut GetpathStack) -> int;  glob:priv READ_BINARY_MODE:
             list[i32] = [i32(114), i32(98), i32(0)]; glob:priv getpath_methods:
             list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("abspath"),
                 ml_meth=ptr(getpath_abspath),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("basename"),
                 ml_meth=ptr(getpath_basename),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("dirname"),
                 ml_meth=ptr(getpath_dirname),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("hassuffix"),
                 ml_meth=ptr(getpath_hassuffix),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isabs"),
                 ml_meth=ptr(getpath_isabs),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isdir"),
                 ml_meth=ptr(getpath_isdir),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isfile"),
                 ml_meth=ptr(getpath_isfile),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("isxfile"),
                 ml_meth=ptr(getpath_isxfile),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("joinpath"),
                 ml_meth=ptr(getpath_joinpath),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("readlines"),
                 ml_meth=ptr(getpath_readlines),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("realpath"),
                 ml_meth=ptr(getpath_realpath),
                 ml_flags=METH_VARARGS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         getpath_warn_method: PyMethodDef = PyMethodDef(
             ml_name=ptr[u8]("warn"),
             ml_meth=ptr(getpath_warn),
             ml_flags=METH_VARARGS,
             ml_doc=ptr[u8]()
         ),
         getpath_nowarn_method: PyMethodDef = PyMethodDef(
             ml_name=ptr[u8]("warn"),
             ml_meth=ptr(getpath_nowarn),
             ml_flags=METH_VARARGS,
             ml_doc=ptr[u8]()
         );
}

glob:priv GETPATH_SEP: i32 = 47,
     MODE_TYPE_MASK: i64 = 0o170000,
     MODE_DIRECTORY: i64 = 0o040000,
     MODE_REGULAR: i64 = 0o100000,
     MODE_ANY_EXECUTE: i64 = 0o111,
     WIDE_SIZE: i64 = 4,
     MAX_FILE: i64 = 32768,
     MACRO_PREFIX: i64 = 0,
     MACRO_EXEC_PREFIX: i64 = 1,
     MACRO_PYTHONPATH: i64 = 2,
     MACRO_VPATH: i64 = 3,
     MACRO_PLATLIBDIR: i64 = 4;

def:priv bool_object(value: bool) -> ptr[PyObject];

def:priv is_unicode(op: ptr[PyObject]) -> bool;

def:priv parse_str_args(
    args: ptr[PyObject], count: i64
) -> tuple[bool, ptr[PyObject], ptr[PyObject]];

def:priv getpath_abspath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_basename(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_dirname(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_isabs(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_hassuffix(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv path_mode(path: ptr[i32]) -> i64;

def:priv getpath_isdir(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_isfile(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_isxfile(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_joinpath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_readlines(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_realpath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_warn(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv getpath_nowarn(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv funcs_to_dict(dct: ptr[PyObject], warnings: i32) -> i32;

def:priv wchar_to_dict(dct: ptr[PyObject], key: ptr[u8], s: ptr[i32]) -> i32;

def:priv decode_to_dict(dct: ptr[PyObject], key: ptr[u8], s: ptr[u8]) -> i32;

def:priv env_to_dict(dct: ptr[PyObject], key: ptr[u8], and_clear: i32) -> i32;

def:priv int_to_dict(dct: ptr[PyObject], key: ptr[u8], v: i32) -> i32;

def:priv progname_to_dict(dct: ptr[PyObject], key: ptr[u8]) -> i32;

def:priv library_to_dict(dct: ptr[PyObject], key: ptr[u8]) -> i32;

import from c {
    def _PyConfig_InitPathConfig(
        config: ptr[u8], compute_path_config: i32
    ) -> PyStatus {
        status = _PyPathConfig_ReadGlobal(config);

        if status._type != _PyStatus_TYPE_OK or compute_path_config == 0 {
            return status;
        }

        if not current_tstate() {
            return PyStatus_Error(
                ptr[u8]("cannot calculate path configuration without GIL")
            );
        }

        configDict = _PyConfig_AsDict(config);
        if not configDict {
            PyErr_Clear();
            return PyStatus_NoMemory();
        }

        dct = PyDict_New();
        if not dct {
            PyErr_Clear();
            object_decref(configDict);
            return PyStatus_NoMemory();
        }

        if PyDict_SetItemString(dct, ptr[u8]("config"), configDict) < 0 {
            PyErr_Clear();
            object_decref(configDict);
            object_decref(dct);
            return PyStatus_NoMemory();
        }

        object_decref(configDict);

        co = _Py_Get_Getpath_CodeObject();
        if not co or int(object_type(co)) != int(addressof(PyCode_Type)) {
            PyErr_Clear();
            object_xdecref(co);
            object_decref(dct);
            return PyStatus_Error(ptr[u8]("error reading frozen getpath.py"));
        }

        if decode_to_dict(dct, ptr[u8]("os_name"), getpath_os_name()) == 0
            or int_to_dict(dct, ptr[u8]("WITH_NEXT_FRAMEWORK"), 0) == 0
            or decode_to_dict(dct, ptr[u8]("PREFIX"), jacpy_getpath_macro(MACRO_PREFIX))
                == 0
            or decode_to_dict(
                dct, ptr[u8]("EXEC_PREFIX"), jacpy_getpath_macro(MACRO_EXEC_PREFIX)
            )
                == 0
            or decode_to_dict(
                dct, ptr[u8]("PYTHONPATH"), jacpy_getpath_macro(MACRO_PYTHONPATH)
            )
                == 0
            or decode_to_dict(dct, ptr[u8]("VPATH"), jacpy_getpath_macro(MACRO_VPATH))
                == 0
            or decode_to_dict(
                dct, ptr[u8]("PLATLIBDIR"), jacpy_getpath_macro(MACRO_PLATLIBDIR)
            )
                == 0
            or decode_to_dict(dct, ptr[u8]("PYDEBUGEXT"), ptr[u8]()) == 0
            or int_to_dict(dct, ptr[u8]("VERSION_MAJOR"), PY_MAJOR_VERSION) == 0
            or int_to_dict(dct, ptr[u8]("VERSION_MINOR"), PY_MINOR_VERSION) == 0
            or decode_to_dict(dct, ptr[u8]("PYWINVER"), ptr[u8]()) == 0
            or wchar_to_dict(dct, ptr[u8]("EXE_SUFFIX"), ptr[i32]()) == 0
            or env_to_dict(dct, ptr[u8]("ENV_PATH"), 0) == 0
            or env_to_dict(dct, ptr[u8]("ENV_PYTHONHOME"), 0) == 0
            or env_to_dict(dct, ptr[u8]("ENV_PYTHONEXECUTABLE"), 0) == 0
            or env_to_dict(dct, ptr[u8]("ENV___PYVENV_LAUNCHER__"), 1) == 0
            or progname_to_dict(dct, ptr[u8]("real_executable")) == 0
            or library_to_dict(dct, ptr[u8]("library")) == 0
            or wchar_to_dict(dct, ptr[u8]("executable_dir"), ptr[i32]()) == 0
            or wchar_to_dict(
                dct, ptr[u8]("py_setpath"), _PyPathConfig_GetGlobalModuleSearchPath()
            )
                == 0
            or funcs_to_dict(
                dct, ptr[i32](config + PyConfig_PATHCONFIG_WARNINGS).view(1)[0]
            )
                == 0
            or decode_to_dict(dct, ptr[u8]("ABI_THREAD"), ptr[u8]("")) == 0
            or PyDict_SetItemString(dct, ptr[u8]("winreg"), Py_None) < 0
            or PyDict_SetItemString(dct, ptr[u8]("__builtins__"), PyEval_GetBuiltins())
                < 0 {
            object_decref(co);
            object_decref(dct);
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while preparing getpath")
            );
            return PyStatus_Error(ptr[u8]("error evaluating initial values"));
        }

        r = PyEval_EvalCode(co, dct, dct);
        object_decref(co);

        if not r {
            object_decref(dct);
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored while running getpath"));
            return PyStatus_Error(ptr[u8]("error evaluating path"));
        }
        object_decref(r);

        if _PyConfig_FromDict(config, configDict) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored while reading getpath results")
            );
            object_decref(dct);
            return PyStatus_Error(ptr[u8]("error getting getpath results"));
        }

        object_decref(dct);

        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }
}

impl bool_object(value: bool) -> ptr[PyObject] {
    if value {
        return object_new_ref(ptr[PyObject](addressof(_Py_TrueStruct)));
    }
    return object_new_ref(ptr[PyObject](addressof(_Py_FalseStruct)));
}

impl is_unicode(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl parse_str_args(
    args: ptr[PyObject], count: i64
) -> tuple[bool, ptr[PyObject], ptr[PyObject]] {
    nargs = object_size(args);
    if nargs != count {
        if count == 1 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("function takes exactly 1 argument (%zd given)"),
                nargs
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("function takes exactly %d arguments (%zd given)"),
                i32(count),
                nargs
            );
        }
        return (False, NULL, NULL);
    }
    first = tuple_get_item(args, 0);
    second = NULL;
    index: i64 = 0;
    while index < count {
        item = tuple_get_item(args, index);
        if not is_unicode(item) {
            type_name = ptr[u8]("None");
            if item != Py_None {
                type_name = object_type(item).view(1)[0].tp_name;
            }
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("argument %zd must be str, not %.50s"),
                index + 1,
                type_name
            );
            return (False, NULL, NULL);
        }
        if index == 1 {
            second = item;
        }
        index += 1;
    }
    return (True, first, second);
}

impl getpath_abspath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    r = NULL;
    length: i64 = 0;
    path = PyUnicode_AsWideCharString(pathobj, &mut length);
    if path {
        slots: own GetpathStack = GetpathStack();
        abs_p = ptr[ptr[i32]](jacpy_stack_address(&mut slots));
        if _Py_abspath(_Py_normpath(path, -1), abs_p) == 0 and abs_p.view(1)[0] {
            abs_path = abs_p.view(1)[0];
            r = PyUnicode_FromWideChar(abs_path, -1);
            PyMem_RawFree(ptr(abs_path));
        } else {
            PyErr_SetString(PyExc_OSError, ptr[u8]("failed to make path absolute"));
        }
        PyMem_Free(ptr(path));
    }
    return r;
}

impl getpath_basename(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, path, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    end = PyUnicode_GetLength(path);
    pos = PyUnicode_FindChar(path, u32(GETPATH_SEP), 0, end, -1);
    if pos < 0 {
        return object_new_ref(path);
    }
    return PyUnicode_Substring(path, pos + 1, end);
}

impl getpath_dirname(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, path, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    end = PyUnicode_GetLength(path);
    pos = PyUnicode_FindChar(path, u32(GETPATH_SEP), 0, end, -1);
    if pos < 0 {
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    return PyUnicode_Substring(path, 0, pos);
}

impl getpath_isabs(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    r = NULL;
    path = PyUnicode_AsWideCharString(pathobj, None);
    if path {
        r = bool_object(_Py_isabs(path) != 0);
        PyMem_Free(ptr(path));
    }
    return r;
}

impl getpath_hassuffix(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, suffixobj) = parse_str_args(args, 2);
    if not ok {
        return NULL;
    }
    r = NULL;
    length: i64 = 0;
    suffix_length: i64 = 0;
    path = PyUnicode_AsWideCharString(pathobj, &mut length);
    if path {
        suffix = PyUnicode_AsWideCharString(suffixobj, &mut suffix_length);
        if suffix {
            if suffix_length > length
                or wcscmp(path + (length - suffix_length), suffix) != 0 {
                r = bool_object(False);
            } else {
                r = bool_object(True);
            }
            PyMem_Free(ptr(suffix));
        }
        PyMem_Free(ptr(path));
    }
    return r;
}

impl path_mode(path: ptr[i32]) -> i64 {
    st = _Py_stat_struct();
    if _Py_wstat(path, &mut st) != 0 {
        return -1;
    }
    return i64(st.st_mode);
}

impl getpath_isdir(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    r = NULL;
    path = PyUnicode_AsWideCharString(pathobj, None);
    if path {
        mode = path_mode(path);
        r = bool_object(mode != -1 and (mode & MODE_TYPE_MASK) == MODE_DIRECTORY);
        PyMem_Free(ptr(path));
    }
    return r;
}

impl getpath_isfile(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    r = NULL;
    path = PyUnicode_AsWideCharString(pathobj, None);
    if path {
        mode = path_mode(path);
        r = bool_object(mode != -1 and (mode & MODE_TYPE_MASK) == MODE_REGULAR);
        PyMem_Free(ptr(path));
    }
    return r;
}

impl getpath_isxfile(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    r = NULL;
    length: i64 = 0;
    path = PyUnicode_AsWideCharString(pathobj, &mut length);
    if path {
        mode = path_mode(path);
        r = bool_object(
            mode != -1
                and (mode & MODE_TYPE_MASK) == MODE_REGULAR
                and (mode & MODE_ANY_EXECUTE) != 0
        );
        PyMem_Free(ptr(path));
    }
    return r;
}

impl getpath_joinpath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    if not type_has_feature(object_type(args), Py_TPFLAGS_TUPLE_SUBCLASS) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("requires tuple of arguments"));
        return NULL;
    }
    n = object_size(args);
    if n == 0 {
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }

    parts = ptr[ptr[i32]](PyMem_Malloc(u64(n * 8)));
    if not parts {
        PyErr_NoMemory();
        return NULL;
    }
    memset(ptr(parts), 0, u64(n * 8));
    cch_final: i64 = 0;
    first: i64 = 0;

    for i in range(n) {
        s = tuple_get_item(args, i);
        cch: i64 = 0;
        if s == Py_None {
            cch = 0;
        } elif is_unicode(s) {
            part = PyUnicode_AsWideCharString(s, &mut cch);
            parts.view(n)[i] = part;
            if not part {
                cch_final = -1;
                break;
            }
            if _Py_isabs(part) != 0 {
                first = i;
            }
        } else {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("all arguments to joinpath() must be str or None")
            );
            cch_final = -1;
            break;
        }
        cch_final += cch + 1;
    }

    joined = ptr[i32]();
    if cch_final > 0 {
        joined = ptr[i32](PyMem_Malloc(u64(cch_final * WIDE_SIZE)));
    }
    if not joined {
        for i in range(n) {
            PyMem_Free(ptr(parts.view(n)[i]));
        }
        PyMem_Free(ptr(parts));
        if cch_final != 0 {
            PyErr_NoMemory();
            return NULL;
        }
        return Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }

    joined.view(1)[0] = 0;

    for i in range(n) {
        part = parts.view(n)[i];
        if not part {
            continue;
        }
        if i >= first and joined {
            if joined.view(1)[0] == 0 {
                wcscpy(joined, part);
            } elif _Py_add_relfile(joined, part, u64(cch_final)) < 0 {
                PyMem_Free(ptr(joined));
                joined = ptr[i32]();
            }
        }
        PyMem_Free(ptr(part));
    }
    PyMem_Free(ptr(parts));
    if not joined {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("failed to join paths"));
        return NULL;
    }
    r = PyUnicode_FromWideChar(_Py_normpath(joined, -1), -1);
    PyMem_Free(ptr(joined));
    return r;
}

impl getpath_readlines(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    path = PyUnicode_AsWideCharString(pathobj, None);
    if not path {
        return NULL;
    }
    fp = _Py_wfopen(path, ptr[i32](addressof(READ_BINARY_MODE)));
    if not fp {
        PyErr_SetFromErrno(PyExc_OSError);
        PyMem_Free(ptr(path));
        return NULL;
    }
    PyMem_Free(ptr(path));

    r = PyList_New(0);
    if not r {
        fclose(fp);
        return NULL;
    }
    buffer = ptr[u8](PyMem_Malloc(u64(MAX_FILE)));
    if not buffer {
        object_decref(r);
        fclose(fp);
        return NULL;
    }

    cb = i64(fread(ptr(buffer), 1, u64(MAX_FILE), fp));
    fclose(fp);
    if cb == 0 {
        return r;
    }
    if cb >= MAX_FILE {
        object_decref(r);
        PyErr_SetString(
            PyExc_MemoryError,
            ptr[u8]("cannot read file larger than 32KB during initialization")
        );
        return NULL;
    }
    buffer.view(MAX_FILE)[cb] = 0;

    slots: own GetpathStack = GetpathStack();
    len_p = ptr[u64](jacpy_stack_address(&mut slots));
    wbuffer = _Py_DecodeUTF8_surrogateescape(buffer, cb, len_p);
    PyMem_Free(ptr(buffer));
    if not wbuffer {
        object_decref(r);
        PyErr_NoMemory();
        return NULL;
    }

    p1 = wbuffer;
    p2 = wcschr(p1, 10);
    while p2 {
        line_end = (int(p2) - int(p1)) // WIDE_SIZE;
        while line_end >= 0
            and (
                (p1 + line_end).view(1)[0] == 10 or (p1 + line_end).view(1)[0] == 13
            ) {
            line_end -= 1;
        }
        count: i64 = 0;
        if line_end >= 0 {
            count = line_end + 1;
        }
        u = PyUnicode_FromWideChar(p1, count);
        if not u or PyList_Append(r, u) < 0 {
            object_xdecref(u);
            old = r;
            r = NULL;
            object_decref(old);
            break;
        }
        object_decref(u);
        p1 = p2 + 1;
        p2 = wcschr(p1, 10);
    }
    if r and p1 and p1.view(1)[0] != 0 {
        u = PyUnicode_FromWideChar(p1, -1);
        if not u or PyList_Append(r, u) < 0 {
            old = r;
            r = NULL;
            object_decref(old);
        }
        object_xdecref(u);
    }
    PyMem_RawFree(ptr(wbuffer));
    return r;
}

impl getpath_realpath(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, pathobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }

    r = NULL;
    nlink: i64 = 0;
    path = PyUnicode_AsWideCharString(pathobj, None);
    if not path {
        return r;
    }
    path2 = _PyMem_RawWcsdup(path);
    PyMem_Free(ptr(path));
    path = path2;
    resolved_size = MAXPATHLEN + 1;
    resolved = ptr[i32](PyMem_RawMalloc(u64(resolved_size * WIDE_SIZE)));
    if not resolved {
        PyMem_RawFree(ptr(path));
        PyErr_NoMemory();
        return NULL;
    }
    while path {
        linklen = _Py_wreadlink(path, resolved, u64(resolved_size));
        if linklen == -1 {
            r = PyUnicode_FromWideChar(path, -1);
            break;
        }
        if _Py_isabs(resolved) != 0 {
            PyMem_RawFree(ptr(path));
            path = _PyMem_RawWcsdup(resolved);
        } else {
            s = wcsrchr(path, GETPATH_SEP);
            if s {
                s.view(1)[0] = 0;
            }
            path2 = _Py_join_relfile(path, resolved);
            if path2 {
                path2 = _Py_normpath(path2, -1);
            }
            PyMem_RawFree(ptr(path));
            path = path2;
        }
        nlink += 1;

        if nlink >= 40 {
            PyErr_SetString(
                PyExc_OSError, ptr[u8]("maximum number of symbolic links reached")
            );
            break;
        }
    }
    if not path {
        PyErr_NoMemory();
    }
    PyMem_RawFree(ptr(resolved));
    PyMem_RawFree(ptr(path));
    return r;
}

impl getpath_warn(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    (ok, msgobj, unused) = parse_str_args(args, 1);
    if not ok {
        return NULL;
    }
    fprintf(jacpy_stdio_stream(2), ptr[u8]("%s\n"), PyUnicode_AsUTF8(msgobj));
    return object_new_ref(Py_None);
}

impl getpath_nowarn(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl funcs_to_dict(dct: ptr[PyObject], warnings: i32) -> i32 {
    m = ptr[PyMethodDef](addressof(getpath_methods));
    while m.view(1)[0].ml_name {
        f = PyCFunction_NewEx(m, NULL, NULL);
        if not f {
            return 0;
        }
        if PyDict_SetItemString(dct, m.view(1)[0].ml_name, f) < 0 {
            object_decref(f);
            return 0;
        }
        object_decref(f);
        m = m + 1;
    }
    m2 = ptr[PyMethodDef](addressof(getpath_nowarn_method));
    if warnings != 0 {
        m2 = ptr[PyMethodDef](addressof(getpath_warn_method));
    }
    f = PyCFunction_NewEx(m2, NULL, NULL);
    if not f {
        return 0;
    }
    if PyDict_SetItemString(dct, m2.view(1)[0].ml_name, f) < 0 {
        object_decref(f);
        return 0;
    }
    object_decref(f);
    return 1;
}

impl wchar_to_dict(dct: ptr[PyObject], key: ptr[u8], s: ptr[i32]) -> i32 {
    u = NULL;
    if s and s.view(1)[0] != 0 {
        u = PyUnicode_FromWideChar(s, -1);
        if not u {
            return 0;
        }
    } else {
        u = object_new_ref(Py_None);
    }
    r = PyDict_SetItemString(dct, key, u) == 0;
    object_decref(u);
    if r {
        return 1;
    }
    return 0;
}

impl decode_to_dict(dct: ptr[PyObject], key: ptr[u8], s: ptr[u8]) -> i32 {
    u = NULL;
    if s and s.view(1)[0] != 0 {
        slots: own GetpathStack = GetpathStack();
        len_p = ptr[u64](jacpy_stack_address(&mut slots));
        w = Py_DecodeLocale(s, len_p);
        if w {
            u = PyUnicode_FromWideChar(w, i64(len_p.view(1)[0]));
            PyMem_RawFree(ptr(w));
        }
        if not u {
            return 0;
        }
    } else {
        u = object_new_ref(Py_None);
    }
    r = PyDict_SetItemString(dct, key, u) == 0;
    object_decref(u);
    if r {
        return 1;
    }
    return 0;
}

impl env_to_dict(dct: ptr[PyObject], key: ptr[u8], and_clear: i32) -> i32 {
    u = NULL;
    r = False;
    v = getenv(key + 4);
    if v {
        slots: own GetpathStack = GetpathStack();
        len_p = ptr[u64](jacpy_stack_address(&mut slots));
        w = Py_DecodeLocale(v, len_p);
        if w {
            u = PyUnicode_FromWideChar(w, i64(len_p.view(1)[0]));
            if not u {
                PyErr_Clear();
            }
            PyMem_RawFree(ptr(w));
        }
    }
    if u {
        r = PyDict_SetItemString(dct, key, u) == 0;
        object_decref(u);
    } else {
        r = PyDict_SetItemString(dct, key, Py_None) == 0;
    }
    if r and and_clear != 0 {
        unsetenv(key + 4);
    }
    if r {
        return 1;
    }
    return 0;
}

impl int_to_dict(dct: ptr[PyObject], key: ptr[u8], v: i32) -> i32 {
    o = PyLong_FromLong(i64(v));
    if not o {
        return 0;
    }
    r = PyDict_SetItemString(dct, key, o) == 0;
    object_decref(o);
    if r {
        return 1;
    }
    return 0;
}

impl progname_to_dict(dct: ptr[PyObject], key: ptr[u8]) -> i32 {
    (found, path) = getpath_executable_path();
    if found < 0 {
        return 0;
    }
    if found > 0 {
        r = decode_to_dict(dct, key, path);
        PyMem_RawFree(ptr(path));
        return r;
    }
    if PyDict_SetItemString(dct, key, Py_None) == 0 {
        return 1;
    }
    return 0;
}

impl library_to_dict(dct: ptr[PyObject], key: ptr[u8]) -> i32 {
    slots: own GetpathStack = GetpathStack();
    info = ptr[ptr[u8]](jacpy_stack_address(&mut slots));
    if dladdr(ptr(Py_Initialize), ptr(info)) != 0 and info.view(1)[0] {
        return decode_to_dict(dct, key, info.view(1)[0]);
    }

    if PyDict_SetItemString(dct, key, Py_None) == 0 {
        return 1;
    }
    return 0;
}
