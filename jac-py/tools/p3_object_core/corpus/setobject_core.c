/* P3.2a setobject core extract — open-address lookup, frozenset hash, richcompare.
 * Curated from reference/cpython Objects/setobject.c.
 */

#include "Python.h"
#include "pycore_setobject.h"

#include "stringlib/eq.h"
#include <stddef.h>

#ifndef LINEAR_PROBES
#define LINEAR_PROBES 9
#endif

#define PERTURB_SHIFT 5

extern PyTypeObject PySet_Type;
extern PyTypeObject PyFrozenSet_Type;

static PyObject _dummy_struct;
#define dummy (&_dummy_struct)

#define PyFrozenSet_CheckExact(ob) Py_IS_TYPE((ob), &PyFrozenSet_Type)
#define PyAnySet_Check(ob) \
    (Py_IS_TYPE((ob), &PySet_Type) || Py_IS_TYPE((ob), &PyFrozenSet_Type))
#define PySet_Check(op) Py_IS_TYPE((op), &PySet_Type)
#define PyUnicode_CheckExact(op) Py_IS_TYPE((op), &PyUnicode_Type)

extern PyTypeObject PyUnicode_Type;

#define FT_ATOMIC_LOAD_SSIZE_RELAXED(x) (x)
#define FT_ATOMIC_STORE_SSIZE_RELAXED(x, v) ((x) = (v))

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

#define Py_RETURN_FALSE return Py_NewRef(Py_False)
#define Py_RETURN_TRUE return Py_NewRef(Py_True)
#define Py_RETURN_NOTIMPLEMENTED return Py_NewRef(Py_NotImplemented)

static Py_hash_t
_PyObject_HashFast(PyObject *op)
{
    return PyObject_Hash(op);
}

static setentry *
set_lookkey(PySetObject *so, PyObject *key, Py_hash_t hash)
{
    setentry *table;
    setentry *entry;
    size_t perturb = (size_t)hash;
    size_t mask = (size_t)so->mask;
    size_t i = (size_t)hash & mask;
    int probes;
    int cmp;
    int frozenset = PyFrozenSet_CheckExact(so);

    while (1) {
        entry = &so->table[i];
        probes = (i + LINEAR_PROBES <= mask) ? LINEAR_PROBES : 0;
        do {
            if (entry->hash == 0 && entry->key == NULL)
                return entry;
            if (entry->hash == hash) {
                PyObject *startkey = entry->key;
                if (startkey == key)
                    return entry;
                if (PyUnicode_CheckExact(startkey)
                    && PyUnicode_CheckExact(key)
                    && unicode_eq(startkey, key))
                    return entry;
                table = so->table;
                if (frozenset) {
                    cmp = PyObject_RichCompareBool(startkey, key, Py_EQ);
                    if (cmp < 0)
                        return NULL;
                } else {
                    Py_INCREF(startkey);
                    cmp = PyObject_RichCompareBool(startkey, key, Py_EQ);
                    Py_DECREF(startkey);
                    if (cmp < 0)
                        return NULL;
                    if (table != so->table || entry->key != startkey)
                        return set_lookkey(so, key, hash);
                }
                if (cmp > 0)
                    return entry;
                mask = (size_t)so->mask;
            }
            entry++;
        } while (probes--);
        perturb >>= PERTURB_SHIFT;
        i = (i * 5 + 1 + perturb) & mask;
    }
}

static int
set_contains_entry(PySetObject *so, PyObject *key, Py_hash_t hash)
{
    setentry *entry;

    entry = set_lookkey(so, key, hash);
    if (entry != NULL)
        return entry->key != NULL;
    return -1;
}

static int
set_next(PySetObject *so, Py_ssize_t *pos_ptr, setentry **entry_ptr)
{
    Py_ssize_t i;
    Py_ssize_t mask;
    setentry *entry;

    i = *pos_ptr;
    mask = so->mask;
    entry = &so->table[i];
    while (i <= mask && (entry->key == NULL || entry->key == dummy)) {
        i++;
        entry++;
    }
    *pos_ptr = i + 1;
    if (i > mask)
        return 0;
    *entry_ptr = entry;
    return 1;
}

