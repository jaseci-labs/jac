import from c {
    def strlen(text: ptr[u8]) -> u64;  def wcslen(s: ptr[i32]) -> u64;  def PyComplex_FromCComplex(
        cval: Py_complex
    ) -> ptr[PyObject];  def PyUnicode_FromStringAndSize(
        u: ptr[u8], size: i64
    ) -> ptr[PyObject];  def PyModule_GetName(m: ptr[PyObject]) -> ptr[u8];  def jacpy_va_list(
        va: ptr
    ) -> VaList;  obj BuildCall {
        has converter: Callable[[ptr], ptr[PyObject]] = 0;
    }
}

glob:priv PY_SSIZE_T_MAX: u64 = 0x7FFFFFFFFFFFFFFF,
     CH_NUL: u8 = 0,
     CH_TAB: u8 = 9,
     CH_SPACE: u8 = 32,
     CH_HASH: u8 = 35,
     CH_AMP: u8 = 38,
     CH_LPAREN: u8 = 40,
     CH_RPAREN: u8 = 41,
     CH_COMMA: u8 = 44,
     CH_COLON: u8 = 58,
     CH_LBRACKET: u8 = 91,
     CH_RBRACKET: u8 = 93,
     CH_LBRACE: u8 = 123,
     CH_RBRACE: u8 = 125,
     CH_B: u8 = 66,
     CH_C: u8 = 67,
     CH_D: u8 = 68,
     CH_H: u8 = 72,
     CH_I: u8 = 73,
     CH_K: u8 = 75,
     CH_L: u8 = 76,
     CH_N: u8 = 78,
     CH_O: u8 = 79,
     CH_S: u8 = 83,
     CH_U: u8 = 85,
     CH_b: u8 = 98,
     CH_c: u8 = 99,
     CH_d: u8 = 100,
     CH_f: u8 = 102,
     CH_h: u8 = 104,
     CH_i: u8 = 105,
     CH_k: u8 = 107,
     CH_l: u8 = 108,
     CH_n: u8 = 110,
     CH_p: u8 = 112,
     CH_s: u8 = 115,
     CH_u: u8 = 117,
     CH_y: u8 = 121,
     CH_z: u8 = 122;

def char_at(p: ptr[u8]) -> u8;

def countformat(format: ptr[u8], endchar: u8) -> i64;

def check_end(format: ptr[u8], endchar: u8) -> (bool, ptr[u8]);

def do_mkvalue(format: ptr[u8], va: VaList) -> (ptr[PyObject], ptr[u8], VaList);

def do_ignore(format: ptr[u8], va: VaList, endchar: u8, n: i64) -> (ptr[u8], VaList);

def do_mkdict(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList);

def do_mklist(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList);

