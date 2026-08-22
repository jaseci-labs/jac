#ifndef PYCORE_OBJECT_H
#define PYCORE_OBJECT_H

#include "Python.h"

void _Py_SetImmortal(PyObject *op);

PyObject *_PyObject_NextNotImplemented(PyObject *self);

#endif /* PYCORE_OBJECT_H */
