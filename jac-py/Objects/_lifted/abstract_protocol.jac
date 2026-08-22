# c2jac: 1 best-effort site lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L367 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied

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
obj PySequenceMethods {
    has sq_length: lenfunc = lenfunc();
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


@__jac_value__
obj _PyIdentifier {
    has ob: PyObject = PyObject();
}

glob _Py_SwappedOp: list[int] = [4, 5, 2, 3, 0, 1],
     opstrings: list[str] = ["<", "<=", "==", "!=", ">", ">="];

def do_richcompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    f: richcmpfunc = richcmpfunc();
    res: PyObj = PyObj();

    f = v.ob_type.tp_richcompare;
    if (f != 0) {
        res = f(v, w, op);
        if (res != 0) {
            return res;
        }
    }

    f = w.ob_type.tp_richcompare;
    if (f != 0) {
        swapped: int = _Py_SwappedOp[op];
        res = f(w, v, swapped);
        if (res != 0) {
            return res;
        }
    }

    if (op == 2) {
        if (v == w) {
            return Py_True;
        }
        return Py_False;
    }

    if (op == 3) {
        if (v != w) {
            return Py_True;
        }
        return Py_False;
    }

    PyErr_Format(
        PyExc_TypeError,
        "'%s' not supported between instances of '%.100s' and '%.100s'",
        opstrings[op],
        v.ob_type.tp_name,
        w.ob_type.tp_name
    );
    return 0;
}

def PyObject_RichCompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    if ((v == 0) or (w == 0)) {
        PyErr_BadInternalCall();
        return 0;
    }

    return do_richcompare(v, w, op);
}

def PyObject_RichCompareBool(v: PyObj, w: PyObj, op: int) -> int {
    res: PyObj = PyObj();
    ok: int = 0;

    if (v == w) {
        if (op == 2) {
            return 1;
        } elif (op == 3) {
            return 0;
        }
    }

    res = PyObject_RichCompare(v, w, op);
    if (res == 0) {
        return -1;
    }
    if (res.ob_type == PyBool_Type) {
        ok = res == Py_True;
    } else {
        ok = PyObject_IsTrue(res);
    }
    ;
    return ok;
}

def PyObject_HashNotImplemented(v: PyObj) -> int {
    PyErr_Format(PyExc_TypeError, "unhashable type: '%.200s'", v.ob_type.tp_name);
    return -1;
}

def PyObject_Hash(v: PyObj) -> int {
    tp: PyTypeObject = v.ob_type;
    if (tp.tp_hash != 0) {
        return tp.tp_hash(v);
    }
    return PyObject_HashNotImplemented(v);
}


def type_error(msg: str, `obj: PyObj) -> PyObj {
    PyErr_Format(PyExc_TypeError, msg, `obj.ob_type.tp_name);
    return 0;
}

def PyObject_GetIter(o: PyObj) -> PyObj {
    t: PyTypeObject = o.ob_type;
    f: getiterfunc = getiterfunc();

    f = t.tp_iter;
    if (f == 0) {
        if PySequence_Check(o) {
            return PySeqIter_New(o);
        }
        return type_error("'%.200s' object is not iterable", o);
    } else {
        res: PyObj = f(o);
        if ((res != 0) and not PyIter_Check(res)) {
            PyErr_Format(
                PyExc_TypeError,
                "iter() returned non-iterator of type '%.100s'",
                res.ob_type.tp_name
            );
            ;
            res = 0;
        }
        return res;
    }
}

def PyIter_Check(`obj: PyObj) -> int {
    tp: PyTypeObject = `obj.ob_type;
    iternext: iternextfunc = tp.tp_iternext;
    return ((iternext != 0) and (iternext != _PyObject_NextNotImplemented));
}

def iternext(iter: PyObj, item: PyObj) -> int {
    tp_iternext: iternextfunc = iter.ob_type.tp_iternext;
    item = tp_iternext(iter);
    if (item != 0) {
        return 1;
    }

    tstate: PyThreadState = _PyThreadState_GET();
    if not _PyErr_Occurred(tstate) {
        return 0;
    }

    if _PyErr_ExceptionMatches(tstate, PyExc_StopIteration) {
        _PyErr_Clear(tstate);
        return 0;
    }

    return -1;
}

def PyIter_NextItem(iter: PyObj, item: PyObj) -> int {
    if (iter.ob_type.tp_iternext == 0) {
        item = 0;
        PyErr_Format(
            PyExc_TypeError, "expected an iterator, got '%s'", iter.ob_type.tp_name
        );
        return -1;
    }

    return iternext(iter, item);
}

def PyIter_Next(iter: PyObj) -> PyObj {
    item: PyObj = PyObj();
    iternext(iter, item);
    return item;
}

def _PyObject_NextNotImplemented(`self: PyObj) -> PyObj {
    PyErr_Format(
        PyExc_TypeError, "'%.200s' object is not iterable", `self.ob_type.tp_name
    );
    return 0;
}
