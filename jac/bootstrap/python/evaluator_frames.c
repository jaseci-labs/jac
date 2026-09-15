/* Field/reference operations for native Jac active-frame cleanup.
 * Frame storage, escaped-frame retention and object GC remain CPython's.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_frames.h"
#include "frameobject.h"
#include "internal/pycore_audit.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_frame.h"
#include "internal/pycore_genobject.h"
#include "internal/pycore_import.h"
#include "internal/pycore_interpframe.h"
#include "internal/pycore_interp.h"
#include "internal/pycore_instruments.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_pyatomic_ft_wrappers.h"
#include "internal/pycore_stackref.h"
#include "internal/pycore_sysmodule.h"
#include "internal/pycore_unicodeobject.h"

void jacpy_frame_close(JacPyFrameRef frame) {
    if (frame != NULL) {
        _PyEval_FrameClearAndPop(PyThreadState_Get(), frame);
    }
}
int64_t jacpy_frame_owned_by_thread(JacPyFrameRef frame) {
    return frame->owner == FRAME_OWNED_BY_THREAD;
}
void jacpy_frame_prepare_thread(PyThreadState *tstate, JacPyFrameRef frame) {
    assert(frame->owner == FRAME_OWNED_BY_THREAD);
    assert((PyObject **)frame + _PyFrame_GetCode(frame)->co_framesize ==
           tstate->datastack_top);
    assert(frame->frame_obj == NULL || frame->frame_obj->f_frame == frame);
    (void)tstate;
    (void)frame;
}
void jacpy_frame_mark_generator_cleared(JacPyFrameRef frame) {
    assert(frame->owner == FRAME_OWNED_BY_GENERATOR);
    _PyGen_GetGeneratorFromFrame(frame)->gi_frame_state = FRAME_CLEARED;
}
void jacpy_frame_unlink_exception_state(PyThreadState *tstate, JacPyFrameRef frame) {
    PyGenObject *gen = _PyGen_GetGeneratorFromFrame(frame);
    assert(tstate->exc_info == &gen->gi_exc_state);
    tstate->exc_info = gen->gi_exc_state.previous_item;
    gen->gi_exc_state.previous_item = NULL;
}
void jacpy_frame_unlink_previous(JacPyFrameRef frame) {
    assert(frame->frame_obj == NULL || frame->frame_obj->f_frame == frame);
    frame->previous = NULL;
}
void jacpy_frame_clear_except_code(JacPyFrameRef frame) {
    _PyFrame_ClearExceptCode(frame);
}
JacPyStackRef jacpy_frame_take_executable(JacPyFrameRef frame) {
    _PyStackRef old = frame->f_executable;
    frame->f_executable = PyStackRef_NULL;
    return old.bits;
}
void jacpy_frame_pop_thread(PyThreadState *tstate, JacPyFrameRef frame) {
    _PyThreadState_PopFrame(tstate, frame);
}
void jacpy_frame_finish_generator(PyThreadState *tstate, JacPyFrameRef frame) {
    (void)tstate;
    _PyErr_ClearExcState(&_PyGen_GetGeneratorFromFrame(frame)->gi_exc_state);
}

_Static_assert(PY_MONITORING_EVENT_STOP_ITERATION == 10 &&
               PY_MONITORING_EVENT_RAISE == 11 &&
               PY_MONITORING_EVENT_EXCEPTION_HANDLED == 12 &&
               PY_MONITORING_EVENT_PY_UNWIND == 13 &&
               PY_MONITORING_EVENT_PY_THROW == 14 &&
               PY_MONITORING_EVENT_RERAISE == 15, "pinned monitoring event ABI");

int32_t jacpy_monitor_global_tools(PyThreadState *tstate, int32_t event) {
    assert(event >= 0 && event < _PY_MONITORING_UNGROUPED_EVENTS);
    return tstate->interp->monitors.tools[event];
}
int32_t jacpy_monitor_local_tools(JacPyFrameRef frame, int32_t event) {
    assert(event >= 0 && event < _PY_MONITORING_LOCAL_EVENTS);
    _PyCoMonitoringData *data = _PyFrame_GetCode(frame)->_co_monitoring;
    return data == NULL ? -1 : data->active_monitors.tools[event];
}
int32_t jacpy_monitor_disabled(JacPyFrameRef frame) {
    return (_PyFrame_GetCode(frame)->co_flags & CO_NO_MONITORING_EVENTS) != 0;
}
JacPyObjectRef jacpy_stop_iteration_type(PyThreadState *tstate) {
    (void)tstate;
    return PyExc_StopIteration;
}
int32_t jacpy_tracing_get(PyThreadState *tstate) {
    assert(tstate->tracing >= 0);
    return tstate->tracing;
}
void jacpy_tracing_set(PyThreadState *tstate, int32_t value) {
    assert(value >= 0);
    tstate->tracing = value;
}
int32_t jacpy_coroutine_depth_get(PyThreadState *tstate) {
    return tstate->coroutine_origin_tracking_depth;
}
void jacpy_coroutine_depth_set(PyThreadState *tstate, int32_t depth) {
    tstate->coroutine_origin_tracking_depth = depth;
}
void jacpy_eval_value_error(PyThreadState *tstate, const char *message) {
    _PyErr_SetString(tstate, PyExc_ValueError, message);
}
int32_t jacpy_audit_noargs(PyThreadState *tstate, const char *event) {
    return _PySys_Audit(tstate, event, NULL);
}
JacPyObjectRef jacpy_asyncgen_firstiter_swap(PyThreadState *tstate, JacPyObjectRef replacement) {
    JacPyObjectRef previous = tstate->async_gen_firstiter;
    tstate->async_gen_firstiter = replacement;
    return previous;
}
JacPyObjectRef jacpy_asyncgen_finalizer_swap(PyThreadState *tstate, JacPyObjectRef replacement) {
    JacPyObjectRef previous = tstate->async_gen_finalizer;
    tstate->async_gen_finalizer = replacement;
    return previous;
}
PyInterpreterState *jacpy_thread_interpreter(PyThreadState *tstate) {
    return tstate->interp;
}
void jacpy_eval_unraisable(const char *message) {
    PyErr_FormatUnraisable("%s", message);
}
/* C bool's target ABI is kept here; the decision is made by native Jac. */
extern int32_t jacpy_monitor_no_tools_for_unwind(PyThreadState *tstate);
bool _PyEval_NoToolsForUnwind(PyThreadState *tstate) {
    return jacpy_monitor_no_tools_for_unwind(tstate) != 0;
}
JacPyObjectRef jacpy_frame_locals(JacPyFrameRef frame) { return frame->f_locals; }
JacPyObjectRef jacpy_frame_globals(JacPyFrameRef frame) { return frame->f_globals; }
JacPyObjectRef jacpy_frame_builtins(JacPyFrameRef frame) { return frame->f_builtins; }
int32_t jacpy_is_default_import(PyThreadState *tstate, JacPyObjectRef function) {
    return _PyImport_IsDefaultImportFunc(tstate->interp, function);
}

