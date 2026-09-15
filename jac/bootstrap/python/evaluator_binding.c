/* Trusted argument-place operations. All binding decisions, name matching,
 * default selection and cleanup iteration are implemented in native Jac.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_binding.h"
#include "internal/pycore_code.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_call.h"
#include "internal/pycore_frame.h"
#include "internal/pycore_function.h"
#include "internal/pycore_interpframe.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_stats.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_tuple.h"

_Static_assert(Py_CONSTANT_EMPTY_TUPLE == 9, "pinned empty tuple identifier");

struct JacPyBindingStorage {
    PyFunctionObject *function;
    PyCodeObject *code;
    _PyStackRef *locals;
    const _PyStackRef *arguments;
    Py_ssize_t count;
    Py_ssize_t cursor;
    int closed;
};

extern void jacpy_binding_close_impl(JacPyBindingStorage *, JacPyBindingRef);

void jacpy_binding_close(JacPyBindingRef binding) {
    if (binding != NULL) {
        assert(!binding->closed);
        jacpy_binding_close_impl(binding, binding);
    }
}
void jacpy_binding_disarm(JacPyBindingStorage *storage, JacPyBindingRef binding) {
    assert(storage == binding && !binding->closed && binding->cursor == binding->count);
    binding->closed = 1;
}
int64_t jacpy_binding_remaining(JacPyBindingRef binding) {
    assert(!binding->closed);
    return binding->count - binding->cursor;
}
int64_t jacpy_binding_position(JacPyBindingRef binding) {
    assert(!binding->closed);
    return binding->cursor;
}
void jacpy_binding_move_next(JacPyBindingRef binding, int64_t local) {
    assert(!binding->closed && binding->cursor < binding->count);
    assert(PyStackRef_IsNull(binding->locals[local]));
    binding->locals[local] = binding->arguments[binding->cursor];
    binding->cursor++;
}
void jacpy_binding_discard_next(JacPyBindingRef binding) {
    assert(!binding->closed && binding->cursor < binding->count);
    _PyStackRef value = binding->arguments[binding->cursor++];
    /* Publish consumption before a finalizer can reenter the evaluator. */
    PyStackRef_CLOSE(value);
}
JacPyObjectRef jacpy_binding_peek_next(JacPyBindingRef binding) {
    assert(!binding->closed && binding->cursor < binding->count);
    return PyStackRef_AsPyObjectBorrow(binding->arguments[binding->cursor]);
}
JacPyObjectRef jacpy_binding_pack(JacPyBindingRef binding, int64_t count) {
    assert(!binding->closed && count >= 0 && count <= binding->count - binding->cursor);
    PyObject *tuple = _PyTuple_FromStackRefStealOnSuccess(binding->arguments + binding->cursor, count);
    if (tuple != NULL) {
        binding->cursor += count;
    }
    return tuple;
}
void jacpy_binding_put_object(JacPyBindingRef binding, int64_t local, JacPyObjectRef value) {
    assert(!binding->closed && PyStackRef_IsNull(binding->locals[local]));
    binding->locals[local] = PyStackRef_FromPyObjectSteal(value);
}
void jacpy_binding_copy_object(JacPyBindingRef binding, int64_t local, JacPyObjectRef value) {
    assert(!binding->closed && PyStackRef_IsNull(binding->locals[local]));
    binding->locals[local] = PyStackRef_FromPyObjectNew(value);
}
JacPyObjectRef jacpy_binding_local_object(JacPyBindingRef binding, int64_t local) {
    return PyStackRef_AsPyObjectBorrow(binding->locals[local]);
}
const void *jacpy_binding_locals(JacPyBindingRef binding) { return binding->locals; }
JacPyObjectRef jacpy_binding_code(JacPyBindingRef binding) { return (PyObject *)binding->code; }
JacPyObjectRef jacpy_binding_qualname(JacPyBindingRef binding) { return binding->function->func_qualname; }
JacPyObjectRef jacpy_binding_defaults(JacPyBindingRef binding) { return binding->function->func_defaults; }
JacPyObjectRef jacpy_binding_kwdefaults(JacPyBindingRef binding) { return binding->function->func_kwdefaults; }
int32_t jacpy_binding_varargs(JacPyBindingRef binding) { return (binding->code->co_flags & CO_VARARGS) != 0; }
int32_t jacpy_binding_varkeywords(JacPyBindingRef binding) { return (binding->code->co_flags & CO_VARKEYWORDS) != 0; }
void jacpy_binding_suggestion_name(JacPyBindingRef binding, JacPyObjectRef names,
    int64_t local, int64_t output) {
    /* Preserve the pinned evaluator's interned-name store, with no extra retain. */
    assert(PyList_GET_ITEM(names, output) == NULL);
    PyObject *name = PyTuple_GET_ITEM(binding->code->co_localsplusnames, local);
    assert(_Py_IsImmortal(name));
    PyList_SET_ITEM(names, output, name);
}
void jacpy_format_three_objects(PyThreadState *tstate, JacPyObjectRef exception,
    const char *format, JacPyObjectRef a, JacPyObjectRef b, JacPyObjectRef c) {
    _PyErr_Format(tstate, exception, format, a, b, c);
}

