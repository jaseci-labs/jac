#ifndef Py_JAC_COMPILE_H
#define Py_JAC_COMPILE_H
#include "Python.h"
PyObject *_PyJac_CompileObject(PyObject *, PyObject *, int, PyCompilerFlags *, int);
PyObject *_PyJac_CompileString(const char *, PyObject *, int, PyCompilerFlags *, int);
PyObject *_PyJac_CompileFile(FILE *, PyObject *, int, PyCompilerFlags *);
#endif
