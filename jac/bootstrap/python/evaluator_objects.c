/* Trusted field, constant and fixed-arity C API adapters. Evaluator branching,
 * error selection and ownership transitions live in Jac, not this file.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_objects.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_call.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_code.h"
#include "internal/pycore_object.h"
#include "internal/pycore_moduleobject.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_typeobject.h"
#include "internal/pycore_traceback.h"
#include "internal/pycore_sysmodule.h"
#include "internal/pycore_stackref.h"
#include "internal/pycore_unicodeobject.h"

_Static_assert(SPECIAL___ENTER__ == 0 && SPECIAL___EXIT__ == 1 &&
               SPECIAL___AENTER__ == 2 && SPECIAL___AEXIT__ == 3,
               "pinned special-method ABI");
_Static_assert(sizeof(int) == sizeof(int32_t), "pinned evaluator integer ABI");
_Static_assert(Py_CONSTANT_EMPTY_STR == 7 && Py_EQ == 2, "pinned object constant ABI");

int32_t jacpy_object_has_iter(JacPyObjectRef value) {
    return Py_TYPE(value)->tp_iter != NULL;
}
JacPyObjectRef jacpy_exception_type(PyThreadState *tstate, int32_t kind) {
    (void)tstate;
    /* Indices belong to this boundary, not CPython's type or opcode numbering. */
    PyObject *types[] = {PyExc_TypeError, PyExc_AttributeError, PyExc_KeyError,
                        PyExc_NameError, PyExc_UnboundLocalError, PyExc_SystemError,
                        PyExc_ImportError, PyExc_ValueError};
    assert(kind >= 0 && kind < (int32_t)(sizeof(types) / sizeof(types[0])));
    return types[kind];
}
void jacpy_format_function_type_error(PyThreadState *tstate, const char *format,
                                    JacPyObjectRef function, JacPyObjectRef operand) {
    _PyErr_Format(tstate, PyExc_TypeError, format, function, Py_TYPE(operand)->tp_name);
}
void jacpy_format_objects_error(PyThreadState *tstate, JacPyObjectRef exception,
                               const char *format, JacPyObjectRef first, JacPyObjectRef second) {
    _PyErr_Format(tstate, exception, format, first, second);
}
void jacpy_format_cstring_error(PyThreadState *tstate, JacPyObjectRef exception,
                               const char *format, const char *value) {
    _PyErr_Format(tstate, exception, format, value);
}
int32_t jacpy_cstring_is_null(const char *value) { return value == NULL; }
int32_t jacpy_name_error_has_name(JacPyObjectRef exception) {
    return ((PyNameErrorObject *)exception)->name != NULL;
}
JacPyObjectRef jacpy_eval_identifier(PyThreadState *tstate, int32_t identifier) {
    (void)tstate;
    PyObject *names[] = {&_Py_ID(name), &_Py_ID(__aenter__), &_Py_ID(__aexit__),
                        &_Py_ID(__enter__), &_Py_ID(__exit__), &_Py_ID(__import__),
                        &_Py_ID(__builtins__), &_Py_ID(__name__), &_Py_ID(__spec__)};
    assert(identifier >= 0 && identifier < (int32_t)(sizeof(names) / sizeof(names[0])));
    return names[identifier];
}
JacPyObjectRef jacpy_code_local_name(JacPyObjectRef code, int64_t index) {
    return PyTuple_GET_ITEM(((PyCodeObject *)code)->co_localsplusnames, index);
}
int32_t jacpy_code_first_free(JacPyObjectRef code) {
    return PyUnstable_Code_GetFirstFree((PyCodeObject *)code);
}
const char *jacpy_eval_error_format(int32_t kind) {
    static const char *const formats[] = {
        "name '%.200s' is not defined",
        "cannot access local variable '%s' where it is not associated with a value",
        "cannot access free variable '%s' where it is not associated with a value in enclosing scope"
    };
    assert(kind >= 0 && kind < (int32_t)(sizeof(formats) / sizeof(formats[0])));
    return formats[kind];
}
int32_t jacpy_type_has_await(JacPyObjectRef type) {
    PyAsyncMethods *async = ((PyTypeObject *)type)->tp_as_async;
    return async != NULL && async->am_await != NULL;
}
void jacpy_format_type_error(PyThreadState *tstate, const char *format, JacPyObjectRef type) {
    _PyErr_Format(tstate, PyExc_TypeError, format, ((PyTypeObject *)type)->tp_name);
}
int32_t jacpy_method_check(JacPyObjectRef value) { return PyMethod_Check(value); }
int32_t jacpy_function_check(JacPyObjectRef value) { return PyFunction_Check(value); }
int32_t jacpy_cfunction_check(JacPyObjectRef value) { return PyCFunction_Check(value); }
JacPyObjectRef jacpy_method_function(JacPyObjectRef method) {
    return PyMethod_GET_FUNCTION(method);
}
JacPyObjectRef jacpy_function_name(JacPyObjectRef function) {
    return ((PyFunctionObject *)function)->func_name;
}
const char *jacpy_cfunction_name(JacPyObjectRef function) {
    return ((PyCFunctionObject *)function)->m_ml->ml_name;
}
const char *jacpy_object_type_name(JacPyObjectRef value) {
    return Py_TYPE(value)->tp_name;
}
const char *jacpy_function_description(int32_t callable) {
    return callable ? "()" : " object";
}
JacPyObjectRef jacpy_object_type(JacPyObjectRef value) { return (PyObject *)Py_TYPE(value); }
JacPyObjectRef jacpy_type_lookup(JacPyObjectRef type, JacPyObjectRef name) {
    return _PyType_Lookup((PyTypeObject *)type, name);
}
int32_t jacpy_object_has_descr_get(JacPyObjectRef value) {
    return Py_TYPE(value)->tp_descr_get != NULL;
}
void jacpy_eval_fatal(const char *message) { Py_FatalError(message); }
int32_t jacpy_object_is(JacPyObjectRef left, JacPyObjectRef right) { return left == right; }

