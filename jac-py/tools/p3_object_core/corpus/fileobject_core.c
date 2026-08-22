/* P3.2e fileobject_core extract — PyFile_WriteObject flag helpers.
 * Curated from reference/cpython Objects/fileobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define Py_PRINT_RAW 1

int
file_print_raw(int flags)
{
    return (flags & Py_PRINT_RAW) != 0;
}

int
file_write_uses_str(int flags)
{
    return file_print_raw(flags);
}

int
file_write_uses_repr(int flags)
{
    return !file_print_raw(flags);
}
