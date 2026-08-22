/* P3.2e templateobject_core extract — PEP 750 template helpers.
 * Curated from reference/cpython Objects/templateobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *strings;
    PyObject *interpolations;
} templateobject;

int
template_nstrings(Py_ssize_t n)
{
    return (int)n;
}

int
template_ninterpolations(Py_ssize_t n)
{
    return (int)n;
}

int
template_is_empty(Py_ssize_t nstrings)
{
    return nstrings == 0;
}
