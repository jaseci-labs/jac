/* P3.2e unionobject core extract — typing.Union flatten helpers.
 * Curated from reference/cpython Objects/unionobject.c.
 */

#include "Python.h"

#include <stddef.h>

int
union_args_len(Py_ssize_t n)
{
    return (int)n;
}

int
union_is_empty(Py_ssize_t n)
{
    return n == 0;
}

/* Union of one arg degenerates to that arg. */
int
union_singleton(Py_ssize_t n)
{
    return n == 1;
}
