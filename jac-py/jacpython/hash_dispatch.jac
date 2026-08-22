# P3 — user-facing ``hash()`` dispatch for builtin ``PyObj`` types.
#
# ``tp_hashkey()`` + FNV (``abstract_protocol.PyObject_Hash``) is the internal
# dict/set key protocol only. ``hash()`` and container hashes (tuple/set lanes)
# must route through CPython algorithms (``long_hash``, native str/float hash,
# ``bytes_hash``, etc.).
import from objects { PyObj, PyInt, PyStr, PyFloat, PyBool, PyBytes, is_error, }
import from abstract_protocol { PyObject_HashNotImplemented, _hashkey_digest, }
import from longobject { long_hash_obj, long_hash, }
import from bytesobject { bytes_hash_obj, }
import from strobject { str_hash_obj, }
import from floatobject { float_hash_obj, }

# Element hash for tuple/set lanes and ``py_hash`` fallback (not tuples/sets).
def hash_element(v: PyObj) -> PyObj {
    if isinstance(v, PyInt) {
        return long_hash_obj(v as PyInt);
    }
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return PyInt(t="int", val=long_hash(1));
        }
        return PyInt(t="int", val=long_hash(0));
    }
    if isinstance(v, PyStr) {
        return str_hash_obj(v as PyStr);
    }
    if isinstance(v, PyFloat) {
        return float_hash_obj(v as PyFloat);
    }
    if isinstance(v, PyBytes) {
        return bytes_hash_obj(v as PyBytes);
    }
    hk = v.tp_hashkey();
    if hk == "" {
        return PyObject_HashNotImplemented(v);
    }
    return PyInt(t="int", val=_hashkey_digest(hk));
}
