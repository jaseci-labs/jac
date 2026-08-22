#ifndef PYCORE_LONG_H
#define PYCORE_LONG_H

#include "Python.h"

#define _PyLong_FALSE_TAG 1UL
#define _PyLong_TRUE_TAG 2UL

#if SIZEOF_VOID_P >= 8
#define PyLong_SHIFT 30
#define _PyHASH_BITS 61
#else
#define PyLong_SHIFT 15
#define _PyHASH_BITS 31
#endif

#define PyLong_BASE ((digit)1 << PyLong_SHIFT)
#define PyLong_MASK ((digit)(PyLong_BASE - 1))
#define _PyHASH_MODULUS (((size_t)1 << _PyHASH_BITS) - 1)

#define PyLong_Check(op) Py_IS_TYPE((op), &PyLong_Type)
#define _PyLong_CAST(op) ((PyLongObject *)(op))

static inline int
_PyLong_IsCompact(const PyLongObject *op)
{
    return (op->long_value.lv_tag & 3UL) == 0;
}

static inline stwodigits
_PyLong_CompactValue(const PyLongObject *op)
{
    return (stwodigits)(op->long_value.lv_tag >> 2);
}

static inline int
_PyLong_IsNegative(const PyLongObject *op)
{
    if (_PyLong_IsCompact(op)) {
        return _PyLong_CompactValue(op) < 0;
    }
    return (op->long_value.lv_tag & 3UL) == 2;
}

static inline Py_ssize_t
_PyLong_DigitCount(const PyLongObject *op)
{
    if (_PyLong_IsCompact(op)) {
        return 1;
    }
    return (Py_ssize_t)(op->long_value.lv_tag >> 3);
}

static inline Py_ssize_t
_PyLong_SignedDigitCount(const PyLongObject *op)
{
    Py_ssize_t n = _PyLong_DigitCount(op);
    if (_PyLong_IsNegative(op)) {
        return -n;
    }
    return n;
}

static inline int
_PyLong_BothAreCompact(const PyLongObject *a, const PyLongObject *b)
{
    return _PyLong_IsCompact(a) && _PyLong_IsCompact(b);
}

static inline void
_PyLong_FlipSign(PyLongObject *op)
{
    if (_PyLong_IsCompact(op)) {
        stwodigits v = _PyLong_CompactValue(op);
        op->long_value.lv_tag = (uintptr_t)(-v) << 2;
        return;
    }
    if (_PyLong_IsNegative(op)) {
        op->long_value.lv_tag &= ~3UL;
    } else {
        op->long_value.lv_tag |= 2UL;
    }
}

#endif /* PYCORE_LONG_H */
