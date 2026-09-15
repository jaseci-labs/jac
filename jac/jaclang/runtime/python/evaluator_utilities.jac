"""Remaining evaluator utilities from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Output stack slots preserve the original
publication order relative to Python error formatting and callbacks.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, PyStackRef, JacPyThreadState, jacpy_ref_null, jacpy_ref_close,
    jacpy_ref_is_null, jacpy_stack_null, jacpy_stack_steal
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }
import from jaclang.runtime.python.evaluator_monitoring {
    JacPyInterpreterState, PyThreadState_Get, jacpy_thread_interpreter
}
import from jaclang.runtime.python.evaluator_calls { jacpy_frame_is_null }
import from jaclang.runtime.python.evaluator_errors {
    _PyEval_FormatExcCheckArg, jacpy_exception_type, jacpy_eval_error_format
}
import from jaclang.runtime.python.evaluator_support { jacpy_eval_error_pending }
import from jaclang.runtime.python.evaluator_lookup {
    PyLookupRef, jacpy_mapping_lookup, jacpy_lookup_state, jacpy_lookup_take, jacpy_lookup_close
}

import from c {
    obj JacPyCompilerFlags;
    obj JacPyCodeFreeFunction;
    obj JacPyStackOut;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_compiler_flags(flags: &JacPyCompilerFlags) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_compiler_flags_store(flags: &JacPyCompilerFlags, value: i32);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_code_flags(frame: &PyFrameRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_extra_count(interpreter: &JacPyInterpreterState) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_extra_callback(interpreter: &JacPyInterpreterState, index: i64,
        callback: &JacPyCodeFreeFunction from interpreter);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_extra_publish(interpreter: &JacPyInterpreterState, count: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def _PyInterpreterState_IsRunningMain(interpreter: &JacPyInterpreterState) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _Py_GetMainModule(tstate: &JacPyThreadState) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _Py_CheckMainModule(module: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_dict_exact(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyDict_LoadGlobalStackRef(globals: &PyObjectRef, builtins: &PyObjectRef,
        name: &PyObjectRef, output: &JacPyStackOut);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_output_is_null(output: &JacPyStackOut) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_output_store(output: &JacPyStackOut, value: own PyStackRef);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_merge_compiler_flags(frame: &PyFrameRef, flags: &JacPyCompilerFlags) -> i32 {
    result: i32 = 0;
    if jacpy_compiler_flags(flags) != 0 { result = 1; }
    if jacpy_frame_is_null(frame) == 0 {
        inherited = jacpy_frame_code_flags(frame) & i32(0x1fe0000);
        if inherited != 0 {
            result = 1;
            jacpy_compiler_flags_store(flags, jacpy_compiler_flags(flags) | inherited);
        }
    }
    return result;
}

# The C API caller supplies a callback that remains callable while this
# interpreter can use code-extra slots. The pointer is never a Jac closure.
@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_request_code_extra(interpreter: &JacPyInterpreterState,
    callback: &JacPyCodeFreeFunction from interpreter) -> i64 {
    index = jacpy_code_extra_count(interpreter);
    if index >= 254 { return -1; }
    jacpy_code_extra_callback(interpreter, index, callback);
    jacpy_code_extra_publish(interpreter, wrapping_add(index, 1));
    return index;
}

# Keep the validated module as an owner. The legacy C API's final conversion
# to a borrowed module dictionary stays at that API boundary; returning a view
# of this local owner with an invented thread lifetime would be incorrect.
@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_running_main_module(tstate: &JacPyThreadState) -> own PyObjectRef {
    if _PyInterpreterState_IsRunningMain(jacpy_thread_interpreter(tstate)) == 0 { return jacpy_ref_null(); }
    module: own PyObjectRef = _Py_GetMainModule(tstate);
    if _Py_CheckMainModule(&module) < 0 {
        jacpy_ref_close(module);
        return jacpy_ref_null();
    }
    return module;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_LoadGlobalStackRef(globals: &PyObjectRef, builtins: &PyObjectRef,
    name: &PyObjectRef, output: &JacPyStackOut) {
    if jacpy_dict_exact(globals) != 0 and jacpy_dict_exact(builtins) != 0 {
        _PyDict_LoadGlobalStackRef(globals, builtins, name, output);
        if jacpy_stack_output_is_null(output) != 0 and jacpy_eval_error_pending() == 0 {
            tstate: &JacPyThreadState = PyThreadState_Get();
            _PyEval_FormatExcCheckArg(tstate, jacpy_exception_type(tstate, 3), jacpy_eval_error_format(0), name);
        }
        return;
    }
    lookup: own PyLookupRef = jacpy_mapping_lookup(globals, name);
    if jacpy_lookup_state(&lookup) < 0 {
        jacpy_lookup_close(lookup);
        jacpy_stack_output_store(output, jacpy_stack_null());
        return;
    }
    value: own PyObjectRef = jacpy_lookup_take(lookup);
    if jacpy_ref_is_null(&value) != 0 {
        fallback: own PyLookupRef = jacpy_mapping_lookup(builtins, name);
        if jacpy_lookup_state(&fallback) < 0 {
            jacpy_lookup_close(fallback);
            jacpy_stack_output_store(output, jacpy_stack_null());
            return;
        }
        value = jacpy_lookup_take(fallback);
        if jacpy_ref_is_null(&value) != 0 {
            tstate: &JacPyThreadState = PyThreadState_Get();
            _PyEval_FormatExcCheckArg(tstate, jacpy_exception_type(tstate, 3), jacpy_eval_error_format(0), name);
            jacpy_stack_output_store(output, jacpy_stack_null());
            return;
        }
    }
    jacpy_stack_output_store(output, jacpy_stack_steal(value));
}

@foreign_resource(abi="pointer", empty=0, drop=jacpy_scratch_close,
                  aliasing="shared", reentrant_drop=False)
obj PyScratchArrayRef;

import from c {
    obj JacPyScratchStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_scratch_close(array: own PyScratchArrayRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_scratch_allocate(array: &PyScratchArrayRef, count: i64) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_scratch_use_caller(array: &PyScratchArrayRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_scratch_copy(array: &PyScratchArrayRef, index: i64);
    # Transfers the allocation to the legacy C output. Array elements remain
    # borrowed from the caller's stack, and no Jac loan of local storage escapes.
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_scratch_publish(storage: &JacPyScratchStorage, array: lin PyScratchArrayRef from storage);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_object_array_from_stack_impl(storage: &JacPyScratchStorage,
    array: lin PyScratchArrayRef from storage, count: i64) {
    if count > 10 {
        if jacpy_scratch_allocate(&array, count) == 0 {
            jacpy_scratch_close(array);
            return;
        }
    } else { jacpy_scratch_use_caller(&array); }
    index: i64 = 0;
    while index < count {
        jacpy_scratch_copy(&array, index);
        index = wrapping_add(index, 1);
    }
    jacpy_scratch_publish(storage, array);
}
