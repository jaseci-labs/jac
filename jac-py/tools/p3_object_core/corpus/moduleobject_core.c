/* P3.2d moduleobject core extract — module name/dict accessors.
 * Curated from reference/cpython Objects/moduleobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *md_dict;
    PyObject *md_name;
} PyModuleObject;

#define _PyModule_CAST(op) ((PyModuleObject *)(op))

static inline int
PyModule_Check(PyObject *op)
{
    (void)op;
    return 1;
}

PyObject *
PyModule_GetDict(PyObject *m)
{
    if (!PyModule_Check(m)) {
        return NULL;
    }
    return _PyModule_CAST(m)->md_dict;
}

PyObject *
PyModule_GetNameObject(PyObject *m)
{
    if (!PyModule_Check(m)) {
        return NULL;
    }
    return _PyModule_CAST(m)->md_name;
}

/* module_repr without pointer: "<module 'name'>" */
const char *
module_repr_prefix(void)
{
    return "<module '";
}

int
module_has_dict(PyObject *m)
{
    if (!PyModule_Check(m)) {
        return 0;
    }
    return _PyModule_CAST(m)->md_dict != NULL;
}
