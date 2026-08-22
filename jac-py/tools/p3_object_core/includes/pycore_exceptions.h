#ifndef PYCORE_EXCEPTIONS_H
#define PYCORE_EXCEPTIONS_H

#include "Python.h"

#define PyException_HEAD \
    PyObject ob_base; \
    PyObject *dict; \
    PyObject *args; \
    PyObject *notes; \
    PyObject *traceback; \
    PyObject *context; \
    PyObject *cause; \
    char suppress_context;

typedef struct {
    PyException_HEAD
} PyBaseExceptionObject;

#define Py_TPFLAGS_BASETYPE (1UL << 10)
#define Py_TPFLAGS_HAVE_GC (1UL << 14)
#define Py_TPFLAGS_BASE_EXC_SUBCLASS (1UL << 30)

#define PyType_FastSubclass(t, f) (((t)->tp_flags & (f)) != 0)

#define PyExceptionClass_Check(x) \
    (PyType_Check(x) && \
     PyType_FastSubclass((PyTypeObject *)(x), Py_TPFLAGS_BASE_EXC_SUBCLASS))

#define PyExceptionInstance_Check(x) \
    PyType_FastSubclass(Py_TYPE(x), Py_TPFLAGS_BASE_EXC_SUBCLASS)

#define PyExceptionInstance_Class(x) ((PyObject *)Py_TYPE(x))

extern PyObject *PyExc_BaseException;

const char *PyExceptionClass_Name(PyObject *ob);
PyObject *PyException_GetArgs(PyObject *self);
void PyException_SetArgs(PyObject *self, PyObject *args);
PyObject *PyException_GetTraceback(PyObject *self);
PyObject *PyException_GetCause(PyObject *self);
PyObject *PyException_GetContext(PyObject *self);

#endif /* PYCORE_EXCEPTIONS_H */
