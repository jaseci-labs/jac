/* P3.2c cellobject core extract — empty-cell ordering + contents guards.
 * Curated from reference/cpython Objects/cellobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *ob_ref;
} PyCellObject;

#define _PyCell_CAST(op) ((PyCellObject *)(op))

static inline int
PyCell_Check(PyObject *op)
{
    (void)op;
    return 1;
}

static inline PyObject *
PyCell_GetRef(PyCellObject *op)
{
    return op->ob_ref;
}

/* Empty cells compare before filled ones (CPython cell_compare_impl). */
static int
cell_empty_before(PyObject *a_ref, PyObject *b_ref)
{
    if (a_ref == NULL && b_ref == NULL) {
        return 0;
    }
    if (a_ref == NULL) {
        return -1;
    }
    if (b_ref == NULL) {
        return 1;
    }
    return 2; /* both filled — caller does content compare */
}

static int
cell_is_empty(PyObject *op)
{
    return PyCell_GetRef(_PyCell_CAST(op)) == NULL;
}

static const char *
cell_repr_kind(PyObject *op)
{
    if (cell_is_empty(op)) {
        return "empty";
    }
    return "filled";
}
