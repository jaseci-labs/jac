"""Monitoring and thread-control algorithms from CPython 3.14.6 ceval.c.

PSF licensed; see LICENSE.cpython. All entry points require the current attached
thread and the GIL. Callback errors stay in CPython's exception state.
"""

import from jaclang.runtime.python.references {
    JacPyThreadState, PyObjectRef, jacpy_ref_new, jacpy_ref_null, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }

import from c {
    obj JacPyCodeUnit;
    # Opaque code address: only the retained tracing runtime invokes it. No
    # integer conversion or Jac closure adapter participates in this ABI.
    obj JacPyTraceFunction;
    obj JacPyInterpreterState;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PyThreadState_Get -> &JacPyThreadState;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_monitor_global_tools(tstate: &JacPyThreadState, event: i32) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_monitor_local_tools(frame: &PyFrameRef, event: i32) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_monitor_disabled(frame: &PyFrameRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def PyErr_GetRaisedException -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyErr_SetRaisedException(exception: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyErr_SetObject(exception_type: &PyObjectRef, value: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stop_iteration_type(tstate: &JacPyThreadState) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _Py_call_instrumentation_arg(tstate: &JacPyThreadState, event: i32,
        frame: &PyFrameRef, instruction: &JacPyCodeUnit, exception: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_tracing_get(tstate: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_tracing_set(tstate: &JacPyThreadState, value: i32);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_Call(function: &PyObjectRef, arguments: &PyObjectRef,
                      keywords: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_coroutine_depth_get(tstate: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_coroutine_depth_set(tstate: &JacPyThreadState, depth: i32);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_value_error(tstate: &JacPyThreadState, message: str);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_audit_noargs(tstate: &JacPyThreadState, event: str) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_asyncgen_firstiter_swap(tstate: &JacPyThreadState,
        replacement: own PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_asyncgen_finalizer_swap(tstate: &JacPyThreadState,
        replacement: own PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_interpreter(tstate: &JacPyThreadState) -> &JacPyInterpreterState from tstate;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyEval_SetProfile(tstate: &JacPyThreadState, callback: &JacPyTraceFunction,
        argument: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyEval_SetProfileAllThreads(interpreter: &JacPyInterpreterState,
        callback: &JacPyTraceFunction, argument: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyEval_SetTrace(tstate: &JacPyThreadState, callback: &JacPyTraceFunction,
        argument: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyEval_SetTraceAllThreads(interpreter: &JacPyInterpreterState,
        callback: &JacPyTraceFunction, argument: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_eval_unraisable(message: str);
}

# The event numbers are pinned by Include/cpython/monitoring.h. Matching static
# assertions accompany the field primitives in evaluator_frames.c.
@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_exception(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame,
    event: i32) -> i32 {
    if jacpy_monitor_disabled(frame) != 0 { return 0; }
    exception: own PyObjectRef = PyErr_GetRaisedException();
    result = _Py_call_instrumentation_arg(tstate, event, frame, instruction, &exception);
    if result == 0 {
        PyErr_SetRaisedException(exception);
    } else {
        # Keep the callback's replacement error; release the original only now.
        jacpy_ref_close(exception);
    }
    return result;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_MonitorRaise(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame) {
    if jacpy_monitor_global_tools(tstate, 11) != 0 {
        jacpy_monitor_exception(tstate, frame, instruction, 11);
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_reraise(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame) {
    if jacpy_monitor_global_tools(tstate, 15) != 0 {
        jacpy_monitor_exception(tstate, frame, instruction, 15);
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_stop_iteration(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame,
    value: &PyObjectRef) -> i32 {
    tools = jacpy_monitor_local_tools(frame, 10);
    if tools < 0 { tools = jacpy_monitor_global_tools(tstate, 10); }
    if tools == 0 { return 0; }
    exception_type: &PyObjectRef from tstate = jacpy_stop_iteration_type(tstate);
    PyErr_SetObject(exception_type, value);
    result = jacpy_monitor_exception(tstate, frame, instruction, 10);
    if result < 0 { return result; }
    PyErr_SetRaisedException(jacpy_ref_null());
    return 0;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_unwind(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame) {
    if jacpy_monitor_global_tools(tstate, 13) != 0 {
        jacpy_monitor_exception(tstate, frame, instruction, 13);
    }
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_monitor_no_tools_for_unwind(tstate: &JacPyThreadState) -> i32 {
    if jacpy_monitor_global_tools(tstate, 13) == 0 { return 1; }
    return 0;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_handled(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame,
    exception: &PyObjectRef) -> i32 {
    if jacpy_monitor_global_tools(tstate, 12) == 0 { return 0; }
    return _Py_call_instrumentation_arg(tstate, 12, frame, instruction, exception);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_monitor_throw(tstate: &JacPyThreadState,
    frame: &PyFrameRef from tstate, instruction: &JacPyCodeUnit from frame) {
    if jacpy_monitor_global_tools(tstate, 14) != 0 {
        jacpy_monitor_exception(tstate, frame, instruction, 14);
    }
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def PyThreadState_EnterTracing(tstate: &JacPyThreadState) {
    # CPython's precondition bounds the tracing nesting count to C int.
    jacpy_tracing_set(tstate, wrapping_add(jacpy_tracing_get(tstate), 1));
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def PyThreadState_LeaveTracing(tstate: &JacPyThreadState) {
    jacpy_tracing_set(tstate, wrapping_sub(jacpy_tracing_get(tstate), 1));
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_CallTracing(function: &PyObjectRef, arguments: &PyObjectRef) -> own PyObjectRef {
    tstate: &JacPyThreadState = PyThreadState_Get();
    saved = jacpy_tracing_get(tstate);
    jacpy_tracing_set(tstate, 0);
    no_keywords: own PyObjectRef = jacpy_ref_null();
    result: own PyObjectRef = PyObject_Call(function, arguments, &no_keywords);
    jacpy_tracing_set(tstate, saved);
    return result;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def PyEval_SetProfile(callback: &JacPyTraceFunction, argument: &PyObjectRef) {
    if _PyEval_SetProfile(PyThreadState_Get(), callback, argument) < 0 {
        jacpy_eval_unraisable("Exception ignored in PyEval_SetProfile");
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def PyEval_SetProfileAllThreads(callback: &JacPyTraceFunction, argument: &PyObjectRef) {
    tstate: &JacPyThreadState = PyThreadState_Get();
    interpreter: &JacPyInterpreterState from tstate = jacpy_thread_interpreter(tstate);
    if _PyEval_SetProfileAllThreads(interpreter, callback, argument) < 0 {
        jacpy_eval_unraisable("Exception ignored in PyEval_SetProfileAllThreads");
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def PyEval_SetTrace(callback: &JacPyTraceFunction, argument: &PyObjectRef) {
    if _PyEval_SetTrace(PyThreadState_Get(), callback, argument) < 0 {
        jacpy_eval_unraisable("Exception ignored in PyEval_SetTrace");
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def PyEval_SetTraceAllThreads(callback: &JacPyTraceFunction, argument: &PyObjectRef) {
    tstate: &JacPyThreadState = PyThreadState_Get();
    interpreter: &JacPyInterpreterState from tstate = jacpy_thread_interpreter(tstate);
    if _PyEval_SetTraceAllThreads(interpreter, callback, argument) < 0 {
        jacpy_eval_unraisable("Exception ignored in PyEval_SetTraceAllThreads");
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_SetCoroutineOriginTrackingDepth(depth: i32) -> i32 {
    tstate: &JacPyThreadState = PyThreadState_Get();
    if depth < 0 {
        jacpy_eval_value_error(tstate, "depth must be >= 0");
        return -1;
    }
    jacpy_coroutine_depth_set(tstate, depth);
    return 0;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def _PyEval_GetCoroutineOriginTrackingDepth -> i32 {
    return jacpy_coroutine_depth_get(PyThreadState_Get());
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_SetAsyncGenFirstiter(firstiter: &PyObjectRef) -> i32 {
    tstate: &JacPyThreadState = PyThreadState_Get();
    if jacpy_audit_noargs(tstate, "sys.set_asyncgen_hook_firstiter") < 0 { return -1; }
    replacement: own PyObjectRef = jacpy_ref_new(firstiter);
    previous: own PyObjectRef = jacpy_asyncgen_firstiter_swap(tstate, replacement);
    jacpy_ref_close(previous);
    return 0;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_SetAsyncGenFinalizer(finalizer: &PyObjectRef) -> i32 {
    tstate: &JacPyThreadState = PyThreadState_Get();
    if jacpy_audit_noargs(tstate, "sys.set_asyncgen_hook_finalizer") < 0 { return -1; }
    replacement: own PyObjectRef = jacpy_ref_new(finalizer);
    previous: own PyObjectRef = jacpy_asyncgen_finalizer_swap(tstate, replacement);
    jacpy_ref_close(previous);
    return 0;
}
