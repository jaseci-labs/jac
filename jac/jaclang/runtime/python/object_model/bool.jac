import from c {
    glob PyType_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyExc_DeprecationWarning: ptr[PyObject]; glob:priv bool_as_number:
             PyNumberMethods = PyNumberMethods(
             nb_invert=bool_invert, nb_and=bool_and, nb_xor=bool_xor, nb_or=bool_or
         ); glob PyBool_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("bool"),
             tp_basicsize=PyLong_DIGITS_OFFSET,
             tp_itemsize=PyLong_DIGIT_SIZE,
             tp_dealloc=bool_dealloc,
             tp_repr=bool_repr,
             tp_as_number=addressof(bool_as_number),
             tp_flags=Py_TPFLAGS_DEFAULT,
             tp_doc=ptr[u8](
                 "bool(object=False, /)\n--\n\n"
                 "Returns True when the argument is true, False otherwise.\n"
                 "The builtins True and False are the only two instances of the class bool.\n"
                 "The class bool is a subclass of the class int, and cannot be subclassed."
             ),
             tp_base=addressof(PyLong_Type),
             tp_new=bool_new,
             tp_vectorcall=bool_vectorcall
         ),
         _Py_FalseStruct: PyLongObject = PyLongObject(
             ob_base=_object(
                 ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                 ob_type=addressof(PyBool_Type)
             ),
             long_value=_PyLongValue(lv_tag=_PyLong_FALSE_TAG, ob_digit=0)
         ),
         _Py_TrueStruct: PyLongObject = PyLongObject(
             ob_base=_object(
                 ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                 ob_type=addressof(PyBool_Type)
             ),
             long_value=_PyLongValue(lv_tag=_PyLong_TRUE_TAG, ob_digit=1)
         );
}

def py_true -> ptr[PyObject];

def py_false -> ptr[PyObject];

def bool_check(op: ptr[PyObject]) -> bool;

def bool_repr(self: ptr[PyObject]) -> ptr[PyObject];

import from c {
    def PyBool_FromLong(ok: i64) -> ptr[PyObject] {
        return py_true() if ok != 0 else py_false();
    }
}

def bool_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def bool_vectorcall(
    _type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def bool_invert(v: ptr[PyObject]) -> ptr[PyObject];

def bool_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def bool_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def bool_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

def long_number -> ptr[PyNumberMethods];

def bool_dealloc(boolean: ptr[PyObject]);

impl py_true -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct));
}

impl py_false -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

impl bool_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyBool_Type));
}

impl bool_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_unicode_intern_text("True" if self == py_true() else "False");
}

impl bool_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    x = py_false();
    if kwds and _PyArg_NoKeywords(ptr[u8]("bool"), kwds) == 0 {
        return NULL;
    }
    if PyArg_UnpackTuple(args, ptr[u8]("bool"), 0, 1, &mut x) == 0 {
        return NULL;
    }
    ok = PyObject_IsTrue(x);
    if ok < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(ok));
}

impl bool_vectorcall(
    _type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    ok: i64 = 0;
    if kwnames and _PyArg_NoKwnames(ptr[u8]("bool"), kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if (nargs < 0 or nargs > 1)
        and _PyArg_CheckPositional(ptr[u8]("bool"), nargs, 0, 1) == 0 {
        return NULL;
    }
    if nargs != 0 {
        ok = i64(PyObject_IsTrue(args.view(1)[0]));
        if ok < 0 {
            return NULL;
        }
    }
    return PyBool_FromLong(ok);
}

impl bool_invert(v: ptr[PyObject]) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        ptr[u8](
            "Bitwise inversion '~' on bool is deprecated and will be removed in "
            "Python 3.16. This returns the bitwise inversion of the underlying int "
            "object and is usually not what you expect from negating "
            "a bool. Use the 'not' operator for boolean negation or "
            "~int(x) if you really want the bitwise inversion of the "
            "underlying int."
        ),
        1
    )
        < 0 {
        return NULL;
    }
    return long_number().view(1)[0].nb_invert(v);
}

impl bool_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_and(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) and (b == py_true())));
}

impl bool_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_or(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) or (b == py_true())));
}

impl bool_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_xor(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) != (b == py_true())));
}

impl long_number -> ptr[PyNumberMethods] {
    return addressof(PyLong_Type).view(1)[0].tp_as_number;
}

impl bool_dealloc(boolean: ptr[PyObject]) {
    _Py_SetImmortal(boolean);
}
