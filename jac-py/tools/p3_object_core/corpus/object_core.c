/* P3.2e object_core extract — identity richcompare + NotImplemented hash.
 * Curated from reference/cpython Objects/object.c.
 */

#include "Python.h"

#include <stddef.h>

Py_hash_t
object_hash_not_implemented(PyObject *v)
{
    (void)v;
    return -1;
}

int
object_richcompare_is(PyObject *a, PyObject *b)
{
    return a == b;
}

int
object_eq_identity(PyObject *a, PyObject *b, int op)
{
    int same = (a == b);
    if (op == Py_EQ) {
        return same;
    }
    if (op == Py_NE) {
        return !same;
    }
    return -1;
}