/* C API entries capture a frame loan at the call boundary. The Jac helpers
 * return views of that frame/interpreter value, not of temporary newrefs.
 */
extern JacPyObjectRef jacpy_get_builtins(JacPyFrameRef, JacPyObjectRef);
extern JacPyObjectRef jacpy_get_globals(JacPyFrameRef);
extern JacPyObjectRef jacpy_get_frame_object(JacPyFrameRef);
extern JacPyObjectRef jacpy_get_locals(PyThreadState *, JacPyFrameRef);
extern JacPyObjectRef jacpy_get_frame_locals(PyThreadState *, JacPyFrameRef);
extern JacPyObjectRef jacpy_get_builtin(PyThreadState *, JacPyObjectRef, JacPyObjectRef);

PyObject *_PyEval_GetAsyncGenFirstiter(void) { return _PyThreadState_GET()->async_gen_firstiter; }
PyObject *_PyEval_GetAsyncGenFinalizer(void) { return _PyThreadState_GET()->async_gen_finalizer; }
_PyInterpreterFrame *_PyEval_GetFrame(void) { return _PyThreadState_GetFrame(_PyThreadState_GET()); }
PyFrameObject *PyEval_GetFrame(void) {
    return (PyFrameObject *)jacpy_get_frame_object(_PyEval_GetFrame());
}
PyObject *_PyEval_GetBuiltins(PyThreadState *tstate) {
    return jacpy_get_builtins(_PyThreadState_GetFrame(tstate), tstate->interp->builtins);
}
PyObject *PyEval_GetBuiltins(void) { return _PyEval_GetBuiltins(_PyThreadState_GET()); }
PyObject *_PyEval_GetBuiltin(PyObject *name) {
    PyThreadState *tstate = _PyThreadState_GET();
    return jacpy_get_builtin(tstate, _PyEval_GetBuiltins(tstate), name);
}
PyObject *_PyEval_GetBuiltinId(_Py_Identifier *name) {
    return _PyEval_GetBuiltin(_PyUnicode_FromId(name));
}
PyObject *PyEval_GetLocals(void) {
    PyThreadState *tstate = _PyThreadState_GET();
    return jacpy_get_locals(tstate, _PyThreadState_GetFrame(tstate));
}
PyObject *_PyEval_GetFrameLocals(void) {
    PyThreadState *tstate = _PyThreadState_GET();
    return jacpy_get_frame_locals(tstate, _PyThreadState_GetFrame(tstate));
}
PyObject *PyEval_GetFrameLocals(void) { return _PyEval_GetFrameLocals(); }
PyObject *PyEval_GetGlobals(void) { return jacpy_get_globals(_PyEval_GetFrame()); }
PyObject *PyEval_GetFrameGlobals(void) { return Py_XNewRef(jacpy_get_globals(_PyEval_GetFrame())); }
PyObject *PyEval_GetFrameBuiltins(void) { return Py_XNewRef(_PyEval_GetBuiltins(_PyThreadState_GET())); }
PyObject *PyEval_EvalFrame(PyFrameObject *frame) {
    return _PyEval_EvalFrame(_PyThreadState_GET(), frame->f_frame, 0);
}
PyObject *PyEval_EvalFrameEx(PyFrameObject *frame, int throwflag) {
    return _PyEval_EvalFrame(_PyThreadState_GET(), frame->f_frame, throwflag);
}
JacPyObjectRef jacpy_ref_borrow_null(void) { return NULL; }
JacPyObjectRef jacpy_frame_object(JacPyFrameRef frame) { return (PyObject *)_PyFrame_GetFrameObject(frame); }
JacPyObjectRef jacpy_frame_get_locals(JacPyFrameRef frame) { return _PyFrame_GetLocals(frame); }
int32_t jacpy_locals_proxy_check(JacPyObjectRef value) { return PyFrameLocalsProxy_Check(value); }
JacPyObjectRef jacpy_frame_locals_cache(JacPyObjectRef frame) { return ((PyFrameObject *)frame)->f_locals_cache; }
void jacpy_frame_install_locals_cache(JacPyObjectRef frame, JacPyObjectRef dictionary) {
    assert(((PyFrameObject *)frame)->f_locals_cache == NULL);
    ((PyFrameObject *)frame)->f_locals_cache = dictionary;
}
JacPyObjectRef jacpy_current_builtins_new(PyThreadState *tstate) { return Py_XNewRef(_PyEval_GetBuiltins(tstate)); }
int32_t jacpy_dict_check(JacPyObjectRef value) { return PyDict_Check(value); }
int32_t jacpy_object_output_is_null(PyObject **output) { return output == NULL; }
void jacpy_object_output_store(PyObject **output, JacPyObjectRef value) { *output = value; }

