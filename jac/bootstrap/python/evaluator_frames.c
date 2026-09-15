/* Field/reference operations for native Jac active-frame cleanup.
 * Frame storage, escaped-frame retention and object GC remain CPython's.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_frames.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_frame.h"
#include "internal/pycore_genobject.h"
#include "internal/pycore_interpframe.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_stackref.h"

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
