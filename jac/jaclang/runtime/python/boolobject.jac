# Objects/boolobject.c ported to native Jac.
#
# The bool object model is the C ABI: _Py_FalseStruct/_Py_TrueStruct keep the
# `struct _longobject` layout (immortal refcount, PyBool_Type, lv_tag, one
# digit), and PyBool_Type is exported under its C name so the C side links
# against the Jac definition. PyBool_FromLong is defined here as def:pub;
# gen_capi then stops declaring it for other modules.
#
# PyNumberMethods is the C layout; bool_as_number is a defined static with the
# five overridden slots. The long-type fallbacks call through PyLong_Type's
# tp_as_number pointer, cast to the typed struct (gap-3 field-call idiom).
#
# PyVectorcall_NARGS is a static inline in C, not a symbol: it is inlined here
# as clearing the PY_VECTORCALL_ARGUMENTS_OFFSET bit.
#
# C residue used here: jacpy_bool_new_too_many (formatted TypeError), the same
# residue rules as cellobject.jac.


import from c {
    obj PyObject;
    # A vectorcall `PyObject *const *args` array (up to 3 positional args):
    # read `args[i]` directly instead of a C helper call.
    obj ArgVec3 {
        has a0: ptr[PyObject] = ptr[PyObject](),
            a1: ptr[PyObject] = ptr[PyObject](),
            a2: ptr[PyObject] = ptr[PyObject]();
    }
    # Local copy of the 53-field type layout (cellobject.jac owns the
    # reference spelling): extern struct globals need a same-module
    # layout for native lowering; imported obj types only lower
    # behind ptr[...].
    obj PyTypeObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            ob_size: i64 = 0,
            tp_name: ptr[u8] = ptr[u8](),
            tp_basicsize: i64 = 0,
            tp_itemsize: i64 = 0,
            tp_dealloc: Callable[[ptr[PyObject]], None] = 0,
            tp_vectorcall_offset: i64 = 0,
            tp_getattr: Callable[[ptr[PyObject], ptr[u8]], ptr[PyObject]] = 0,
            tp_setattr: Callable[[ptr[PyObject], ptr[u8], ptr[PyObject]], i32] = 0,
            tp_as_async: ptr = ptr(),
            tp_repr: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_as_number: ptr = ptr(),
            tp_as_sequence: ptr = ptr(),
            tp_as_mapping: ptr = ptr(),
            tp_hash: Callable[[ptr[PyObject]], i64] = 0,
            tp_call: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_str: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_getattro: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_setattro: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            tp_as_buffer: ptr = ptr(),
            tp_flags: u64 = 0,
            tp_doc: ptr[u8] = ptr[u8](),
            tp_traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            tp_clear: Callable[[ptr[PyObject]], i32] = 0,
            tp_richcompare: Callable[[ptr[PyObject], ptr[PyObject], i32], ptr[PyObject]] = 0,
            tp_weaklistoffset: i64 = 0,
            tp_iter: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_iternext: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            tp_methods: ptr = ptr(),
            tp_members: ptr = ptr(),
            tp_getset: ptr = ptr(),
            tp_base: ptr[PyTypeObject_Layout] = ptr[PyTypeObject_Layout](),
            tp_dict: ptr[PyObject] = ptr[PyObject](),
            tp_descr_get: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_descr_set: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], None] = 0,
            tp_dictoffset: i64 = 0,
            tp_init: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], i32] = 0,
            tp_alloc: Callable[[ptr[PyTypeObject_Layout], i64], ptr[PyObject]] = 0,
            tp_new: Callable[[ptr[PyTypeObject_Layout], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            tp_free: Callable[[ptr], None] = 0,
            tp_is_gc: Callable[[ptr[PyObject]], i32] = 0,
            tp_bases: ptr[PyObject] = ptr[PyObject](),
            tp_mro: ptr[PyObject] = ptr[PyObject](),
            tp_cache: ptr[PyObject] = ptr[PyObject](),
            tp_subclasses: ptr = ptr(),
            tp_weaklist: ptr[PyObject] = ptr[PyObject](),
            tp_del: Callable[[ptr[PyObject]], None] = 0,
            tp_version_tag: u32 = 0,
            tp_finalize: Callable[[ptr[PyObject]], None] = 0,
            tp_vectorcall: Callable[[ptr[PyObject], ptr[PyObject], i64, ptr[PyObject]], ptr[PyObject]] = 0,
            tp_watched: u8 = 0,
            tp_versions_used: u16 = 0;
    }

    obj PyObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject]();
    }

    obj PyNumberMethods {
        has nb_add: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_subtract: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_multiply: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_remainder: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_divmod: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_power: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_negative: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_positive: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_absolute: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_bool: Callable[[ptr[PyObject]], i32] = 0,
            nb_invert: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_lshift: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_rshift: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_and: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_xor: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_or: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_int: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_reserved: ptr = ptr(),
            nb_float: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_add: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_subtract: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_multiply: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_remainder: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_power: Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_lshift: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_rshift: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_and: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_xor: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_or: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_floor_divide: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_true_divide: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_floor_divide: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_true_divide: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_index: Callable[[ptr[PyObject]], ptr[PyObject]] = 0,
            nb_matrix_multiply: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            nb_inplace_matrix_multiply: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }

    # `struct _longobject`: PyObject head, lv_tag, one digit. The trailing
    # three padding bytes are struct tail padding, same as C.
    obj PyLongObject_Layout {
        has ob_refcnt: i64 = 0,
            ob_type: ptr[PyObject] = ptr[PyObject](),
            lv_tag: i64 = 0,
            ob_digit0: u32 = 0;
    }

    glob PyType_Type: PyTypeObject_Layout;
    glob PyLong_Type: PyTypeObject_Layout;
    glob PyExc_DeprecationWarning: ptr[PyObject];

    # The long type's number-slot fallback calls stay C: calling through a
    # function pointer loaded from a struct does not lower natively.
    def jacpy_bool_fallback_invert(v: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_bool_fallback_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_bool_fallback_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];
    def jacpy_bool_fallback_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject];

    def PyObject_IsTrue(o: ptr[PyObject]) -> i32;
    def PyTuple_Size(p: ptr[PyObject]) -> i64;
    def PyTuple_GetItem(p: ptr[PyObject], index: i64) -> ptr[PyObject];
    def _PyArg_NoKeywords(fname: ptr[u8], kwargs: ptr[PyObject]) -> i32;
    def _PyArg_NoKwnames(fname: ptr[u8], kwnames: ptr[PyObject]) -> i32;
    def _PyArg_CheckPositional(fname: ptr[u8], nargs: i64, min: i64, max: i64) -> i32;
    def PyErr_SetString(exc: ptr[PyObject], msg: ptr[u8]) -> None;
    def PyErr_WarnEx(category: ptr[PyObject], message: ptr[u8], stack_level: i64) -> i32;
    def _Py_SetImmortal(op: ptr[PyObject]) -> None;
    def jacpy_is_tuple(handle: ptr[PyObject]) -> i64;
    def jacpy_bool_new_too_many(nargs: i64) -> None;
    # The interned "True"/"False" strings (_Py_ID static identifiers).
    def jacpy_bool_repr_str(value: i32) -> ptr[PyObject];
    def jacpy_exception_type(kind: ptr[u8]) -> ptr[PyObject];
}

