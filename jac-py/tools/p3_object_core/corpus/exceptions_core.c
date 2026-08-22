/* P3.2a exceptions core extract — BaseException str/repr and class helpers.
 * Curated from reference/cpython Objects/exceptions.c.
 */

#include "Python.h"
#include "pycore_exceptions.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
    PyObject *ob_item[1];
} PyTupleObject;

#define _PyTuple_CAST(op) ((PyTupleObject *)(op))
#define PyTuple_GET_SIZE(op) (_PyTuple_CAST(op)->ob_size)
#define PyTuple_GET_ITEM(op, i) (_PyTuple_CAST(op)->ob_item[i])

static inline PyBaseExceptionObject *
PyBaseExceptionObject_CAST(PyObject *exc)
{
    return (PyBaseExceptionObject *)exc;
}

static PyObject *
BaseException_str(PyObject *op)
{
    PyBaseExceptionObject *self = PyBaseExceptionObject_CAST(op);
    PyObject *res;
    Py_ssize_t n;

    n = PyTuple_GET_SIZE(self->args);
    switch (n) {
    case 0:
        res = Py_GetEmptyString();
        break;
    case 1:
        res = PyObject_Str(PyTuple_GET_ITEM(self->args, 0));
        break;
    default:
        res = PyObject_Str(self->args);
        break;
    }
    return res;
}

static PyObject *
BaseException_repr(PyObject *op)
{
    PyBaseExceptionObject *self = PyBaseExceptionObject_CAST(op);
    const char *name = _PyType_Name(Py_TYPE(self));
    Py_ssize_t n = PyTuple_GET_SIZE(self->args);

    if (n == 1) {
        return PyUnicode_FromFormat("%s(%R)", name,
                                    PyTuple_GET_ITEM(self->args, 0));
    }
    return PyUnicode_FromFormat("%s%R", name, self->args);
}

PyObject *
PyException_GetTraceback(PyObject *self)
{
    PyBaseExceptionObject *exc = PyBaseExceptionObject_CAST(self);
    return Py_XNewRef(exc->traceback);
}

PyObject *
PyException_GetCause(PyObject *self)
{
    PyBaseExceptionObject *exc = PyBaseExceptionObject_CAST(self);
    return Py_XNewRef(exc->cause);
}

PyObject *
PyException_GetContext(PyObject *self)
{
    PyBaseExceptionObject *exc = PyBaseExceptionObject_CAST(self);
    return Py_XNewRef(exc->context);
}

PyObject *
PyException_GetArgs(PyObject *self)
{
    PyBaseExceptionObject *exc = PyBaseExceptionObject_CAST(self);
    return Py_NewRef(exc->args);
}

void
PyException_SetArgs(PyObject *self, PyObject *args)
{
    PyBaseExceptionObject *exc = PyBaseExceptionObject_CAST(self);
    Py_INCREF(args);
    Py_XSETREF(exc->args, args);
}

const char *
PyExceptionClass_Name(PyObject *ob)
{
    return ((PyTypeObject *)ob)->tp_name;
}

/* PyErr_GivenExceptionMatches — except-handler isinstance primitive (from
 * Python/errors.c; paired with exception classes defined in exceptions.c). */
int
PyErr_GivenExceptionMatches(PyObject *err, PyObject *exc)
{
    Py_ssize_t i, n;

    if (err == NULL || exc == NULL) {
        return 0;
    }
    if (PyTuple_Check(exc)) {
        n = PyTuple_GET_SIZE(exc);
        for (i = 0; i < n; i++) {
            if (PyErr_GivenExceptionMatches(err, PyTuple_GET_ITEM(exc, i))) {
                return 1;
            }
        }
        return 0;
    }
    if (PyExceptionInstance_Check(err)) {
        err = PyExceptionInstance_Class(err);
    }
    if (PyExceptionClass_Check(err) && PyExceptionClass_Check(exc)) {
        return PyType_IsSubtype((PyTypeObject *)err, (PyTypeObject *)exc);
    }
    return err == exc;
}
