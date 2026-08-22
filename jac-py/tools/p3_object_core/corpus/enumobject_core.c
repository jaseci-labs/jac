/* P3.2c enumobject core extract — enumerate index advance helpers.
 * Curated from reference/cpython Objects/enumobject.c.
 */

#include "Python.h"

#include <stddef.h>
#include <limits.h>

#ifndef PY_SSIZE_T_MAX
#define PY_SSIZE_T_MAX ((Py_ssize_t)(((size_t)-1) >> 1))
#endif

/* True when enum_next must switch to the long-index path. */
int
enum_index_at_max(Py_ssize_t en_index)
{
    return en_index == PY_SSIZE_T_MAX;
}

/* Advance enumerate index; returns next index to yield. */
Py_ssize_t
enum_advance_index(Py_ssize_t en_index)
{
    return en_index + 1;
}

/* reversed index after yielding current (count-style countdown). */
Py_ssize_t
reversed_advance_index(Py_ssize_t index)
{
    return index - 1;
}

/* Initial reversed index for a sequence of length n. */
Py_ssize_t
reversed_start_index(Py_ssize_t n)
{
    return n - 1;
}