glob:pub PyBool_Type: PyTypeObject_Layout = PyTypeObject_Layout(
    ob_refcnt=1407378104778752,          # _Py_STATIC_IMMORTAL_INITIAL_REFCNT
    ob_type=PyType_Type,                 # PyVarObject_HEAD_INIT(&PyType_Type, 0)
    ob_size=0,
    tp_name="bool",
    tp_basicsize=24,                     # offsetof(_longobject, long_value.ob_digit)
    tp_itemsize=4,                       # sizeof(digit)
    tp_dealloc=bool_dealloc,
    tp_repr=bool_repr,
    tp_as_number=bool_as_number,
    tp_flags=0,                          # Py_TPFLAGS_DEFAULT (non-stackless)
    tp_doc=(
        "bool(object=False, /)\n"
        "--\n"
        "\n"
        "Returns True when the argument is true, False otherwise.\n"
        "The builtins True and False are the only two instances of the class bool.\n"
        "The class bool is a subclass of the class int, and cannot be subclassed."
    ),
    tp_base=PyLong_Type,
    tp_new=bool_new,
    tp_vectorcall=bool_vectorcall
);

glob bool_as_number: PyNumberMethods = PyNumberMethods(
    nb_invert=bool_invert,
    nb_and=bool_and,
    nb_xor=bool_xor,
    nb_or=bool_or
);

# The objects representing bool values False and True. Sign in the low two
# bits of lv_tag (zero=1, positive=0), digit count in bits 3+:
# _PyLong_FALSE_TAG = TAG_FROM_SIGN_AND_SIZE(0, 0) = 1,
# _PyLong_TRUE_TAG  = TAG_FROM_SIGN_AND_SIZE(1, 1) = 8.
glob:pub _Py_FalseStruct: PyLongObject_Layout = PyLongObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyBool_Type,
    lv_tag=1,
    ob_digit0=0
);

glob:pub _Py_TrueStruct: PyLongObject_Layout = PyLongObject_Layout(
    ob_refcnt=1407378104778752,
    ob_type=PyBool_Type,
    lv_tag=8,
    ob_digit0=1
);