def do_mkstack(
    stack: ptr[ptr[PyObject]], format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (i32, ptr[u8], VaList);

def do_mktuple(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList);

def bytes_of_char(value: i32) -> ptr[PyObject];

def call_converter(func: ptr, arg: ptr) -> ptr[PyObject];

impl do_mkvalue(format: ptr[u8], va: VaList) -> (ptr[PyObject], ptr[u8], VaList) {
    f = format;
    while True {
        c = char_at(f);
        f = f + 1;
        if c == CH_LPAREN {
            return do_mktuple(f, va, CH_RPAREN, countformat(f, CH_RPAREN));
        } elif c == CH_LBRACKET {
            return do_mklist(f, va, CH_RBRACKET, countformat(f, CH_RBRACKET));
        } elif c == CH_LBRACE {
            return do_mkdict(f, va, CH_RBRACE, countformat(f, CH_RBRACE));
        } elif c == CH_b or c == CH_B or c == CH_h or c == CH_i {
            iv = va.arg(i32);
            return (PyLong_FromLong(i64(iv)), f, va);
        } elif c == CH_H {
            hv = va.arg(u32);
            return (PyLong_FromLong(i64(hv)), f, va);
        } elif c == CH_I {
            uv = va.arg(u32);
            return (PyLong_FromUnsignedLong(u64(uv)), f, va);
        } elif c == CH_n or c == CH_l {
            lv = va.arg(i64);
            return (PyLong_FromLong(lv), f, va);
        } elif c == CH_k {
            kv = va.arg(u64);
            return (PyLong_FromUnsignedLong(kv), f, va);
        } elif c == CH_L {
            llv = va.arg(i64);
            return (PyLong_FromLongLong(llv), f, va);
        } elif c == CH_K {
            ullv = va.arg(u64);
            return (PyLong_FromUnsignedLongLong(ullv), f, va);
        } elif c == CH_u {
            u = va.arg(ptr[i32]);
            un: i64 = -1;
            if char_at(f) == CH_HASH {
                f = f + 1;
                un = va.arg(i64);
            }
            if not u {
                return (object_new_ref(Py_None), f, va);
            }
            if un < 0 {
                un = i64(wcslen(u));
            }
            return (PyUnicode_FromWideChar(u, un), f, va);
        } elif c == CH_f or c == CH_d {
            dv = va.arg(f64);
            return (PyFloat_FromDouble(dv), f, va);
        } elif c == CH_D {
            cp = va.arg(ptr[Py_complex]);
            return (PyComplex_FromCComplex(cp.view(1)[0]), f, va);
        } elif c == CH_c {
            cv = va.arg(i32);
            return (bytes_of_char(cv), f, va);
        } elif c == CH_C {
            ordinal = va.arg(i32);
            return (PyUnicode_FromOrdinal(ordinal), f, va);
        } elif c == CH_p {
            truth = va.arg(i32);
            return (PyBool_FromLong(i64(truth)), f, va);
        } elif c == CH_s or c == CH_z or c == CH_U {
            text = va.arg(ptr[u8]);
            tn: i64 = -1;
            if char_at(f) == CH_HASH {
                f = f + 1;
                tn = va.arg(i64);
            }
            if not text {
                return (object_new_ref(Py_None), f, va);
            }
            if tn < 0 {
                m = strlen(text);
                if m > PY_SSIZE_T_MAX {
                    PyErr_SetString(
                        PyExc_OverflowError, ptr[u8]("string too long for Python string")
                    );
                    return (NULL, f, va);
                }
                tn = i64(m);
            }
            return (PyUnicode_FromStringAndSize(text, tn), f, va);
        } elif c == CH_y {
            data = va.arg(ptr[u8]);
            yn: i64 = -1;
            if char_at(f) == CH_HASH {
                f = f + 1;
                yn = va.arg(i64);
            }
            if not data {
                return (object_new_ref(Py_None), f, va);
            }
            if yn < 0 {
                ym = strlen(data);
                if ym > PY_SSIZE_T_MAX {
                    PyErr_SetString(
                        PyExc_OverflowError, ptr[u8]("string too long for Python bytes")
                    );
                    return (NULL, f, va);
                }
                yn = i64(ym);
            }
            return (PyBytes_FromStringAndSize(data, yn), f, va);
        } elif c == CH_N or c == CH_S or c == CH_O {
            if char_at(f) == CH_AMP {
                func = va.arg(ptr);
                arg = va.arg(ptr);
                f = f + 1;
                return (call_converter(func, arg), f, va);
            }
            v = va.arg(ptr[PyObject]);
            if v {
                if c != CH_N {
                    object_incref(v);
                }
            } elif not PyErr_Occurred() {
                PyErr_SetString(
                    PyExc_SystemError, ptr[u8]("NULL object passed to Py_BuildValue")
                );
            }
            return (v, f, va);
        } elif c != CH_COLON and c != CH_COMMA and c != CH_SPACE and c != CH_TAB {
            PyErr_SetString(
                PyExc_SystemError, ptr[u8]("bad format char passed to Py_BuildValue")
            );
            return (NULL, f, va);
        }
    }
}

def va_build_value(format: ptr[u8], va: VaList) -> ptr[PyObject];

def module_dict_for_add(mod: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def _Py_convert_optional_to_ssize_t(obj_: ptr[PyObject], result: ptr) -> i32 {
        limit: i64 = 0;
        if obj_ == Py_None {
            return 1;
        } elif index_check(obj_) {
            limit = PyNumber_AsSsize_t(obj_, PyExc_OverflowError);
            if limit == -1 and PyErr_Occurred() {
                return 0;
            }
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("argument should be integer or None, not '%.200s'"),
                object_type(obj_).view(1)[0].tp_name
            );
            return 0;
        }
        ptr[i64](result).view(1)[0] = limit;
        return 1;
    }  def Py_BuildValue(format: ptr[u8], *vargs: VaList) -> ptr[PyObject] {
        return va_build_value(format, vargs);
    }  def _Py_BuildValue_SizeT(format: ptr[u8], *vargs: VaList) -> ptr[PyObject] {
        return va_build_value(format, vargs);
    }  def Py_VaBuildValue(format: ptr[u8], va: ptr) -> ptr[PyObject] {
        return va_build_value(format, jacpy_va_list(va));
    }  def _Py_VaBuildValue_SizeT(format: ptr[u8], va: ptr) -> ptr[PyObject] {
        return va_build_value(format, jacpy_va_list(va));
    }  def _Py_VaBuildStack(
        small_stack: ptr[ptr[PyObject]],
        small_stack_len: i64,
        format: ptr[u8],
        va: ptr,
        p_nargs: ptr[i64]
    ) -> ptr[ptr[PyObject]] {
        n = countformat(format, CH_NUL);
        if n < 0 {
            p_nargs.view(1)[0] = 0;
            return ptr[ptr[PyObject]]();
        }
        if n == 0 {
            p_nargs.view(1)[0] = 0;
            return small_stack;
        }
        stack = small_stack;
        if n > small_stack_len {
            stack = ptr[ptr[PyObject]](PyMem_Malloc(u64(n) * u64(8)));
            if not stack {
                PyErr_NoMemory();
                return ptr[ptr[PyObject]]();
            }
        }
        (res, f, rest) = do_mkstack(stack, format, jacpy_va_list(va), CH_NUL, n);
        if res < 0 {
            if stack != small_stack {
                PyMem_Free(ptr(stack));
            }
            return ptr[ptr[PyObject]]();
        }
        p_nargs.view(1)[0] = n;
        return stack;
    }  def PyModule_AddObjectRef(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        dict = module_dict_for_add(mod, value);
        if not dict {
            return -1;
        }
        return PyDict_SetItemString(dict, name, value);
    }  def PyModule_Add(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        res = PyModule_AddObjectRef(mod, name, value);
        object_xdecref(value);
        return res;
    }  def PyModule_AddObject(
        mod: ptr[PyObject], name: ptr[u8], value: ptr[PyObject]
    ) -> i32 {
        res = PyModule_AddObjectRef(mod, name, value);
        if res == 0 {
            object_decref(value);
        }
        return res;
    }  def PyModule_AddIntConstant(m: ptr[PyObject], name: ptr[u8], value: i64) -> i32 {
        return PyModule_Add(m, name, PyLong_FromLong(value));
    }  def PyModule_AddStringConstant(
        m: ptr[PyObject], name: ptr[u8], value: ptr[u8]
    ) -> i32 {
        return PyModule_Add(m, name, PyUnicode_FromString(value));
    }  def PyModule_AddType(module: ptr[PyObject], type: ptr[PyTypeObject]) -> i32 {
        if not type_is_ready(type) and PyType_Ready(ptr[PyObject](type)) < 0 {
            return -1;
        }
        name = _PyType_Name(ptr[PyObject](type));
        return PyModule_AddObjectRef(module, name, ptr[PyObject](type));
    }  def Py_PACK_FULL_VERSION(
        x: i32, y: i32, z: i32, level: i32, serial: i32
    ) -> u32 {
        return (u32.wrap(x & 0xff) << u32(24))
            | (u32.wrap(y & 0xff) << u32(16))
            | (u32.wrap(z & 0xff) << u32(8))
            | (u32.wrap(level & 0xf) << u32(4))
            | u32.wrap(serial & 0xf);
    }  def Py_PACK_VERSION(x: i32, y: i32) -> u32 {
        return Py_PACK_FULL_VERSION(x, y, 0, 0, 0);
    }
}

