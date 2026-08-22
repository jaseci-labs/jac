/* P3.1c sliceobject core extract — PySlice_AdjustIndices helpers.
 * Curated from reference/cpython Objects/sliceobject.c.
 */

#include "Python.h"

#include <stddef.h>

static Py_ssize_t
adjust_index(Py_ssize_t i, Py_ssize_t length, int neg)
{
    if (i < 0) {
        i += length;
        if (i < 0)
            return neg ? -1 : 0;
    }
    else if (i >= length) {
        return neg ? length - 1 : length;
    }
    return i;
}

int
PySlice_AdjustIndices(Py_ssize_t length, Py_ssize_t *start, Py_ssize_t *stop,
                       Py_ssize_t step)
{
    Py_ssize_t cur_start, cur_stop, cur_step;
    int neg;

    cur_step = step;
    neg = cur_step < 0;

    if (*start == PY_SSIZE_T_MAX) {
        *start = neg ? length - 1 : 0;
    }
    else {
        *start = adjust_index(*start, length, neg);
    }

    if (*stop == PY_SSIZE_T_MAX) {
        *stop = neg ? -1 : length;
    }
    else {
        *stop = adjust_index(*stop, length, neg);
    }

    cur_start = *start;
    cur_stop = *stop;

    if ((cur_step < 0 && cur_stop < cur_start) ||
        (cur_step > 0 && cur_start < cur_stop))
        return 1;
    return 0;
}
