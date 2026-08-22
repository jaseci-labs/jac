#ifndef PYCORE_TUPLE_H
#define PYCORE_TUPLE_H

#include "Python.h"

typedef unsigned long long Py_uhash_t;

#ifndef SIZEOF_PY_UHASH_T
#define SIZEOF_PY_UHASH_T 8
#endif

#if SIZEOF_PY_UHASH_T > 4
#define _PyTuple_HASH_XXPRIME_1 ((Py_uhash_t)11400714785074694791ULL)
#define _PyTuple_HASH_XXPRIME_2 ((Py_uhash_t)14029467366897019727ULL)
#define _PyTuple_HASH_XXPRIME_5 ((Py_uhash_t)2870177450012600261ULL)
#define _PyTuple_HASH_XXROTATE(x) ((x << 31) | (x >> 33))
#else
#define _PyTuple_HASH_XXPRIME_1 ((Py_uhash_t)2654435761UL)
#define _PyTuple_HASH_XXPRIME_2 ((Py_uhash_t)2246822519UL)
#define _PyTuple_HASH_XXPRIME_5 ((Py_uhash_t)374761393UL)
#define _PyTuple_HASH_XXROTATE(x) ((x << 13) | (x >> 19))
#endif

#define _PyTuple_HASH_EMPTY (_PyTuple_HASH_XXPRIME_5 + (_PyTuple_HASH_XXPRIME_5 ^ 3527539UL))

#endif /* PYCORE_TUPLE_H */
