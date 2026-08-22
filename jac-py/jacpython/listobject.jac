# P3.2a — list core algorithms (richcompare, repr).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/listobject_core.c``
# (lift: ``jac-py/Objects/_lifted/listobject_core.jac``).
import from objects {
    PyObj,
    PyList,
    PyBool,
    PyStr,
    is_error,
    expect_str,
    _cmp3,
    _bool_from_cmp,
    _object_is_true,
    Py_LT,
    Py_LE,
    Py_EQ,
    Py_NE,
    Py_GT,
    Py_GE,
}

# CPython ``list_richcompare_impl`` — EQ/NE length shortcut, live size re-fetch.
# ``compare_fn`` is ``py_compare`` from ceval (element-wise dispatch + user slots).
def list_richcompare(op: int, vl: PyList, wl: PyList, compare_fn: any) -> PyObj {
    vlen = len(vl.items);
    wlen = len(wl.items);
    if vlen != wlen and (op == Py_EQ or op == Py_NE) {
        if op == Py_EQ {
            return PyBool(t="bool", val=False);
        }
        return PyBool(t="bool", val=True);
    }
    i = 0;
    while i < len(vl.items) and i < len(wl.items) {
        vitem = vl.items[i];
        witem = wl.items[i];
        if vitem is witem {
            i = i + 1;
            continue;
        }
        keq = compare_fn(2, vitem, witem);
        if is_error(keq) {
            return keq;
        }
        if not _object_is_true(keq) {
            break;
        }
        i = i + 1;
    }
    vlen = len(vl.items);
    wlen = len(wl.items);
    if i >= vlen or i >= wlen {
        return _bool_from_cmp(_cmp3(vlen, wlen), op);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=False);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=True);
    }
    return compare_fn(op, vl.items[i], wl.items[i]);
}

# CPython ``list_repr_impl``: strong ref per element, re-fetch length each step.
def list_repr(v: PyList, repr_elem: any) -> PyObj {
    if len(v.items) == 0 {
        return PyStr(t="str", val="[]");
    }
    out = "[";
    i = 0;
    while i < len(v.items) {
        if i > 0 {
            out = out + ", ";
        }
        item = v.items[i];
        piece = repr_elem(item);
        if is_error(piece) {
            return piece;
        }
        out = out + expect_str(piece);
        i = i + 1;
    }
    return PyStr(t="str", val=out + "]");
}
