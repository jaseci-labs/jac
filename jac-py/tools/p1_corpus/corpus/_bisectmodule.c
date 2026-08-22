/* Header-free extract of CPython Modules/_bisectmodule.c (bisect_right core). */

#include "Python.h"

PyObject *PyExc_ValueError;
PyObject *PyExc_TypeError;
PyObject *Py_None;
PyObject *Py_True;
PyObject *Py_False;
PyObject *Py_NotImplemented;

static ssizeargfunc
get_sq_item(PyObject *s)
{
    PyTypeObject *tp = Py_TYPE(s);
    PySequenceMethods *m = tp->tp_as_sequence;
    if (m && m->sq_item) {
        return m->sq_item;
    }
    PyErr_SetString(PyExc_TypeError, "object does not support indexing");
    return NULL;
}

static Py_ssize_t
internal_bisect_right(PyObject *list, PyObject *item, Py_ssize_t lo, Py_ssize_t hi,
                      PyObject *key)
{
    PyObject *litem = NULL;
    Py_ssize_t mid;
    int res;

    if (lo < 0) {
        PyErr_SetString(PyExc_ValueError, "lo must be non-negative");
        return -1;
    }
    if (hi == -1) {
        hi = PySequence_Size(list);
        if (hi < 0)
            return -1;
    }
    ssizeargfunc sq_item = get_sq_item(list);
    if (sq_item == NULL) {
        return -1;
    }
    if (Py_EnterRecursiveCall(" in _bisect.bisect_right")) {
        return -1;
    }
    PyTypeObject *tp = Py_TYPE(item);
    richcmpfunc compare = tp->tp_richcompare;
    while (lo < hi) {
        mid = ((size_t)lo + hi) / 2;
        litem = sq_item(list, mid);
        if (litem == NULL) {
            Py_LeaveRecursiveCall();
            return -1;
        }
        if (key != Py_None) {
            PyObject *newitem = PyObject_CallOneArg(key, litem);
            if (newitem == NULL) {
                Py_DECREF(litem);
                Py_LeaveRecursiveCall();
                return -1;
            }
            Py_DECREF(litem);
            litem = newitem;
        }
        if (compare != NULL && Py_IS_TYPE(litem, tp)) {
            PyObject *res_obj = compare(item, litem, Py_LT);
            if (res_obj == Py_True) {
                Py_DECREF(res_obj);
                Py_DECREF(litem);
                litem = NULL;
                hi = mid;
                continue;
            }
            if (res_obj == Py_False) {
                Py_DECREF(res_obj);
                Py_DECREF(litem);
                litem = NULL;
                lo = mid + 1;
                continue;
            }
            if (res_obj == NULL) {
                Py_DECREF(litem);
                Py_LeaveRecursiveCall();
                return -1;
            }
            if (res_obj == Py_NotImplemented) {
                Py_DECREF(res_obj);
                compare = NULL;
                res = PyObject_RichCompareBool(item, litem, Py_LT);
            }
            else {
                res = PyObject_IsTrue(res_obj);
                Py_DECREF(res_obj);
            }
        }
        else {
            res = PyObject_RichCompareBool(item, litem, Py_LT);
        }
        if (res < 0) {
            Py_DECREF(litem);
            Py_LeaveRecursiveCall();
            return -1;
        }
        Py_DECREF(litem);
        litem = NULL;
        if (res)
            hi = mid;
        else
            lo = mid + 1;
    }
    Py_LeaveRecursiveCall();
    return lo;
}

Py_ssize_t bisect_right(PyObject *list, PyObject *item, Py_ssize_t lo, Py_ssize_t hi,
                        PyObject *key) {
    return internal_bisect_right(list, item, lo, hi, key);
}
