/* Trusted active-frame storage boundary; algorithms live in evaluator_frames.jac.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 * The caller holds the GIL and the thread/frame must belong to that thread.
 */
#ifndef JAC_EVALUATOR_FRAMES_H
#define JAC_EVALUATOR_FRAMES_H
#include "evaluator_refs.h"

typedef struct _PyInterpreterFrame *JacPyFrameRef;

/* Consumes the obligation to clear an active frame, through native Jac. */
void jacpy_frame_close(JacPyFrameRef frame);
int64_t jacpy_frame_owned_by_thread(JacPyFrameRef frame);
void jacpy_frame_prepare_thread(PyThreadState *tstate, JacPyFrameRef frame);
void jacpy_frame_mark_generator_cleared(JacPyFrameRef frame);
void jacpy_frame_unlink_exception_state(PyThreadState *tstate, JacPyFrameRef frame);
void jacpy_frame_unlink_previous(JacPyFrameRef frame);
void jacpy_frame_clear_except_code(JacPyFrameRef frame);
/* Publishes PyStackRef_NULL before handing ownership to the caller. */
JacPyStackRef jacpy_frame_take_executable(JacPyFrameRef frame);
void jacpy_frame_pop_thread(PyThreadState *tstate, JacPyFrameRef frame);
void jacpy_frame_finish_generator(PyThreadState *tstate, JacPyFrameRef frame);
int32_t jacpy_monitor_global_tools(PyThreadState *tstate, int32_t event);
/* A missing local monitoring table returns -1; the Jac caller chooses fallback. */
int32_t jacpy_monitor_local_tools(JacPyFrameRef frame, int32_t event);
int32_t jacpy_monitor_disabled(JacPyFrameRef frame);
JacPyObjectRef jacpy_stop_iteration_type(PyThreadState *tstate);
int32_t jacpy_tracing_get(PyThreadState *tstate);
void jacpy_tracing_set(PyThreadState *tstate, int32_t value);
int32_t jacpy_coroutine_depth_get(PyThreadState *tstate);
void jacpy_coroutine_depth_set(PyThreadState *tstate, int32_t depth);
void jacpy_eval_value_error(PyThreadState *tstate, const char *message);
int32_t jacpy_audit_noargs(PyThreadState *tstate, const char *event);
/* Swap publishes the replacement before the Jac caller decrefs the old owner. */
JacPyObjectRef jacpy_asyncgen_firstiter_swap(PyThreadState *tstate, JacPyObjectRef replacement);
JacPyObjectRef jacpy_asyncgen_finalizer_swap(PyThreadState *tstate, JacPyObjectRef replacement);
PyInterpreterState *jacpy_thread_interpreter(PyThreadState *tstate);
void jacpy_eval_unraisable(const char *message);
JacPyObjectRef jacpy_frame_locals(JacPyFrameRef frame);
JacPyObjectRef jacpy_frame_globals(JacPyFrameRef frame);
JacPyObjectRef jacpy_frame_builtins(JacPyFrameRef frame);
int32_t jacpy_is_default_import(PyThreadState *tstate, JacPyObjectRef function);
#endif
