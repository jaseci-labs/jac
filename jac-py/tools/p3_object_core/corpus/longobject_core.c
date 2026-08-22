/* P3.2a longobject core extract — digit vector ops, compare, hash.
 * Curated from reference/cpython Objects/longobject.c.
 */

#include "Python.h"
#include "pycore_long.h"

#include <stddef.h>

#define Py_RETURN_RICHCOMPARE(val1, val2, op)          \
    do {                                                 \
        switch (op) {                                    \
        case Py_EQ:                                      \
            if ((val1) == (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_NE:                                      \
            if ((val1) != (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_LT:                                      \
            if ((val1) < (val2))                         \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_GT:                                      \
            if ((val1) > (val2))                         \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_LE:                                      \
            if ((val1) <= (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        case Py_GE:                                      \
            if ((val1) >= (val2))                        \
                return Py_NewRef(Py_True);               \
            return Py_NewRef(Py_False);                  \
        default:                                         \
            PyErr_BadInternalCall();                     \
            return NULL;                                 \
        }                                                \
    } while (0)

#define CHECK_BINOP(v, w)                                  \
    do {                                                   \
        if (!PyLong_Check(v) || !PyLong_Check(w))         \
            return Py_NewRef(Py_NotImplemented);           \
    } while(0)

static PyLongObject *
long_alloc(Py_ssize_t size)
{
    (void)size;
    return NULL;
}

static PyLongObject *
long_normalize(PyLongObject *v)
{
    return v;
}

static PyLongObject *
maybe_small_long(PyLongObject *v)
{
    return v;
}

/* x[0:m] and y[0:n] are digit vectors, LSD first, m >= n required. */
static digit
v_iadd(digit *x, Py_ssize_t m, digit *y, Py_ssize_t n)
{
    Py_ssize_t i;
    digit carry = 0;

    for (i = 0; i < n; ++i) {
        carry += x[i] + y[i];
        x[i] = carry & PyLong_MASK;
        carry >>= PyLong_SHIFT;
    }
    for (; carry && i < m; ++i) {
        carry += x[i];
        x[i] = carry & PyLong_MASK;
        carry >>= PyLong_SHIFT;
    }
    return carry;
}

static digit
v_isub(digit *x, Py_ssize_t m, digit *y, Py_ssize_t n)
{
    Py_ssize_t i;
    digit borrow = 0;

    for (i = 0; i < n; ++i) {
        borrow = x[i] - y[i] - borrow;
        x[i] = borrow & PyLong_MASK;
        borrow >>= PyLong_SHIFT;
        borrow &= 1;
    }
    for (; borrow && i < m; ++i) {
        borrow = x[i] - borrow;
        x[i] = borrow & PyLong_MASK;
        borrow >>= PyLong_SHIFT;
        borrow &= 1;
    }
    return borrow;
}

static PyLongObject *
x_add(PyLongObject *a, PyLongObject *b)
{
    Py_ssize_t size_a = _PyLong_DigitCount(a), size_b = _PyLong_DigitCount(b);
    PyLongObject *z;
    Py_ssize_t i;
    digit carry = 0;

    if (size_a < size_b) {
        { PyLongObject *temp = a; a = b; b = temp; }
        { Py_ssize_t size_temp = size_a;
            size_a = size_b;
            size_b = size_temp; }
    }
    z = long_alloc(size_a + 1);
    if (z == NULL)
        return NULL;
    for (i = 0; i < size_b; ++i) {
        carry += a->long_value.ob_digit[i] + b->long_value.ob_digit[i];
        z->long_value.ob_digit[i] = carry & PyLong_MASK;
        carry >>= PyLong_SHIFT;
    }
    for (; i < size_a; ++i) {
        carry += a->long_value.ob_digit[i];
        z->long_value.ob_digit[i] = carry & PyLong_MASK;
        carry >>= PyLong_SHIFT;
    }
    z->long_value.ob_digit[i] = carry;
    return long_normalize(z);
}

static PyLongObject *
x_sub(PyLongObject *a, PyLongObject *b)
{
    Py_ssize_t size_a = _PyLong_DigitCount(a), size_b = _PyLong_DigitCount(b);
    PyLongObject *z;
    Py_ssize_t i;
    int sign = 1;
    digit borrow = 0;

    if (size_a < size_b) {
        sign = -1;
        { PyLongObject *temp = a; a = b; b = temp; }
        { Py_ssize_t size_temp = size_a;
            size_a = size_b;
            size_b = size_temp; }
    }
    else if (size_a == size_b) {
        i = size_a;
        while (--i >= 0 && a->long_value.ob_digit[i] == b->long_value.ob_digit[i])
            ;
        if (i < 0) {
            z = long_alloc(1);
            if (z == NULL)
                return NULL;
            z->long_value.ob_digit[0] = 0;
            return long_normalize(z);
        }
        if (a->long_value.ob_digit[i] < b->long_value.ob_digit[i]) {
            sign = -1;
            { PyLongObject *temp = a; a = b; b = temp; }
        }
        size_a = size_b = i + 1;
    }
    z = long_alloc(size_a);
    if (z == NULL)
        return NULL;
    for (i = 0; i < size_b; ++i) {
        borrow = a->long_value.ob_digit[i] - b->long_value.ob_digit[i] - borrow;
        z->long_value.ob_digit[i] = borrow & PyLong_MASK;
        borrow >>= PyLong_SHIFT;
        borrow &= 1;
    }
    for (; i < size_a; ++i) {
        borrow = a->long_value.ob_digit[i] - borrow;
        z->long_value.ob_digit[i] = borrow & PyLong_MASK;
        borrow >>= PyLong_SHIFT;
        borrow &= 1;
    }
    if (sign < 0) {
        _PyLong_FlipSign(z);
    }
    return maybe_small_long(long_normalize(z));
}

static Py_ssize_t
long_compare(PyLongObject *a, PyLongObject *b)
{
    if (_PyLong_BothAreCompact(a, b)) {
        return _PyLong_CompactValue(a) - _PyLong_CompactValue(b);
    }
    Py_ssize_t sign = _PyLong_SignedDigitCount(a) - _PyLong_SignedDigitCount(b);
    if (sign == 0) {
        Py_ssize_t i = _PyLong_DigitCount(a);
        sdigit diff = 0;
        while (--i >= 0) {
            diff = (sdigit)a->long_value.ob_digit[i] - (sdigit)b->long_value.ob_digit[i];
            if (diff) {
                break;
            }
        }
        sign = _PyLong_IsNegative(a) ? -diff : diff;
    }
    return sign;
}

static Py_hash_t
long_hash(PyObject *obj)
{
    PyLongObject *v = (PyLongObject *)obj;
    Py_uhash_t x;
    Py_ssize_t i;
    int sign;

    if (_PyLong_IsCompact(v)) {
        x = (Py_uhash_t)_PyLong_CompactValue(v);
        if (x == (Py_uhash_t)-1) {
            x = (Py_uhash_t)-2;
        }
        return (Py_hash_t)x;
    }
    i = _PyLong_DigitCount(v);
    sign = _PyLong_IsNegative(v) ? -1 : 1;
    x = 0;
    while (--i >= 0) {
        x = ((x << PyLong_SHIFT) & _PyHASH_MODULUS) |
            (x >> (_PyHASH_BITS - PyLong_SHIFT));
        x += v->long_value.ob_digit[i];
        if (x >= _PyHASH_MODULUS)
            x -= _PyHASH_MODULUS;
    }
    x = x * sign;
    if (x == (Py_uhash_t)-1)
        x = (Py_uhash_t)-2;
    return (Py_hash_t)x;
}

static PyObject *
long_richcompare(PyObject *self, PyObject *other, int op)
{
    Py_ssize_t result;
    CHECK_BINOP(self, other);
    if (self == other)
        result = 0;
    else
        result = long_compare((PyLongObject *)self, (PyLongObject *)other);
    Py_RETURN_RICHCOMPARE(result, 0, op);
}
