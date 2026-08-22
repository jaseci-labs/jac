/* Runtime stubs for P3 Objects/ c2jac lifts (boolobject.c, abstract_protocol.c). */

#include "Python.h"
#include "pycore_modsupport.h"
#include "pycore_object.h"
#include "pycore_runtime.h"

_PyIdentifier _Py_id_True;
_PyIdentifier _Py_id_False;

PyObject *PyExc_DeprecationWarning;
PyObject *PyExc_BaseException;
PyObject *PyExc_TypeError;
PyObject *_PyEmptyString;
PyObject *PyExc_StopIteration;
PyObject *PyExc_IndexError;
PyObject *Py_NotImplemented;
PyObject *Py_None;

static PyNumberMethods long_as_number = {
    .nb_invert = NULL,
    .nb_and = NULL,
    .nb_xor = NULL,
    .nb_or = NULL,
};

PyTypeObject PyLong_Type = {
    .tp_as_number = &long_as_number,
};

PyTypeObject PyType_Type;
PyTypeObject PyBool_Type;
PyTypeObject PyTuple_Type;
PyTypeObject PySet_Type;
PyTypeObject PyFrozenSet_Type;
PyTypeObject PyUnicode_Type;
PyTypeObject PyBytes_Type;

const char Py_hexdigits[] = "0123456789abcdef";

typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
} PyUnicodeObject;

PyObject *PyUnicode_New(Py_ssize_t size, unsigned int maxchar)
{
    (void)size;
    (void)maxchar;
    return NULL;
}

unsigned char *PyUnicode_1BYTE_DATA(PyObject *op)
{
    (void)op;
    return NULL;
}
PyTypeObject PyDict_Type;
PyTypeObject PyList_Type;

struct _longobject _Py_FalseStruct;
struct _longobject _Py_TrueStruct;

PyObject *Py_True = (PyObject *)&_Py_TrueStruct;
PyObject *Py_False = (PyObject *)&_Py_FalseStruct;

PyObject *PyBool_FromLong(long ok)
{
    return ok ? Py_True : Py_False;
}

int PyObject_IsTrue(PyObject *o)
{
    (void)o;
    return 0;
}

int PySequence_Check(PyObject *s)
{
    (void)s;
    return 0;
}

PyObject *PySeqIter_New(PyObject *seq)
{
    (void)seq;
    return NULL;
}

int PyErr_Format(PyObject *exc, const char *format, ...)
{
    (void)exc;
    (void)format;
    return -1;
}

void PyErr_SetString(PyObject *exc, const char *message)
{
    (void)exc;
    (void)message;
}

void PyErr_BadInternalCall(void)
{
}

PyObject *Py_NewRef(PyObject *obj)
{
    return obj;
}

PyObject *Py_XNewRef(PyObject *obj)
{
    return obj;
}

PyObject *Py_GetEmptyString(void)
{
    return _PyEmptyString;
}

void Py_INCREF(PyObject *op)
{
    (void)op;
}

void Py_XSETREF(PyObject **p, PyObject *o)
{
    *p = o;
}

void Py_DECREF(PyObject *op)
{
    (void)op;
}

void Py_CLEAR(PyObject *op)
{
    (void)op;
}

void Py_XDECREF(PyObject *op)
{
    (void)op;
}

PyObject *PyObject_Str(PyObject *o)
{
    (void)o;
    return NULL;
}

PyObject *PyUnicode_FromFormat(const char *format, ...)
{
    (void)format;
    return NULL;
}

const char *
_PyType_Name(PyTypeObject *type)
{
    if (type == NULL) {
        return "?";
    }
    return type->tp_name;
}

int
PyErr_GivenExceptionMatches(PyObject *err, PyObject *exc)
{
    (void)err;
    (void)exc;
    return 0;
}

PyObject *PyObject_Repr(PyObject *v)
{
    (void)v;
    return NULL;
}

PyObject *PyUnicode_FromString(const char *u)
{
    (void)u;
    return NULL;
}

PyObject *PyUnicode_FromFormat(const char *format, ...)
{
    (void)format;
    return NULL;
}

int PyType_IsSubtype(PyTypeObject *a, PyTypeObject *b)
{
    (void)a;
    (void)b;
    return 0;
}

PyThreadState *_PyThreadState_GET(void)
{
    return NULL;
}

PyObject *_PyErr_Occurred(PyThreadState *tstate)
{
    (void)tstate;
    return NULL;
}

int _PyErr_ExceptionMatches(PyThreadState *tstate, PyObject *exc)
{
    (void)tstate;
    (void)exc;
    return 0;
}

void _PyErr_Clear(PyThreadState *tstate)
{
    (void)tstate;
}

int PyArg_UnpackTuple(PyObject *args, const char *name, Py_ssize_t min, Py_ssize_t max, ...)
{
    (void)args;
    (void)name;
    (void)min;
    (void)max;
    return 1;
}

int _PyArg_NoKwnames(const char *funcname, PyObject *kwnames)
{
    (void)funcname;
    (void)kwnames;
    return 1;
}

int _PyArg_NoKeywords(const char *funcname, PyObject *kwargs)
{
    (void)funcname;
    (void)kwargs;
    return 1;
}

int _PyArg_CheckPositional(const char *funcname, Py_ssize_t nargs, Py_ssize_t min, Py_ssize_t max)
{
    (void)funcname;
    (void)nargs;
    (void)min;
    (void)max;
    return 1;
}

int PyErr_WarnEx(PyObject *category, const char *message, Py_ssize_t stack_level)
{
    (void)category;
    (void)message;
    (void)stack_level;
    return 0;
}

Py_ssize_t PyNumber_AsSsize_t(PyObject *o, PyObject *exc)
{
    (void)exc;
    (void)o;
    return 0;
}

int PyErr_Occurred(void)
{
    return 0;
}

void PyErr_Clear(void)
{
}

Py_hash_t Py_HashBuffer(const void *ptr, Py_ssize_t len)
{
    (void)ptr;
    (void)len;
    return 0;
}

PyObject *PyExc_ValueError;

void _Py_SetImmortal(PyObject *op)
{
    (void)op;
}
