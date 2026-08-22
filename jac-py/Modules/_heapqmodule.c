/* Header-free extract of CPython Modules/_heapqmodule.c (siftdown core). */

#include "Python.h"
#include "pycore_list.h"
#include "pycore_pyatomic_ft_wrappers.h"

PyObject *PyExc_IndexError;
PyObject *PyExc_RuntimeError;

static int
siftdown(PyListObject *heap, Py_ssize_t startpos, Py_ssize_t pos)
{
    PyObject *newitem, *parent, **arr;
    Py_ssize_t parentpos, size;
    int cmp;

    size = PyList_GET_SIZE(heap);
    if (pos >= size) {
        PyErr_SetString(PyExc_IndexError, "index out of range");
        return -1;
    }

    arr = _PyList_ITEMS(heap);
    newitem = arr[pos];
    while (pos > startpos) {
        parentpos = (pos - 1) >> 1;
        parent = arr[parentpos];
        Py_INCREF(newitem);
        Py_INCREF(parent);
        cmp = PyObject_RichCompareBool(newitem, parent, Py_LT);
        Py_DECREF(parent);
        Py_DECREF(newitem);
        if (cmp < 0)
            return -1;
        if (size != PyList_GET_SIZE(heap)) {
            PyErr_SetString(PyExc_RuntimeError,
                            "list changed size during iteration");
            return -1;
        }
        if (cmp == 0)
            break;
        arr = _PyList_ITEMS(heap);
        arr[pos] = parent;
        arr[parentpos] = newitem;
        pos = parentpos;
    }
    return 0;
}

int heap_siftdown(PyObject *heap, Py_ssize_t startpos, Py_ssize_t pos) {
    return siftdown((PyListObject *)heap, startpos, pos);
}
