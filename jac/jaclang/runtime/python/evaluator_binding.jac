"""Argument binding from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. The linear binding resource tracks the
unconsumed arguments in caller storage. Place operations preserve stackref
bits, including borrowed references, without modifying the const input array.
"""

import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_arguments {
    JacPyStackArray, jacpy_code_argcount, jacpy_code_kwonlyargcount,
    jacpy_code_posonlyargcount, jacpy_stack_array_is_null, PyList_New,
    Py_GetConstant, PyObject_RichCompareBool, jacpy_missing_arguments,
    jacpy_too_many_positional, jacpy_positional_only_as_keyword
}
import from jaclang.runtime.python.evaluator_errors {
    jacpy_code_local_name, jacpy_object_is, jacpy_exception_type,
    jacpy_format_objects_error, PyErr_Clear
}
import from jaclang.runtime.python.evaluator_support { jacpy_eval_tuple_size, jacpy_eval_tuple_item }
import from jaclang.runtime.python.evaluator_imports { jacpy_unicode_check }
import from jaclang.runtime.python.evaluator_lookup {
    PyLookupRef, jacpy_dict_lookup, jacpy_lookup_state, jacpy_lookup_take, jacpy_lookup_close
}

@foreign_resource(abi="pointer", empty=0, drop=jacpy_binding_close,
                  aliasing="shared", reentrant_drop=True)
obj PyBindingRef;

