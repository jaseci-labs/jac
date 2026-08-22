# P3.2a — str core algorithms (repr, hash).
import from objects { PyInt, PyObj, PyStr, str_repr_text, }
import from pyhash { str_hash_text, }

# CPython ``unicode_repr`` — smart quotes + escapes (see ``str_repr_text``).
def str_repr(v: PyStr) -> PyObj {
    return PyStr(t="str", val=str_repr_text(v.val));
}

# CPython ``unicode_hash`` — ``Py_HashBuffer`` on canonical unicode bytes.
def str_hash_obj(v: PyStr) -> PyObj {
    return PyInt(t="int", val=int(str_hash_text(v.val)));
}
