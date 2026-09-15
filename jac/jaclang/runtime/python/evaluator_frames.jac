"""Active-frame cleanup from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. A PyFrameRef owns the obligation to clear
an active frame, not the memory containing a generator's embedded frame.
The thread remains live through cleanup and every dependent stack release.
"""

import from jaclang.runtime.python.references {
    JacPyThreadState, PyStackRef, jacpy_stack_close
}

@foreign_resource(abi="pointer", empty=0, drop=jacpy_frame_close,
                  aliasing="shared", reentrant_drop=True)
obj PyFrameRef;

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_frame_close(frame: own PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_owned_by_thread(frame: &PyFrameRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_prepare_thread(tstate: &JacPyThreadState, frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_mark_generator_cleared(frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_unlink_exception_state(tstate: &JacPyThreadState, frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_unlink_previous(frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_frame_clear_except_code(frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_take_executable(frame: &PyFrameRef) -> own PyStackRef from frame;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_pop_thread(tstate: &JacPyThreadState, frame: lin PyFrameRef from tstate);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_frame_finish_generator(tstate: &JacPyThreadState, frame: lin PyFrameRef from tstate);
}

# CPython Python/ceval.c:1927-1964. Both paths explicitly discharge the frame
# obligation. The executable loan ends before its frame can be popped.
@foreign_call(requires=["gil"], errors="none", reentrant=True)
def _PyEval_FrameClearAndPop(tstate: &JacPyThreadState,
                            frame: lin PyFrameRef from tstate) {
    if jacpy_frame_owned_by_thread(&frame) != 0 {
        jacpy_frame_prepare_thread(tstate, &frame);
        jacpy_frame_clear_except_code(&frame);
        executable: own PyStackRef from frame = jacpy_frame_take_executable(&frame);
        jacpy_stack_close(executable);
        jacpy_frame_pop_thread(tstate, frame);
    } else {
        jacpy_frame_mark_generator_cleared(&frame);
        jacpy_frame_unlink_exception_state(tstate, &frame);
        jacpy_frame_unlink_previous(&frame);
        jacpy_frame_clear_except_code(&frame);
        jacpy_frame_finish_generator(tstate, frame);
    }
}
