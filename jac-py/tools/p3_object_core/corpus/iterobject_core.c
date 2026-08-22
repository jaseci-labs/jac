/* P3.2c iterobject core extract — seqiter length_hint + exhaustion.
 * Curated from reference/cpython Objects/iterobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    Py_ssize_t it_index;
    PyObject *it_seq;
} seqiterobject;

/* Remaining length hint: max(0, seqsize - index), or 0 if exhausted. */
Py_ssize_t
seqiter_length_hint(Py_ssize_t seqsize, Py_ssize_t it_index, int has_seq)
{
    Py_ssize_t len;
    if (!has_seq) {
        return 0;
    }
    len = seqsize - it_index;
    if (len >= 0) {
        return len;
    }
    return 0;
}

int
seqiter_exhausted(PyObject *it_seq)
{
    return it_seq == NULL;
}

Py_ssize_t
seqiter_next_index(Py_ssize_t it_index)
{
    return it_index + 1;
}
