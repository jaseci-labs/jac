#ifndef PYCORE_BYTES_H
#define PYCORE_BYTES_H

#include "Python.h"

typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
    Py_hash_t ob_hash;
    char ob_sval[1];
} PyBytesObject;

extern PyTypeObject PyBytes_Type;

#define PyBytes_Check(op) Py_IS_TYPE((op), &PyBytes_Type)
#define _PyBytes_CAST(op) ((PyBytesObject *)(op))
#define PyBytes_AS_STRING(op) (_PyBytes_CAST(op)->ob_sval)
#define PyBytes_GET_SIZE(op) Py_SIZE(op)

static inline void
set_ob_shash(PyBytesObject *a, Py_hash_t hash)
{
    a->ob_hash = hash;
}

static inline Py_hash_t
get_ob_shash(PyBytesObject *a)
{
    return a->ob_hash;
}

#endif /* PYCORE_BYTES_H */
