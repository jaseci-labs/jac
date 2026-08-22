#ifndef PYCORE_SETOBJECT_H
#define PYCORE_SETOBJECT_H

#include "Python.h"

#define PySet_MINSIZE 8

typedef struct {
    PyObject *key;
    Py_hash_t hash;
} setentry;

typedef struct {
    PyObject ob_base;
    Py_ssize_t fill;
    Py_ssize_t used;
    Py_ssize_t mask;
    setentry *table;
    Py_hash_t hash;
    Py_ssize_t finger;
    setentry smalltable[PySet_MINSIZE];
    PyObject *weakreflist;
} PySetObject;

#define _PySet_CAST(so) ((PySetObject *)(so))

static inline Py_ssize_t
PySet_GET_SIZE(PyObject *so)
{
    return _PySet_CAST(so)->used;
}

#endif /* PYCORE_SETOBJECT_H */