extern JacPyFrameRef jacpy_frame_push_impl(JacPyBindingStorage *, JacPyBindingRef,
    PyThreadState *, const void *, JacPyFrameRef, JacPyStackRef, JacPyObjectRef,
    int64_t, JacPyObjectRef);

/* Adapt the public stackref-by-value ABI and provide only descriptor storage.
 * Allocation decisions, ownership transfers, binding and rollback are Jac.
 */
_PyInterpreterFrame *_PyEvalFramePushAndInit(PyThreadState *tstate, _PyStackRef function,
    PyObject *locals, const _PyStackRef *arguments, size_t positional,
    PyObject *keywords, _PyInterpreterFrame *previous) {
    Py_ssize_t keyword_count = keywords == NULL ? 0 : PyTuple_GET_SIZE(keywords);
    assert(positional <= PY_SSIZE_T_MAX && keyword_count <= PY_SSIZE_T_MAX - positional);
    PyFunctionObject *func = (PyFunctionObject *)PyStackRef_AsPyObjectBorrow(function);
    JacPyBindingStorage storage = {
        func, (PyCodeObject *)func->func_code, NULL, arguments,
        (Py_ssize_t)positional + keyword_count, 0, 0
    };
    return jacpy_frame_push_impl(&storage, &storage, tstate, arguments, previous,
        function.bits, locals, (int64_t)positional, keywords);
}
JacPyFrameSpace *jacpy_frame_allocate(PyThreadState *tstate, JacPyObjectRef code) {
    CALL_STAT_INC(frames_pushed);
    return _PyThreadState_PushFrame(tstate, ((PyCodeObject *)code)->co_framesize);
}
int32_t jacpy_frame_space_is_null(JacPyFrameSpace *space) { return space == NULL; }
JacPyFrameRef jacpy_frame_null(void) { return NULL; }
JacPyFrameRef jacpy_frame_initialize(PyThreadState *tstate, JacPyFrameSpace *space,
    const void *arguments, JacPyFrameRef previous, JacPyStackRef function,
    JacPyObjectRef locals, JacPyObjectRef code) {
    (void)arguments;
    _PyStackRef stack_function = { .bits = function };
    _PyFrame_Initialize(tstate, space, stack_function, locals, (PyCodeObject *)code, 0, previous);
    return space;
}
void jacpy_binding_attach_frame(JacPyBindingRef binding, JacPyFrameRef frame) {
    assert(binding->locals == NULL && binding->cursor == 0);
    assert(frame->owner == FRAME_OWNED_BY_THREAD);
    binding->locals = frame->localsplus;
}

struct JacPyCallStorage {
    _PyStackRef small[8];
    _PyStackRef *values;
    Py_ssize_t capacity;
    Py_ssize_t filled;
    Py_ssize_t consumed;
    int heap;
    int closed;
    PyObject *const *unpacked;
    PyObject *keywords;
};
extern PyObject *jacpy_eval_vector_impl(JacPyCallStorage *, PyThreadState *,
    PyObject *, PyObject *, PyObject *const *, int64_t, PyObject *);
extern void jacpy_callargs_close_impl(JacPyCallStorage *, JacPyCallArgsRef);

