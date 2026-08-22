# P3.2a — dict core algorithms (richcompare / equality on hashkey buckets).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/dictobject_core.c``
# (lift: ``jac-py/Objects/_lifted/dictobject_core.jac``).
#
# Runtime dicts use hashkey-backed ``dict[str, DictEntry]`` in ``objects.jac``;
# CPython's open-addressing table is not modeled. The c2jac reference lives in
# ``Objects/_lifted/dictobject_core.jac`` if a native table lands later.
import from objects { PyObj, PyDict, PyBool, PyStr, is_error, py_error, expect_str, _object_is_true, Py_EQ, Py_NE, }
import from abstract_protocol {
    PyObject_RichCompareBool,
}
# CPython dict equality adapted to PyDict hashkey buckets (``dict_equal_lock_held``).
# ``compare_fn`` is ``py_compare`` from ceval (element-wise dispatch + user slots).
def dict_equal(a: PyDict, b: PyDict, compare_fn: any) -> PyObj {
    if len(a.items) != len(b.items) {
        return PyBool(t="bool", val=False);
    }
    for hk in a.items {
        ak = a.items[hk].key;
        av = a.items[hk].value;
        if not (hk in b.items) {
            return PyBool(t="bool", val=False);
        }
        bk = b.items[hk].key;
        bv = b.items[hk].value;
        if ak is not bk {
            keq = compare_fn(Py_EQ, ak, bk);
            if is_error(keq) {
                return keq;
            }
            if not _object_is_true(keq) {
                return PyBool(t="bool", val=False);
            }
        }
        if av is not bv {
            veq = compare_fn(Py_EQ, av, bv);
            if is_error(veq) {
                return veq;
            }
            if not _object_is_true(veq) {
                return PyBool(t="bool", val=False);
            }
        }
    }
    return PyBool(t="bool", val=True);
}

def dict_richcompare(op: int, a: PyDict, b: PyDict, compare_fn: any) -> PyObj {
    if op != Py_EQ and op != Py_NE {
        return py_error(
            "TypeError", "'<' not supported between instances of 'dict' and 'dict'"
        );
    }
    eq = dict_equal(a, b, compare_fn);
    if is_error(eq) {
        return eq;
    }
    if op == Py_EQ {
        return eq;
    }
    return PyBool(t="bool", val=not _object_is_true(eq));
}

# CPython ``dict_repr_lock_held`` — insertion-order walk with strong refs.
def dict_repr(d: PyDict, repr_elem: any) -> PyObj {
    if len(d.items) == 0 {
        return PyStr(t="str", val="{}");
    }
    out = "{";
    first = True;
    for hk in d.items {
        `entry = d.items[hk];
        if not first {
            out = out + ", ";
        }
        first = False;
        kpiece = repr_elem(`entry.key);
        if is_error(kpiece) {
            return kpiece;
        }
        vpiece = repr_elem(`entry.value);
        if is_error(vpiece) {
            return vpiece;
        }
        out = out + expect_str(kpiece) + ": " + expect_str(vpiece);
    }
    return PyStr(t="str", val=out + "}");
}
