/* P3.2a dictobject core extract — open-addressing probe / lookup.
 * Curated from reference/cpython Objects/dictobject.c.
 */

#include "Python.h"
#include "pycore_dict.h"

#include <stddef.h>
#include <stdint.h>

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
        default:                                         \
            return Py_NewRef(Py_NotImplemented);          \
        }                                                \
    } while (0)

/* Simplified index table: int32 slots (corpus stub; CPython varies by size). */
static inline Py_ssize_t
dictkeys_get_index(const PyDictKeysObject *keys, Py_ssize_t i)
{
    const int32_t *indices = (const int32_t *)keys->dk_indices;
    (void)keys;
    return (Py_ssize_t)indices[i];
}

static inline void
dictkeys_set_index(PyDictKeysObject *keys, Py_ssize_t i, Py_ssize_t ix)
{
    int32_t *indices = (int32_t *)keys->dk_indices;
    (void)keys;
    indices[i] = (int32_t)ix;
}

static inline uint8_t
calculate_log2_keysize(Py_ssize_t minsize)
{
    uint8_t log2_size;
    minsize = minsize < PyDict_MINSIZE ? PyDict_MINSIZE : minsize;
    for (log2_size = PyDict_LOG_MINSIZE;
         (((Py_ssize_t)1) << log2_size) < minsize;
         log2_size++)
        ;
    return log2_size;
}

static inline uint8_t
estimate_log2_keysize(Py_ssize_t n)
{
    return calculate_log2_keysize((n * 3 + 1) / 2);
}

/* Search index of hash table from offset of entry table */
static Py_ssize_t
lookdict_index(PyDictKeysObject *k, Py_hash_t hash, Py_ssize_t index)
{
    size_t mask = DK_MASK(k);
    size_t perturb = (size_t)hash;
    size_t i = (size_t)hash & mask;

    for (;;) {
        Py_ssize_t ix = dictkeys_get_index(k, (Py_ssize_t)i);
        if (ix == index) {
            return (Py_ssize_t)i;
        }
        if (ix == DKIX_EMPTY) {
            return DKIX_EMPTY;
        }
        perturb >>= PERTURB_SHIFT;
        i = mask & (i * 5 + perturb + 1);
    }
    Py_UNREACHABLE();
}

static inline int
compare_generic(PyDictObject *mp, PyDictKeysObject *dk,
                void *ep0, Py_ssize_t ix, PyObject *key, Py_hash_t hash)
{
    PyDictKeyEntry *ep = &((PyDictKeyEntry *)ep0)[ix];
    (void)mp;
    assert(ep->me_key != NULL);
    if (ep->me_key == key) {
        return 1;
    }
    if (ep->me_hash == hash) {
        PyObject *startkey = ep->me_key;
        Py_INCREF(startkey);
        int cmp = PyObject_RichCompareBool(startkey, key, Py_EQ);
        Py_DECREF(startkey);
        if (cmp < 0) {
            return DKIX_ERROR;
        }
        if (dk == mp->ma_keys && ep->me_key == startkey) {
            return cmp;
        }
        return DKIX_KEY_CHANGED;
    }
    return 0;
}

static inline Py_ssize_t
do_lookup(PyDictObject *mp, PyDictKeysObject *dk, PyObject *key, Py_hash_t hash,
          int (*check_lookup)(PyDictObject *, PyDictKeysObject *, void *,
                              Py_ssize_t ix, PyObject *key, Py_hash_t))
{
    void *ep0 = _DK_ENTRIES(dk);
    size_t mask = DK_MASK(dk);
    size_t perturb = (size_t)hash;
    size_t i = (size_t)hash & mask;
    Py_ssize_t ix;

    for (;;) {
        ix = dictkeys_get_index(dk, (Py_ssize_t)i);
        if (ix >= 0) {
            int cmp = check_lookup(mp, dk, ep0, ix, key, hash);
            if (cmp < 0) {
                return cmp;
            }
            if (cmp) {
                return ix;
            }
        }
        else if (ix == DKIX_EMPTY) {
            return DKIX_EMPTY;
        }
        perturb >>= PERTURB_SHIFT;
        i = mask & (i * 5 + perturb + 1);
    }
    Py_UNREACHABLE();
}

static Py_ssize_t
dictkeys_generic_lookup(PyDictObject *mp, PyDictKeysObject *dk,
                        PyObject *key, Py_hash_t hash)
{
    return do_lookup(mp, dk, key, hash, compare_generic);
}

/* Find slot for an item from its hash when key is known absent. */
static Py_ssize_t
find_empty_slot(PyDictKeysObject *keys, Py_hash_t hash)
{
    const size_t mask = DK_MASK(keys);
    size_t i = (size_t)hash & mask;
    Py_ssize_t ix = dictkeys_get_index(keys, (Py_ssize_t)i);
    for (size_t perturb = (size_t)hash; is_unusable_slot(ix);) {
        perturb >>= PERTURB_SHIFT;
        i = (i * 5 + perturb + 1) & mask;
        ix = dictkeys_get_index(keys, (Py_ssize_t)i);
    }
    return (Py_ssize_t)i;
}

static int
dict_equal_entries(PyDictObject *a, PyDictObject *b)
{
    Py_ssize_t i;

    if (a->ma_used != b->ma_used) {
        return 0;
    }
    for (i = 0; i < a->ma_keys->dk_nentries; i++) {
        PyObject *key, *aval;
        Py_hash_t hash;
        PyDictKeyEntry *ep = &DK_ENTRIES(a->ma_keys)[i];
        key = ep->me_key;
        aval = ep->me_value;
        hash = ep->me_hash;
        if (key == NULL || aval == NULL) {
            continue;
        }
        PyObject *bval = NULL;
        Py_ssize_t ix = dictkeys_generic_lookup(b, b->ma_keys, key, hash);
        if (ix == DKIX_EMPTY) {
            return 0;
        }
        if (ix < 0) {
            return -1;
        }
        bval = DK_ENTRIES(b->ma_keys)[ix].me_value;
        if (bval == NULL) {
            return 0;
        }
        int cmp = PyObject_RichCompareBool(aval, bval, Py_EQ);
        if (cmp <= 0) {
            return cmp;
        }
    }
    return 1;
}

static PyObject *
dict_richcompare(PyObject *v, PyObject *w, int op)
{
    int cmp;

    if (!PyDict_Check(v) || !PyDict_Check(w)) {
        return Py_NewRef(Py_NotImplemented);
    }
    if (op != Py_EQ && op != Py_NE) {
        return Py_NewRef(Py_NotImplemented);
    }
    cmp = dict_equal_entries((PyDictObject *)v, (PyDictObject *)w);
    if (cmp < 0) {
        return NULL;
    }
    Py_RETURN_RICHCOMPARE(cmp, (op == Py_EQ), op);
}
