# P3.1e — PyObject_* protocol helpers (comparison / iter / hash).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/abstract_protocol.c``
# (lift: ``jac-py/Objects/_lifted/abstract_protocol.jac``). Runtime uses Jac
# virtual slots on ``PyObj`` instead of C ``tp_*`` function pointers.
import from objects {
    PyObj,
    PyBool,
    PyInt,
    is_error,
    py_error,
    PY_NOT_IMPLEMENTED,
    Py_LT,
    Py_LE,
    Py_EQ,
    Py_NE,
    Py_GT,
    Py_GE,
    _object_is_true,
    _richcompare_to_bool,
    _signed_hash,
    _PY_SWAPPED_OP,
}


def PyObject_RichCompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    res = v.tp_richcompare(op, w);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    swapped = _PY_SWAPPED_OP[op];
    res = w.tp_richcompare(swapped, v);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=v is w);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=v is not w);
    }
    return py_error("TypeError", "unorderable types");
}

# Integer tri-state: 1 true, 0 false, -1 error (matches C API).
def PyObject_RichCompareBool(v: PyObj, w: PyObj, op: int) -> int {
    if v is w {
        if op == Py_EQ {
            return 1;
        }
        if op == Py_NE {
            return 0;
        }
    }
    res = PyObject_RichCompare(v, w, op);
    return _richcompare_to_bool(res);
}

# Deterministic digest of ``tp_hashkey()`` for dict/set keying only — not the
# user-facing ``hash()`` int (see ``hash_dispatch.hash_element`` / ``py_hash``).
def _hashkey_digest(hk: str) -> int {
    if hk.startswith("n:") {
        v = int(hk[2:]);
        if v == -1 {
            return -2;
        }
        return v;
    }
    h = 1469598103934665603;
    i = 0;
    while i < len(hk) {
        h = h ^ ord(hk[i]);
        h = (h * 1099511628211) & 0xFFFFFFFFFFFFFFFF;
        i = i + 1;
    }
    return _signed_hash(h);
}

def PyObject_HashNotImplemented(v: PyObj) -> PyObj {
    return py_error("TypeError", "unhashable type: '" + v.t + "'");
}

def PyObject_Hash(v: PyObj) -> PyObj {
    hk = v.tp_hashkey();
    if hk == "" {
        return PyObject_HashNotImplemented(v);
    }
    return PyInt(t="int", val=_hashkey_digest(hk));
}

# ``abstract.c`` iterator surface: ``tp_iter`` + iterator-type check.
def PyIter_Check(value: PyObj) -> bool {
    return value.t == "iter" or value.t == "generator" or value.t == "dictiter";
}

def PyObject_GetIter(o: PyObj) -> PyObj {
    res = o.tp_iter();
    if is_error(res) {
        return res;
    }
    if not PyIter_Check(res) {
        return py_error(
            "TypeError", "iter() returned non-iterator of type '" + res.t + "'"
        );
    }
    return res;
}
