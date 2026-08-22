/* P3.2d odictobject core extract — OrderedDict move-to-end / equality notes.
 * Curated from reference/cpython Objects/odictobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define LAST 1
#define FIRST 0

/* move_to_end: last=1 appends; last=0 prepends. */
int
odict_move_to_end_last(int last)
{
    return last != 0;
}

/* OrderedDict equality requires same order; dict equality does not. */
int
odict_eq_requires_order(void)
{
    return 1;
}

int
odict_is_empty(Py_ssize_t size)
{
    return size == 0;
}