impl char_at(p: ptr[u8]) -> u8 {
    return p.view(1)[0];
}

impl countformat(format: ptr[u8], endchar: u8) -> i64 {
    count: i64 = 0;
    level: i32 = 0;
    f = format;
    while level > 0 or char_at(f) != endchar {
        c = char_at(f);
        if c == CH_NUL {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("unmatched paren in format"));
            return -1;
        } elif c == CH_LPAREN or c == CH_LBRACKET or c == CH_LBRACE {
            if level == 0 {
                count += 1;
            }
            level += 1;
        } elif c == CH_RPAREN or c == CH_RBRACKET or c == CH_RBRACE {
            level -= 1;
        } elif level == 0
            and c != CH_HASH
            and c != CH_AMP
            and c != CH_COMMA
            and c != CH_COLON
            and c != CH_SPACE
            and c != CH_TAB {
            count += 1;
        }
        f = f + 1;
    }
    return count;
}

impl check_end(format: ptr[u8], endchar: u8) -> (bool, ptr[u8]) {
    f = format;
    while char_at(f) != endchar {
        c = char_at(f);
        if c != CH_SPACE and c != CH_TAB and c != CH_COMMA and c != CH_COLON {
            PyErr_SetString(PyExc_SystemError, ptr[u8]("Unmatched paren in format"));
            return (False, format);
        }
        f = f + 1;
    }
    if endchar != CH_NUL {
        f = f + 1;
    }
    return (True, f);
}