/* Output-parameter ABI adaptation. The private marker cannot escape through
 * a PyObjectRef; only jacpy_lookup_take converts a lookup back to an object.
 * No new reference is added to a successful API result.
 */
static char jacpy_lookup_missing;
static JacPyLookupRef jacpy_lookup_pack(int status, PyObject *value) {
    assert(status >= -1 && status <= 1);
    assert((status == 1) == (value != NULL));
    return status == 0 ? (void *)&jacpy_lookup_missing : value;
}
void jacpy_lookup_close(JacPyLookupRef result) {
    if (result != &jacpy_lookup_missing) {
        Py_XDECREF((PyObject *)result);
    }
}
int32_t jacpy_lookup_state(JacPyLookupRef result) {
    return result == NULL ? -1 : result == &jacpy_lookup_missing ? 0 : 1;
}
JacPyObjectRef jacpy_lookup_take(JacPyLookupRef result) {
    return result == &jacpy_lookup_missing ? NULL : (PyObject *)result;
}
JacPyLookupRef jacpy_mapping_lookup(JacPyObjectRef mapping, JacPyObjectRef key) {
    PyObject *value = NULL;
    int status = PyMapping_GetOptionalItem(mapping, key, &value);
    return jacpy_lookup_pack(status, value);
}
JacPyLookupRef jacpy_dict_lookup(JacPyObjectRef dictionary, JacPyObjectRef key) {
    PyObject *value = NULL;
    int status = PyDict_GetItemRef(dictionary, key, &value);
    return jacpy_lookup_pack(status, value);
}
JacPyLookupRef jacpy_attribute_lookup(JacPyObjectRef object, JacPyObjectRef name) {
    PyObject *value = NULL;
    int status = PyObject_GetOptionalAttr(object, name, &value);
    return jacpy_lookup_pack(status, value);
}
JacPyLookupRef jacpy_module_origin_lookup(JacPyObjectRef specification) {
    PyObject *value = NULL;
    int status = _PyModuleSpec_GetFileOrigin(specification, &value);
    return jacpy_lookup_pack(status, value);
}
JacPyLookupRef jacpy_sys_lookup(const char *name) {
    PyObject *value = NULL;
    int status = _PySys_GetOptionalAttrString(name, &value);
    return jacpy_lookup_pack(status, value);
}
JacPyObjectRef jacpy_none(PyThreadState *tstate) { (void)tstate; return Py_None; }
void jacpy_set_string_error(PyThreadState *tstate, JacPyObjectRef exception, const char *message) {
    _PyErr_SetString(tstate, exception, message);
}
JacPyObjectRef jacpy_vectorcall_five(JacPyObjectRef function, JacPyObjectRef a,
    JacPyObjectRef b, JacPyObjectRef c, JacPyObjectRef d, JacPyObjectRef e) {
    PyObject *arguments[5] = {a, b, c, d, e};
    return PyObject_Vectorcall(function, arguments, 5, NULL);
}
JacPyObjectRef jacpy_unicode_format_four(const char *format, JacPyObjectRef a,
    JacPyObjectRef b, JacPyObjectRef c, JacPyObjectRef d) {
    return PyUnicode_FromFormat(format, a, b, c, d);
}
int32_t jacpy_unicode_check(JacPyObjectRef value) { return PyUnicode_Check(value); }
int32_t jacpy_anyset_check(JacPyObjectRef value) { return PyAnySet_Check(value); }
int32_t jacpy_module_check(JacPyObjectRef value) { return PyModule_Check(value); }

