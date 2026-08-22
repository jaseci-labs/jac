#ifndef PYCORE_RUNTIME_H
#define PYCORE_RUNTIME_H

#include "Python.h"

typedef struct {
    PyObject ob;
} _PyIdentifier;

extern _PyIdentifier _Py_id_True;
extern _PyIdentifier _Py_id_False;

#define _Py_ID(NAME) ((PyObject *)&_Py_id_##NAME)

#endif /* PYCORE_RUNTIME_H */
