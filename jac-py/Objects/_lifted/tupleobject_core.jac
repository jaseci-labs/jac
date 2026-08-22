# c2jac: 10 best-effort sites lowered with known infidelities (behavior/hole sites quarantine their containing function; module-scope holes remain as `__c_unsupported__`):
#   L250 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L252 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L253 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L256 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L258 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L261 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L261 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L263 [W4201] cast to `Py_uhash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L267 [W4201] cast to `Py_hash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied
#   L268 [W4201] cast to `Py_hash_t` elided — representation-changing conversion (truncation/narrowing/discard) not applied

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


glob Py_uhash_t = int;

@__jac_value__
obj PyTupleObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        ob_hash: int = 0,
        ob_item: list = list();
}


def tuple_hash(op: PyObj) -> int {
    v: PyTupleObject = op;
    len: int = 0;
    item: object = object();
    acc: Py_uhash_t = Py_uhash_t();

    if (v.ob_hash != -1) {
        return v.ob_hash;
    }

    len = Py_SIZE(v);
    item = v.ob_item;
    acc = 2870177450012600261;
    for i = 0 while i < len with i += 1 {
        lane: Py_uhash_t = PyObject_Hash(item[i]);
        if (lane == -1) {
            return -1;
        }

        acc += lane * 14029467366897019727;
        acc = (acc << 31) | (acc >> 33);
        acc *= 11400714785074694791;
    }

    acc += len ^ (2870177450012600261 ^ 3527539);

    if (acc == -1) {
        acc = 1546275796;
    }

    v.ob_hash = acc;
    return acc;
}

def tuple_length(`self: PyObj) -> int {
    a: PyTupleObject = `self;
    return Py_SIZE(a);
}

def tuple_contains(`self: PyObj, el: PyObj) -> int {
    a: PyTupleObject = `self;
    cmp: int = 0;
    i: int = 0;
    while ((cmp == 0) and (i < Py_SIZE(a))) {
        cmp = PyObject_RichCompareBool(a.ob_item[i], el, 2);
        i += 1;
    }

    return cmp;
}

def tuple_item(op: PyObj, i: int) -> PyObj {
    a: PyTupleObject = op;
    if ((i < 0) or (i >= Py_SIZE(a))) {
        PyErr_SetString(PyExc_IndexError, "tuple index out of range");
        return 0;
    }

    return a.ob_item[i];
}

def tuple_richcompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    vt: PyTupleObject = PyTupleObject();
    wt: PyTupleObject = PyTupleObject();
    i: int = 0;
    vlen: int = 0;
    wlen: int = 0;

    if (not (v.ob_type == PyTuple_Type) or not (w.ob_type == PyTuple_Type)) {
        return Py_NotImplemented;
    }

    vt = v;
    wt = w;

    vlen = Py_SIZE(vt);
    wlen = Py_SIZE(wt);

    i = 0;
    while ((i < vlen) and (i < wlen)) {
        k: int = PyObject_RichCompareBool(vt.ob_item[i], wt.ob_item[i], 2);
        if (k < 0) {
            return 0;
        }

        if not k {
            break;
        }
        i += 1;
    }

    if ((i >= vlen) or (i >= wlen)) {
        while True {
            if op == 2 {
                if (vlen == wlen) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 3 {
                if (vlen != wlen) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 0 {
                if (vlen < wlen) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 4 {
                if (vlen > wlen) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 1 {
                if (vlen <= wlen) {
                    return Py_True;
                }
                return Py_False;
            } elif op == 5 {
                if (vlen >= wlen) {
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

    return PyObject_RichCompare(vt.ob_item[i], wt.ob_item[i], op);
}
