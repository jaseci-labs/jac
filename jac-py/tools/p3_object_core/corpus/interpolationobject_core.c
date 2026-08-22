/* P3.2e interpolationobject_core extract — PEP 750 interpolation helpers.
 * Curated from reference/cpython Objects/interpolationobject.c.
 */

#include "Python.h"

#include <stddef.h>

typedef struct {
    PyObject ob_base;
    PyObject *value;
    PyObject *expression;
    int conversion;
} interpolationobject;

int
interpolation_has_expression(PyObject *expression)
{
    return expression != NULL;
}

int
interpolation_conversion_ok(int conversion)
{
    return conversion >= 0;
}
