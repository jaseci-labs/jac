"""The bool type, a subtype of int: Objects/boolobject.c in native Jac.

`PyBool_Type`, `_Py_FalseStruct` and `_Py_TrueStruct` are C data Jac defines
under their C names, statically allocated and immortal exactly as
`PyVarObject_HEAD_INIT` and `PyObject_HEAD_INIT` make them, so `Py_True` and
`Py_False` in C are the addresses of these objects. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    _Py_SetImmortal,
    _PyArg_CheckPositional,
    _PyArg_NoKeywords,
    _PyArg_NoKwnames,
    PyArg_UnpackTuple,
    PyErr_WarnEx,
    PyObject,
    PyObject_IsTrue,
    PyUnicode_InternFromString,
    PyVectorcall_NARGS
}
import from jaclang.runtime.python.layouts {
    PyLongObject,
    PyLong_DIGITS_OFFSET,
    PyLong_DIGIT_SIZE,
    PyNumberMethods,
    PyTypeObject,
    PyVarObject,
    Py_TPFLAGS_DEFAULT,
    _PyLongValue,
    _PyLong_FALSE_TAG,
    _PyLong_TRUE_TAG,
    _Py_STATIC_IMMORTAL_INITIAL_REFCNT,
    _object
}
import from jaclang.runtime.python.object_model.header { object_is_type }

import from c {
    glob PyType_Type: PyTypeObject,
         PyLong_Type: PyTypeObject,
         PyExc_DeprecationWarning: ptr[PyObject];
    # Arithmetic methods -- only so we can override &, |, ^.
    glob:priv bool_as_number: PyNumberMethods = PyNumberMethods(
             nb_invert=bool_invert, nb_and=bool_and, nb_xor=bool_xor, nb_or=bool_or
         );
    # The type object for bool. Note that this cannot be subclassed!
    glob PyBool_Type: PyTypeObject = PyTypeObject(
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
         # The objects representing bool values False and True.
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

"""Py_True."""
def py_true -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_TrueStruct));
}

"""Py_False."""
def py_false -> ptr[PyObject] {
    return ptr[PyObject](addressof(_Py_FalseStruct));
}

"""PyBool_Check."""
def bool_check(op: ptr[PyObject]) -> bool {
    return object_is_type(op, addressof(PyBool_Type));
}

# We define bool_repr to return "False" or "True": the interpreter's static
# identifier strings, which interning returns.
def bool_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    return PyUnicode_InternFromString("True" if self == py_true() else "False");
}

# Function to return a bool from a C long.
import from c {
    def PyBool_FromLong(ok: i64) -> ptr[PyObject] {
        return py_true() if ok != 0 else py_false();
    }
}

# We define bool_new to always return either Py_True or Py_False.
def bool_new(
    _type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    x = py_false();
    if kwds and _PyArg_NoKeywords("bool", kwds) == 0 {
        return NULL;
    }
    if PyArg_UnpackTuple(args, "bool", 0, 1, &mut x) == 0 {
        return NULL;
    }
    ok = PyObject_IsTrue(x);
    if ok < 0 {
        return NULL;
    }
    return PyBool_FromLong(i64(ok));
}

def bool_vectorcall(
    _type: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    ok: i64 = 0;
    if kwnames and _PyArg_NoKwnames("bool", kwnames) == 0 {
        return NULL;
    }
    nargs = PyVectorcall_NARGS(nargsf);
    if (nargs < 0 or nargs > 1) and _PyArg_CheckPositional("bool", nargs, 0, 1) == 0 {
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

# Arithmetic operations redefined to return bool if both args are bool.
def bool_invert(v: ptr[PyObject]) -> ptr[PyObject] {
    if PyErr_WarnEx(
        PyExc_DeprecationWarning,
        "Bitwise inversion '~' on bool is deprecated and will be removed in "
        "Python 3.16. This returns the bitwise inversion of the underlying int "
        "object and is usually not what you expect from negating "
        "a bool. Use the 'not' operator for boolean negation or "
        "~int(x) if you really want the bitwise inversion of the "
        "underlying int.",
        1
    )
        < 0 {
        return NULL;
    }
    return long_number().view(1)[0].nb_invert(v);
}

def bool_and(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_and(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) and (b == py_true())));
}

def bool_or(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_or(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) or (b == py_true())));
}

def bool_xor(a: ptr[PyObject], b: ptr[PyObject]) -> ptr[PyObject] {
    if not bool_check(a) or not bool_check(b) {
        return long_number().view(1)[0].nb_xor(a, b);
    }
    return PyBool_FromLong(i64((a == py_true()) != (b == py_true())));
}

# PyLong_Type.tp_as_number, the int slots bool defers to.
def long_number -> ptr[PyNumberMethods] {
    return addressof(PyLong_Type).view(1)[0].tp_as_number;
}

# This should never get called, but we also don't want to SEGV if we
# accidentally decref Booleans out of existence. Instead, since bools are
# immortal, re-set the reference count.
def bool_dealloc(boolean: ptr[PyObject]) {
    _Py_SetImmortal(boolean);
}