impl do_ignore(format: ptr[u8], va: VaList, endchar: u8, n: i64) -> (ptr[u8], VaList) {
    v = PyTuple_New(n);
    f = format;
    for i in range(n) {
        exc = PyErr_GetRaisedException();
        (w, f, va) = do_mkvalue(f, va);
        PyErr_SetRaisedException(exc);
        if w {
            if v {
                tuple_set_item(v, i, w);
            } else {
                object_decref(w);
            }
        }
    }
    object_xdecref(v);
    (ok, f) = check_end(f, endchar);
    return (f, va);
}

impl do_mkdict(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList) {
    f = format;
    if n < 0 {
        return (NULL, f, va);
    }
    if n % 2 != 0 {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("Bad dict format"));
        (f, va) = do_ignore(f, va, endchar, n);
        return (NULL, f, va);
    }

    d = PyDict_New();
    if not d {
        (f, va) = do_ignore(f, va, endchar, n);
        return (NULL, f, va);
    }
    i: i64 = 0;
    while i < n {
        (k, f, va) = do_mkvalue(f, va);
        if not k {
            (f, va) = do_ignore(f, va, endchar, n - i - 1);
            object_decref(d);
            return (NULL, f, va);
        }
        (v, f, va) = do_mkvalue(f, va);
        if not v or PyDict_SetItem(d, k, v) < 0 {
            (f, va) = do_ignore(f, va, endchar, n - i - 2);
            object_decref(k);
            object_xdecref(v);
            object_decref(d);
            return (NULL, f, va);
        }
        object_decref(k);
        object_decref(v);
        i += 2;
    }
    (ok, f) = check_end(f, endchar);
    if not ok {
        object_decref(d);
        return (NULL, f, va);
    }
    return (d, f, va);
}

impl do_mklist(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList) {
    f = format;
    if n < 0 {
        return (NULL, f, va);
    }

