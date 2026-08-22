/* P3.2e typevarobject_core extract — TypeVar bound/constraint helpers.
 * Curated from reference/cpython Objects/typevarobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *name;
    PyObject *bound;
    PyObject *constraints;
    int covariant;
    int contravariant;
} typevarobject;

int
typevar_is_covariant(int covariant)
{
    return covariant != 0;
}

int
typevar_is_contravariant(int contravariant)
{
    return contravariant != 0;
}

int
typevar_has_bound(PyObject *bound)
{
    return bound != NULL;
}

int
typevar_has_constraints(PyObject *constraints)
{
    return constraints != NULL;
}
