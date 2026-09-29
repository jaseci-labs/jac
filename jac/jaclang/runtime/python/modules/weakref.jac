"""Weak-reference support; derived from CPython 3.14.6 Modules/_weakref.c.

The weakref types and the per-object reference list belong to the object
model (Objects/weakrefobject.c); this module only exposes them.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyObject,
    PyWeakref_NewProxy,
    Py_NewRef,
    _PyWeakref_GetWeakrefCount,
    jacpy_remove_dead_weakref,
    jacpy_weakref_list
}
import from jaclang.runtime.python.bindings.converters { borrowed_none }

def _weakref_getweakrefcount_impl(module: ptr[PyObject], object: ptr[PyObject]) -> i64 {
    return _PyWeakref_GetWeakrefCount(object);
}

def _weakref__remove_dead_weakref_impl(
    module: ptr[PyObject], dct: ptr[PyObject], key: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_remove_dead_weakref(dct, key) < 0 {
        return NULL;
    }
    return Py_NewRef(borrowed_none());
}

def _weakref_getweakrefs_impl(
    module: ptr[PyObject], object: ptr[PyObject]
) -> ptr[PyObject] {
    return jacpy_weakref_list(object);
}

def _weakref_proxy_impl(
    module: ptr[PyObject], object: ptr[PyObject], callback: ptr[PyObject]
) -> ptr[PyObject] {
    return PyWeakref_NewProxy(object, callback);
}
