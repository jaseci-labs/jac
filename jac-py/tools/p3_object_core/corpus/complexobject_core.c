/* P3.2c complexobject core extract — complex hash combination.
 * Curated from reference/cpython Objects/complexobject.c.
 */

#include "Python.h"

#include <stddef.h>

#ifndef _PyHASH_IMAG
#define _PyHASH_IMAG 1000003UL
#endif

typedef struct {
    double real;
    double imag;
} Py_complex;

typedef struct {
    PyObject ob_base;
    Py_complex cval;
} PyComplexObject;

#define _PyComplexObject_CAST(op) ((PyComplexObject *)(op))

/* Stub: real float hash lives in pyhash.jac / _Py_HashDouble. */
static Py_hash_t
_Py_HashDouble(PyObject *op, double v)
{
    (void)op;
    (void)v;
    return 0;
}

Py_hash_t
complex_hash_combine(Py_hash_t hashreal, Py_hash_t hashimag)
{
    Py_uhash_t combined;
    if (hashreal == -1 || hashimag == -1) {
        return -1;
    }
    combined = (Py_uhash_t)hashreal + _PyHASH_IMAG * (Py_uhash_t)hashimag;
    if (combined == (Py_uhash_t)-1) {
        combined = (Py_uhash_t)-2;
    }
    return (Py_hash_t)combined;
}

Py_hash_t
complex_hash(PyObject *op)
{
    PyComplexObject *v = _PyComplexObject_CAST(op);
    Py_hash_t hashreal = _Py_HashDouble(op, v->cval.real);
    Py_hash_t hashimag = _Py_HashDouble(op, v->cval.imag);
    return complex_hash_combine(hashreal, hashimag);
}

/* Equality when imag is 0 reduces to real equality (cross-type hash note). */
int
complex_imag_is_zero(double imag)
{
    return imag == 0.0;
}
