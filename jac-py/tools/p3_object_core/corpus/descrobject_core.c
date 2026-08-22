/* P3.2b descrobject core extract — descr_check, getset/property getter paths.
 * Curated from reference/cpython Objects/descrobject.c.
 * Python-level classmethod/staticmethod __get__ live in funcobject.c (deferred).
 */

#include "Python.h"

#include <assert.h>
#include <stddef.h>

#ifndef PyObject_TypeCheck
#define PyObject_TypeCheck(ob, type) \
    (Py_IS_TYPE((ob), (type)) || PyType_IsSubtype(Py_TYPE(ob), (type)))
#endif

typedef struct {
    PyObject_HEAD
    PyTypeObject *d_type;
    PyObject *d_name;
    PyObject *d_qualname;
} PyDescrObject;

typedef struct {
    PyObject *(*get)(PyObject *, void *);
    int (*set)(PyObject *, PyObject *, void *);
    const char *name;
    const char *doc;
    void *closure;
} PyGetSetDef;

typedef struct {
    PyDescrObject d_common;
    PyGetSetDef *d_getset;
} PyGetSetDescrObject;

typedef struct {
    PyObject_HEAD
    PyObject *prop_get;
    PyObject *prop_set;
    PyObject *prop_del;
    PyObject *prop_doc;
    PyObject *prop_name;
    int getter_doc;
} propertyobject;

#define PyDescr_TYPE(x) (((PyDescrObject *)(x))->d_type)

PyObject *PyObject_CallOneArg(PyObject *func, PyObject *arg);

static PyObject *
descr_name(PyDescrObject *descr)
{
    if (descr->d_name != NULL && PyUnicode_Check(descr->d_name))
        return descr->d_name;
    return NULL;
}

static int
descr_check(PyDescrObject *descr, PyObject *obj)
{
    if (!PyObject_TypeCheck(obj, descr->d_type)) {
        PyErr_Format(PyExc_TypeError,
                     "descriptor '%V' for '%.100s' objects "
                     "doesn't apply to a '%.100s' object",
                     descr_name(descr), "?",
                     descr->d_type->tp_name,
                     Py_TYPE(obj)->tp_name);
        return -1;
    }
    return 0;
}

static int
descr_setcheck(PyDescrObject *descr, PyObject *obj, PyObject *value)
{
    assert(obj != NULL);
    if (!PyObject_TypeCheck(obj, descr->d_type)) {
        PyErr_Format(PyExc_TypeError,
                     "descriptor '%V' for '%.100s' objects "
                     "doesn't apply to a '%.100s' object",
                     descr_name(descr), "?",
                     descr->d_type->tp_name,
                     Py_TYPE(obj)->tp_name);
        return -1;
    }
    return 0;
}

static PyObject *
getset_get(PyObject *self, PyObject *obj, PyObject *type)
{
    PyGetSetDescrObject *descr = (PyGetSetDescrObject *)self;
    if (obj == NULL) {
        return Py_NewRef(descr);
    }
    if (descr_check((PyDescrObject *)descr, obj) < 0) {
        return NULL;
    }
    if (descr->d_getset->get != NULL)
        return descr->d_getset->get(obj, descr->d_getset->closure);
    PyErr_Format(PyExc_AttributeError,
                 "attribute '%V' of '%.100s' objects is not readable",
                 descr_name((PyDescrObject *)descr), "?",
                 PyDescr_TYPE(descr)->tp_name);
    return NULL;
}

static PyObject *
property_descr_get(PyObject *self, PyObject *obj, PyObject *type)
{
    if (obj == NULL || obj == Py_None) {
        return Py_NewRef(self);
    }

    propertyobject *gs = (propertyobject *)self;
    if (gs->prop_get == NULL) {
        PyErr_SetString(PyExc_AttributeError,
                        "property has no getter");
        return NULL;
    }

    return PyObject_CallOneArg(gs->prop_get, obj);
}
