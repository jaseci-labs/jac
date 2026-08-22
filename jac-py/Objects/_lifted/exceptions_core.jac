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
     Py_hash_t = int;

@__jac_value__
obj PyVarObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0;
}

glob digit = int,
     stwodigits = int,
     sdigit = int,
     _Pyuintptr_t = int,
     Py_uhash_t = int;


@__jac_value__
obj lenfunc {
    def call -> int {
        ;
    }
}

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
obj hashfunc {
    def call -> int {
        ;
    }
}

@__jac_value__
obj richcmpfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj getiterfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj iternextfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj ssizeargfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc(),
        sq_item: ssizeargfunc = ssizeargfunc(),
        sq_contains: inquiry = inquiry();
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
        tp_as_sequence: PySequenceMethods = PySequenceMethods(),
        tp_hash: hashfunc = hashfunc(),
        tp_richcompare: richcmpfunc = richcmpfunc(),
        tp_iter: getiterfunc = getiterfunc(),
        tp_iternext: iternextfunc = iternextfunc(),
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


glob Py_UCS1 = int;

@__jac_value__
obj PyBaseExceptionObject {
    has ob_base: PyObject = PyObject(),
        dict: PyObj = PyObj(),
        args: PyObj = PyObj(),
        notes: PyObj = PyObj(),
        traceback: PyObj = PyObj(),
        context: PyObj = PyObj(),
        cause: PyObj = PyObj(),
        suppress_context: int = 0;
}


@__jac_value__
obj PyTupleObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        ob_item: list = list();
}


def PyBaseExceptionObject_CAST(exc: PyObj) -> PyBaseExceptionObject {
    return exc;
}

def BaseException_str(op: PyObj) -> PyObj {
    `self: PyBaseExceptionObject = PyBaseExceptionObject_CAST(op);
    res: PyObj = PyObj();
    n: int = 0;

    n = `self.args.ob_size;
    if n == 0 {
        res = Py_GetEmptyString();
    } elif n == 1 {
        res = PyObject_Str(`self.args.ob_item[0]);
    } else {
        res = PyObject_Str(`self.args);
    }

    return res;
}

def BaseException_repr(op: PyObj) -> PyObj {
    `self: PyBaseExceptionObject = PyBaseExceptionObject_CAST(op);
    name: str = _PyType_Name(`self.ob_type);
    n: int = `self.args.ob_size;

    if (n == 1) {
        return PyUnicode_FromFormat("%s(%R)", name, `self.args.ob_item[0]);
    }

    return PyUnicode_FromFormat("%s%R", name, `self.args);
}

def PyException_GetTraceback(`self: PyObj) -> PyObj {
    exc: PyBaseExceptionObject = PyBaseExceptionObject_CAST(`self);
    return exc.traceback;
}

def PyException_GetCause(`self: PyObj) -> PyObj {
    exc: PyBaseExceptionObject = PyBaseExceptionObject_CAST(`self);
    return exc.cause;
}

def PyException_GetContext(`self: PyObj) -> PyObj {
    exc: PyBaseExceptionObject = PyBaseExceptionObject_CAST(`self);
    return exc.context;
}

def PyException_GetArgs(`self: PyObj) -> PyObj {
    exc: PyBaseExceptionObject = PyBaseExceptionObject_CAST(`self);
    return exc.args;
}

def PyException_SetArgs(`self: PyObj, args: PyObj) {
    exc: PyBaseExceptionObject = PyBaseExceptionObject_CAST(`self);
    ;
    Py_XSETREF(exc.args, args);
}

def PyExceptionClass_Name(ob: PyObj) -> str {
    return ob.tp_name;
}


def PyErr_GivenExceptionMatches(err: PyObj, exc: PyObj) -> int {
    i: int = 0;
    n: int = 0;

    if ((err == 0) or (exc == 0)) {
        return 0;
    }

    if (exc.ob_type == PyTuple_Type) {
        n = exc.ob_size;
        for i = 0 while i < n with i += 1 {
            if PyErr_GivenExceptionMatches(err, exc.ob_item[i]) {
                return 1;
            }
        }

        return 0;
    }

    if ((err.ob_type.tp_flags & (1 << 30)) != 0) {
        err = err.ob_type;
    }

    if (
        ((err.ob_type == PyType_Type) and ((err.tp_flags & (1 << 30)) != 0))
        and ((exc.ob_type == PyType_Type) and ((exc.tp_flags & (1 << 30)) != 0))
    ) {
        return PyType_IsSubtype(err, exc);
    }

    return (err == exc);
}
