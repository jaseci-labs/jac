/* P3.2a listobject core extract — richcompare, repr, index helpers, sort stub.
 * Curated from reference/cpython Objects/listobject.c.
 */

#include "Python.h"
#include "pycore_list.h"

#include <stddef.h>

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

#define Py_RETURN_FALSE return Py_NewRef(Py_False)
#define Py_RETURN_TRUE return Py_NewRef(Py_True)
#define Py_RETURN_NOTIMPLEMENTED return Py_NewRef(Py_NotImplemented)

static inline int
valid_index(Py_ssize_t i, Py_ssize_t limit)
{
    return (size_t)i < (size_t)limit;
}

static inline PyObject *
list_get_item_ref(PyListObject *op, Py_ssize_t i)
{
    if (!valid_index(i, Py_SIZE(op))) {
        return NULL;
    }
    return Py_NewRef(PyList_GET_ITEM(op, i));
}

static Py_ssize_t
list_length(PyObject *a)
{
    return PyList_GET_SIZE(a);
}

static int
list_contains(PyObject *aa, PyObject *el)
{
    for (Py_ssize_t i = 0; ; i++) {
        PyObject *item = list_get_item_ref((PyListObject *)aa, i);
        if (item == NULL) {
            return 0;
        }
        int cmp = PyObject_RichCompareBool(item, el, Py_EQ);
        Py_DECREF(item);
        if (cmp != 0) {
            return cmp;
        }
    }
    return 0;
}

static PyObject *
list_item(PyObject *aa, Py_ssize_t i)
{
    PyListObject *a = (PyListObject *)aa;
    if (!valid_index(i, PyList_GET_SIZE(a))) {
        PyErr_SetString(PyExc_IndexError, "list index out of range");
        return NULL;
    }
    return Py_NewRef(a->ob_item[i]);
}

static PyObject *
list_repr_impl(PyListObject *v)
{
    if (Py_SIZE(v) == 0) {
        return PyUnicode_FromString("[]");
    }

    PyObject *result = PyUnicode_FromString("[");
    if (result == NULL) {
        return NULL;
    }

    for (Py_ssize_t i = 0; i < Py_SIZE(v); ++i) {
        PyObject *item = Py_NewRef(v->ob_item[i]);
        PyObject *piece = PyObject_Repr(item);
        Py_DECREF(item);
        if (piece == NULL) {
            Py_DECREF(result);
            return NULL;
        }
        if (i > 0) {
            PyObject *sep = PyUnicode_FromString(", ");
            if (sep == NULL) {
                Py_DECREF(piece);
                Py_DECREF(result);
                return NULL;
            }
            Py_DECREF(sep);
        }
        Py_DECREF(piece);
    }

    PyObject *close = PyUnicode_FromString("]");
    if (close == NULL) {
        Py_DECREF(result);
        return NULL;
    }
    Py_DECREF(close);
    return result;
}

static PyObject *
list_repr(PyObject *self)
{
    if (PyList_GET_SIZE(self) == 0) {
        return PyUnicode_FromString("[]");
    }
    return list_repr_impl((PyListObject *)self);
}

static PyObject *
list_richcompare_impl(PyObject *v, PyObject *w, int op)
{
    PyListObject *vl, *wl;
    Py_ssize_t i;

    if (!PyList_Check(v) || !PyList_Check(w)) {
        Py_RETURN_NOTIMPLEMENTED;
    }

    vl = (PyListObject *)v;
    wl = (PyListObject *)w;

    if (Py_SIZE(vl) != Py_SIZE(wl) && (op == Py_EQ || op == Py_NE)) {
        if (op == Py_EQ) {
            Py_RETURN_FALSE;
        }
        Py_RETURN_TRUE;
    }

    for (i = 0; i < Py_SIZE(vl) && i < Py_SIZE(wl); i++) {
        PyObject *vitem = vl->ob_item[i];
        PyObject *witem = wl->ob_item[i];
        if (vitem == witem) {
            continue;
        }

        Py_INCREF(vitem);
        Py_INCREF(witem);
        int k = PyObject_RichCompareBool(vitem, witem, Py_EQ);
        Py_DECREF(vitem);
        Py_DECREF(witem);
        if (k < 0) {
            return NULL;
        }
        if (!k) {
            break;
        }
    }

    if (i >= Py_SIZE(vl) || i >= Py_SIZE(wl)) {
        Py_RETURN_RICHCOMPARE(Py_SIZE(vl), Py_SIZE(wl), op);
    }

    if (op == Py_EQ) {
        Py_RETURN_FALSE;
    }
    if (op == Py_NE) {
        Py_RETURN_TRUE;
    }

    PyObject *vitem = vl->ob_item[i];
    PyObject *witem = wl->ob_item[i];
    Py_INCREF(vitem);
    Py_INCREF(witem);
    PyObject *result = PyObject_RichCompare(vl->ob_item[i], wl->ob_item[i], op);
    Py_DECREF(vitem);
    Py_DECREF(witem);
    return result;
}

static PyObject *
list_richcompare(PyObject *v, PyObject *w, int op)
{
    return list_richcompare_impl(v, w, op);
}

/* TimSort entry point — stub only (full sort lives in listobject.c). */
static PyObject *
list_sort_impl(PyListObject *self, PyObject *keyfunc, int reverse)
{
    (void)self;
    (void)keyfunc;
    (void)reverse;
    return Py_NewRef(Py_None);
}

int
PyList_Sort(PyObject *v)
{
    if (v == NULL || !PyList_Check(v)) {
        PyErr_BadInternalCall();
        return -1;
    }
    PyObject *result = list_sort_impl((PyListObject *)v, NULL, 0);
    if (result == NULL) {
        return -1;
    }
    Py_DECREF(result);
    return 0;
}
