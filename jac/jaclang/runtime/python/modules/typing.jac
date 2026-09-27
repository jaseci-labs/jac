import from jaclang.runtime.python.cpython_api { PyObject, Py_NewRef }

"""Primitives for the typing module; derived from CPython 3.14.6 Modules/_typingmodule.c."""
def _typing__idfunc_impl(module: ptr[PyObject], x: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(x);
}
