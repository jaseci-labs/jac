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
#endif
