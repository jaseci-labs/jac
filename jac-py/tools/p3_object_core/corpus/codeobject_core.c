/* P3.2d codeobject core extract — code flag / argcount helpers.
 * Curated from reference/cpython Objects/codeobject.c.
 */

#include "Python.h"

#include <stddef.h>

#define CO_OPTIMIZED    0x0001
#define CO_NEWLOCALS    0x0002
#define CO_VARARGS      0x0004
#define CO_VARKEYWORDS  0x0008
#define CO_NESTED       0x0010
#define CO_GENERATOR    0x0020
#define CO_COROUTINE    0x0080
#define CO_ASYNC_GENERATOR 0x0200

typedef struct {
    PyObject ob_base;
    int co_argcount;
    int co_posonlyargcount;
    int co_kwonlyargcount;
    int co_nlocals;
    int co_flags;
} PyCodeObject;

#define _PyCode_CAST(op) ((PyCodeObject *)(op))

int
code_is_generator(int flags)
{
    return (flags & CO_GENERATOR) != 0;
}

int
code_is_coroutine(int flags)
{
    return (flags & CO_COROUTINE) != 0;
}

int
code_has_varargs(int flags)
{
    return (flags & CO_VARARGS) != 0;
}

int
code_has_varkeywords(int flags)
{
    return (flags & CO_VARKEYWORDS) != 0;
}

int
code_total_argcount(int argcount, int kwonlyargcount)
{
    return argcount + kwonlyargcount;
}
