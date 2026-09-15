"""Evaluator entry and throw setup from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. The C API caller provides the interpreter
trampoline's stack storage. Linking a frame adds that storage dependency; the
frame must be consumed by dispatch or cleared before the entry can return.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, PyStackRef, JacPyThreadState, jacpy_ref_null, jacpy_ref_is_null, jacpy_stack_new
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef, jacpy_frame_close }
import from jaclang.runtime.python.evaluator_monitoring { JacPyCodeUnit, jacpy_monitor_throw }
import from jaclang.runtime.python.evaluator_recursion {
    jacpy_thread_recursion_remaining, _Py_CheckRecursiveCallPy
}

import from c {
    obj JacPyEvalStorage;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_entry_recursive_guard(tstate: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_link(storage: &JacPyEvalStorage, tstate: &JacPyThreadState,
        frame: lin PyFrameRef from tstate) -> lin PyFrameRef from (storage, tstate);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_executor(tstate: &JacPyThreadState) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_save_executor(storage: &JacPyEvalStorage, tstate: &JacPyThreadState,
        executor: own PyStackRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_remaining_set(tstate: &JacPyThreadState, remaining: i32);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_unlink(tstate: &JacPyThreadState, frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_finish_early(storage: &JacPyEvalStorage, tstate: &JacPyThreadState);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_entry_instrument(tstate: &JacPyThreadState, frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_entry_instruction(frame: &PyFrameRef) -> &JacPyCodeUnit from frame;
    # These C-ABI bridges enter the existing preserve_none handlers while their
    # implementations are being replaced. Provenance identifies C dispatch.
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_entry_dispatch_start(storage: &JacPyEvalStorage, tstate: &JacPyThreadState,
        frame: lin PyFrameRef from (storage, tstate)) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_entry_dispatch_error(storage: &JacPyEvalStorage, tstate: &JacPyThreadState,
        frame: lin PyFrameRef from (storage, tstate), instruction: &JacPyCodeUnit from frame) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_enter_recursive_py(tstate: &JacPyThreadState) -> i32 {
    previous = jacpy_thread_recursion_remaining(tstate);
    jacpy_thread_remaining_set(tstate, wrapping_sub(previous, i32(1)));
    if previous <= 0 {
        if _Py_CheckRecursiveCallPy(tstate) != 0 { return 1; }
    }
    return 0;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_leave_recursive_py(tstate: &JacPyThreadState) {
    jacpy_thread_remaining_set(tstate, wrapping_add(jacpy_thread_recursion_remaining(tstate), i32(1)));
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_eval_frame_entry(storage: &JacPyEvalStorage, tstate: &JacPyThreadState,
    frame: lin PyFrameRef from tstate, throwflag: i32) -> own PyObjectRef {
    if jacpy_entry_recursive_guard(tstate) != 0 {
        jacpy_frame_close(frame);
        return jacpy_ref_null();
    }
    active: lin PyFrameRef from (storage, tstate) = jacpy_entry_link(storage, tstate, frame);
    executor: &PyObjectRef from tstate = jacpy_entry_executor(tstate);
    if jacpy_ref_is_null(executor) == 0 {
        saved: own PyStackRef = jacpy_stack_new(executor);
        jacpy_entry_save_executor(storage, tstate, saved);
    }
    if throwflag != 0 {
        if jacpy_enter_recursive_py(tstate) != 0 {
            jacpy_leave_recursive_py(tstate);
            jacpy_entry_unlink(tstate, &active);
            jacpy_frame_close(active);
            jacpy_entry_finish_early(storage, tstate);
            return jacpy_ref_null();
        }
        jacpy_entry_instrument(tstate, &active);
        instruction: &JacPyCodeUnit from active = jacpy_entry_instruction(&active);
        jacpy_monitor_throw(tstate, &active, instruction);
        return jacpy_entry_dispatch_error(storage, tstate, active, instruction);
    }
    return jacpy_entry_dispatch_start(storage, tstate, active);
}
