/* P3.2e unicodeobject_core extract — UTF-8 kind / ASCII helpers.
 * Curated from reference/cpython Objects/unicodeobject.c (tiny slice).
 * Full unicode machinery remains deferred.
 */

#include "Python.h"

#include <stddef.h>

#define PyUnicode_1BYTE_KIND 1
#define PyUnicode_2BYTE_KIND 2
#define PyUnicode_4BYTE_KIND 4

int
unicode_kind_is_ascii(int kind, int maxchar)
{
    return kind == PyUnicode_1BYTE_KIND && maxchar < 128;
}

int
unicode_kind_width(int kind)
{
    return kind;
}

Py_ssize_t
unicode_nbytes(Py_ssize_t length, int kind)
{
    return length * (Py_ssize_t)kind;
}

int
unicode_is_empty(Py_ssize_t length)
{
    return length == 0;
}