struct JacPyUnpackStorage {
    _PyStackRef *top;
    Py_ssize_t pending;
    int closed;
};
extern int32_t jacpy_unpack_iterable(JacPyUnpackStorage *, JacPyUnpackRef,
    PyThreadState *, PyObject *, int32_t, int32_t);
extern void jacpy_unpack_close_impl(JacPyUnpackStorage *, JacPyUnpackRef);
int _PyEval_UnpackIterableStackRef(PyThreadState *tstate, PyObject *value,
    int before, int after, _PyStackRef *top) {
    JacPyUnpackStorage storage = { top, 0, 0 };
    return jacpy_unpack_iterable(&storage, &storage, tstate, value, before, after);
}
void jacpy_unpack_close(JacPyUnpackRef stack) {
    if (stack != NULL) {
        assert(!stack->closed);
        jacpy_unpack_close_impl(stack, stack);
    }
}
int64_t jacpy_unpack_pending(JacPyUnpackRef stack) { return stack->pending; }
void jacpy_unpack_discard(JacPyUnpackRef stack) {
    assert(!stack->closed && stack->pending > 0);
    _PyStackRef value = *stack->top++;
    stack->pending--;
    PyStackRef_CLOSE(value);
}
void jacpy_unpack_commit(JacPyUnpackStorage *storage, JacPyUnpackRef stack) {
    assert(storage == stack && !stack->closed);
    stack->pending = 0;
    stack->closed = 1;
}
void jacpy_unpack_finish_error(JacPyUnpackStorage *storage, JacPyUnpackRef stack) {
    assert(storage == stack && !stack->closed && stack->pending == 0);
    stack->closed = 1;
}
JacPyObjectRef jacpy_unpack_push(JacPyUnpackRef stack, JacPyObjectRef value) {
    assert(!stack->closed && value != NULL);
    *--stack->top = PyStackRef_FromPyObjectSteal(value);
    stack->pending++;
    return value;
}
void jacpy_unpack_list_item(JacPyUnpackRef stack, JacPyObjectRef values, int64_t index) {
    assert(!stack->closed);
    *--stack->top = PyStackRef_FromPyObjectSteal(PyList_GET_ITEM(values, index));
    stack->pending++;
}
void jacpy_unpack_shrink_list(JacPyObjectRef values, int64_t count) { Py_SET_SIZE(values, count); }
int64_t jacpy_unpack_exact_size(JacPyObjectRef value) {
    if (PyDict_CheckExact(value)) { return PyDict_Size(value); }
    if (PyList_CheckExact(value) || PyTuple_CheckExact(value)) { return Py_SIZE(value); }
    return -1;
}
void jacpy_unpack_error(PyThreadState *tstate, const char *format, int32_t expected, int64_t actual) {
    _PyErr_Format(tstate, PyExc_ValueError, format, (int)expected, (Py_ssize_t)actual);
}

