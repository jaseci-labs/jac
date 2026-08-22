/* P3.2d weakrefobject core extract — proxy/ref kind helpers.
 * Curated from reference/cpython Objects/weakrefobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *wr_object;
    PyObject *wr_callback;
} PyWeakReference;

#define _PyWeakRef_CAST(op) ((PyWeakReference *)(op))

#define Py_None ((PyObject *)0) /* corpus-local: dead ref sentinel via NULL */

int
weakref_is_dead(PyObject *wr_object)
{
    return wr_object == NULL;
}

int
weakref_has_callback(PyObject *callback)
{
    return callback != NULL;
}

/* Alive weakref returns its referent; dead returns NULL. */
PyObject *
weakref_get_object(PyObject *wr_object)
{
    return wr_object;
}
