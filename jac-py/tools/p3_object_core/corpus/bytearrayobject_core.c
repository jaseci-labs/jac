/* P3.2d bytearrayobject core extract — length/index helpers.
 * Curated from reference/cpython Objects/bytearrayobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject_HEAD
    Py_ssize_t ob_alloc;
    char *ob_bytes;
    Py_ssize_t ob_start;
    Py_ssize_t ob_exports;
} PyByteArrayObject;

#define _PyByteArray_CAST(op) ((PyByteArrayObject *)(op))

Py_ssize_t
bytearray_length(Py_ssize_t size)
{
    return size;
}

int
bytearray_valid_index(Py_ssize_t i, Py_ssize_t size)
{
    return (size_t)i < (size_t)size;
}

Py_ssize_t
bytearray_adjust_index(Py_ssize_t i, Py_ssize_t size)
{
    if (i < 0) {
        i += size;
    }
    return i;
}

int
bytearray_eq_lens(Py_ssize_t a, Py_ssize_t b)
{
    return a == b;
}
