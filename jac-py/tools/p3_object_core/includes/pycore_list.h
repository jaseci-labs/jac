#ifndef PYCORE_LIST_H
#define PYCORE_LIST_H

#include "Python.h"

#define PyList_GET_SIZE(op) Py_SIZE(op)
#define PyList_GET_ITEM(op, i) (((PyListObject *)(op))->ob_item[i])

typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
    PyObject **ob_item;
} PyListObject;

extern PyTypeObject PyList_Type;

#define PyList_Check(op) Py_IS_TYPE((op), &PyList_Type)

#endif /* PYCORE_LIST_H */
