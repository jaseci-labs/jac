"""Argument-binding diagnostics from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Borrowed array storage is supplied by the
active frame; these helpers neither transfer that storage nor retain its slots.
"""

import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_null, jacpy_ref_new, jacpy_ref_close, jacpy_ref_is_null
}
import from jaclang.runtime.python.evaluator_errors {
    JacPyCString, jacpy_code_local_name, jacpy_object_is,
    jacpy_exception_type, jacpy_format_objects_error
}
import from jaclang.runtime.python.evaluator_support { jacpy_eval_tuple_size, jacpy_eval_tuple_item }
import from jaclang.runtime.python.evaluator_imports { jacpy_unicode_format_four, PyUnicode_FromString }

import from c {
    obj JacPyStackArray;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_argcount(code: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_kwonlyargcount(code: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_code_posonlyargcount(code: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_list_size(values: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_list_item(values: &PyObjectRef, index: i64) -> &PyObjectRef from values;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_list_initialize_item(values: &PyObjectRef, index: i64, value: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_list_delete_slice(values: &PyObjectRef, start: i64, end: i64) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_argument_text(kind: i32) -> &JacPyCString;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_missing_error(tstate: &JacPyThreadState, qualname: &PyObjectRef,
        count: i64, kind: &JacPyCString, plural: &JacPyCString, names: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def jacpy_unicode_format_sizes(format: str, first: i64, second: i64) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def jacpy_unicode_format_kwonly(given_plural: &JacPyCString, count: i64,
        plural: &JacPyCString) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_format_positional_error(tstate: &JacPyThreadState, qualname: &PyObjectRef,
        signature: &PyObjectRef, plural: &JacPyCString, given: i64,
        keyword_signature: &PyObjectRef, verb: &JacPyCString);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_array_is_null(values: &JacPyStackArray, index: i64) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def jacpy_stack_array_has_object(values: &JacPyStackArray, index: i64) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyList_New(size: i64) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_Repr(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyUnicode_Join(separator: &PyObjectRef, values: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=False)
    def PyUnicode_Concat(first: &PyObjectRef, second: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def Py_GetConstant(identifier: u32) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyList_Append(values: &PyObjectRef, value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_RichCompareBool(first: &PyObjectRef, second: &PyObjectRef, operation: i32) -> i32;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_format_missing(tstate: &JacPyThreadState, kind: &JacPyCString,
    names: &PyObjectRef, qualname: &PyObjectRef) {
    length = jacpy_list_size(names);
    name_string: own PyObjectRef = jacpy_ref_null();
    if length == 1 {
        name_string = jacpy_ref_new(jacpy_list_item(names, 0));
    } elif length == 2 {
        name_string = jacpy_unicode_format_four("%U and %U", jacpy_list_item(names, 0),
            jacpy_list_item(names, 1), names, names);
    } else {
        tail: own PyObjectRef = jacpy_unicode_format_four(", %U, and %U",
            jacpy_list_item(names, wrapping_sub(length, 2)),
            jacpy_list_item(names, wrapping_sub(length, 1)), names, names);
        if jacpy_ref_is_null(&tail) != 0 { return; }
        if jacpy_list_delete_slice(names, wrapping_sub(length, 2), length) == -1 { return; }
        comma: own PyObjectRef = PyUnicode_FromString(", ");
        if jacpy_ref_is_null(&comma) != 0 { return; }
        joined: own PyObjectRef = PyUnicode_Join(&comma, names);
        jacpy_ref_close(comma);
        if jacpy_ref_is_null(&joined) != 0 { return; }
        name_string = PyUnicode_Concat(&joined, &tail);
        jacpy_ref_close(joined);
        jacpy_ref_close(tail);
    }
    if jacpy_ref_is_null(&name_string) != 0 { return; }
    plural: &JacPyCString = jacpy_argument_text(1);
    if length == 1 { plural = jacpy_argument_text(0); }
    jacpy_format_missing_error(tstate, qualname, length, kind, plural, &name_string);
    jacpy_ref_close(name_string);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_missing_arguments(tstate: &JacPyThreadState, code: &PyObjectRef,
    missing: i64, default_count: i64, locals: &JacPyStackArray, qualname: &PyObjectRef) {
    names: own PyObjectRef = PyList_New(missing);
    if jacpy_ref_is_null(&names) != 0 { return; }
    start: i64 = 0;
    end: i64 = 0;
    kind: &JacPyCString = jacpy_argument_text(4);
    if default_count != -1 {
        end = wrapping_sub(jacpy_code_argcount(code), default_count);
    } else {
        start = jacpy_code_argcount(code);
        end = wrapping_add(start, jacpy_code_kwonlyargcount(code));
        kind = jacpy_argument_text(5);
    }
    index = start;
    output: i64 = 0;
    while index < end {
        if jacpy_stack_array_is_null(locals, index) != 0 {
            name: own PyObjectRef = PyObject_Repr(jacpy_code_local_name(code, index));
            if jacpy_ref_is_null(&name) != 0 { return; }
            jacpy_list_initialize_item(&names, output, name);
            output = wrapping_add(output, 1);
        }
        index = wrapping_add(index, 1);
    }
    jacpy_format_missing(tstate, kind, &names, qualname);
    jacpy_ref_close(names);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_too_many_positional(tstate: &JacPyThreadState, code: &PyObjectRef,
    given: i64, defaults: &PyObjectRef, locals: &JacPyStackArray, qualname: &PyObjectRef) {
    count = jacpy_code_argcount(code);
    end = wrapping_add(count, jacpy_code_kwonlyargcount(code));
    keyword_count: i64 = 0;
    index = count;
    while index < end {
        if jacpy_stack_array_has_object(locals, index) != 0 {
            keyword_count = wrapping_add(keyword_count, 1);
        }
        index = wrapping_add(index, 1);
    }
    default_count: i64 = 0;
    if jacpy_ref_is_null(defaults) == 0 { default_count = jacpy_eval_tuple_size(defaults); }
    plural: &JacPyCString = jacpy_argument_text(1);
    signature: own PyObjectRef = jacpy_ref_null();
    if default_count != 0 {
        signature = jacpy_unicode_format_sizes("from %zd to %zd", wrapping_sub(count, default_count), count);
    } else {
        if count == 1 { plural = jacpy_argument_text(0); }
        signature = jacpy_unicode_format_sizes("%zd", count, count);
    }
    if jacpy_ref_is_null(&signature) != 0 { return; }
    keyword_signature: own PyObjectRef = jacpy_ref_null();
    if keyword_count != 0 {
        given_plural: &JacPyCString = jacpy_argument_text(1);
        if given == 1 { given_plural = jacpy_argument_text(0); }
        keyword_plural: &JacPyCString = jacpy_argument_text(1);
        if keyword_count == 1 { keyword_plural = jacpy_argument_text(0); }
        keyword_signature = jacpy_unicode_format_kwonly(given_plural, keyword_count, keyword_plural);
        if jacpy_ref_is_null(&keyword_signature) != 0 { return; }
    } else {
        keyword_signature = Py_GetConstant(7);
    }
    verb: &JacPyCString = jacpy_argument_text(3);
    if given == 1 and keyword_count == 0 { verb = jacpy_argument_text(2); }
    jacpy_format_positional_error(tstate, qualname, &signature, plural, given, &keyword_signature, verb);
    jacpy_ref_close(signature);
    jacpy_ref_close(keyword_signature);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_positional_only_as_keyword(tstate: &JacPyThreadState, code: &PyObjectRef,
    keyword_count: i64, keywords: &PyObjectRef, qualname: &PyObjectRef) -> i32 {
    names: own PyObjectRef = PyList_New(0);
    if jacpy_ref_is_null(&names) != 0 { return 1; }
    conflicts: i64 = 0;
    index: i64 = 0;
    count = jacpy_code_posonlyargcount(code);
    while index < count {
        positional_name: &PyObjectRef from code = jacpy_code_local_name(code, index);
        keyword_index: i64 = 0;
        while keyword_index < keyword_count {
            keyword: &PyObjectRef from keywords = jacpy_eval_tuple_item(keywords, keyword_index);
            if jacpy_object_is(keyword, positional_name) != 0 {
                if PyList_Append(&names, keyword) != 0 { return 1; }
                conflicts = wrapping_add(conflicts, 1);
            } else {
                comparison = PyObject_RichCompareBool(positional_name, keyword, 2);
                if comparison > 0 {
                    if PyList_Append(&names, keyword) != 0 { return 1; }
                    conflicts = wrapping_add(conflicts, 1);
                } elif comparison < 0 { return 1; }
            }
            keyword_index = wrapping_add(keyword_index, 1);
        }
        index = wrapping_add(index, 1);
    }
    if conflicts != 0 {
        comma: own PyObjectRef = PyUnicode_FromString(", ");
        if jacpy_ref_is_null(&comma) != 0 { return 1; }
        error_names: own PyObjectRef = PyUnicode_Join(&comma, &names);
        jacpy_ref_close(comma);
        if jacpy_ref_is_null(&error_names) != 0 { return 1; }
        jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0),
            "%U() got some positional-only arguments passed as keyword arguments: '%U'", qualname, &error_names);
        jacpy_ref_close(error_names);
        jacpy_ref_close(names);
        return 1;
    }
    jacpy_ref_close(names);
    return 0;
}
