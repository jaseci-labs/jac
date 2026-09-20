#include <stdint.h>

typedef struct _ts PyThreadState;
typedef struct _object PyObject;
extern PyObject *PyExc_ValueError;
extern void Py_Initialize(void);
extern int Py_FinalizeEx(void);
extern PyThreadState *PyEval_SaveThread(void);
extern void PyEval_RestoreThread(PyThreadState *);
extern void PyErr_SetString(PyObject *, const char *);
extern int PyErr_ExceptionMatches(PyObject *);
extern void PyErr_Clear(void);
extern int64_t jacpy_error_pending(void);

int main(void) {
    if (jacpy_error_pending()) return 1;
    for (int cycle = 0; cycle < 2; ++cycle) {
        Py_Initialize();
        if (jacpy_error_pending()) return 2;
        PyErr_SetString(PyExc_ValueError, "retained across detachment");
        if (!jacpy_error_pending()) return 3;
        PyThreadState *thread = PyEval_SaveThread();
        if (jacpy_error_pending()) return 4;
        PyEval_RestoreThread(thread);
        if (!jacpy_error_pending() || !PyErr_ExceptionMatches(PyExc_ValueError)) return 5;
        PyErr_Clear();
        if (jacpy_error_pending()) return 6;
        if (Py_FinalizeEx() != 0) return 7;
        if (jacpy_error_pending()) return 8;
    }
    return 0;
}
