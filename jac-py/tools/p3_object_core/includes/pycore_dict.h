#ifndef PYCORE_DICT_H
#define PYCORE_DICT_H

#include "Python.h"

#define DKIX_EMPTY (-1)
#define DKIX_DUMMY (-2)
#define DKIX_ERROR (-3)
#define DKIX_KEY_CHANGED (-4)

#define PERTURB_SHIFT 5

#define PyDict_LOG_MINSIZE 3
#define PyDict_MINSIZE 8

#define USABLE_FRACTION(n) (((n) << 1) / 3)

typedef enum {
    DICT_KEYS_GENERAL = 0,
    DICT_KEYS_UNICODE = 1,
    DICT_KEYS_SPLIT = 2
} DictKeysKind;

typedef struct {
    Py_hash_t me_hash;
    PyObject *me_key;
    PyObject *me_value;
} PyDictKeyEntry;

typedef struct {
    PyObject *me_key;
    PyObject *me_value;
} PyDictUnicodeEntry;

typedef struct _dictkeysobject {
    Py_ssize_t dk_refcnt;
    uint8_t dk_log2_size;
    uint8_t dk_log2_index_bytes;
    uint8_t dk_kind;
    uint32_t dk_version;
    Py_ssize_t dk_usable;
    Py_ssize_t dk_nentries;
    char dk_indices[];
} PyDictKeysObject;

typedef struct _dictvalues {
    uint8_t capacity;
    uint8_t size;
    uint8_t embedded;
    uint8_t valid;
    PyObject *values[1];
} PyDictValues;

typedef struct {
    PyObject ob_base;
    Py_ssize_t ma_used;
    PyDictKeysObject *ma_keys;
    PyDictValues *ma_values;
} PyDictObject;

extern PyTypeObject PyDict_Type;

#define PyDict_Check(op) Py_IS_TYPE((op), &PyDict_Type)
#define _PyDict_CAST(op) ((PyDictObject *)(op))
#define _PyDict_HasSplitTable(d) ((d)->ma_values != NULL)

#define DK_LOG_SIZE(dk) ((dk)->dk_log2_size)

#if SIZEOF_VOID_P > 4
#define DK_SIZE(dk) (((int64_t)1) << DK_LOG_SIZE(dk))
#else
#define DK_SIZE(dk) (1 << DK_LOG_SIZE(dk))
#endif

#define DK_MASK(dk) (DK_SIZE(dk) - 1)
#define DK_IS_UNICODE(dk) ((dk)->dk_kind != DICT_KEYS_GENERAL)

static inline void *
_DK_ENTRIES(PyDictKeysObject *dk)
{
    int8_t *indices = (int8_t *)(dk->dk_indices);
    size_t index = (size_t)1 << dk->dk_log2_index_bytes;
    return (&indices[index]);
}

static inline PyDictKeyEntry *
DK_ENTRIES(PyDictKeysObject *dk)
{
    return (PyDictKeyEntry *)_DK_ENTRIES(dk);
}

static inline PyDictUnicodeEntry *
DK_UNICODE_ENTRIES(PyDictKeysObject *dk)
{
    return (PyDictUnicodeEntry *)_DK_ENTRIES(dk);
}

static inline int
is_unusable_slot(Py_ssize_t ix)
{
    return ix >= 0;
}

#endif /* PYCORE_DICT_H */
