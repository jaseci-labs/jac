"""The object header operations of Include/object.h, inline in Jac.

CPython defines Py_TYPE, Py_IS_TYPE, Py_SIZE and PyType_HasFeature as static
inline functions; object ports read the header through the layouts instead of
calling the exported compatibility functions. See ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    PyObject
}
import from jaclang.runtime.python.layouts { PyTypeObject, PyVarObject, _object }

"""Py_TYPE: the type of `op` (borrowed)."""
def object_type(op: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[_object](op).view(1)[0].ob_type;
}

"""Py_IS_TYPE."""
def object_is_type(op: ptr[PyObject], type: ptr[PyTypeObject]) -> bool {
    return object_type(op) == type;
}

"""Py_SIZE: the item count of a variable-size object."""
def object_size(op: ptr[PyObject]) -> i64 {
    return ptr[PyVarObject](op).view(1)[0].ob_size;
}

"""PyType_HasFeature."""
def type_has_feature(type: ptr[PyTypeObject], feature: u64) -> bool {
    return (type.view(1)[0].tp_flags & feature) != u64(0);
}
