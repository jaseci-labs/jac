/* Field/reference operations for native Jac active-frame cleanup.
 * Frame storage, escaped-frame retention and object GC remain CPython's.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_frames.h"
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
#include "internal/pycore_stackref.h"
#include "internal/pycore_sysmodule.h"

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
