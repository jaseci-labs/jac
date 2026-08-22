/* P3.2e picklebufobject_core extract — pickle buffer view helpers.
 * Curated from reference/cpython Objects/picklebufobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *view;
} PyPickleBufferObject;

#define _PyPickleBuffer_CAST(op) ((PyPickleBufferObject *)(op))

int
picklebuf_has_view(PyObject *view)
{
    return view != NULL;
}

int
picklebuf_released(PyObject *view)
{
    return view == NULL;
}