PyObject *_PyEval_Vector(PyThreadState *tstate, PyFunctionObject *function,
    PyObject *locals, PyObject *const *arguments, size_t positional, PyObject *keywords) {
    assert(positional <= PY_SSIZE_T_MAX);
    JacPyCallStorage storage = {0};
    return jacpy_eval_vector_impl(&storage, tstate, (PyObject *)function,
        locals, arguments, (int64_t)positional, keywords);
}
JacPyCallArgsRef jacpy_callargs_begin(JacPyCallStorage *storage) {
    assert(storage->values == NULL && !storage->closed);
    return storage;
}
void jacpy_callargs_close(JacPyCallArgsRef arguments) {
    if (arguments != NULL) {
        assert(!arguments->closed);
        jacpy_callargs_close_impl(arguments, arguments);
    }
}
void jacpy_callargs_use_small(JacPyCallArgsRef arguments, int64_t count) {
    assert(arguments->values == NULL && count >= 0 && count <= 8);
    arguments->values = arguments->small;
    arguments->capacity = count;
}
int32_t jacpy_callargs_allocate(JacPyCallArgsRef arguments, int64_t count) {
    assert(arguments->values == NULL && count > 8);
    arguments->values = PyMem_Malloc(sizeof(_PyStackRef) * count);
    arguments->capacity = count;
    arguments->heap = 1;
    return arguments->values != NULL;
}
void jacpy_callargs_copy_next(JacPyCallArgsRef arguments, JacPyObjectRef value) {
    assert(!arguments->closed && arguments->filled < arguments->capacity);
    arguments->values[arguments->filled++] = PyStackRef_FromPyObjectNew(value);
}
int64_t jacpy_callargs_pending(JacPyCallArgsRef arguments) {
    assert(!arguments->closed);
    return (arguments->unpacked != NULL ? arguments->capacity : arguments->filled) - arguments->consumed;
}
void jacpy_callargs_discard_next(JacPyCallArgsRef arguments) {
    Py_ssize_t index = arguments->consumed++;
    if (index < arguments->filled) {
        _PyStackRef value = arguments->values[index];
        PyStackRef_CLOSE(value);
    }
    else {
        assert(arguments->unpacked != NULL && index < arguments->capacity);
        Py_DECREF(arguments->unpacked[index]);
    }
}
void jacpy_callargs_release(JacPyCallStorage *storage, JacPyCallArgsRef arguments) {
    assert(storage == arguments && !arguments->closed && jacpy_callargs_pending(arguments) == 0);
    arguments->closed = 1;
    if (arguments->unpacked != NULL) {
        _PyStack_UnpackDict_FreeNoDecRef(arguments->unpacked, arguments->keywords);
    }
    else if (arguments->heap) {
        PyMem_Free(arguments->values);
    }
}
JacPyObjectRef jacpy_object_array_item(PyObject *const *values, int64_t index) { return values[index]; }
JacPyFrameRef jacpy_frame_previous_null(PyThreadState *tstate) { (void)tstate; return NULL; }
int32_t jacpy_frame_is_null(JacPyFrameRef frame) { return frame == NULL; }
JacPyFrameRef jacpy_callargs_push_frame(PyThreadState *tstate, JacPyCallArgsRef arguments,
    JacPyFrameRef previous, JacPyStackRef function, JacPyObjectRef locals,
    int64_t positional, JacPyObjectRef keywords) {
    assert(arguments->filled == arguments->capacity && arguments->consumed == 0);
    /* Every entry was constructed from a newly owned object reference, so
     * freeing this temporary array cannot invalidate the frame's references.
     * The callee consumes them on both success and failure.
     */
    arguments->consumed = arguments->filled;
    _PyStackRef stack_function = { .bits = function };
    return _PyEvalFramePushAndInit(tstate, stack_function, locals,
        arguments->values, positional, keywords, previous);
}
void jacpy_eval_vector_stat(void) { EVAL_CALL_STAT_INC(EVAL_CALL_VECTOR); }
JacPyObjectRef jacpy_eval_owned_frame(PyThreadState *tstate, JacPyFrameRef frame, int32_t throwflag) {
    return _PyEval_EvalFrame(tstate, frame, throwflag);
}

struct JacPyLocalTransferSlot { PyObject *value; };
extern JacPyFrameRef jacpy_frame_push_ex_impl(JacPyCallStorage *, PyThreadState *,
    JacPyFrameRef, JacPyStackRef, JacPyLocalTransferSlot *, int64_t, PyObject *, PyObject *);
JacPyFrameRef jacpy_frame_push_ex(PyThreadState *tstate, _PyStackRef function,
    PyObject *locals, Py_ssize_t positional, PyObject *values, PyObject *keywords,
    JacPyFrameRef previous) {
    JacPyCallStorage storage = {0};
    JacPyLocalTransferSlot local_slot = { locals };
    return jacpy_frame_push_ex_impl(&storage, tstate, previous, function.bits,
        &local_slot, positional, values, keywords);
}
JacPyObjectRef jacpy_locals_transfer(JacPyLocalTransferSlot *slot) {
    PyObject *value = slot->value;
    slot->value = NULL;
    return value;
}
int64_t jacpy_call_dict_size(JacPyObjectRef dictionary) { return PyDict_GET_SIZE(dictionary); }
int32_t jacpy_callargs_unpack(JacPyCallArgsRef arguments, PyThreadState *tstate,
    JacPyObjectRef values, int64_t positional, JacPyObjectRef keywords) {
    assert(arguments->values == NULL);
    arguments->unpacked = _PyStack_UnpackDict(tstate, _PyTuple_ITEMS(values), positional,
        keywords, &arguments->keywords);
    if (arguments->unpacked == NULL) {
        return 0;
    }
    _Static_assert(sizeof(PyObject *) == sizeof(_PyStackRef), "unpacked argument storage ABI");
    arguments->capacity = positional + PyDict_GET_SIZE(keywords);
    arguments->values = (_PyStackRef *)arguments->unpacked;
    return 1;
}
void jacpy_callargs_convert_next(JacPyCallArgsRef arguments) {
    assert(arguments->unpacked != NULL && arguments->filled < arguments->capacity);
    Py_ssize_t index = arguments->filled++;
    arguments->values[index] = PyStackRef_FromPyObjectSteal(arguments->unpacked[index]);
}
int64_t jacpy_callargs_filled(JacPyCallArgsRef arguments) { return arguments->filled; }
int64_t jacpy_callargs_capacity(JacPyCallArgsRef arguments) { return arguments->capacity; }
JacPyObjectRef jacpy_callargs_keywords(JacPyCallArgsRef arguments) { return arguments->keywords; }

