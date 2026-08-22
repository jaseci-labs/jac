/* P3.2c funcobject core extract — function attribute helpers.
 * Curated from reference/cpython Objects/funcobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *func_name;
    PyObject *func_defaults;
    PyObject *func_kwdefaults;
    PyObject *func_closure;
    PyObject *func_code;
} PyFunctionObject;

#define _PyFunction_CAST(op) ((PyFunctionObject *)(op))

static inline int
PyFunction_Check(PyObject *op)
{
    (void)op;
    return 1;
}

PyObject *
PyFunction_GetName(PyObject *op)
{
    if (!PyFunction_Check(op)) {
        return NULL;
    }
    return _PyFunction_CAST(op)->func_name;
}

PyObject *
PyFunction_GetDefaults(PyObject *op)
{
    if (!PyFunction_Check(op)) {
        return NULL;
    }
    return _PyFunction_CAST(op)->func_defaults;
}

PyObject *
PyFunction_GetKwDefaults(PyObject *op)
{
    if (!PyFunction_Check(op)) {
        return NULL;
    }
    return _PyFunction_CAST(op)->func_kwdefaults;
}

int
func_has_closure(PyObject *op)
{
    if (!PyFunction_Check(op)) {
        return 0;
    }
    return _PyFunction_CAST(op)->func_closure != NULL;
}

/* Built-in function vs user function repr prefix. */
const char *
func_repr_prefix(int is_builtin)
{
    if (is_builtin) {
        return "<built-in function ";
    }
    return "<function ";
}
