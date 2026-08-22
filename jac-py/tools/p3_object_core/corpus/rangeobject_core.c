/* P3.2c rangeobject core extract — get_len_of_range + contains-on-ints.
 * Curated from reference/cpython Objects/rangeobject.c.
 */

#include "Python.h"

#include <stddef.h>

/* Length of range(lo, hi, step) as unsigned long. step must be nonzero. */
unsigned long
get_len_of_range(long lo, long hi, long step)
{
    if (step > 0 && lo < hi)
        return 1UL + (hi - 1UL - lo) / (unsigned long)step;
    else if (step < 0 && lo > hi)
        return 1UL + (lo - 1UL - hi) / (0UL - (unsigned long)step);
    else
        return 0UL;
}

/* range_contains_long for plain C longs (no PyLong overflow path). */
int
range_contains_longs(long start, long stop, long step, long value)
{
    if (step > 0) {
        if (value < start || value >= stop) {
            return 0;
        }
    } else {
        if (value > start || value <= stop) {
            return 0;
        }
    }
    return ((value - start) % step) == 0;
}

int
range_equals_longs(
    long s0, long e0, long st0,
    long s1, long e1, long st1
)
{
    unsigned long len0 = get_len_of_range(s0, e0, st0);
    unsigned long len1 = get_len_of_range(s1, e1, st1);
    if (len0 != len1) {
        return 0;
    }
    if (len0 == 0) {
        return 1;
    }
    if (s0 != s1) {
        return 0;
    }
    if (len0 == 1) {
        return 1;
    }
    return st0 == st1;
}
