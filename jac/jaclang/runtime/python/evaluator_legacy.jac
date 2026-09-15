"""Legacy evaluation entry points from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. The temporary keyword array borrows its
entries from the caller and owns only its allocation, never those references.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_new, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_monitoring { PyThreadState_Get }
import from jaclang.runtime.python.evaluator_calls { JacPyObjectArray, jacpy_object_array_item }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_legacy_arguments_close,
                  aliasing="shared", reentrant_drop=False)
obj PyLegacyArgsRef;

import from c {
    obj JacPyLegacyStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_arguments_begin(storage: &JacPyLegacyStorage,
        arguments: &JacPyObjectArray, keywords: &JacPyObjectArray) -> lin PyLegacyArgsRef from (storage, arguments, keywords);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_arguments_close(arguments: own PyLegacyArgsRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_arguments_allocate(arguments: &PyLegacyArgsRef, count: i64) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_arguments_copy(arguments: &PyLegacyArgsRef, source: i64, destination: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_keyword_copy(arguments: &PyLegacyArgsRef, source: i64, destination: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_legacy_arguments_values(arguments: &PyLegacyArgsRef) -> &JacPyObjectArray from arguments;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_array_null() -> &JacPyObjectArray;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_tuple_from_array(values: &JacPyObjectArray, count: i64) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyTuple_New(count: i64) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_tuple_initialize_item(tuple: &PyObjectRef, index: i64, value: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyDict_LoadBuiltinsFromGlobals(globals: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_function_from_code(code: &PyObjectRef, globals: &PyObjectRef,
        builtins: &PyObjectRef, defaults: &PyObjectRef, keyword_defaults: &PyObjectRef,
        closure: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_legacy_stat();
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyEval_Vector(tstate: &JacPyThreadState, function: &PyObjectRef,
        locals: &PyObjectRef, arguments: &JacPyObjectArray,
        positional: i64, keywords: &PyObjectRef) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def PyEval_EvalCode(code: &PyObjectRef, globals: &PyObjectRef, locals: &PyObjectRef) -> own PyObjectRef {
    tstate: &JacPyThreadState = PyThreadState_Get();
    local_values: &PyObjectRef from (locals, globals) = locals;
    if jacpy_ref_is_null(local_values) != 0 { local_values = globals; }
    builtins: own PyObjectRef = _PyDict_LoadBuiltinsFromGlobals(globals);
    if jacpy_ref_is_null(&builtins) != 0 { return builtins; }
    absent: own PyObjectRef = jacpy_ref_null();
    function: own PyObjectRef = jacpy_function_from_code(code, globals, &builtins, &absent, &absent, &absent);
    jacpy_ref_close(builtins);
    if jacpy_ref_is_null(&function) != 0 { return function; }
    jacpy_eval_legacy_stat();
    result: own PyObjectRef = _PyEval_Vector(tstate, &function, local_values, jacpy_object_array_null(), 0, &absent);
    jacpy_ref_close(function);
    jacpy_ref_close(absent);
    return result;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_eval_code_ex_impl(storage: &JacPyLegacyStorage, code: &PyObjectRef,
    globals: &PyObjectRef, locals: &PyObjectRef, input: &JacPyObjectArray,
    positional: i64, keywords: &JacPyObjectArray, keyword_count: i64,
    default_values: &JacPyObjectArray, default_count: i64,
    keyword_defaults: &PyObjectRef, closure: &PyObjectRef) -> own PyObjectRef {
    tstate: &JacPyThreadState = PyThreadState_Get();
    defaults: own PyObjectRef = jacpy_tuple_from_array(default_values, default_count);
    if jacpy_ref_is_null(&defaults) != 0 { return defaults; }
    builtins: own PyObjectRef = _PyDict_LoadBuiltinsFromGlobals(globals);
    if jacpy_ref_is_null(&builtins) != 0 {
        jacpy_ref_close(defaults);
        return builtins;
    }
    local_values: &PyObjectRef from (locals, globals) = locals;
    if jacpy_ref_is_null(local_values) != 0 { local_values = globals; }
    arguments: lin PyLegacyArgsRef from (storage, input, keywords) = jacpy_legacy_arguments_begin(storage, input, keywords);
    names: own PyObjectRef = jacpy_ref_null();
    function: own PyObjectRef = jacpy_ref_null();
    result: own PyObjectRef = jacpy_ref_null();
    # A single completion path preserves the pinned cleanup order, including
    # freeing the borrowed argument buffer before builtins and defaults.
    while True {
        if keyword_count != 0 {
            names = PyTuple_New(keyword_count);
            if jacpy_ref_is_null(&names) != 0 { break; }
            if jacpy_legacy_arguments_allocate(&arguments, wrapping_add(keyword_count, positional)) == 0 { break; }
            index: i64 = 0;
            while index < positional {
                jacpy_legacy_arguments_copy(&arguments, index, index);
                index = wrapping_add(index, 1);
            }
            index = 0;
            while index < keyword_count {
                source = wrapping_mul(index, 2);
                name: own PyObjectRef = jacpy_ref_new(jacpy_object_array_item(keywords, source));
                jacpy_tuple_initialize_item(&names, index, name);
                jacpy_legacy_keyword_copy(&arguments, wrapping_add(source, 1), wrapping_add(positional, index));
                index = wrapping_add(index, 1);
            }
        }
        function = jacpy_function_from_code(code, globals, &builtins, &defaults, keyword_defaults, closure);
        if jacpy_ref_is_null(&function) != 0 { break; }
        jacpy_eval_legacy_stat();
        result = _PyEval_Vector(tstate, &function, local_values,
            jacpy_legacy_arguments_values(&arguments), positional, &names);
        break;
    }
    jacpy_ref_close(function);
    jacpy_ref_close(names);
    jacpy_legacy_arguments_close(arguments);
    jacpy_ref_close(builtins);
    jacpy_ref_close(defaults);
    return result;
}