struct JacPyLegacyStorage {
    PyObject *const *input;
    PyObject *const *keywords;
    PyObject **allocated;
    Py_ssize_t capacity;
    int closed;
};
extern PyObject *jacpy_eval_code_ex_impl(JacPyLegacyStorage *, PyObject *, PyObject *,
    PyObject *, PyObject *const *, int64_t, PyObject *const *, int64_t,
    PyObject *const *, int64_t, PyObject *, PyObject *);
PyObject *PyEval_EvalCodeEx(PyObject *code, PyObject *globals, PyObject *locals,
    PyObject *const *arguments, int positional, PyObject *const *keywords, int keyword_count,
    PyObject *const *defaults, int default_count, PyObject *keyword_defaults, PyObject *closure) {
    JacPyLegacyStorage storage = {0};
    return jacpy_eval_code_ex_impl(&storage, code, globals, locals, arguments, positional,
        keywords, keyword_count, defaults, default_count, keyword_defaults, closure);
}
JacPyLegacyArgsRef jacpy_legacy_arguments_begin(JacPyLegacyStorage *storage,
    PyObject *const *arguments, PyObject *const *keywords) {
    storage->input = arguments;
    storage->keywords = keywords;
    return storage;
}
void jacpy_legacy_arguments_close(JacPyLegacyArgsRef arguments) {
    if (arguments != NULL) {
        assert(!arguments->closed);
        arguments->closed = 1;
        PyMem_Free(arguments->allocated);
    }
}
int32_t jacpy_legacy_arguments_allocate(JacPyLegacyArgsRef arguments, int64_t count) {
    assert(arguments->allocated == NULL);
    arguments->allocated = PyMem_Malloc(sizeof(PyObject *) * count);
    arguments->capacity = count;
    return arguments->allocated != NULL;
}
void jacpy_legacy_arguments_copy(JacPyLegacyArgsRef arguments, int64_t source, int64_t destination) {
    assert(destination >= 0 && destination < arguments->capacity);
    arguments->allocated[destination] = arguments->input[source];
}
void jacpy_legacy_keyword_copy(JacPyLegacyArgsRef arguments, int64_t source, int64_t destination) {
    assert(destination >= 0 && destination < arguments->capacity);
    arguments->allocated[destination] = arguments->keywords[source];
}
PyObject *const *jacpy_legacy_arguments_values(JacPyLegacyArgsRef arguments) {
    return arguments->allocated == NULL ? arguments->input : arguments->allocated;
}
PyObject *const *jacpy_object_array_null(void) { return NULL; }
JacPyObjectRef jacpy_tuple_from_array(PyObject *const *values, int64_t count) {
    return _PyTuple_FromArray(values, count);
}
void jacpy_tuple_initialize_item(JacPyObjectRef tuple, int64_t index, JacPyObjectRef value) {
    assert(PyTuple_GET_ITEM(tuple, index) == NULL);
    PyTuple_SET_ITEM(tuple, index, value);
}
JacPyObjectRef jacpy_function_from_code(JacPyObjectRef code, JacPyObjectRef globals,
    JacPyObjectRef builtins, JacPyObjectRef defaults, JacPyObjectRef keyword_defaults,
    JacPyObjectRef closure) {
    PyFrameConstructor constructor = {
        .fc_globals = globals,
        .fc_builtins = builtins,
        .fc_name = ((PyCodeObject *)code)->co_name,
        .fc_qualname = ((PyCodeObject *)code)->co_name,
        .fc_code = code,
        .fc_defaults = defaults,
        .fc_kwdefaults = keyword_defaults,
        .fc_closure = closure
    };
    return (PyObject *)_PyFunction_FromConstructor(&constructor);
}
void jacpy_eval_legacy_stat(void) { EVAL_CALL_STAT_INC(EVAL_CALL_LEGACY); }