int64_t jacpy_exception_table_size(JacPyObjectRef code) {
    return PyBytes_GET_SIZE(((PyCodeObject *)code)->co_exceptiontable);
}
int32_t jacpy_exception_table_byte(JacPyObjectRef code, int64_t offset) {
    const unsigned char *bytes = (const unsigned char *)PyBytes_AS_STRING(
        ((PyCodeObject *)code)->co_exceptiontable);
    return bytes[offset];
}
/* Keep C int output slots and stack storage at the C ABI boundary. The search
 * and varint decoding run in native Jac and allocate no cursor object.
 */
extern int32_t jacpy_exception_table_handler(PyObject *, int32_t,
    int *, int *, int *, JacPyExceptionCursor *);
int jacpy_get_exception_handler(PyCodeObject *code, int index,
    int *level, int *handler, int *lasti) {
    JacPyExceptionCursor cursor = {0};
    return jacpy_exception_table_handler((PyObject *)code, index, level, handler, lasti, &cursor);
}

int64_t jacpy_code_argcount(JacPyObjectRef code) { return ((PyCodeObject *)code)->co_argcount; }
int64_t jacpy_code_kwonlyargcount(JacPyObjectRef code) { return ((PyCodeObject *)code)->co_kwonlyargcount; }
int64_t jacpy_code_posonlyargcount(JacPyObjectRef code) { return ((PyCodeObject *)code)->co_posonlyargcount; }
int64_t jacpy_list_size(JacPyObjectRef list) { return PyList_GET_SIZE(list); }
JacPyObjectRef jacpy_list_item(JacPyObjectRef list, int64_t index) { return PyList_GET_ITEM(list, index); }
void jacpy_list_initialize_item(JacPyObjectRef list, int64_t index, JacPyObjectRef item) {
    assert(PyList_GET_ITEM(list, index) == NULL);
    PyList_SET_ITEM(list, index, item);
}
int32_t jacpy_list_delete_slice(JacPyObjectRef list, int64_t start, int64_t end) {
    return PyList_SetSlice(list, start, end, NULL);
}
const char *jacpy_argument_text(int32_t kind) {
    static const char *const words[] = {"", "s", "was", "were", "positional", "keyword-only"};
    assert(kind >= 0 && kind < (int32_t)(sizeof(words) / sizeof(words[0])));
    return words[kind];
}
void jacpy_format_missing_error(PyThreadState *tstate, JacPyObjectRef qualname,
    int64_t count, const char *kind, const char *plural, JacPyObjectRef names) {
    _PyErr_Format(tstate, PyExc_TypeError, "%U() missing %zd required %s argument%s: %U",
                  qualname, (Py_ssize_t)count, kind, plural, names);
}
JacPyObjectRef jacpy_unicode_format_sizes(const char *format, int64_t first, int64_t second) {
    return PyUnicode_FromFormat(format, (Py_ssize_t)first, (Py_ssize_t)second);
}
JacPyObjectRef jacpy_unicode_format_kwonly(const char *given_plural, int64_t count, const char *plural) {
    return PyUnicode_FromFormat(" positional argument%s (and %zd keyword-only argument%s)",
                               given_plural, (Py_ssize_t)count, plural);
}
void jacpy_format_positional_error(PyThreadState *tstate, JacPyObjectRef qualname,
    JacPyObjectRef signature, const char *plural, int64_t given,
    JacPyObjectRef keyword_signature, const char *verb) {
    _PyErr_Format(tstate, PyExc_TypeError, "%U() takes %U positional argument%s but %zd%U %s given",
                  qualname, signature, plural, (Py_ssize_t)given, keyword_signature, verb);
}
int32_t jacpy_stack_array_is_null(const void *array, int64_t index) {
    return PyStackRef_IsNull(((const _PyStackRef *)array)[index]);
}
int32_t jacpy_stack_array_has_object(const void *array, int64_t index) {
    return PyStackRef_AsPyObjectBorrow(((const _PyStackRef *)array)[index]) != NULL;
}

