/* Reference mechanics only; evaluator algorithms belong in native Jac.
 * See evaluator_refs.h for ownership, suspension and reentrancy contracts.
 * Stack-reference operations are supplied by the pinned CPython headers under
 * the PSF license (jaclang/runtime/python/LICENSE.cpython).
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_refs.h"
#include "internal/pycore_stackref.h"
#include "internal/pycore_genobject.h"
#include "internal/pycore_pyerrors.h"

_Static_assert(sizeof(_PyStackRef) == sizeof(JacPyStackRef), "stackref ABI");
_Static_assert(_Alignof(_PyStackRef) == _Alignof(JacPyStackRef), "stackref alignment");
_Static_assert(Py_TAG_REFCNT == 1 && Py_TAG_BITS == 3, "stackref tags changed");

static inline _PyStackRef unpack(JacPyStackRef value) {
    _PyStackRef ref = { .bits = value };
    assert(ref.bits != 0);
    return ref;
}

static inline JacPyStackRef pack(_PyStackRef value) {
    return value.bits;
}

JacPyObjectRef jacpy_ref_null(void) { return NULL; }
JacPyObjectRef jacpy_ref_new(JacPyObjectRef value) { return Py_XNewRef(value); }
int64_t jacpy_ref_is_null(JacPyObjectRef value) { return value == NULL; }
void jacpy_ref_close(JacPyObjectRef value) { Py_XDECREF(value); }
void jacpy_ref_clear(JacPyObjectRef *slot) { Py_CLEAR(*slot); }

JacPyStackRef jacpy_stack_null(void) { return pack(PyStackRef_NULL); }
int64_t jacpy_stack_is_null(JacPyStackRef value) {
    return PyStackRef_IsNull(unpack(value));
}
int64_t jacpy_stack_is_heap_safe(JacPyStackRef value) {
    return PyStackRef_IsHeapSafe(unpack(value));
}
int64_t jacpy_stack_is_int(JacPyStackRef value) {
    return PyStackRef_IsTaggedInt(unpack(value));
}
JacPyStackRef jacpy_stack_new(JacPyObjectRef value) {
    return pack(value ? PyStackRef_FromPyObjectNew(value) : PyStackRef_NULL);
}
JacPyStackRef jacpy_stack_steal(JacPyObjectRef value) {
    return pack(value ? PyStackRef_FromPyObjectSteal(value) : PyStackRef_NULL);
}
JacPyStackRef jacpy_stack_dup(JacPyStackRef value) {
    _PyStackRef ref = unpack(value);
    assert(PyStackRef_IsHeapSafe(ref));
    return pack(PyStackRef_IsNull(ref) ? ref : PyStackRef_DUP(ref));
}
JacPyStackRef jacpy_stack_promote(JacPyStackRef value) {
    _PyStackRef ref = unpack(value);
    if (PyStackRef_IsNull(ref)) return value;
    /* DUP retains owning references but leaves a tagged mortal borrow alone.
     * MakeHeapSafe supplies the missing retain in precisely that case. */
    return pack(PyStackRef_MakeHeapSafe(PyStackRef_DUP(ref)));
}
JacPyObjectRef jacpy_stack_object_new(JacPyStackRef value) {
    _PyStackRef ref = unpack(value);
    if (PyStackRef_IsNull(ref)) return NULL;
    if (PyStackRef_IsTaggedInt(ref))
        return PyLong_FromSsize_t(PyStackRef_UntagInt(ref));
    return PyStackRef_AsPyObjectNew(ref);
}
JacPyObjectRef jacpy_stack_object_borrow(JacPyStackRef value) {
    _PyStackRef ref = unpack(value);
    if (PyStackRef_IsNull(ref)) return NULL;
    if (PyStackRef_IsTaggedInt(ref)) {
        PyErr_SetString(PyExc_TypeError, "a tagged integer has no Python object to borrow");
        return NULL;
    }
    return PyStackRef_AsPyObjectBorrow(ref);
}
JacPyObjectRef jacpy_stack_object_steal(JacPyStackRef value) {
    _PyStackRef ref = unpack(value);
    if (PyStackRef_IsNull(ref)) return NULL;
    if (PyStackRef_IsTaggedInt(ref))
        return PyLong_FromSsize_t(PyStackRef_UntagInt(ref));
    return PyStackRef_AsPyObjectSteal(ref);
}
void jacpy_stack_close(JacPyStackRef value) { PyStackRef_XCLOSE(unpack(value)); }
void jacpy_stack_clear(JacPyStackRef *slot) {
    JacPyStackRef old = *slot;
    *slot = pack(PyStackRef_NULL);
    jacpy_stack_close(old);
}

