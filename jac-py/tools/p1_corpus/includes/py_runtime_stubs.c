/* Minimal Python C-API stubs for jac-py module differential oracles.
 *
 * Mock int objects embed { PyObject ob_base; int val; } — drivers and
 * PyObject_RichCompareBool must use the same layout.
 */

#include "Python.h"

typedef struct {
    PyObject ob_base;
    int val;
} MockIntObject;

void Py_INCREF(PyObject *o) { (void)o; }
void Py_DECREF(PyObject *o) { (void)o; }
void Py_XDECREF(PyObject *o) { (void)o; }

void PyErr_SetString(PyObject *exc, const char *msg)
{
    (void)exc;
    (void)msg;
}

PyObject *PyErr_Occurred(void) { return NULL; }

int PyObject_RichCompareBool(PyObject *a, PyObject *b, int op)
{
    int av = ((MockIntObject *)a)->val;
    int bv = ((MockIntObject *)b)->val;
    if (op == Py_LT) {
        return av < bv ? 1 : 0;
    }
    return -1;
}

Py_ssize_t PySequence_Size(PyObject *seq)
{
    return PyList_GET_SIZE(seq);
}

PyObject *PyObject_CallOneArg(PyObject *func, PyObject *arg)
{
    (void)func;
    (void)arg;
    return NULL;
}

int PyObject_IsTrue(PyObject *o)
{
    (void)o;
    return 0;
}

int Py_EnterRecursiveCall(const char *where)
{
    (void)where;
    return 0;
}

void Py_LeaveRecursiveCall(void) {}
