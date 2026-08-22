/* P3.2c classobject core extract — bound-method accessors + EQ compare.
 * Curated from reference/cpython Objects/classobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *im_func;
    PyObject *im_self;
} PyMethodObject;

#define _PyMethodObject_CAST(op) ((PyMethodObject *)(op))

static inline int
PyMethod_Check(PyObject *op)
{
    (void)op;
    return 1;
}

PyObject *
PyMethod_Function(PyObject *im)
{
    if (!PyMethod_Check(im)) {
        return NULL;
    }
    return _PyMethodObject_CAST(im)->im_func;
}

PyObject *
PyMethod_Self(PyObject *im)
{
    if (!PyMethod_Check(im)) {
        return NULL;
    }
    return _PyMethodObject_CAST(im)->im_self;
}

/* method_richcompare EQ path: same func (by identity here) and same self. */
int
method_eq(PyObject *a_func, PyObject *a_self, PyObject *b_func, PyObject *b_self)
{
    if (a_func != b_func) {
        return 0;
    }
    return a_self == b_self;
}

/* Bound-method repr shape without pointer formatting. */
const char *
method_repr_prefix(void)
{
    return "<bound method ";
}
