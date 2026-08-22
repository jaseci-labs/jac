/* P3.2e genericaliasobject_core extract — typing.GenericAlias helpers.
 * Curated from reference/cpython Objects/genericaliasobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *origin;
    PyObject *args;
    PyObject *parameters;
} gaobject;

int
genericalias_has_args(PyObject *args)
{
    return args != NULL;
}

int
genericalias_nargs(Py_ssize_t n)
{
    return (int)n;
}

const char *
genericalias_repr_sep(void)
{
    return "[";
}
