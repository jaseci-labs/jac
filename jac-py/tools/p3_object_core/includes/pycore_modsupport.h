#ifndef PYCORE_MODSUPPORT_H
#define PYCORE_MODSUPPORT_H

#include "Python.h"

#define PY_SSIZE_T_MAX ((Py_ssize_t)(((size_t)-1) >> 1))

int _PyArg_NoKwnames(const char *funcname, PyObject *kwnames);
int _PyArg_NoKeywords(const char *funcname, PyObject *kwargs);
int _PyArg_CheckPositional(const char *funcname, Py_ssize_t nargs, Py_ssize_t min, Py_ssize_t max);

#define _Py_ANY_VARARGS(n) ((n) == PY_SSIZE_T_MAX)
#define _PyArg_NoKwnames(funcname, kwnames) \
    ((kwnames) == NULL || _PyArg_NoKwnames((funcname), (kwnames)))
#define _PyArg_NoKeywords(funcname, kwargs) \
    ((kwargs) == NULL || _PyArg_NoKeywords((funcname), (kwargs)))
#define _PyArg_CheckPositional(funcname, nargs, min, max) \
    ((!_Py_ANY_VARARGS(max) && (min) <= (nargs) && (nargs) <= (max)) \
     || _PyArg_CheckPositional((funcname), (nargs), (min), (max)))

#endif /* PYCORE_MODSUPPORT_H */