    v = PyList_New(n);
    if not v {
        (f, va) = do_ignore(f, va, endchar, n);
        return (NULL, f, va);
    }
    items = ptr[PyListObject](v).view(1)[0].ob_item;
    for i in range(n) {
        (w, f, va) = do_mkvalue(f, va);
        if not w {
            (f, va) = do_ignore(f, va, endchar, n - i - 1);
            object_decref(v);
            return (NULL, f, va);
        }
        (items + i).view(1)[0] = w;
    }
    (ok, f) = check_end(f, endchar);
    if not ok {
        object_decref(v);
        return (NULL, f, va);
    }
    return (v, f, va);
}

impl do_mkstack(
    stack: ptr[ptr[PyObject]], format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (i32, ptr[u8], VaList) {
    f = format;
    if n < 0 {
        return (i32(-1), f, va);
    }

    filled: i64 = 0;
    failed = False;
    while filled < n {
        (w, f, va) = do_mkvalue(f, va);
        if not w {
            (f, va) = do_ignore(f, va, endchar, n - filled - 1);
            failed = True;
            break;
        }
        (stack + filled).view(1)[0] = w;
        filled += 1;
    }
    if not failed {
        (ok, f) = check_end(f, endchar);
        if ok {
            return (i32(0), f, va);
        }
    }
    for i in range(filled) {
        object_decref((stack + i).view(1)[0]);
    }
    return (i32(-1), f, va);
}

impl do_mktuple(
    format: ptr[u8], va: VaList, endchar: u8, n: i64
) -> (ptr[PyObject], ptr[u8], VaList) {
    f = format;
    if n < 0 {
        return (NULL, f, va);
    }

    v = PyTuple_New(n);
    if not v {
        (f, va) = do_ignore(f, va, endchar, n);
        return (NULL, f, va);
    }
    for i in range(n) {
        (w, f, va) = do_mkvalue(f, va);
        if not w {
            (f, va) = do_ignore(f, va, endchar, n - i - 1);
            object_decref(v);
            return (NULL, f, va);
        }
        tuple_set_item(v, i, w);
    }
    (ok, f) = check_end(f, endchar);
    if not ok {
        object_decref(v);
        return (NULL, f, va);
    }
    return (v, f, va);
}

impl bytes_of_char(value: i32) -> ptr[PyObject] {
    cell = ptr[u8](__thread_local_block("jac_object_model_modsupport_char", 8));
    cell.view(1)[0] = u8.wrap(value);
    return PyBytes_FromStringAndSize(cell, 1);
}

impl call_converter(func: ptr, arg: ptr) -> ptr[PyObject] {
    calls = ptr[BuildCall](
        __thread_local_block("jac_object_model_modsupport_call_slot", 8)
    );
    calls.view(1)[0].converter = int(func);
    return calls.view(1)[0].converter(arg);
}

impl va_build_value(format: ptr[u8], va: VaList) -> ptr[PyObject] {
    n = countformat(format, CH_NUL);
    if n < 0 {
        return NULL;
    }
    if n == 0 {
        return object_new_ref(Py_None);
    }
    if n == 1 {
        (retval, f, va) = do_mkvalue(format, va);
        return retval;
    }
    (result, f2, va) = do_mktuple(format, va, CH_NUL, n);
    return result;
}

impl module_dict_for_add(mod: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    if not object_type_check(mod, ptr[PyTypeObject](addressof(PyModule_Type))) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("PyModule_AddObjectRef() first argument must be a module")
        );
        return NULL;
    }
    if not value {
        if not PyErr_Occurred() {
            PyErr_SetString(
                PyExc_SystemError,
                ptr[u8]("PyModule_AddObjectRef() must be called with an exception raised if value is NULL")
            );
        }
        return NULL;
    }
    dict = PyModule_GetDict(mod);
    if not dict {
        PyErr_Format(
            PyExc_SystemError, ptr[u8]("module '%s' has no __dict__"), PyModule_GetName(mod)
        );
    }
    return dict;
}
