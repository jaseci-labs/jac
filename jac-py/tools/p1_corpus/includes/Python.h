#ifndef PYTHON_H
#define PYTHON_H

#include <jacport.h>

typedef struct _object PyObject;
typedef struct _typeobject PyTypeObject;
typedef struct _listobject PyListObject;

typedef PyObject *(*unaryfunc)(PyObject *);
typedef PyObject *(*richcmpfunc)(PyObject *, PyObject *, int);
typedef PyObject *(*ssizeargfunc)(PyObject *, Py_ssize_t);

typedef struct {
    ssizeargfunc sq_item;
} PySequenceMethods;

struct _object {
    PyTypeObject *ob_type;
};

struct _typeobject {
    const char *tp_name;
    PySequenceMethods *tp_as_sequence;
    richcmpfunc tp_richcompare;
};

struct _listobject {
    PyObject ob_base;
    Py_ssize_t ob_size;
    PyObject **ob_item;
};

#define PyObject_HEAD PyObject ob_base;

#define Py_LT 0
#define PyList_Check(op) 1
#define PyList_GET_SIZE(op) (((PyListObject *)(op))->ob_size)
#define PyList_GET_ITEM(op, i) (((PyListObject *)(op))->ob_item[i])
#define PyList_SetSlice(op, i, j, v) 0
#define Py_TYPE(op) (((PyObject *)(op))->ob_type)
#define Py_IS_TYPE(ob, type) (Py_TYPE(ob) == (type))

extern PyObject *PyExc_IndexError;
extern PyObject *PyExc_RuntimeError;
extern PyObject *PyExc_ValueError;
extern PyObject *PyExc_TypeError;
extern PyObject *Py_None;
extern PyObject *Py_True;
extern PyObject *Py_False;
extern PyObject *Py_NotImplemented;

void Py_INCREF(PyObject *o);
void Py_DECREF(PyObject *o);
void Py_XDECREF(PyObject *o);
void PyErr_SetString(PyObject *exc, const char *msg);
int PyObject_RichCompareBool(PyObject *a, PyObject *b, int op);
Py_ssize_t PySequence_Size(PyObject *seq);
PyObject *PyObject_CallOneArg(PyObject *func, PyObject *arg);
int PyObject_IsTrue(PyObject *o);
int Py_EnterRecursiveCall(const char *where);
void Py_LeaveRecursiveCall(void);
PyObject *PyErr_Occurred(void);

#endif /* PYTHON_H */
