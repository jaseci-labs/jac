/* P3.2a typeobject core extract — name/repr/hash helpers, PyType_Ready stub,
 * richcompare for types. Curated from reference/cpython Objects/typeobject.c.
 * Heap-type creation and full type_ready() deferred per TODO.md.
 */

#include "Python.h"
#include "pycore_type.h"

#include <stddef.h>
#include <string.h>

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

#define CHECK_TYPEPAIR(v, w)                             \
    do {                                                 \
        if (!PyType_Check(v) || !PyType_Check(w))         \
            return Py_NewRef(Py_NotImplemented);           \
    } while (0)

const char *
_PyType_Name(PyTypeObject *type)
{
    const char *s;

    if (type->tp_name == NULL) {
        return "";
    }
    s = strrchr(type->tp_name, '.');
    if (s == NULL) {
        return type->tp_name;
    }
    return s + 1;
}

static PyObject *
type_name(PyObject *tp)
{
    PyTypeObject *type = PyTypeObject_CAST(tp);

    if (type->tp_flags & Py_TPFLAGS_HEAPTYPE) {
        PyHeapTypeObject *et = (PyHeapTypeObject *)type;
        if (et->ht_name != NULL) {
            return Py_NewRef(et->ht_name);
        }
    }
    return PyUnicode_FromString(_PyType_Name(type));
}

static PyObject *
type_repr(PyObject *self)
{
    PyTypeObject *type = PyTypeObject_CAST(self);

    if (type->tp_name == NULL) {
        return PyUnicode_FromFormat("<class at %p>", (void *)type);
    }
    return PyUnicode_FromFormat("<class '%s'>", type->tp_name);
}

static Py_hash_t
type_hash(PyObject *self)
{
    (void)self;
    return PyObject_HashNotImplemented(self);
}

static PyObject *
type_richcompare(PyObject *v, PyObject *w, int op)
{
    CHECK_TYPEPAIR(v, w);
    if (v == w) {
        if (op == Py_EQ) {
            return Py_NewRef(Py_True);
        }
        if (op == Py_NE) {
            return Py_NewRef(Py_False);
        }
        return Py_NewRef(Py_NotImplemented);
    }
    if (op == Py_EQ) {
        return Py_NewRef(Py_False);
    }
    if (op == Py_NE) {
        return Py_NewRef(Py_True);
    }
    return Py_NewRef(Py_NotImplemented);
}

int
PyType_Ready(PyTypeObject *type)
{
    if (type->tp_flags & Py_TPFLAGS_READY) {
        return 0;
    }
    if (type->tp_flags & Py_TPFLAGS_READYING) {
        PyErr_SetString(PyExc_TypeError, "type is being readied recursively");
        return -1;
    }
    type->tp_flags |= Py_TPFLAGS_READYING;
    /* Full type_ready() (MRO, slots, dict) deferred — mark ready only. */
    type->tp_flags &= ~Py_TPFLAGS_READYING;
    type->tp_flags |= Py_TPFLAGS_READY;
    return 0;
}
