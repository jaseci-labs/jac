#ifndef PYCORE_TYPE_H
#define PYCORE_TYPE_H

#include "Python.h"

#define PyTypeObject_CAST(op) ((PyTypeObject *)(op))

#ifndef Py_TPFLAGS_HEAPTYPE
#define Py_TPFLAGS_HEAPTYPE (1UL << 9)
#endif

#ifndef Py_TPFLAGS_READY
#define Py_TPFLAGS_READY (1UL << 12)
#endif

#ifndef Py_TPFLAGS_READYING
#define Py_TPFLAGS_READYING (1UL << 13)
#endif

typedef struct {
    PyTypeObject ht_type;
    PyObject *ht_name;
    PyObject *ht_qualname;
} PyHeapTypeObject;

const char *_PyType_Name(PyTypeObject *type);
int PyType_Ready(PyTypeObject *type);

#endif /* PYCORE_TYPE_H */
