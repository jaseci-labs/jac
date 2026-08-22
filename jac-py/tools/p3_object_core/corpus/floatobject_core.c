/* P3.2c floatobject core extract — float hash entry + EQ compare lane.
 * Curated from reference/cpython Objects/floatobject.c.
 * Full shortest-repr lives in jacpython/floatobject.jac already.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    double ob_fval;
} PyFloatObject;

#define _PyFloat_CAST(op) ((PyFloatObject *)(op))

/* Stub — real algorithm in pyhash.jac. */
static Py_hash_t
_Py_HashDouble(PyObject *op, double v)
{
    (void)op;
    (void)v;
    return 0;
}

Py_hash_t
float_hash(PyObject *op)
{
    PyFloatObject *v = _PyFloat_CAST(op);
    return _Py_HashDouble(op, v->ob_fval);
}

/* float_richcompare EQ/NE identity shortcut for identical doubles. */
int
float_eq_doubles(double a, double b)
{
    /* NaN is never equal to itself in Python richcompare for floats —
     * CPython uses IEEE rules via direct == which is False for NaN. */
    return a == b;
}

int
float_ne_doubles(double a, double b)
{
    return a != b;
}
