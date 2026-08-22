#ifndef PYTHON_H
#define PYTHON_H

#include <jacport.h>
#include <stddef.h>
#include <stdint.h>

typedef struct _object PyObject;
typedef struct {
    PyObject ob_base;
    Py_ssize_t ob_size;
} PyVarObject;
typedef struct _typeobject PyTypeObject;
typedef struct _longobject PyLongObject;
typedef struct _listobject PyListObject;
typedef struct _ts PyThreadState;

typedef unsigned int digit;
typedef int64_t stwodigits;
typedef int32_t sdigit;
typedef uintptr_t _Pyuintptr_t;
typedef unsigned long long Py_uhash_t;

#ifndef SIZEOF_VOID_P
#define SIZEOF_VOID_P 8
#endif

typedef Py_ssize_t (*lenfunc)(PyObject *);
typedef PyObject *(*unaryfunc)(PyObject *);
typedef PyObject *(*binaryfunc)(PyObject *, PyObject *);
typedef int (*inquiry)(PyObject *);
typedef PyObject *(*vectorcallfunc)(PyObject *, PyObject *const *, size_t, PyObject *);
typedef Py_hash_t (*hashfunc)(PyObject *);
typedef PyObject *(*richcmpfunc)(PyObject *, PyObject *, int);
typedef PyObject *(*getiterfunc)(PyObject *);
typedef PyObject *(*iternextfunc)(PyObject *);
typedef PyObject *(*ssizeargfunc)(PyObject *, Py_ssize_t);

typedef struct {
    lenfunc sq_length;
    ssizeargfunc sq_item;
    inquiry sq_contains;
} PySequenceMethods;

typedef struct {
    binaryfunc nb_add;
    binaryfunc nb_subtract;
    binaryfunc nb_multiply;
    binaryfunc nb_remainder;
    binaryfunc nb_divmod;
    binaryfunc nb_power;
    binaryfunc nb_negative;
    binaryfunc nb_positive;
    binaryfunc nb_absolute;
    inquiry nb_bool;
    unaryfunc nb_invert;
    binaryfunc nb_lshift;
    binaryfunc nb_rshift;
    binaryfunc nb_and;
    binaryfunc nb_xor;
    binaryfunc nb_or;
} PyNumberMethods;

struct _object {
    PyTypeObject *ob_type;
};

struct _typeobject {
    PyObject ob_base;
    Py_ssize_t ob_size;
    const char *tp_name;
    Py_ssize_t tp_basicsize;
    Py_ssize_t tp_itemsize;
    void (*tp_dealloc)(PyObject *);
    unaryfunc tp_repr;
    PyNumberMethods *tp_as_number;
    PySequenceMethods *tp_as_sequence;
    hashfunc tp_hash;
    richcmpfunc tp_richcompare;
    getiterfunc tp_iter;
    iternextfunc tp_iternext;
    unsigned long tp_flags;
    const char *tp_doc;
    PyTypeObject *tp_base;
    vectorcallfunc tp_vectorcall;
};

struct _PyLongValue {
    uintptr_t lv_tag;
    digit ob_digit[1];
};

struct _longobject {
    PyObject ob_base;
    struct _PyLongValue long_value;
};

#define PyObject_HEAD PyObject ob_base;

#define PyObject_HEAD_INIT(type)    \
    {                               \
        (type)                      \
    },

#define PyVarObject_HEAD_INIT(type, size) \
    {                                     \
        PyObject_HEAD_INIT(type)          \
        (size)                            \
    },

#define Py_TYPE(op) (((PyObject *)(op))->ob_type)
#define Py_SIZE(op) (((PyVarObject *)(op))->ob_size)
#define Py_IS_TYPE(ob, type) (Py_TYPE(ob) == (type))
#define PyBool_Check(x) Py_IS_TYPE((x), &PyBool_Type)
#define PyLong_Check(op) Py_IS_TYPE((op), &PyLong_Type)
#define PyUnicode_Check(op) Py_IS_TYPE((op), &PyUnicode_Type)
#define PyTuple_Check(op) Py_IS_TYPE((op), &PyTuple_Type)
#define PyType_Check(op) Py_IS_TYPE((op), &PyType_Type)

