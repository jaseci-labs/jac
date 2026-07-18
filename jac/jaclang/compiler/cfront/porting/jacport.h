/* CPython / jac-py porting surface (LP64). Include after stddef/stdint. */
#ifndef _JAC_PORT_H
#define _JAC_PORT_H

#include "stddef.h"
#include "stdint.h"

typedef ssize_t Py_ssize_t;
typedef Py_ssize_t Py_hash_t;

#ifndef PY_SSIZE_T_MAX
#define PY_SSIZE_T_MAX ((Py_ssize_t)(((size_t)-1) >> 1))
#endif
#ifndef PY_SSIZE_T_MIN
#define PY_SSIZE_T_MIN (-PY_SSIZE_T_MAX - 1)
#endif

#endif /* _JAC_PORT_H */
