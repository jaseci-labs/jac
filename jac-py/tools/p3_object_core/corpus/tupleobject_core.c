/* P3.2a tupleobject core extract — hash, richcompare, sequence helpers.
 * Curated from reference/cpython Objects/tupleobject.c.
 */

#include "Python.h"
#include "pycore_tuple.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
    Py_hash_t ob_hash;
    PyObject *ob_item[1];
} PyTupleObject;

extern PyTypeObject PyTuple_Type;

#define PyTuple_Check(op) Py_IS_TYPE((op), &PyTuple_Type)
#define _PyTuple_CAST(op) ((PyTupleObject *)(op))
#define PyTuple_GET_SIZE(op) Py_SIZE(op)
#define PyTuple_GET_ITEM(op, i) (_PyTuple_CAST(op)->ob_item[i])

#define Py_RETURN_RICHCOMPARE(val1, val2, op)          \
    do {                                                 \
        switch (op) {                                    \
        case Py_EQ:                                      \
            if ((val1) == (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_NE:                                      \
            if ((val1) != (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_LT:                                      \
            if ((val1) < (val2))                         \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_GT:                                      \
            if ((val1) > (val2))                         \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_LE:                                      \
            if ((val1) <= (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_GE:                                      \
            if ((val1) >= (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        default:                                         \
            PyErr_BadInternalCall();                     \
            return NULL;                                 \
        }                                                \
    } while (0)

static Py_hash_t
tuple_hash(PyObject *op)
{
    PyTupleObject *v = _PyTuple_CAST(op);
    Py_ssize_t len;
    PyObject **item;
    Py_uhash_t acc;

    if (v->ob_hash != -1) {
        return v->ob_hash;
    }

    len = PyTuple_GET_SIZE(v);
    item = v->ob_item;
    acc = _PyTuple_HASH_XXPRIME_5;
    for (Py_ssize_t i = 0; i < len; i++) {
        Py_uhash_t lane = (Py_uhash_t)PyObject_Hash(item[i]);
        if (lane == (Py_uhash_t)-1) {
            return -1;
        }
        acc += lane * _PyTuple_HASH_XXPRIME_2;
        acc = _PyTuple_HASH_XXROTATE(acc);
        acc *= _PyTuple_HASH_XXPRIME_1;
    }

    acc += (Py_uhash_t)len ^ (_PyTuple_HASH_XXPRIME_5 ^ 3527539UL);

    if (acc == (Py_uhash_t)-1) {
        acc = 1546275796;
    }

    v->ob_hash = (Py_hash_t)acc;
    return (Py_hash_t)acc;
}

static Py_ssize_t
tuple_length(PyObject *self)
{
    PyTupleObject *a = _PyTuple_CAST(self);
    return PyTuple_GET_SIZE(a);
}

static int
tuple_contains(PyObject *self, PyObject *el)
{
    PyTupleObject *a = _PyTuple_CAST(self);
    int cmp = 0;
    for (Py_ssize_t i = 0; cmp == 0 && i < PyTuple_GET_SIZE(a); ++i) {
        cmp = PyObject_RichCompareBool(PyTuple_GET_ITEM(a, i), el, Py_EQ);
    }
    return cmp;
}

static PyObject *
tuple_item(PyObject *op, Py_ssize_t i)
{
    PyTupleObject *a = _PyTuple_CAST(op);
    if (i < 0 || i >= PyTuple_GET_SIZE(a)) {
        PyErr_SetString(PyExc_IndexError, "tuple index out of range");
        return NULL;
    }
    return Py_NewRef(a->ob_item[i]);
}

static PyObject *
tuple_richcompare(PyObject *v, PyObject *w, int op)
{
    PyTupleObject *vt, *wt;
    Py_ssize_t i;
    Py_ssize_t vlen, wlen;

    if (!PyTuple_Check(v) || !PyTuple_Check(w)) {
        return Py_NewRef(Py_NotImplemented);
    }

    vt = _PyTuple_CAST(v);
    wt = _PyTuple_CAST(w);

    vlen = PyTuple_GET_SIZE(vt);
    wlen = PyTuple_GET_SIZE(wt);

    for (i = 0; i < vlen && i < wlen; i++) {
        int k = PyObject_RichCompareBool(PyTuple_GET_ITEM(vt, i),
                                         PyTuple_GET_ITEM(wt, i), Py_EQ);
        if (k < 0) {
            return NULL;
        }
        if (!k) {
            break;
        }
    }

    if (i >= vlen || i >= wlen) {
        Py_RETURN_RICHCOMPARE(vlen, wlen, op);
    }

    if (op == Py_EQ) {
        return Py_NewRef(Py_False);
    }
    if (op == Py_NE) {
        return Py_NewRef(Py_True);
    }

    return PyObject_RichCompare(PyTuple_GET_ITEM(vt, i),
                                PyTuple_GET_ITEM(wt, i), op);
}
