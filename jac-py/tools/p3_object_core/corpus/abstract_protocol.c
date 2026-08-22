/* P3.1e abstract protocol extract — hash, richcompare, and iterator helpers.
 * Curated from reference/cpython Objects/object.c and Objects/abstract.c.
 */

#include "Python.h"
#include "pycore_object.h"
#include "pycore_runtime.h"

#include <stddef.h>

/* --- object.c: rich comparison + hash --- */

int _Py_SwappedOp[] = {Py_GT, Py_GE, Py_EQ, Py_NE, Py_LT, Py_LE};

static const char * const opstrings[] = {"<", "<=", "==", "!=", ">", ">="};

static PyObject *
do_richcompare(PyObject *v, PyObject *w, int op)
{
    richcmpfunc f;
    PyObject *res;

    f = Py_TYPE(v)->tp_richcompare;
    if (f != NULL) {
        res = (*f)(v, w, op);
        if (res != NULL)
            return res;
    }
    f = Py_TYPE(w)->tp_richcompare;
    if (f != NULL) {
        int swapped = _Py_SwappedOp[op];
        res = (*f)(w, v, swapped);
        if (res != NULL)
            return res;
    }
    if (op == Py_EQ) {
        if (v == w)
            return Py_NewRef(Py_True);
        return Py_NewRef(Py_False);
    }
    if (op == Py_NE) {
        if (v != w)
            return Py_NewRef(Py_True);
        return Py_NewRef(Py_False);
    }
    PyErr_Format(PyExc_TypeError,
                 "'%s' not supported between instances of '%.100s' and '%.100s'",
                 opstrings[op],
                 Py_TYPE(v)->tp_name,
                 Py_TYPE(w)->tp_name);
    return NULL;
}

PyObject *
PyObject_RichCompare(PyObject *v, PyObject *w, int op)
{
    if (v == NULL || w == NULL) {
        PyErr_BadInternalCall();
        return NULL;
    }
    return do_richcompare(v, w, op);
}

int
PyObject_RichCompareBool(PyObject *v, PyObject *w, int op)
{
    PyObject *res;
    int ok;

    if (v == w) {
        if (op == Py_EQ)
            return 1;
        else if (op == Py_NE)
            return 0;
    }

    res = PyObject_RichCompare(v, w, op);
    if (res == NULL)
        return -1;
    if (PyBool_Check(res))
        ok = (res == Py_True);
    else
        ok = PyObject_IsTrue(res);
    Py_DECREF(res);
    return ok;
}

Py_hash_t
PyObject_HashNotImplemented(PyObject *v)
{
    PyErr_Format(PyExc_TypeError, "unhashable type: '%.200s'",
                 Py_TYPE(v)->tp_name);
    return -1;
}

Py_hash_t
PyObject_Hash(PyObject *v)
{
    PyTypeObject *tp = Py_TYPE(v);
    if (tp->tp_hash != NULL)
        return (*tp->tp_hash)(v);
    return PyObject_HashNotImplemented(v);
}

/* --- abstract.c: iteration protocol --- */

static PyObject *
type_error(const char *msg, PyObject *obj)
{
    PyErr_Format(PyExc_TypeError, msg, Py_TYPE(obj)->tp_name);
    return NULL;
}

PyObject *
PyObject_GetIter(PyObject *o)
{
    PyTypeObject *t = Py_TYPE(o);
    getiterfunc f;

    f = t->tp_iter;
    if (f == NULL) {
        if (PySequence_Check(o))
            return PySeqIter_New(o);
        return type_error("'%.200s' object is not iterable", o);
    }
    else {
        PyObject *res = (*f)(o);
        if (res != NULL && !PyIter_Check(res)) {
            PyErr_Format(PyExc_TypeError,
                         "iter() returned non-iterator "
                         "of type '%.100s'",
                         Py_TYPE(res)->tp_name);
            Py_DECREF(res);
            res = NULL;
        }
        return res;
    }
}

int
PyIter_Check(PyObject *obj)
{
    PyTypeObject *tp = Py_TYPE(obj);
    iternextfunc iternext = tp->tp_iternext;
    return (iternext != NULL &&
            iternext != _PyObject_NextNotImplemented);
}

static int
iternext(PyObject *iter, PyObject **item)
{
    iternextfunc tp_iternext = Py_TYPE(iter)->tp_iternext;
    *item = tp_iternext(iter);
    if (*item != NULL) {
        return 1;
    }

    PyThreadState *tstate = _PyThreadState_GET();
    if (!_PyErr_Occurred(tstate)) {
        return 0;
    }
    if (_PyErr_ExceptionMatches(tstate, PyExc_StopIteration)) {
        _PyErr_Clear(tstate);
        return 0;
    }
    return -1;
}

int
PyIter_NextItem(PyObject *iter, PyObject **item)
{
    if (Py_TYPE(iter)->tp_iternext == NULL) {
        *item = NULL;
        PyErr_Format(PyExc_TypeError, "expected an iterator, got '%s'",
                     Py_TYPE(iter)->tp_name);
        return -1;
    }

    return iternext(iter, item);
}

PyObject *
PyIter_Next(PyObject *iter)
{
    PyObject *item;
    (void)iternext(iter, &item);
    return item;
}

PyObject *
_PyObject_NextNotImplemented(PyObject *self)
{
    PyErr_Format(PyExc_TypeError,
                 "'%.200s' object is not iterable",
                 Py_TYPE(self)->tp_name);
    return NULL;
}
