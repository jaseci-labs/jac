"""Name lookup and imports from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Every owned API result is transferred or
released at the same point as the C evaluator, including diagnostic failures.
"""

import from jaclang.runtime.python.references {
    JacPyThreadState, PyObjectRef, jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }
import from jaclang.runtime.python.evaluator_lookup {
    PyLookupRef, jacpy_lookup_state, jacpy_lookup_take, jacpy_lookup_close,
    jacpy_mapping_lookup, jacpy_dict_lookup, jacpy_attribute_lookup,
    jacpy_module_origin_lookup, jacpy_sys_lookup
}
import from jaclang.runtime.python.evaluator_support { jacpy_eval_error_pending }
import from jaclang.runtime.python.evaluator_errors {
    _PyEval_FormatExcCheckArg, jacpy_eval_error_format, jacpy_exception_type,
    jacpy_eval_identifier, PyErr_ExceptionMatches, PyErr_Clear
}

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_locals(frame: &PyFrameRef) -> &PyObjectRef from frame;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_globals(frame: &PyFrameRef) -> &PyObjectRef from frame;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_builtins(frame: &PyFrameRef) -> &PyObjectRef from frame;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_none(tstate: &JacPyThreadState) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_is_default_import(tstate: &JacPyThreadState, function: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_set_string_error(tstate: &JacPyThreadState, exception: &PyObjectRef, message: str);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyLong_AsInt(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyImport_ImportModuleLevelObject(name: &PyObjectRef, globals: &PyObjectRef,
        locals: &PyObjectRef, fromlist: &PyObjectRef, level: i32) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_vectorcall_five(function: &PyObjectRef, a: &PyObjectRef, b: &PyObjectRef,
        c: &PyObjectRef, d: &PyObjectRef, e: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_unicode_format_four(format: str, a: &PyObjectRef, b: &PyObjectRef,
        c: &PyObjectRef, d: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unicode_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_anyset_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_module_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyImport_GetModule(name: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def PyUnicode_FromString(value: str) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyModule_IsPossiblyShadowing(origin: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PySet_Contains(values: &PyObjectRef, key: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyModule_GetFilenameObject(module: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyModuleSpec_IsInitializing(specification: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyErr_SetImportErrorWithNameFrom(message: &PyObjectRef, module_name: &PyObjectRef,
        origin: &PyObjectRef, name: &PyObjectRef) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_LoadName(tstate: &JacPyThreadState, frame: &PyFrameRef from tstate,
    name: &PyObjectRef) -> own PyObjectRef {
    locals: &PyObjectRef from frame = jacpy_frame_locals(frame);
    if jacpy_ref_is_null(locals) != 0 {
        jacpy_set_string_error(tstate, jacpy_exception_type(tstate, 5), "no locals found");
        return jacpy_ref_null();
    }
    local: own PyLookupRef = jacpy_mapping_lookup(locals, name);
    if jacpy_lookup_state(&local) != 0 { return jacpy_lookup_take(local); }
    jacpy_lookup_close(local);
    global: own PyLookupRef = jacpy_dict_lookup(jacpy_frame_globals(frame), name);
    if jacpy_lookup_state(&global) != 0 { return jacpy_lookup_take(global); }
    jacpy_lookup_close(global);
    builtin: own PyLookupRef = jacpy_mapping_lookup(jacpy_frame_builtins(frame), name);
    if jacpy_lookup_state(&builtin) == 0 {
        _PyEval_FormatExcCheckArg(tstate, jacpy_exception_type(tstate, 3),
            jacpy_eval_error_format(0), name);
    }
    return jacpy_lookup_take(builtin);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_import_name_call(tstate: &JacPyThreadState, frame: &PyFrameRef from tstate,
    name: &PyObjectRef, fromlist: &PyObjectRef, level: &PyObjectRef,
    importer: own PyObjectRef, locals: &PyObjectRef) -> own PyObjectRef {
    if jacpy_is_default_import(tstate, &importer) != 0 {
        jacpy_ref_close(importer);
        integer_level = PyLong_AsInt(level);
        if integer_level == -1 and jacpy_eval_error_pending() != 0 { return jacpy_ref_null(); }
        return PyImport_ImportModuleLevelObject(name, jacpy_frame_globals(frame),
            locals, fromlist, integer_level);
    }
    result: own PyObjectRef = jacpy_vectorcall_five(&importer, name,
        jacpy_frame_globals(frame), locals, fromlist, level);
    jacpy_ref_close(importer);
    return result;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_ImportName(tstate: &JacPyThreadState, frame: &PyFrameRef from tstate,
    name: &PyObjectRef, fromlist: &PyObjectRef, level: &PyObjectRef) -> own PyObjectRef {
    found: own PyLookupRef = jacpy_mapping_lookup(jacpy_frame_builtins(frame),
        jacpy_eval_identifier(tstate, 5));
    status = jacpy_lookup_state(&found);
    if status < 0 { return jacpy_ref_null(); }
    if status == 0 {
        jacpy_set_string_error(tstate, jacpy_exception_type(tstate, 6), "__import__ not found");
        return jacpy_ref_null();
    }
    importer: own PyObjectRef = jacpy_lookup_take(found);
    locals: &PyObjectRef from frame = jacpy_frame_locals(frame);
    if jacpy_ref_is_null(locals) != 0 {
        return jacpy_import_name_call(tstate, frame, name, fromlist, level,
            importer, jacpy_none(tstate));
    }
    return jacpy_import_name_call(tstate, frame, name, fromlist, level, importer, locals);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_import_error_message(name: &PyObjectRef, display_name: &PyObjectRef,
    origin: &PyObjectRef, specification: &PyObjectRef,
    shadowing: i32, shadowing_stdlib: i32) -> own PyObjectRef {
    if jacpy_ref_is_null(specification) != 0 {
        return jacpy_unicode_format_four("cannot import name %R from %R (unknown location)",
            name, display_name, origin, display_name);
    }
    if shadowing_stdlib != 0 {
        return jacpy_unicode_format_four(
            "cannot import name %R from %R (consider renaming %R since it has the same name as the standard library module named %R and prevents importing that standard library module)",
            name, display_name, origin, display_name);
    }
    initializing = _PyModuleSpec_IsInitializing(specification);
    if initializing < 0 { return jacpy_ref_null(); }
    if initializing > 0 {
        if shadowing != 0 {
            return jacpy_unicode_format_four(
                "cannot import name %R from %R (consider renaming %R if it has the same name as a library you intended to import)",
                name, display_name, origin, display_name);
        } elif jacpy_ref_is_null(origin) == 0 {
            return jacpy_unicode_format_four(
                "cannot import name %R from partially initialized module %R (most likely due to a circular import) (%S)",
                name, display_name, origin, display_name);
        }
        return jacpy_unicode_format_four(
            "cannot import name %R from partially initialized module %R (most likely due to a circular import)",
            name, display_name, origin, display_name);
    }
    if jacpy_ref_is_null(origin) == 0 {
        return jacpy_unicode_format_four("cannot import name %R from %R (%S)",
            name, display_name, origin, display_name);
    }
    return jacpy_unicode_format_four("cannot import name %R from %R (unknown location)",
        name, display_name, origin, display_name);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_import_error_origin(tstate: &JacPyThreadState, module: &PyObjectRef,
    name: &PyObjectRef, module_name: &PyObjectRef, display_name: &PyObjectRef,
    specification: &PyObjectRef) {
    origin: own PyObjectRef = jacpy_ref_null();
    shadowing: i32 = 0;
    shadowing_stdlib: i32 = 0;
    if jacpy_ref_is_null(specification) == 0 {
        origin_lookup: own PyLookupRef = jacpy_module_origin_lookup(specification);
        if jacpy_lookup_state(&origin_lookup) < 0 { return; }
        origin = jacpy_lookup_take(origin_lookup);
        shadowing = _PyModule_IsPossiblyShadowing(&origin);
        if shadowing < 0 { return; }
        if shadowing != 0 {
            stdlib_lookup: own PyLookupRef = jacpy_sys_lookup("stdlib_module_names");
            if jacpy_lookup_state(&stdlib_lookup) < 0 { return; }
            stdlib: own PyObjectRef = jacpy_lookup_take(stdlib_lookup);
            if jacpy_ref_is_null(&stdlib) == 0 and jacpy_anyset_check(&stdlib) != 0 {
                shadowing_stdlib = PySet_Contains(&stdlib, display_name);
                if shadowing_stdlib < 0 {
                    jacpy_ref_close(stdlib);
                    return;
                }
            }
            jacpy_ref_close(stdlib);
        }
        if jacpy_ref_is_null(&origin) != 0 and jacpy_module_check(module) != 0 {
            origin = PyModule_GetFilenameObject(module);
            if jacpy_ref_is_null(&origin) != 0 {
                if PyErr_ExceptionMatches(jacpy_exception_type(tstate, 5)) == 0 { return; }
                PyErr_Clear();
            }
        }
    }
    message: own PyObjectRef = jacpy_import_error_message(name, display_name,
        &origin, specification, shadowing, shadowing_stdlib);
    if jacpy_ref_is_null(&message) == 0 {
        # This error API returns a null owner; it never lends the exception.
        _PyErr_SetImportErrorWithNameFrom(&message, module_name, &origin, name);
        jacpy_ref_close(message);
    }
    jacpy_ref_close(origin);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_import_error_specification(tstate: &JacPyThreadState, module: &PyObjectRef,
    name: &PyObjectRef, module_name: &PyObjectRef, display_name: &PyObjectRef) {
    found: own PyLookupRef = jacpy_attribute_lookup(module, jacpy_eval_identifier(tstate, 8));
    if jacpy_lookup_state(&found) < 0 { return; }
    specification: own PyObjectRef = jacpy_lookup_take(found);
    jacpy_import_error_origin(tstate, module, name, module_name, display_name, &specification);
    jacpy_ref_close(specification);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_import_from_error(tstate: &JacPyThreadState, module: &PyObjectRef,
    name: &PyObjectRef, module_name: own PyObjectRef) -> own PyObjectRef {
    if jacpy_ref_is_null(&module_name) != 0 {
        display_name: own PyObjectRef = PyUnicode_FromString("<unknown module name>");
        if jacpy_ref_is_null(&display_name) != 0 { return jacpy_ref_null(); }
        jacpy_import_error_specification(tstate, module, name, &module_name, &display_name);
        jacpy_ref_close(display_name);
    } else {
        jacpy_import_error_specification(tstate, module, name, &module_name, &module_name);
        jacpy_ref_close(module_name);
    }
    return jacpy_ref_null();
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_ImportFrom(tstate: &JacPyThreadState, module: &PyObjectRef,
    name: &PyObjectRef) -> own PyObjectRef {
    attribute: own PyLookupRef = jacpy_attribute_lookup(module, name);
    if jacpy_lookup_state(&attribute) != 0 { return jacpy_lookup_take(attribute); }
    jacpy_lookup_close(attribute);
    named: own PyLookupRef = jacpy_attribute_lookup(module, jacpy_eval_identifier(tstate, 7));
    if jacpy_lookup_state(&named) < 0 { return jacpy_ref_null(); }
    module_name: own PyObjectRef = jacpy_lookup_take(named);
    if jacpy_ref_is_null(&module_name) != 0 or jacpy_unicode_check(&module_name) == 0 {
        module_name = jacpy_ref_null();
        return jacpy_import_from_error(tstate, module, name, module_name);
    }
    full_name: own PyObjectRef = jacpy_unicode_format_four("%U.%U",
        &module_name, name, name, name);
    if jacpy_ref_is_null(&full_name) != 0 { return jacpy_ref_null(); }
    result: own PyObjectRef = PyImport_GetModule(&full_name);
    jacpy_ref_close(full_name);
    if jacpy_ref_is_null(&result) != 0 and jacpy_eval_error_pending() == 0 {
        return jacpy_import_from_error(tstate, module, name, module_name);
    }
    jacpy_ref_close(module_name);
    return result;
}
