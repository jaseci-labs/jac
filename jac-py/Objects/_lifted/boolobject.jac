# c2jac: 9 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L1 [W4209] designated initializer `.lv_tag=` — field name dropped, emitted positionally
#   L1 [W4209] designated initializer `.lv_tag=` — field name dropped, emitted positionally
#   L149 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L149 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L186 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L186 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder
#   L187 [W4201] cast to `Py_ssize_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L307 [W4290] C construct `Typename` has no faithful Jac lowering — emitted as a placeholder
#   L308 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder

glob ptrdiff_t = int,
     size_t = int,
     ssize_t = int,
     intptr_t = int,
     uintptr_t = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     intmax_t = int,
     uintmax_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     Py_ssize_t = int,
     Py_hash_t = int,
     digit = int,
     _Pyuintptr_t = int;

@__jac_value__
obj unaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj binaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj inquiry {
    def call -> int {
        ;
    }
}

@__jac_value__
obj vectorcallfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj PyNumberMethods {
    has nb_add: binaryfunc = binaryfunc(),
        nb_subtract: binaryfunc = binaryfunc(),
        nb_multiply: binaryfunc = binaryfunc(),
        nb_remainder: binaryfunc = binaryfunc(),
        nb_divmod: binaryfunc = binaryfunc(),
        nb_power: binaryfunc = binaryfunc(),
        nb_negative: binaryfunc = binaryfunc(),
        nb_positive: binaryfunc = binaryfunc(),
        nb_absolute: binaryfunc = binaryfunc(),
        nb_bool: inquiry = inquiry(),
        nb_invert: unaryfunc = unaryfunc(),
        nb_lshift: binaryfunc = binaryfunc(),
        nb_rshift: binaryfunc = binaryfunc(),
        nb_and: binaryfunc = binaryfunc(),
        nb_xor: binaryfunc = binaryfunc(),
        nb_or: binaryfunc = binaryfunc();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyTypeObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        tp_name: str = str(),
        tp_basicsize: int = 0,
        tp_itemsize: int = 0,
        tp_dealloc: object = object(),
        tp_repr: unaryfunc = unaryfunc(),
        tp_as_number: PyNumberMethods = PyNumberMethods(),
        tp_flags: int = 0,
        tp_doc: str = str(),
        tp_base: PyTypeObject = PyTypeObject(),
        tp_vectorcall: vectorcallfunc = vectorcallfunc();
}

@__jac_value__
obj _PyLongValue {
    has lv_tag: int = 0,
        ob_digit: list = list();
}

@__jac_value__
obj PyLongObject {
    has ob_base: PyObject = PyObject(),
        long_value: _PyLongValue = _PyLongValue();
}


@__jac_value__
obj _PyIdentifier {
    has ob: PyObject = PyObject();
}

def bool_repr(`self: PyObj) -> PyObj {
    raise "c2jac: quarantined function 'bool_repr' — L149 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder; L149 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder";
}


def PyBool_FromLong(ok: int) -> PyObj {
    return Py_True if ok else Py_False;
}


def bool_new(`type: PyTypeObject, args: PyObj, kwds: PyObj) -> PyObj {
    x: PyObj = Py_False;
    ok: int = 0;

    if not ((kwds == 0) or _PyArg_NoKeywords("bool", kwds)) {
        return 0;
    }
    if not PyArg_UnpackTuple(args, "bool", 0, 1, x) {
        return 0;
    }
    ok = PyObject_IsTrue(x);
    if (ok < 0) {
        return 0;
    }
    return PyBool_FromLong(ok);
}

def bool_vectorcall(`type: PyObj, args: PyObj, nargsf: int, kwnames: PyObj) -> PyObj {
    raise "c2jac: quarantined function 'bool_vectorcall' — L186 [W4290] C construct `UnaryOp` has no faithful Jac lowering — emitted as a placeholder";
}


def bool_invert(v: PyObj) -> PyObj {
    if (
        PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "Bitwise inversion '~' on bool is deprecated and will be removed in Python 3.16. This returns the bitwise inversion of the underlying int object and is usually not what you expect from negating a bool. Use the 'not' operator for boolean negation or ~int(x) if you really want the bitwise inversion of the underlying int.",
            1
        )
        < 0
    ) {
        return 0;
    }

    return PyLong_Type.tp_as_number.nb_invert(v);
}

def bool_and(a: PyObj, b: PyObj) -> PyObj {
    if (not (a.ob_type == PyBool_Type) or not (b.ob_type == PyBool_Type)) {
        return PyLong_Type.tp_as_number.nb_and(a, b);
    }
    return PyBool_FromLong(((a == Py_True) & (b == Py_True)));
}

def bool_or(a: PyObj, b: PyObj) -> PyObj {
    if (not (a.ob_type == PyBool_Type) or not (b.ob_type == PyBool_Type)) {
        return PyLong_Type.tp_as_number.nb_or(a, b);
    }
    return PyBool_FromLong(((a == Py_True) | (b == Py_True)));
}

def bool_xor(a: PyObj, b: PyObj) -> PyObj {
    if (not (a.ob_type == PyBool_Type) or not (b.ob_type == PyBool_Type)) {
        return PyLong_Type.tp_as_number.nb_xor(a, b);
    }
    return PyBool_FromLong(((a == Py_True) ^ (b == Py_True)));
}


glob bool_doc: list[int] = "bool(object=False, /)\n--\n\nReturns True when the argument is true, False otherwise.\nThe builtins True and False are the only two instances of the class bool.\nThe class bool is a subclass of the class int, and cannot be subclassed.",
     bool_as_number: PyNumberMethods = PyNumberMethods(
         nb_add=0,
         nb_subtract=0,
         nb_multiply=0,
         nb_remainder=0,
         nb_divmod=0,
         nb_power=0,
         nb_negative=0,
         nb_positive=0,
         nb_absolute=0,
         nb_bool=0,
         nb_invert=bool_invert,
         nb_lshift=0,
         nb_rshift=0,
         nb_and=bool_and,
         nb_xor=bool_xor,
         nb_or=bool_or
     );

def bool_dealloc(boolean: PyObj) {
    _Py_SetImmortal(boolean);
}


glob PyBool_Type: PyTypeObject = PyTypeObject(
         ob_base=PyObject(ob_type=[PyType_Type]),
         ob_size="bool",
         tp_name=offsetof(__c_unsupported__(307), long_value.ob_digit),
         tp_basicsize=__c_unsupported__(308),
         tp_itemsize=bool_dealloc,
         tp_dealloc=0,
         tp_repr=0,
         tp_as_number=0,
         tp_flags=0,
         tp_doc=bool_repr,
         tp_base=bool_as_number,
         tp_vectorcall=0
     ),
     _Py_FalseStruct: _longobject = [[PyBool_Type], [1, [0]]],
     _Py_TrueStruct: _longobject = [[PyBool_Type], [2, [1]]];
