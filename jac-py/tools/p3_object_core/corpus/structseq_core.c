/* P3.2e structseq_core extract — struct sequence field count helpers.
 * Curated from reference/cpython Objects/structseq.c.
 */

#include "Python.h"

#include <stddef.h>

int
structseq_n_in_sequence(int n_in_sequence)
{
    return n_in_sequence;
}

int
structseq_n_fields(int n_fields)
{
    return n_fields;
}

int
structseq_index_ok(Py_ssize_t i, Py_ssize_t n)
{
    return (size_t)i < (size_t)n;
}
