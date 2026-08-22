/* P3.2b methodobject core extract — PyCFunction_GetFlags, vectorcall dispatch
 * selection, and meth_repr. Curated from reference/cpython Objects/methodobject.c.
 * Full PyCMethod_New / vectorcall bodies deferred per TODO.md.
 */

#include <stddef.h>

typedef struct _object PyObject;
typedef struct _typeobject PyTypeObject;

#define METH_VARARGS  0x0001
#define METH_KEYWORDS 0x0002
#define METH_NOARGS   0x0004
#define METH_O        0x0008
#define METH_STATIC   0x0020
#define METH_FASTCALL 0x0080
#define METH_METHOD   0x0200

typedef enum {
    CF_VECTORCALL_NONE = 0,
    CF_VECTORCALL_FASTCALL,
    CF_VECTORCALL_FASTCALL_KEYWORDS,
    CF_VECTORCALL_NOARGS,
    CF_VECTORCALL_O,
    CF_VECTORCALL_FASTCALL_KEYWORDS_METHOD,
    CF_VECTORCALL_BAD
} CFunctionVectorcallKind;

typedef PyObject *(*PyCFunction)(PyObject *, PyObject *);

struct PyMethodDef {
    const char  *ml_name;
    PyCFunction ml_meth;
    int         ml_flags;
    const char  *ml_doc;
};

typedef struct {
    PyObject ob_base;
    PyMethodDef *m_ml;
    PyObject    *m_self;
    PyObject    *m_module;
    PyObject    *m_weakreflist;
    void       *vectorcall;
} PyCFunctionObject;

typedef struct {
    PyCFunctionObject func;
    PyTypeObject *mm_class;
} PyCMethodObject;

#define _PyCFunctionObject_CAST(func) ((PyCFunctionObject *)(func))
#define Py_TYPE(op) (((PyObject *)(op))->ob_type)

struct _object {
    PyTypeObject *ob_type;
};

struct _typeobject {
    const char *tp_name;
};

static inline int
PyCFunction_Check(PyObject *op)
{
    (void)op;
    return 1;
}

static inline PyCFunction
PyCFunction_GET_FUNCTION(PyObject *func)
{
    return _PyCFunctionObject_CAST(func)->m_ml->ml_meth;
}

static inline PyObject *
PyCFunction_GET_SELF(PyObject *func_obj)
{
    PyCFunctionObject *func = _PyCFunctionObject_CAST(func_obj);
    if (func->m_ml->ml_flags & METH_STATIC) {
        return NULL;
    }
    return func->m_self;
}

static inline int
PyCFunction_GET_FLAGS(PyObject *func)
{
    return _PyCFunctionObject_CAST(func)->m_ml->ml_flags;
}

static inline PyTypeObject *
PyCFunction_GET_CLASS(PyObject *func_obj)
{
    PyCFunctionObject *func = _PyCFunctionObject_CAST(func_obj);
    if (func->m_ml->ml_flags & METH_METHOD) {
        return ((PyCMethodObject *)func)->mm_class;
    }
    return NULL;
}

CFunctionVectorcallKind
cfunction_select_vectorcall(int ml_flags)
{
    switch (ml_flags & (METH_VARARGS | METH_FASTCALL | METH_NOARGS |
                        METH_O | METH_KEYWORDS | METH_METHOD))
    {
        case METH_VARARGS:
        case METH_VARARGS | METH_KEYWORDS:
            return CF_VECTORCALL_NONE;
        case METH_FASTCALL:
            return CF_VECTORCALL_FASTCALL;
        case METH_FASTCALL | METH_KEYWORDS:
            return CF_VECTORCALL_FASTCALL_KEYWORDS;
        case METH_NOARGS:
            return CF_VECTORCALL_NOARGS;
        case METH_O:
            return CF_VECTORCALL_O;
        case METH_METHOD | METH_FASTCALL | METH_KEYWORDS:
            return CF_VECTORCALL_FASTCALL_KEYWORDS_METHOD;
        default:
            return CF_VECTORCALL_BAD;
    }
}

int
cfunction_uses_vectorcall(int ml_flags)
{
    CFunctionVectorcallKind kind = cfunction_select_vectorcall(ml_flags);
    return kind != CF_VECTORCALL_NONE && kind != CF_VECTORCALL_BAD;
}

PyCFunction
PyCFunction_GetFunction(PyObject *op)
{
    if (!PyCFunction_Check(op)) {
        return NULL;
    }
    return PyCFunction_GET_FUNCTION(op);
}

PyObject *
PyCFunction_GetSelf(PyObject *op)
{
    if (!PyCFunction_Check(op)) {
        return NULL;
    }
    return PyCFunction_GET_SELF(op);
}

int
PyCFunction_GetFlags(PyObject *op)
{
    if (!PyCFunction_Check(op)) {
        return -1;
    }
    return PyCFunction_GET_FLAGS(op);
}

PyTypeObject *
PyCMethod_GetClass(PyObject *op)
{
    if (!PyCFunction_Check(op)) {
        return NULL;
    }
    return PyCFunction_GET_CLASS(op);
}

static int
PyModule_Check(PyObject *obj)
{
    (void)obj;
    return 0;
}

static PyObject *
PyUnicode_FromFormat(const char *fmt, ...)
{
    (void)fmt;
    return NULL;
}

static PyObject *
meth_repr(PyObject *self)
{
    PyCFunctionObject *m = _PyCFunctionObject_CAST(self);
    if (m->m_self == NULL || PyModule_Check(m->m_self)) {
        return PyUnicode_FromFormat("<built-in function %s>",
                                    m->m_ml->ml_name);
    }

    return PyUnicode_FromFormat("<built-in method %s of %s object at %p>",
                                m->m_ml->ml_name,
                                Py_TYPE(m->m_self)->tp_name,
                                m->m_self);
}
