/* P3.2a bytesobject core extract — hash, richcompare, contains.
 * Curated from reference/cpython Objects/bytesobject.c and bytes_methods.c.
 */

#include "Python.h"
#include "pycore_bytes.h"

#include <stddef.h>
#include <string.h>

#define Py_CHARMASK(c) ((unsigned char)(c))
#define Py_MIN(a, b) (((a) < (b)) ? (a) : (b))

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

#define Py_RETURN_TRUE return Py_NewRef(Py_True)
#define Py_RETURN_FALSE return Py_NewRef(Py_False)
#define Py_RETURN_NOTIMPLEMENTED return Py_NewRef(Py_NotImplemented)

static int
bytes_compare_eq(PyBytesObject *a, PyBytesObject *b)
{
    int cmp;
    Py_ssize_t len;

    len = Py_SIZE(a);
    if (Py_SIZE(b) != len)
        return 0;

    if (a->ob_sval[0] != b->ob_sval[0])
        return 0;

    cmp = memcmp(a->ob_sval, b->ob_sval, (size_t)len);
    return (cmp == 0);
}

static int
_Py_bytes_contains(const char *str, Py_ssize_t len, PyObject *arg)
{
    Py_ssize_t ival = PyNumber_AsSsize_t(arg, NULL);
    if (ival == -1 && PyErr_Occurred()) {
        PyErr_Clear();
        return -1;
    }
    if (ival < 0 || ival >= 256) {
        PyErr_SetString(PyExc_ValueError, "byte must be in range(0, 256)");
        return -1;
    }

    return memchr(str, (int)ival, (size_t)len) != NULL;
}

static int
bytes_contains(PyObject *self, PyObject *arg)
{
    PyBytesObject *a = _PyBytes_CAST(self);
    return _Py_bytes_contains(PyBytes_AS_STRING(a), PyBytes_GET_SIZE(a), arg);
}

static PyObject *
bytes_richcompare(PyObject *aa, PyObject *bb, int op)
{
    if (!(PyBytes_Check(aa) && PyBytes_Check(bb))) {
        Py_RETURN_NOTIMPLEMENTED;
    }

    PyBytesObject *a = _PyBytes_CAST(aa);
    PyBytesObject *b = _PyBytes_CAST(bb);
    if (a == b) {
        switch (op) {
        case Py_EQ:
        case Py_LE:
        case Py_GE:
            Py_RETURN_TRUE;
        case Py_NE:
        case Py_LT:
        case Py_GT:
            Py_RETURN_FALSE;
        default:
            PyErr_BadInternalCall();
            return NULL;
        }
    }
    else if (op == Py_EQ || op == Py_NE) {
        int eq = bytes_compare_eq(a, b);
        eq ^= (op == Py_NE);
        return PyBool_FromLong(eq);
    }
    else {
        Py_ssize_t len_a = Py_SIZE(a);
        Py_ssize_t len_b = Py_SIZE(b);
        Py_ssize_t min_len = Py_MIN(len_a, len_b);
        int c;
        if (min_len > 0) {
            c = Py_CHARMASK(*a->ob_sval) - Py_CHARMASK(*b->ob_sval);
            if (c == 0)
                c = memcmp(a->ob_sval, b->ob_sval, (size_t)min_len);
        }
        else {
            c = 0;
        }
        if (c != 0) {
            Py_RETURN_RICHCOMPARE(c, 0, op);
        }
        Py_RETURN_RICHCOMPARE(len_a, len_b, op);
    }
}

static Py_hash_t
bytes_hash(PyObject *self)
{
    PyBytesObject *a = _PyBytes_CAST(self);
    Py_hash_t hash = get_ob_shash(a);
    if (hash == -1) {
        hash = Py_HashBuffer(a->ob_sval, Py_SIZE(a));
        set_ob_shash(a, hash);
    }
    return hash;
}