struct JacPyMatchStorage {
    PyThreadState *tstate;
    _PyCStackRef self;
    _PyCStackRef method;
    int closed;
};
extern JacPyObjectRef jacpy_match_keys_impl(JacPyMatchStorage *, PyThreadState *,
    JacPyObjectRef, JacPyObjectRef);
PyObject *_PyEval_MatchKeys(PyThreadState *tstate, PyObject *mapping, PyObject *keys) {
    assert(PyTuple_CheckExact(keys));
    JacPyMatchStorage storage = {0};
    return jacpy_match_keys_impl(&storage, tstate, mapping, keys);
}
JacPyMatchRootsRef jacpy_match_roots_begin(JacPyMatchStorage *storage, PyThreadState *tstate,
    JacPyObjectRef mapping) {
    storage->tstate = tstate;
    _PyThreadState_PushCStackRef(tstate, &storage->self);
    _PyThreadState_PushCStackRef(tstate, &storage->method);
    storage->self.ref = PyStackRef_FromPyObjectBorrow(mapping);
    return storage;
}
void jacpy_match_roots_close(JacPyMatchRootsRef roots) {
    if (roots != NULL) {
        assert(!roots->closed);
        roots->closed = 1;
        _PyThreadState_PopCStackRef(roots->tstate, &roots->method);
        _PyThreadState_PopCStackRef(roots->tstate, &roots->self);
    }
}
int32_t jacpy_match_get_method(JacPyMatchRootsRef roots) {
    return _PyObject_GetMethodStackRef(roots->tstate, &roots->self.ref,
        &_Py_ID(get), &roots->method.ref);
}
int32_t jacpy_match_has_self(JacPyMatchRootsRef roots) { return !PyStackRef_IsNull(roots->self.ref); }
JacPyObjectRef jacpy_match_call_self(JacPyMatchRootsRef roots, JacPyObjectRef key, JacPyObjectRef missing) {
    PyObject *arguments[] = { PyStackRef_AsPyObjectBorrow(roots->self.ref), key, missing };
    return PyObject_Vectorcall(PyStackRef_AsPyObjectBorrow(roots->method.ref), arguments, 3, NULL);
}
JacPyObjectRef jacpy_match_call_bound(JacPyMatchRootsRef roots, JacPyObjectRef key, JacPyObjectRef missing) {
    PyObject *arguments[] = { key, missing };
    return PyObject_Vectorcall(PyStackRef_AsPyObjectBorrow(roots->method.ref), arguments, 2, NULL);
}
JacPyObjectRef jacpy_match_dummy(void) { return _PyObject_CallNoArgs((PyObject *)&PyBaseObject_Type); }
int32_t jacpy_type_check(JacPyObjectRef value) { return PyType_Check(value); }
int32_t jacpy_tuple_exact(JacPyObjectRef value) { return PyTuple_CheckExact(value); }
int32_t jacpy_unicode_exact(JacPyObjectRef value) { return PyUnicode_CheckExact(value); }
int32_t jacpy_type_match_self(JacPyObjectRef type) { return PyType_HasFeature((PyTypeObject *)type, _Py_TPFLAGS_MATCH_SELF); }
JacPyObjectRef jacpy_match_args_name(PyThreadState *tstate) { (void)tstate; return &_Py_ID(__match_args__); }
void jacpy_match_duplicate(PyThreadState *tstate, JacPyObjectRef type, JacPyObjectRef name) {
    _PyErr_Format(tstate, PyExc_TypeError, "%s() got multiple sub-patterns for attribute %R",
        ((PyTypeObject *)type)->tp_name, name);
}
void jacpy_match_args_type_error(PyThreadState *tstate, JacPyObjectRef type, JacPyObjectRef match_args) {
    _PyErr_Format(tstate, PyExc_TypeError, "%s.__match_args__ must be a tuple (got %s)",
        ((PyTypeObject *)type)->tp_name, Py_TYPE(match_args)->tp_name);
}
void jacpy_match_arity_error(PyThreadState *tstate, JacPyObjectRef type, int64_t allowed,
    const char *plural, int64_t given) {
    _PyErr_Format(tstate, PyExc_TypeError, "%s() accepts %zd positional sub-pattern%s (%zd given)",
        ((PyTypeObject *)type)->tp_name, (Py_ssize_t)allowed, plural, (Py_ssize_t)given);
}