_Static_assert(PyCF_MASK == 0x1fe0000 && MAX_CO_EXTRA_USERS == 255, "pinned evaluator utility constants");
extern int32_t jacpy_merge_compiler_flags(JacPyFrameRef, PyCompilerFlags *);
extern int64_t jacpy_request_code_extra(PyInterpreterState *, freefunc);
extern JacPyObjectRef jacpy_running_main_module(PyThreadState *);
int PyEval_MergeCompilerFlags(PyCompilerFlags *flags) {
    return jacpy_merge_compiler_flags(_PyThreadState_GET()->current_frame, flags);
}
Py_ssize_t PyUnstable_Eval_RequestCodeExtraIndex(freefunc callback) {
    return jacpy_request_code_extra(_PyInterpreterState_GET(), callback);
}
PyObject *_PyEval_GetGlobalsFromRunningMain(PyThreadState *tstate) {
    PyObject *module = jacpy_running_main_module(tstate);
    if (module == NULL) { return NULL; }
    /* Preserve the legacy API's borrowed-return boundary. Native Jac returns
     * the module owner; it does not assert that this dictionary is owned by
     * the thread (sys.modules can be a user-supplied mapping).
     */
    PyObject *globals = PyModule_GetDict(module);
    Py_DECREF(module);
    return globals;
}
int32_t jacpy_compiler_flags(PyCompilerFlags *flags) { return flags->cf_flags; }
void jacpy_compiler_flags_store(PyCompilerFlags *flags, int32_t value) { flags->cf_flags = value; }
int32_t jacpy_frame_code_flags(JacPyFrameRef frame) { return _PyFrame_GetCode(frame)->co_flags; }
int64_t jacpy_code_extra_count(PyInterpreterState *interpreter) { return interpreter->co_extra_user_count; }
void jacpy_code_extra_callback(PyInterpreterState *interpreter, int64_t index, freefunc callback) {
    interpreter->co_extra_freefuncs[index] = callback;
}
void jacpy_code_extra_publish(PyInterpreterState *interpreter, int64_t count) {
    FT_ATOMIC_STORE_SSIZE_RELEASE(interpreter->co_extra_user_count, count);
}
int32_t jacpy_dict_exact(JacPyObjectRef value) { return PyDict_CheckExact(value); }
int32_t jacpy_stack_output_is_null(_PyStackRef *output) { return PyStackRef_IsNull(*output); }
void jacpy_stack_output_store(_PyStackRef *output, JacPyStackRef value) { output->bits = value; }