def bool_is_bool(op: ptr[PyObject]) -> i32 {
    head = ptr[PyObject_Layout](op);
    bt: ptr[PyObject] = PyBool_Type;
    if head.ob_type == bt {
        return 1;
    }
    return 0;
}

def bool_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    t: ptr[PyObject] = _Py_TrueStruct;
    return jacpy_bool_repr_str(i32(1 if self == t else 0));
}

# Function to return a bool from a C long.
def:pub PyBool_FromLong(ok: i64) -> ptr[PyObject] {
    t: ptr[PyObject] = _Py_TrueStruct;
    if ok {
        return t;
    }
    f: ptr[PyObject] = _Py_FalseStruct;
    return f;
}

# We define bool_new to always return either Py_True or Py_False.
def bool_new(
    type_: ptr[PyTypeObject_Layout], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds {
        if not _PyArg_NoKeywords("bool", kwds) {
            return ptr[PyObject]();
        }
    }
    f: ptr[PyObject] = _Py_FalseStruct;
    x: ptr[PyObject] = f;
    if not jacpy_is_tuple(args) {
        PyErr_SetString(
            jacpy_exception_type("TypeError"),
            "PyArg_UnpackTuple() argument list is not a tuple"
        );
        return ptr[PyObject]();
    }
    nargs = PyTuple_Size(args);
    if nargs > 1 {
        jacpy_bool_new_too_many(nargs);
        return ptr[PyObject]();
    }
    if nargs == 1 {
        x = PyTuple_GetItem(args, 0);
        if not x {
            return ptr[PyObject]();
        }
    }
    ok = PyObject_IsTrue(x);
    if ok < 0 {
        return ptr[PyObject]();
    }
    return PyBool_FromLong(ok);
}

def bool_vectorcall(
    type_: ptr[PyTypeObject_Layout], args: ptr, nargsf: i64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    # _PyArg_NoKwnames / _PyArg_CheckPositional are macros that only call
    # out when the fast check fails.
    if kwnames != ptr[PyObject]() and not _PyArg_NoKwnames("bool", kwnames) {
        return ptr[PyObject]();
    }
    # PyVectorcall_NARGS(nargsf): clear PY_VECTORCALL_ARGUMENTS_OFFSET.
    nargs = nargsf & 9223372036854775807;
    if nargs > 1 and not _PyArg_CheckPositional("bool", nargs, 0, 1) {
        return ptr[PyObject]();
    }
    ok: i64 = 0;
    if nargs {
        a0 = ptr[ArgVec3](args).a0;
        ok = PyObject_IsTrue(a0);
        if ok < 0 {
            return ptr[PyObject]();
        }
    }
    return PyBool_FromLong(ok);
}

# Arithmetic operations redefined to return bool if both args are bool.

def bool_invert(v: ptr[PyObject]) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        "Bitwise inversion '~' on bool is deprecated and will be removed in Python 3.16. This returns the bitwise inversion of the underlying int object and is usually not what you expect from negating a bool. Use the 'not' operator for boolean negation or ~int(x) if you really want the bitwise inversion of the underlying int.",
        1
    ) < 0 {
        return ptr[PyObject]();
    }
    return jacpy_bool_fallback_invert(v);
}

def bool_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_is_bool(a) or not bool_is_bool(b) {
        return jacpy_bool_fallback_and(a, b);
    }
    ta: ptr[PyObject] = _Py_TrueStruct;
    tb: ptr[PyObject] = _Py_TrueStruct;
    r: i64 = 0;
    if a == ta {
        if b == tb {
            r = 1;
        }
    }
    return PyBool_FromLong(r);
}

def bool_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_is_bool(a) or not bool_is_bool(b) {
        return jacpy_bool_fallback_or(a, b);
    }
    ta: ptr[PyObject] = _Py_TrueStruct;
    tb: ptr[PyObject] = _Py_TrueStruct;
    r: i64 = 0;
    if a == ta {
        r = 1;
    }
    if b == tb {
        r = 1;
    }
    return PyBool_FromLong(r);
}

def bool_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_is_bool(a) or not bool_is_bool(b) {
        return jacpy_bool_fallback_xor(a, b);
    }
    ta: ptr[PyObject] = _Py_TrueStruct;
    tb: ptr[PyObject] = _Py_TrueStruct;
    r: i64 = 0;
    if a == ta {
        if b != tb {
            r = 1;
        }
    } elif b == tb {
        r = 1;
    }
    return PyBool_FromLong(r);
}

def bool_dealloc(boolean: ptr[PyObject]) -> None {
    # This should never get called, but we also don't want to SEGV if
    # we accidentally decref Booleans out of existence. Instead,
    # since bools are immortal, re-set the reference count.
    _Py_SetImmortal(boolean);
}
