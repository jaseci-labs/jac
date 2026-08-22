/* P3.2e namespaceobject core extract — SimpleNamespace helpers.
 * Curated from reference/cpython Objects/namespaceobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *ns_dict;
} _PyNamespaceObject;

#define _PyNamespace_CAST(op) ((_PyNamespaceObject *)(op))

int
namespace_has_dict(PyObject *ns_dict)
{
    return ns_dict != NULL;
}

const char *
namespace_repr_prefix(void)
{
    return "namespace(";
}