/* Object-runtime primitives used by the evaluator support port. */
int64_t jacpy_eval_is_none(JacPyObjectRef value) { return Py_IsNone(value); }
int64_t jacpy_eval_index_check(JacPyObjectRef value) { return PyIndex_Check(value); }
int64_t jacpy_as_ssize(JacPyObjectRef value) { return PyNumber_AsSsize_t(value, NULL); }
int64_t jacpy_eval_error_pending(void) { return PyErr_Occurred() != NULL; }
void jacpy_type_error(const char *message) { PyErr_SetString(PyExc_TypeError, message); }

int64_t jacpy_coro_check(JacPyObjectRef value) { return PyCoro_CheckExact(value); }
int64_t jacpy_has_await(JacPyObjectRef value) {
    PyAsyncMethods *methods = Py_TYPE(value)->tp_as_async;
    return methods != NULL && methods->am_await != NULL;
}
JacPyObjectRef jacpy_gen_yieldfrom(JacPyObjectRef value) {
    assert(PyCoro_CheckExact(value));
    return _PyGen_yf((PyGenObject *)value);
}
int64_t jacpy_asyncgen_check(JacPyObjectRef value) { return PyAsyncGen_CheckExact(value); }
int64_t jacpy_has_anext(JacPyObjectRef value) {
    PyAsyncMethods *methods = Py_TYPE(value)->tp_as_async;
    return methods != NULL && methods->am_anext != NULL;
}
JacPyObjectRef jacpy_anext_call(JacPyObjectRef value) {
    assert(jacpy_has_anext(value));
    return Py_TYPE(value)->tp_as_async->am_anext(value);
}
void jacpy_type_error_for_object(const char *message, JacPyObjectRef value) {
    PyErr_Format(PyExc_TypeError, message, Py_TYPE(value)->tp_name);
}
void jacpy_type_error_from_cause(const char *message, JacPyObjectRef value) {
    _PyErr_FormatFromCause(PyExc_TypeError, message, Py_TYPE(value)->tp_name);
}
void jacpy_runtime_error(const char *message) {
    PyErr_SetString(PyExc_RuntimeError, message);
}

int64_t jacpy_eval_tuple_check(JacPyObjectRef value) { return PyTuple_Check(value); }
int64_t jacpy_eval_tuple_size(JacPyObjectRef value) { return PyTuple_GET_SIZE(value); }
JacPyObjectRef jacpy_eval_tuple_item(JacPyObjectRef value, int64_t index) {
    assert(index >= 0 && index < PyTuple_GET_SIZE(value));
    return PyTuple_GET_ITEM(value, index);
}
int64_t jacpy_eval_exception_class_check(JacPyObjectRef value) {
    return PyExceptionClass_Check(value);
}
int64_t jacpy_eval_exception_group_subclass(JacPyObjectRef value) {
    return PyObject_IsSubclass(value, PyExc_BaseExceptionGroup);
}
void jacpy_eval_type_error(PyThreadState *tstate, const char *message) {
    _PyErr_SetString(tstate, PyExc_TypeError, message);
}

JacPyObjectRef jacpy_eval_topmost_exception(PyThreadState *tstate) {
    return _PyErr_GetTopmostException(tstate)->exc_value;
}
int64_t jacpy_eval_exception_instance_check(JacPyObjectRef value) {
    return PyExceptionInstance_Check(value);
}
JacPyObjectRef jacpy_eval_exception_type_new(JacPyObjectRef value) {
    return Py_NewRef(PyExceptionInstance_Class(value));
}
void jacpy_eval_runtime_error(PyThreadState *tstate, const char *message) {
    _PyErr_SetString(tstate, PyExc_RuntimeError, message);
}
void jacpy_eval_bad_exception_result(PyThreadState *tstate,
                                   JacPyObjectRef factory, JacPyObjectRef result) {
    _PyErr_Format(tstate, PyExc_TypeError,
                  "calling %R should have returned an instance of "
                  "BaseException, not %R", factory, Py_TYPE(result));
}