#define Py_TPFLAGS_DEFAULT 0UL
#define Py_TPFLAGS_HEAPTYPE (1UL << 9)
#define Py_TPFLAGS_READY (1UL << 12)
#define Py_TPFLAGS_READYING (1UL << 13)
#define Py_TPFLAGS_BASETYPE (1UL << 10)
#define Py_TPFLAGS_HAVE_GC (1UL << 14)
#define Py_TPFLAGS_BASE_EXC_SUBCLASS (1UL << 30)
#define PY_VECTORCALL_ARGUMENTS_OFFSET ((size_t)1 << (8 * sizeof(size_t) - 1))
#define PyVectorcall_NARGS(n) ((Py_ssize_t)((n) & ~PY_VECTORCALL_ARGUMENTS_OFFSET))

#define Py_LT 0
#define Py_LE 1
#define Py_EQ 2
#define Py_NE 3
#define Py_GT 4
#define Py_GE 5

#define WITH_DOC_STRINGS 1
#define PyDoc_STR(str) str
#define PyDoc_VAR(name) static const char name[]
#define PyDoc_STRVAR(name, str) PyDoc_VAR(name) = PyDoc_STR(str)

extern PyObject *Py_True;
extern PyObject *Py_False;
extern PyObject *Py_None;
extern PyObject *Py_NotImplemented;
extern PyObject *PyExc_TypeError;
extern PyObject *PyExc_StopIteration;
extern PyObject *PyExc_IndexError;
extern PyObject *PyExc_ValueError;
extern PyTypeObject PyBool_Type;
extern PyTypeObject PyTuple_Type;
extern PyTypeObject PyBytes_Type;
extern const char Py_hexdigits[];

typedef unsigned char Py_UCS1;

PyObject *PyUnicode_New(Py_ssize_t size, unsigned int maxchar);
unsigned char *PyUnicode_1BYTE_DATA(PyObject *op);
Py_hash_t Py_HashBuffer(const void *ptr, Py_ssize_t len);
extern PyTypeObject PyList_Type;
extern PyTypeObject PyDict_Type;
extern PyTypeObject PyLong_Type;
extern PyTypeObject PyType_Type;
extern PyObject *PyExc_DeprecationWarning;
extern PyObject *PyExc_BaseException;
extern PyObject *PyExc_Exception;

PyObject *PyBool_FromLong(long ok);
PyObject *Py_GetEmptyString(void);
PyObject *PyObject_Str(PyObject *o);
PyObject *PyUnicode_FromString(const char *s);
PyObject *PyUnicode_FromFormat(const char *format, ...);
const char *_PyType_Name(PyTypeObject *type);
int PyType_Ready(PyTypeObject *type);
int PyErr_GivenExceptionMatches(PyObject *err, PyObject *exc);
int PyObject_IsTrue(PyObject *o);
int PyArg_UnpackTuple(PyObject *args, const char *name, Py_ssize_t min, Py_ssize_t max, ...);
int PyErr_WarnEx(PyObject *category, const char *message, Py_ssize_t stack_level);

PyObject *PyObject_RichCompare(PyObject *v, PyObject *w, int op);
int PyObject_RichCompareBool(PyObject *v, PyObject *w, int op);
Py_hash_t PyObject_HashNotImplemented(PyObject *v);
Py_hash_t PyObject_Hash(PyObject *v);
PyObject *PyObject_GetIter(PyObject *o);
int PyIter_Check(PyObject *obj);
int PyIter_NextItem(PyObject *iter, PyObject **item);
PyObject *PyIter_Next(PyObject *iter);

int PySequence_Check(PyObject *s);
PyObject *PySeqIter_New(PyObject *seq);
int PyErr_Format(PyObject *exc, const char *format, ...);
void PyErr_SetString(PyObject *exc, const char *message);
void PyErr_BadInternalCall(void);
int PyErr_Occurred(void);
void PyErr_Clear(void);
Py_ssize_t PyNumber_AsSsize_t(PyObject *o, PyObject *exc);
PyObject *Py_NewRef(PyObject *obj);
PyObject *Py_XNewRef(PyObject *obj);
void Py_INCREF(PyObject *op);
void Py_DECREF(PyObject *op);
void Py_XSETREF(PyObject **p, PyObject *o);
void Py_CLEAR(PyObject *op);
void Py_XDECREF(PyObject *op);
PyObject *PyObject_Repr(PyObject *v);
int PyType_IsSubtype(PyTypeObject *a, PyTypeObject *b);

PyThreadState *_PyThreadState_GET(void);
PyObject *_PyErr_Occurred(PyThreadState *tstate);
int _PyErr_ExceptionMatches(PyThreadState *tstate, PyObject *exc);
void _PyErr_Clear(PyThreadState *tstate);

PyObject *_PyObject_NextNotImplemented(PyObject *self);

#endif /* PYTHON_H */
