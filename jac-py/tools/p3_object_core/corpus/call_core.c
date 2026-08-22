/* P3.2e call_core extract — vectorcall nargs helpers.
 * Curated from reference/cpython Objects/call.c.
 * Avoids size_t high-bit masks that c2jac quarantines (UnaryOp ~).
 */

#include "Python.h"

#include <stddef.h>

/* Plain nargs path (offset bit already cleared by caller). */
Py_ssize_t
vectorcall_nargs_plain(Py_ssize_t nargs)
{
    return nargs;
}

int
vectorcall_args_ok(Py_ssize_t nargs, Py_ssize_t min_args)
{
    return nargs >= min_args;
}

int
vectorcall_kwargs_present(int nkwargs)
{
    return nkwargs > 0;
}