int32_t jacpy_exception_group_check(JacPyObjectRef value) { return _PyBaseExceptionGroup_Check(value); }
JacPyObjectRef jacpy_tuple_single(JacPyObjectRef value) { return PyTuple_Pack(1, value); }
JacPyObjectRef jacpy_traceback_from_frame(JacPyObjectRef frame) {
    return _PyTraceBack_FromFrame(NULL, (PyFrameObject *)frame);
}
JacPyObjectRef jacpy_exception_group_split(JacPyObjectRef exception, JacPyObjectRef type) {
    return PyObject_CallMethod(exception, "split", "(O)", type);
}
void jacpy_exception_split_type_error(JacPyObjectRef exception, JacPyObjectRef pair) {
    PyErr_Format(PyExc_TypeError, "%.200s.split must return a tuple, not %.200s",
        Py_TYPE(exception)->tp_name, Py_TYPE(pair)->tp_name);
}
void jacpy_exception_split_size_error(JacPyObjectRef exception, int64_t size) {
    PyErr_Format(PyExc_TypeError, "%.200s.split must return a 2-tuple, got tuple of size %zd",
        Py_TYPE(exception)->tp_name, (Py_ssize_t)size);
}
void jacpy_exception_group_leak_on_traceback_error(JacPyObjectRef exception) {
    /* CPython 3.14.6 ceval.c returns without decrefing `wrapped` when
     * _PyTraceBack_FromFrame fails. This deliberately preserves that leak.
     * Removing it is a separate Python-semantics change, not an implicit
     * cleanup insertion by the ownership compiler.
     */
    (void)exception;
}

/* Stack-reference ABI adapter for the retained object runtime. */
_PyStackRef
_Py_LoadAttr_StackRefSteal(
    PyThreadState *tstate, _PyStackRef owner,
    PyObject *name, _PyStackRef *self_or_null)
{
    // Use _PyCStackRefs to ensure that both method and self are visible to
    // the GC. Even though self_or_null is on the evaluation stack, it may be
    // after the stackpointer and therefore not visible to the GC.
    _PyCStackRef method, self;
    _PyThreadState_PushCStackRef(tstate, &method);
    _PyThreadState_PushCStackRef(tstate, &self);
    self.ref = owner;  // steal reference to owner
    // NOTE: method.ref is initialized to PyStackRef_NULL and remains null on
    // error, so we don't need to explicitly use the return code from the call.
    _PyObject_GetMethodStackRef(tstate, &self.ref, name, &method.ref);
    *self_or_null = _PyThreadState_PopCStackRefSteal(tstate, &self);
    return _PyThreadState_PopCStackRefSteal(tstate, &method);
}
