"""Frame introspection and builtins from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Legacy C entries supply the current frame
as a scoped borrow. Borrowed results retain that frame dependency; owning
variants copy exactly where the corresponding CPython API does.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_new, jacpy_ref_null, jacpy_ref_close, jacpy_ref_is_null
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }
import from jaclang.runtime.python.evaluator_support { jacpy_eval_error_pending }
import from jaclang.runtime.python.evaluator_calls { jacpy_frame_is_null }
import from jaclang.runtime.python.evaluator_binding { PyDict_New, PyDict_SetItem }
import from jaclang.runtime.python.evaluator_errors { PyErr_Clear, jacpy_exception_type, jacpy_eval_identifier }
import from jaclang.runtime.python.evaluator_imports {
    jacpy_frame_locals, jacpy_frame_globals, jacpy_frame_builtins, jacpy_set_string_error
}
import from jaclang.runtime.python.evaluator_monitoring { PyErr_SetObject }
import from jaclang.runtime.python.evaluator_lookup {
    PyLookupRef, jacpy_dict_lookup, jacpy_mapping_lookup, jacpy_lookup_take, jacpy_lookup_state, jacpy_lookup_close
}

import from c {
    obj JacPyObjectOut;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_ref_borrow_null() -> &PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_frame_object(frame: &PyFrameRef) -> &PyObjectRef from frame;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_frame_get_locals(frame: &PyFrameRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_locals_proxy_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_locals_cache(frame: &PyObjectRef) -> &PyObjectRef from frame;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_install_locals_cache(frame: &PyObjectRef, dictionary: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyDict_Update(dictionary: &PyObjectRef, values: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_dict_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_SetItem(mapping: &PyObjectRef, key: &PyObjectRef, value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_current_builtins_new(tstate: &JacPyThreadState) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyImport_ImportModuleLevel(name: str, globals: &PyObjectRef,
        locals: &PyObjectRef, fromlist: &PyObjectRef, level: i32) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_output_is_null(output: &JacPyObjectOut) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_output_store(output: &JacPyObjectOut, value: own PyObjectRef);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_get_builtins(frame: &PyFrameRef, interpreter_builtins: &PyObjectRef) -> &PyObjectRef from (frame, interpreter_builtins) {
    if jacpy_frame_is_null(frame) == 0 { return jacpy_frame_builtins(frame); }
    return interpreter_builtins;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_get_globals(frame: &PyFrameRef) -> &PyObjectRef from frame {
    if jacpy_frame_is_null(frame) == 0 { return jacpy_frame_globals(frame); }
    return jacpy_ref_borrow_null();
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_get_frame_object(frame: &PyFrameRef) -> &PyObjectRef from frame {
    if jacpy_frame_is_null(frame) != 0 { return jacpy_ref_borrow_null(); }
    result: &PyObjectRef from frame = jacpy_frame_object(frame);
    if jacpy_ref_is_null(result) != 0 { PyErr_Clear(); }
    return result;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_get_locals(tstate: &JacPyThreadState, frame: &PyFrameRef) -> &PyObjectRef from frame {
    if jacpy_frame_is_null(frame) != 0 {
        jacpy_set_string_error(tstate, jacpy_exception_type(tstate, 5), "frame does not exist");
        return jacpy_ref_borrow_null();
    }
    locals: own PyObjectRef = jacpy_frame_get_locals(frame);
    if jacpy_ref_is_null(&locals) != 0 { return jacpy_ref_borrow_null(); }
    if jacpy_locals_proxy_check(&locals) != 0 {
        frame_object: &PyObjectRef from frame = jacpy_frame_object(frame);
        if jacpy_ref_is_null(frame_object) != 0 {
            jacpy_ref_close(locals);
            return jacpy_ref_borrow_null();
        }
        cached: &PyObjectRef from frame = jacpy_frame_locals_cache(frame_object);
        if jacpy_ref_is_null(cached) != 0 {
            dictionary: own PyObjectRef = PyDict_New();
            if jacpy_ref_is_null(&dictionary) != 0 {
                jacpy_ref_close(locals);
                return jacpy_ref_borrow_null();
            }
            jacpy_frame_install_locals_cache(frame_object, dictionary);
            cached = jacpy_frame_locals_cache(frame_object);
        }
        if PyDict_Update(cached, &locals) < 0 { cached = jacpy_ref_borrow_null(); }
        jacpy_ref_close(locals);
        return cached;
    }
    # Non-proxy locals are retained by frame.f_locals. Return that owner's
    # view after releasing the temporary reference, not a view of that owner.
    jacpy_ref_close(locals);
    return jacpy_frame_locals(frame);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_get_frame_locals(tstate: &JacPyThreadState, frame: &PyFrameRef) -> own PyObjectRef {
    if jacpy_frame_is_null(frame) != 0 {
        jacpy_set_string_error(tstate, jacpy_exception_type(tstate, 5), "frame does not exist");
        return jacpy_ref_null();
    }
    locals: own PyObjectRef = jacpy_frame_get_locals(frame);
    if jacpy_ref_is_null(&locals) != 0 { return locals; }
    if jacpy_locals_proxy_check(&locals) != 0 {
        result: own PyObjectRef = PyDict_New();
        if jacpy_ref_is_null(&result) != 0 {
            jacpy_ref_close(locals);
            return result;
        }
        if PyDict_Update(&result, &locals) < 0 {
            jacpy_ref_close(result);
            jacpy_ref_close(locals);
            return jacpy_ref_null();
        }
        jacpy_ref_close(locals);
        return result;
    }
    return locals;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_get_builtin(tstate: &JacPyThreadState, builtins: &PyObjectRef, name: &PyObjectRef) -> own PyObjectRef {
    result: own PyLookupRef = jacpy_mapping_lookup(builtins, name);
    if jacpy_lookup_state(&result) == 0 { PyErr_SetObject(jacpy_exception_type(tstate, 1), name); }
    return jacpy_lookup_take(result);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_set_globals_builtins(tstate: &JacPyThreadState, globals: &PyObjectRef, builtins: &PyObjectRef) -> i32 {
    name: &PyObjectRef from tstate = jacpy_eval_identifier(tstate, 6);
    if jacpy_dict_check(globals) != 0 { return PyDict_SetItem(globals, name, builtins); }
    return PyObject_SetItem(globals, name, builtins);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_ensure_builtins(tstate: &JacPyThreadState, globals: &PyObjectRef,
    output: &JacPyObjectOut, use_module: i32) -> i32 {
    name: &PyObjectRef from tstate = jacpy_eval_identifier(tstate, 6);
    result: own PyLookupRef;
    if jacpy_dict_check(globals) != 0 { result = jacpy_dict_lookup(globals, name); }
    else { result = jacpy_mapping_lookup(globals, name); }
    if jacpy_lookup_state(&result) < 0 {
        jacpy_lookup_close(result);
        return -1;
    }
    builtins: own PyObjectRef = jacpy_lookup_take(result);
    if jacpy_ref_is_null(&builtins) != 0 {
        if jacpy_eval_error_pending() != 0 { return -1; }
        if use_module != 0 {
            absent: own PyObjectRef = jacpy_ref_null();
            builtins = PyImport_ImportModuleLevel("builtins", &absent, &absent, &absent, 0);
            jacpy_ref_close(absent);
        } else { builtins = jacpy_current_builtins_new(tstate); }
        if jacpy_ref_is_null(&builtins) != 0 { return -1; }
        if jacpy_set_globals_builtins(tstate, globals, &builtins) < 0 {
            jacpy_ref_close(builtins);
            return -1;
        }
    }
    if jacpy_object_output_is_null(output) == 0 { jacpy_object_output_store(output, builtins); }
    else { jacpy_ref_close(builtins); }
    return 0;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_EnsureBuiltins(tstate: &JacPyThreadState, globals: &PyObjectRef, output: &JacPyObjectOut) -> i32 {
    return jacpy_ensure_builtins(tstate, globals, output, 0);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_EnsureBuiltinsWithModule(tstate: &JacPyThreadState, globals: &PyObjectRef, output: &JacPyObjectOut) -> i32 {
    return jacpy_ensure_builtins(tstate, globals, output, 1);
}