import from c {
    obj JacPyBindingStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_binding_close(binding: own PyBindingRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_disarm(storage: &JacPyBindingStorage, binding: lin PyBindingRef from storage);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_remaining(binding: &PyBindingRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_position(binding: &PyBindingRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_move_next(binding: &PyBindingRef, local: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_binding_discard_next(binding: &PyBindingRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_peek_next(binding: &PyBindingRef) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_binding_pack(binding: &PyBindingRef, count: i64) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_put_object(binding: &PyBindingRef, local: i64, value: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_copy_object(binding: &PyBindingRef, local: i64, value: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_local_object(binding: &PyBindingRef, local: i64) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_locals(binding: &PyBindingRef) -> &JacPyStackArray from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_code(binding: &PyBindingRef) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_qualname(binding: &PyBindingRef) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_defaults(binding: &PyBindingRef) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_kwdefaults(binding: &PyBindingRef) -> &PyObjectRef from binding;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_varargs(binding: &PyBindingRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_varkeywords(binding: &PyBindingRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_suggestion_name(binding: &PyBindingRef, names: &PyObjectRef, local: i64, output: i64);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_three_objects(tstate: &JacPyThreadState, exception: &PyObjectRef,
        format: str, first: &PyObjectRef, second: &PyObjectRef, third: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyDict_New() -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyDict_SetItem(dictionary: &PyObjectRef, key: &PyObjectRef, value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _Py_CalculateSuggestions(names: &PyObjectRef, keyword: &PyObjectRef) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="none", reentrant=True)
def jacpy_binding_close_impl(storage: &JacPyBindingStorage, binding: lin PyBindingRef from storage) {
    while jacpy_binding_remaining(&binding) > 0 {
        jacpy_binding_discard_next(&binding);
    }
    jacpy_binding_disarm(storage, binding);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_binding_keyword_error(binding: &PyBindingRef, tstate: &JacPyThreadState,
    keyword: &PyObjectRef, keywords: &PyObjectRef, keyword_count: i64) {
    code: &PyObjectRef from binding = jacpy_binding_code(binding);
    first = jacpy_code_posonlyargcount(code);
    total = wrapping_add(jacpy_code_argcount(code), jacpy_code_kwonlyargcount(code));
    if first != 0 and jacpy_positional_only_as_keyword(tstate, code, keyword_count,
        keywords, jacpy_binding_qualname(binding)) != 0 { return; }
    suggestion: own PyObjectRef = jacpy_ref_null();
    if total > first {
        names: own PyObjectRef = PyList_New(wrapping_sub(total, first));
        if jacpy_ref_is_null(&names) != 0 {
            PyErr_Clear();
        } else {
            index = first;
            while index < total {
                jacpy_binding_suggestion_name(binding, &names, index, wrapping_sub(index, first));
                index = wrapping_add(index, 1);
            }
            suggestion = _Py_CalculateSuggestions(&names, keyword);
        }
        jacpy_ref_close(names);
    }
    if jacpy_ref_is_null(&suggestion) == 0 {
        jacpy_format_three_objects(tstate, jacpy_exception_type(tstate, 0),
            "%U() got an unexpected keyword argument '%S'. Did you mean '%S'?",
            jacpy_binding_qualname(binding), keyword, &suggestion);
    } else {
        jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0),
            "%U() got an unexpected keyword argument '%S'", jacpy_binding_qualname(binding), keyword);
    }
    jacpy_ref_close(suggestion);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_bind_locals_body(binding: &PyBindingRef, tstate: &JacPyThreadState,
    positional: i64, keywords: &PyObjectRef) -> i32 {
    code: &PyObjectRef from binding = jacpy_binding_code(binding);
    argument_count = jacpy_code_argcount(code);
    total = wrapping_add(argument_count, jacpy_code_kwonlyargcount(code));
    has_varargs = jacpy_binding_varargs(binding);
    has_keywords = jacpy_binding_varkeywords(binding);
    dictionary_slot = total;
    if has_varargs != 0 { dictionary_slot = wrapping_add(dictionary_slot, 1); }
    if has_keywords != 0 {
        dictionary: own PyObjectRef = PyDict_New();
        if jacpy_ref_is_null(&dictionary) != 0 { return -1; }
        jacpy_binding_put_object(binding, dictionary_slot, dictionary);
    }
    copied = positional;
    if copied > argument_count { copied = argument_count; }
    while jacpy_binding_position(binding) < copied {
        jacpy_binding_move_next(binding, jacpy_binding_position(binding));
    }
    if has_varargs != 0 {
        rest: own PyObjectRef = jacpy_ref_null();
        if positional == copied {
            rest = Py_GetConstant(9);
        } else {
            rest = jacpy_binding_pack(binding, wrapping_sub(positional, copied));
        }
        if jacpy_ref_is_null(&rest) != 0 { return -1; }
        jacpy_binding_put_object(binding, total, rest);
    } else {
        while jacpy_binding_position(binding) < positional { jacpy_binding_discard_next(binding); }
    }
    if jacpy_ref_is_null(keywords) == 0 {
        keyword_count = jacpy_eval_tuple_size(keywords);
        keyword_index: i64 = 0;
        while keyword_index < keyword_count {
            keyword: &PyObjectRef from keywords = jacpy_eval_tuple_item(keywords, keyword_index);
            if jacpy_ref_is_null(keyword) != 0 or jacpy_unicode_check(keyword) == 0 {
                jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0),
                    "%U() keywords must be strings", jacpy_binding_qualname(binding), keyword);
                return -1;
            }
            slot = jacpy_code_posonlyargcount(code);
            while slot < total {
                if jacpy_object_is(jacpy_code_local_name(code, slot), keyword) != 0 { break; }
                slot = wrapping_add(slot, 1);
            }
            if slot == total {
                slot = jacpy_code_posonlyargcount(code);
                while slot < total {
                    comparison = PyObject_RichCompareBool(keyword, jacpy_code_local_name(code, slot), 2);
                    if comparison > 0 { break; }
                    if comparison < 0 { return -1; }
                    slot = wrapping_add(slot, 1);
                }
            }
            if slot < total {
                if jacpy_ref_is_null(jacpy_binding_local_object(binding, slot)) == 0 {
                    jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0),
                        "%U() got multiple values for argument '%S'", jacpy_binding_qualname(binding), keyword);
                    return -1;
                }
                jacpy_binding_move_next(binding, slot);
            } else {
                if has_keywords == 0 {
                    jacpy_binding_keyword_error(binding, tstate, keyword, keywords, keyword_count);
                    return -1;
                }
                if PyDict_SetItem(jacpy_binding_local_object(binding, dictionary_slot), keyword,
                    jacpy_binding_peek_next(binding)) == -1 { return -1; }
                jacpy_binding_discard_next(binding);
            }
            keyword_index = wrapping_add(keyword_index, 1);
        }
    }
    if positional > argument_count and has_varargs == 0 {
        jacpy_too_many_positional(tstate, code, positional, jacpy_binding_defaults(binding),
            jacpy_binding_locals(binding), jacpy_binding_qualname(binding));
        return -1;
    }
    if positional < argument_count {
        defaults: &PyObjectRef from binding = jacpy_binding_defaults(binding);
        default_count: i64 = 0;
        if jacpy_ref_is_null(defaults) == 0 { default_count = jacpy_eval_tuple_size(defaults); }
        required = wrapping_sub(argument_count, default_count);
        missing: i64 = 0;
        index = positional;
        while index < required {
            if jacpy_stack_array_is_null(jacpy_binding_locals(binding), index) != 0 {
                missing = wrapping_add(missing, 1);
            }
            index = wrapping_add(index, 1);
        }
        if missing != 0 {
            jacpy_missing_arguments(tstate, code, missing, default_count,
                jacpy_binding_locals(binding), jacpy_binding_qualname(binding));
            return -1;
        }
        index = 0;
        if copied > required { index = wrapping_sub(copied, required); }
        while index < default_count {
            slot = wrapping_add(required, index);
            if jacpy_ref_is_null(jacpy_binding_local_object(binding, slot)) != 0 {
                jacpy_binding_copy_object(binding, slot, jacpy_eval_tuple_item(defaults, index));
            }
            index = wrapping_add(index, 1);
        }
    }
    missing: i64 = 0;
    index = argument_count;
    while index < total {
        if jacpy_ref_is_null(jacpy_binding_local_object(binding, index)) == 0 {
            index = wrapping_add(index, 1);
            continue;
        }
        # Re-read this function field after any earlier dict lookup can reenter.
        keyword_defaults: &PyObjectRef from binding = jacpy_binding_kwdefaults(binding);
        if jacpy_ref_is_null(keyword_defaults) == 0 {
            found: own PyLookupRef = jacpy_dict_lookup(keyword_defaults, jacpy_code_local_name(code, index));
            state = jacpy_lookup_state(&found);
            if state < 0 { return -1; }
            if state > 0 {
                value: own PyObjectRef = jacpy_lookup_take(found);
                jacpy_binding_put_object(binding, index, value);
                index = wrapping_add(index, 1);
                continue;
            }
            jacpy_lookup_close(found);
        }
        missing = wrapping_add(missing, 1);
        index = wrapping_add(index, 1);
    }
    if missing != 0 {
        jacpy_missing_arguments(tstate, code, missing, -1,
            jacpy_binding_locals(binding), jacpy_binding_qualname(binding));
        return -1;
    }
    return 0;
}

import from jaclang.runtime.python.references { PyStackRef, jacpy_stack_close }
import from jaclang.runtime.python.evaluator_frames { PyFrameRef, jacpy_frame_close }

import from c {
    obj JacPyFrameSpace;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_frame_allocate(tstate: &JacPyThreadState, code: &PyObjectRef) -> &JacPyFrameSpace from tstate;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_space_is_null(space: &JacPyFrameSpace) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_null() -> lin PyFrameRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_initialize(tstate: &JacPyThreadState, space: &JacPyFrameSpace,
        arguments: &JacPyStackArray, previous: &PyFrameRef,
        function: lin PyStackRef from (arguments, previous), locals: own PyObjectRef,
        code: &PyObjectRef) -> lin PyFrameRef from (tstate, arguments, previous);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_binding_attach_frame(binding: &PyBindingRef, frame: &PyFrameRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyErr_NoMemory() -> own PyObjectRef;
}

# The C caller supplies the descriptor's stack storage. The returned frame
# depends on its thread and caller argument/previous-frame lifetimes, never on
# the temporary descriptor. Initialization consumes the function and locals;
# binding consumes each argument even when it fails.
@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_frame_push_impl(storage: &JacPyBindingStorage, binding: lin PyBindingRef from storage,
    tstate: &JacPyThreadState, arguments: &JacPyStackArray, previous: &PyFrameRef,
    function: lin PyStackRef from (arguments, previous), locals: own PyObjectRef,
    positional: i64, keywords: &PyObjectRef) -> lin PyFrameRef from (tstate, arguments, previous) {
    code: &PyObjectRef from binding = jacpy_binding_code(&binding);
    space: &JacPyFrameSpace from tstate = jacpy_frame_allocate(tstate, code);
    if jacpy_frame_space_is_null(space) != 0 {
        jacpy_stack_close(function);
        jacpy_ref_close(locals);
        jacpy_binding_close(binding);
        failure: own PyObjectRef = PyErr_NoMemory();
        jacpy_ref_close(failure);
        return jacpy_frame_null();
    }
    frame: lin PyFrameRef from (tstate, arguments, previous) = jacpy_frame_initialize(
        tstate, space, arguments, previous, function, locals, code);
    jacpy_binding_attach_frame(&binding, &frame);
    status = jacpy_bind_locals_body(&binding, tstate, positional, keywords);
    jacpy_binding_close(binding);
    if status != 0 {
        jacpy_frame_close(frame);
        return jacpy_frame_null();
    }
    return frame;
}
