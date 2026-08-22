# c2jac: Tier-B clean (no best-effort fidelity sites).

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
obj unaryfunc {
    def call -> PyObj {
        ;
    }
}

@__jac_value__
obj richcmpfunc {
    def call -> int {
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
    has sq_item: ssizeargfunc = ssizeargfunc();
}

@__jac_value__
obj PyTypeObject {
    has tp_name: str = str(),
        tp_as_sequence: PySequenceMethods = PySequenceMethods(),
        tp_richcompare: richcmpfunc = richcmpfunc();
}

@__jac_value__
obj PyListObject {
    has ob_base: PyObject = PyObject(),
        ob_size: int = 0,
        ob_item: object = object();
}

@__jac_value__
obj PyObject {
    has ob_type: PyTypeObject = PyTypeObject();
}


glob PyExc_ValueError: PyObj = PyObj(),
     PyExc_TypeError: PyObj = PyObj(),
     Py_None: PyObj = PyObj(),
     Py_True: PyObj = PyObj(),
     Py_False: PyObj = PyObj(),
     Py_NotImplemented: PyObj = PyObj();

def get_sq_item(s: PyObj) -> ssizeargfunc {
    tp: PyTypeObject = s.ob_type;
    m: PySequenceMethods = tp.tp_as_sequence;
    if (m and m.sq_item) {
        return m.sq_item;
    }

    PyErr_SetString(PyExc_TypeError, "object does not support indexing");
    return 0;
}

def internal_bisect_right(
    `list: PyObj, item: PyObj, lo: int, hi: int, key: PyObj
) -> int {
    litem: PyObj = 0;
    mid: int = 0;
    res: int = 0;

    if (lo < 0) {
        raise ValueError("lo must be non-negative");
    }

    if (hi == -1) {
        hi = PySequence_Size(`list);
        if (hi < 0) {
            return -1;
        }
    }

    sq_item: ssizeargfunc = get_sq_item(`list);
    if (sq_item == 0) {
        return -1;
    }

    if Py_EnterRecursiveCall(" in _bisect.bisect_right") {
        return -1;
    }

    tp: PyTypeObject = item.ob_type;
    compare: richcmpfunc = tp.tp_richcompare;
    while (lo < hi) {
        mid = (lo + hi) // 2;
        litem = sq_item(`list, mid);
        if (litem == 0) {
            Py_LeaveRecursiveCall();
            return -1;
        }

        if (key != Py_None) {
            newitem: PyObj = PyObject_CallOneArg(key, litem);
            if (newitem == 0) {
                ;
                Py_LeaveRecursiveCall();
                return -1;
            }

            ;
            litem = newitem;
        }

        if ((compare != 0) and (litem.ob_type == tp)) {
            res_obj: PyObj = compare(item, litem, 0);
            if (res_obj == Py_True) {
                ;
                ;
                litem = 0;
                hi = mid;
                continue;
            }

            if (res_obj == Py_False) {
                ;
                ;
                litem = 0;
                lo = mid + 1;
                continue;
            }

            if (res_obj == 0) {
                ;
                Py_LeaveRecursiveCall();
                return -1;
            }

            if (res_obj == Py_NotImplemented) {
                ;
                compare = 0;
                res = PyObject_RichCompareBool(item, litem, 0);
            } else {
                res = PyObject_IsTrue(res_obj);
                ;
            }
        } else {
            res = PyObject_RichCompareBool(item, litem, 0);
        }

        if (res < 0) {
            ;
            Py_LeaveRecursiveCall();
            return -1;
        }

        ;
        litem = 0;
        if res {
            hi = mid;
        } else {
            lo = mid + 1;
        }
    }

    Py_LeaveRecursiveCall();
    return lo;
}

def bisect_right(`list: PyObj, item: PyObj, lo: int, hi: int, key: PyObj) -> int {
    return internal_bisect_right(`list, item, lo, hi, key);
}
