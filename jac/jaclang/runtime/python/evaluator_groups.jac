"""Exception-group matching from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Output slots receive owned references only
on the original success paths; errors remain in CPython's exception state.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_new, jacpy_ref_close, jacpy_ref_is_null
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }
import from jaclang.runtime.python.evaluator_support {
    jacpy_eval_is_none, jacpy_eval_tuple_size, jacpy_eval_tuple_item
}
import from jaclang.runtime.python.evaluator_errors { PyErr_GivenExceptionMatches }
import from jaclang.runtime.python.evaluator_monitoring { PyThreadState_Get }
import from jaclang.runtime.python.evaluator_imports { jacpy_none }
import from jaclang.runtime.python.evaluator_matching { jacpy_tuple_exact }
import from jaclang.runtime.python.evaluator_context {
    JacPyObjectOut, jacpy_object_output_store, jacpy_frame_object
}

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_exception_group_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_tuple_single(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyExc_CreateExceptionGroup(message: str, exceptions: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_traceback_from_frame(frame: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyException_SetTraceback(exception: &PyObjectRef, traceback: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_exception_group_split(exception: &PyObjectRef, type: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_exception_split_type_error(exception: &PyObjectRef, pair: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_exception_split_size_error(exception: &PyObjectRef, size: i64);
    # The pinned implementation leaks this new group when traceback allocation
    # fails in ceval.c. Keep that behavior explicit, rather than changing
    # Python reference/finalizer timing as an incidental effect of the port.
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_exception_group_leak_on_traceback_error(exception: own PyObjectRef);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_ExceptionGroupMatch(frame: &PyFrameRef, exception: &PyObjectRef,
    type: &PyObjectRef, match: &JacPyObjectOut, rest: &JacPyObjectOut) -> i32 {
    tstate: &JacPyThreadState = PyThreadState_Get();
    if jacpy_eval_is_none(exception) != 0 {
        jacpy_object_output_store(match, jacpy_ref_new(jacpy_none(tstate)));
        jacpy_object_output_store(rest, jacpy_ref_new(jacpy_none(tstate)));
        return 0;
    }
    if PyErr_GivenExceptionMatches(exception, type) != 0 {
        if jacpy_exception_group_check(exception) != 0 {
            jacpy_object_output_store(match, jacpy_ref_new(exception));
        } else {
            exceptions: own PyObjectRef = jacpy_tuple_single(exception);
            if jacpy_ref_is_null(&exceptions) != 0 { return -1; }
            wrapped: own PyObjectRef = _PyExc_CreateExceptionGroup("", &exceptions);
            jacpy_ref_close(exceptions);
            if jacpy_ref_is_null(&wrapped) != 0 { return -1; }
            frame_object: &PyObjectRef from frame = jacpy_frame_object(frame);
            if jacpy_ref_is_null(frame_object) != 0 {
                jacpy_ref_close(wrapped);
                return -1;
            }
            traceback: own PyObjectRef = jacpy_traceback_from_frame(frame_object);
            if jacpy_ref_is_null(&traceback) != 0 {
                jacpy_exception_group_leak_on_traceback_error(wrapped);
                return -1;
            }
            PyException_SetTraceback(&wrapped, &traceback);
            jacpy_ref_close(traceback);
            jacpy_object_output_store(match, wrapped);
        }
        jacpy_object_output_store(rest, jacpy_ref_new(jacpy_none(tstate)));
        return 0;
    }
    if jacpy_exception_group_check(exception) != 0 {
        pair: own PyObjectRef = jacpy_exception_group_split(exception, type);
        if jacpy_ref_is_null(&pair) != 0 { return -1; }
        if jacpy_tuple_exact(&pair) == 0 {
            jacpy_exception_split_type_error(exception, &pair);
            jacpy_ref_close(pair);
            return -1;
        }
        size = jacpy_eval_tuple_size(&pair);
        if size < 2 {
            jacpy_exception_split_size_error(exception, size);
            jacpy_ref_close(pair);
            return -1;
        }
        jacpy_object_output_store(match, jacpy_ref_new(jacpy_eval_tuple_item(&pair, 0)));
        jacpy_object_output_store(rest, jacpy_ref_new(jacpy_eval_tuple_item(&pair, 1)));
        jacpy_ref_close(pair);
        return 0;
    }
    jacpy_object_output_store(match, jacpy_ref_new(jacpy_none(tstate)));
    jacpy_object_output_store(rest, jacpy_ref_new(exception));
    return 0;
}