static Py_uhash_t
_shuffle_bits(Py_uhash_t h)
{
    return ((h ^ 89869747UL) ^ (h << 16)) * 3644798167UL;
}

static Py_hash_t
frozenset_hash_impl(PyObject *self)
{
    PySetObject *so = _PySet_CAST(self);
    Py_uhash_t hash = 0;
    setentry *entry;

    for (entry = so->table; entry <= &so->table[so->mask]; entry++)
        hash ^= _shuffle_bits((Py_uhash_t)entry->hash);

    if ((so->mask + 1 - so->fill) & 1)
        hash ^= _shuffle_bits(0);

    if ((so->fill - so->used) & 1)
        hash ^= _shuffle_bits((Py_uhash_t)-1);

    hash ^= ((Py_uhash_t)PySet_GET_SIZE(self) + 1) * 1927868237UL;
    hash ^= (hash >> 11) ^ (hash >> 25);
    hash = hash * 69069U + 907133923UL;

    if (hash == (Py_uhash_t)-1)
        hash = 590923713UL;

    return (Py_hash_t)hash;
}

static Py_hash_t
frozenset_hash(PyObject *self)
{
    PySetObject *so = _PySet_CAST(self);
    Py_hash_t hash;

    if (FT_ATOMIC_LOAD_SSIZE_RELAXED(so->hash) != -1)
        return FT_ATOMIC_LOAD_SSIZE_RELAXED(so->hash);

    hash = frozenset_hash_impl(self);
    FT_ATOMIC_STORE_SSIZE_RELAXED(so->hash, hash);
    return hash;
}

static PyObject *
set_issubset(PySetObject *so, PyObject *other)
{
    setentry *entry;
    Py_ssize_t pos = 0;
    int rv;

    if (!PyAnySet_Check(other))
        Py_RETURN_NOTIMPLEMENTED;

    if (PySet_GET_SIZE(so) > PySet_GET_SIZE(other))
        Py_RETURN_FALSE;

    while (set_next(so, &pos, &entry)) {
        PyObject *key = entry->key;
        Py_INCREF(key);
        rv = set_contains_entry((PySetObject *)other, key, entry->hash);
        Py_DECREF(key);
        if (rv < 0)
            return NULL;
        if (!rv)
            Py_RETURN_FALSE;
    }
    Py_RETURN_TRUE;
}

static PyObject *
set_issuperset(PySetObject *so, PyObject *other)
{
    if (PyAnySet_Check(other))
        return set_issubset((PySetObject *)other, (PyObject *)so);
    Py_RETURN_NOTIMPLEMENTED;
}

static PyObject *
set_richcompare(PyObject *self, PyObject *w, int op)
{
    PySetObject *v = _PySet_CAST(self);
    PyObject *r1;
    int r2;

    if (!PyAnySet_Check(w))
        Py_RETURN_NOTIMPLEMENTED;

    switch (op) {
    case Py_EQ:
        if (PySet_GET_SIZE(v) != PySet_GET_SIZE(w))
            Py_RETURN_FALSE;
        {
            Py_hash_t v_hash = FT_ATOMIC_LOAD_SSIZE_RELAXED(v->hash);
            Py_hash_t w_hash = FT_ATOMIC_LOAD_SSIZE_RELAXED(((PySetObject *)w)->hash);
            if (v_hash != -1 && w_hash != -1 && v_hash != w_hash)
                Py_RETURN_FALSE;
        }
        return set_issubset(v, w);
    case Py_NE:
        r1 = set_richcompare(self, w, Py_EQ);
        if (r1 == NULL)
            return NULL;
        r2 = PyObject_IsTrue(r1);
        Py_DECREF(r1);
        if (r2 < 0)
            return NULL;
        return PyBool_FromLong(!r2);
    case Py_LE:
        return set_issubset(v, w);
    case Py_GE:
        return set_issuperset(v, w);
    case Py_LT:
        if (PySet_GET_SIZE(v) >= PySet_GET_SIZE(w))
            Py_RETURN_FALSE;
        return set_issubset(v, w);
    case Py_GT:
        if (PySet_GET_SIZE(v) <= PySet_GET_SIZE(w))
            Py_RETURN_FALSE;
        return set_issuperset(v, w);
    }
    Py_RETURN_NOTIMPLEMENTED;
}
