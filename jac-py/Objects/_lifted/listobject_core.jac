# c2jac: 3 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L409 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L410 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L411 [W4201] cast to `void` elided — representation-changing conversion (truncation/narrowing/discard) not applied

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

def valid_index(i: int, limit: int) -> int {
    return (i < limit);
}

def list_get_item_ref(op: PyListObject, i: int) -> PyObj {
    if not valid_index(i, op.ob_size) {
        return 0;
    }

    return PyList_GET_ITEM(op, i);
}

def list_length(a: PyObj) -> int {
    return a.ob_size;
}

def list_contains(aa: PyObj, el: PyObj) -> int {
    i: int = 0;
    while True {
        item: PyObj = list_get_item_ref(aa, i);
        if (item == 0) {
            return 0;
        }

        cmp: int = PyObject_RichCompareBool(item, el, 2);
        ;
        if (cmp != 0) {
            return cmp;
        }
        i += 1;
    }

    return 0;
}

def list_item(aa: PyObj, i: int) -> PyObj {
    a: PyListObject = aa;
    if not valid_index(i, a.ob_size) {
        PyErr_SetString(PyExc_IndexError, "list index out of range");
        return 0;
    }

    return a.ob_item[i];
}

def list_repr_impl(v: PyListObject) -> PyObj {
    if (v.ob_size == 0) {
        return PyUnicode_FromString("[]");
    }

    result: PyObj = PyUnicode_FromString("[");
    if (result == 0) {
        return 0;
    }

    for i = 0 while i < v.ob_size with i += 1 {
        item: PyObj = v.ob_item[i];
        piece: PyObj = PyObject_Repr(item);
        ;
        if (piece == 0) {
            ;
            return 0;
        }

        if (i > 0) {
            sep: PyObj = PyUnicode_FromString(", ");
            if (sep == 0) {
                ;
                ;
                return 0;
            }

            ;
        }

        ;
    }

    close: PyObj = PyUnicode_FromString("]");
    if (close == 0) {
        ;
        return 0;
    }

    ;
    return result;
}

def list_repr(`self: PyObj) -> PyObj {
    if (`self.ob_size == 0) {
        return PyUnicode_FromString("[]");
    }

    return list_repr_impl(`self);
}

def list_richcompare_impl(v: PyObj, w: PyObj, op: int) -> PyObj {
    vl: PyListObject = PyListObject();
    wl: PyListObject = PyListObject();
    i: int = 0;

    if (not PyList_Check(v) or not PyList_Check(w)) {
        return Py_NotImplemented;
    }

    vl = v;
    wl = w;

    if ((vl.ob_size != wl.ob_size) and ((op == 2) or (op == 3))) {
        if (op == 2) {
            return Py_False;
        }

        return Py_True;
    }

    i = 0;
    while ((i < vl.ob_size) and (i < wl.ob_size)) {
        vitem: PyObj = vl.ob_item[i];
        witem: PyObj = wl.ob_item[i];
        if (vitem == witem) {
            i += 1;

            continue;
        }

        ;
        ;
        k: int = PyObject_RichCompareBool(vitem, witem, 2);
        ;
        ;
        if (k < 0) {
            return 0;
        }

        if not k {
            break;
        }
        i += 1;
    }

    if ((i >= vl.ob_size) or (i >= wl.ob_size)) {
        while True {
            if op == 2 {
                if (vl.ob_size == wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 3 {
                if (vl.ob_size != wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 0 {
                if (vl.ob_size < wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 4 {
                if (vl.ob_size > wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 1 {
                if (vl.ob_size <= wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 5 {
                if (vl.ob_size >= wl.ob_size) {
                    return Py_True;
                }
                return Py_False;
            } else {
                PyErr_BadInternalCall();
                return 0;
            }
            if not 0 {
                break;
            }
        }
    }

    if (op == 2) {
        return Py_False;
    }

    if (op == 3) {
        return Py_True;
    }

    vitem: PyObj = vl.ob_item[i];
    witem: PyObj = wl.ob_item[i];
    ;
    ;
    result: PyObj = PyObject_RichCompare(vl.ob_item[i], wl.ob_item[i], op);
    ;
    ;
    return result;
}

def list_richcompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    return list_richcompare_impl(v, w, op);
}


def list_sort_impl(`self: PyListObject, keyfunc: PyObj, reverse: int) -> PyObj {
    `self;
    keyfunc;
    reverse;
    return Py_None;
}

def PyList_Sort(v: PyObj) -> int {
    if ((v == 0) or not PyList_Check(v)) {
        PyErr_BadInternalCall();
        return -1;
    }

    result: PyObj = list_sort_impl(v, 0, 0);
    if (result == 0) {
        return -1;
    }

    ;
    return 0;
}
