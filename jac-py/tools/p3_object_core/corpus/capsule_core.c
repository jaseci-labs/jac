/* P3.2e capsule_core extract — PyCapsule name/pointer guards.
 * Curated from reference/cpython Objects/capsule.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    void *pointer;
    const char *name;
    void *context;
} PyCapsule;

#define _PyCapsule_CAST(op) ((PyCapsule *)(op))

int
capsule_name_matches(const char *a, const char *b)
{
    if (a == NULL && b == NULL) {
        return 1;
    }
    if (a == NULL || b == NULL) {
        return 0;
    }
    while (*a && *a == *b) {
        a++;
        b++;
    }
    return *a == *b;
}

int
capsule_pointer_is_null(void *pointer)
{
    return pointer == NULL;
}

const char *
capsule_repr_prefix(void)
{
    return "<capsule object ";
}
