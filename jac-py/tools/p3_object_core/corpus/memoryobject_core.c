/* P3.2d memoryobject core extract — buffer length / contiguous flags.
 * Curated from reference/cpython Objects/memoryobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define PyBUF_SIMPLE 0
#define PyBUF_WRITABLE 0x0001
#define PyBUF_FORMAT 0x0004
#define PyBUF_ND 0x0008
#define PyBUF_STRIDES (0x0010 | PyBUF_ND)
#define PyBUF_C_CONTIGUOUS (0x0020 | PyBUF_STRIDES)
#define PyBUF_F_CONTIGUOUS (0x0040 | PyBUF_STRIDES)
#define PyBUF_ANY_CONTIGUOUS (0x0080 | PyBUF_STRIDES)

int
memoryview_flags_writable(int flags)
{
    return (flags & PyBUF_WRITABLE) != 0;
}

int
memoryview_flags_c_contiguous(int flags)
{
    return (flags & PyBUF_C_CONTIGUOUS) == PyBUF_C_CONTIGUOUS;
}

Py_ssize_t
memoryview_nbytes(Py_ssize_t len, Py_ssize_t itemsize)
{
    return len * itemsize;
}

int
memoryview_ndim_ok(int ndim)
{
    return ndim >= 0;
}
