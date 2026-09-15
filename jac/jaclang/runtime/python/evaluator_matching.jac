"""Structural pattern matching from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Mapping method/self references use CPython's C-stack-reference protocol
while callbacks can execute Python or run GC. Root-chain registration follows
the upstream build configuration.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_new, jacpy_ref_null, jacpy_ref_close, jacpy_ref_is_null
}
import from jaclang.runtime.python.evaluator_support {
    jacpy_eval_tuple_size, jacpy_eval_tuple_item, jacpy_eval_error_pending, jacpy_type_error_for_object
}
import from jaclang.runtime.python.evaluator_arguments {
    PyList_New, PyList_Append, jacpy_argument_text
}
import from jaclang.runtime.python.evaluator_legacy { PyTuple_New, jacpy_tuple_initialize_item }
import from jaclang.runtime.python.evaluator_errors {
    JacPyCString, jacpy_object_is, jacpy_exception_type, jacpy_format_objects_error
}
import from jaclang.runtime.python.evaluator_imports { PySet_Contains, jacpy_none }
import from jaclang.runtime.python.evaluator_lookup {
    PyLookupRef, jacpy_attribute_lookup, jacpy_lookup_take, jacpy_lookup_state, jacpy_lookup_close
}

@foreign_resource(abi="pointer", empty=0, drop=jacpy_match_roots_close,
                  aliasing="shared", reentrant_drop=True)
obj PyMatchRootsRef;

import from c {
    obj JacPyMatchStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_match_roots_begin(storage: &JacPyMatchStorage, tstate: &JacPyThreadState,
        mapping: &PyObjectRef) -> lin PyMatchRootsRef from (storage, tstate, mapping);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_match_roots_close(roots: own PyMatchRootsRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_get_method(roots: &PyMatchRootsRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_match_has_self(roots: &PyMatchRootsRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_call_self(roots: &PyMatchRootsRef, key: &PyObjectRef, missing: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_call_bound(roots: &PyMatchRootsRef, key: &PyObjectRef, missing: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_dummy() -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PySet_New(iterable: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PySet_Add(values: &PyObjectRef, value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_IsInstance(value: &PyObjectRef, type: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyList_AsTuple(values: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_type_check(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_tuple_exact(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unicode_exact(value: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_type_match_self(type: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_match_args_name(tstate: &JacPyThreadState) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_duplicate(tstate: &JacPyThreadState, type: &PyObjectRef, name: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_args_type_error(tstate: &JacPyThreadState, type: &PyObjectRef, match_args: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_match_arity_error(tstate: &JacPyThreadState, type: &PyObjectRef,
        allowed: i64, plural: &JacPyCString, given: i64);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_match_keys_impl(storage: &JacPyMatchStorage, tstate: &JacPyThreadState,
    mapping: &PyObjectRef, keys: &PyObjectRef) -> own PyObjectRef {
    count = jacpy_eval_tuple_size(keys);
    if count == 0 { return PyTuple_New(0); }
    seen: own PyObjectRef = jacpy_ref_null();
    missing: own PyObjectRef = jacpy_ref_null();
    values: own PyObjectRef = jacpy_ref_null();
    roots: lin PyMatchRootsRef from (storage, tstate, mapping) = jacpy_match_roots_begin(storage, tstate, mapping);
    status: i32 = -1;
    while True {
        if jacpy_match_get_method(&roots) < 0 { break; }
        seen = PySet_New(&missing);
        if jacpy_ref_is_null(&seen) != 0 { break; }
        missing = jacpy_match_dummy();
        if jacpy_ref_is_null(&missing) != 0 { break; }
        values = PyTuple_New(count);
        if jacpy_ref_is_null(&values) != 0 { break; }
        status = jacpy_match_keys_fill(tstate, &roots, keys, &seen, &missing, &values, count);
        if status == 0 {
            jacpy_ref_close(values);
            values = jacpy_ref_new(jacpy_none(tstate));
        }
        break;
    }
    jacpy_match_roots_close(roots);
    jacpy_ref_close(seen);
    jacpy_ref_close(missing);
    if status < 0 {
        jacpy_ref_close(values);
        return jacpy_ref_null();
    }
    return values;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_match_keys_fill(tstate: &JacPyThreadState, roots: &PyMatchRootsRef,
    keys: &PyObjectRef, seen: &PyObjectRef, missing: &PyObjectRef,
    values: &PyObjectRef, count: i64) -> i32 {
    index: i64 = 0;
    while index < count {
        key: &PyObjectRef from keys = jacpy_eval_tuple_item(keys, index);
        if PySet_Contains(seen, key) != 0 or PySet_Add(seen, key) != 0 {
            if jacpy_eval_error_pending() == 0 {
                jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 7),
                    "mapping pattern checks duplicate key (%R)", key, key);
            }
            return -1;
        }
        value: own PyObjectRef;
        if jacpy_match_has_self(roots) != 0 { value = jacpy_match_call_self(roots, key, missing); }
        else { value = jacpy_match_call_bound(roots, key, missing); }
        if jacpy_ref_is_null(&value) != 0 { return -1; }
        if jacpy_object_is(&value, missing) != 0 {
            jacpy_ref_close(value);
            return 0;
        }
        jacpy_tuple_initialize_item(values, index, value);
        index = wrapping_add(index, 1);
    }
    return 1;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_match_class_attr(tstate: &JacPyThreadState, subject: &PyObjectRef,
    type: &PyObjectRef, name: &PyObjectRef, seen: &PyObjectRef) -> own PyObjectRef {
    if PySet_Contains(seen, name) != 0 or PySet_Add(seen, name) != 0 {
        if jacpy_eval_error_pending() == 0 { jacpy_match_duplicate(tstate, type, name); }
        return jacpy_ref_null();
    }
    lookup: own PyLookupRef = jacpy_attribute_lookup(subject, name);
    return jacpy_lookup_take(lookup);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_match_positional(tstate: &JacPyThreadState, subject: &PyObjectRef,
    type: &PyObjectRef, seen: &PyObjectRef, attributes: &PyObjectRef, count: i64) -> i32 {
    if count == 0 { return 1; }
    lookup: own PyLookupRef = jacpy_attribute_lookup(type, jacpy_match_args_name(tstate));
    if jacpy_lookup_state(&lookup) < 0 {
        jacpy_lookup_close(lookup);
        return 0;
    }
    match_args: own PyObjectRef = jacpy_lookup_take(lookup);
    match_self: i32 = 0;
    if jacpy_ref_is_null(&match_args) == 0 {
        if jacpy_tuple_exact(&match_args) == 0 {
            jacpy_match_args_type_error(tstate, type, &match_args);
            return 0;
        }
    } else {
        match_args = PyTuple_New(0);
        match_self = jacpy_type_match_self(type);
    }
    allowed: i64 = 1;
    if match_self == 0 { allowed = jacpy_eval_tuple_size(&match_args); }
    if allowed < count {
        plural: &JacPyCString = jacpy_argument_text(1);
        if allowed == 1 { plural = jacpy_argument_text(0); }
        jacpy_match_arity_error(tstate, type, allowed, plural, count);
        return 0;
    }
    if match_self != 0 {
        if PyList_Append(attributes, subject) < 0 { return 0; }
    } else {
        index: i64 = 0;
        while index < count {
            name: &PyObjectRef from match_args = jacpy_eval_tuple_item(&match_args, index);
            if jacpy_unicode_exact(name) == 0 {
                jacpy_type_error_for_object("__match_args__ elements must be strings (got %s)", name);
                return 0;
            }
            attribute: own PyObjectRef = jacpy_match_class_attr(tstate, subject, type, name, seen);
            if jacpy_ref_is_null(&attribute) != 0 { return 0; }
            status = PyList_Append(attributes, &attribute);
            jacpy_ref_close(attribute);
            if status < 0 { return 0; }
            index = wrapping_add(index, 1);
        }
    }
    jacpy_ref_close(match_args);
    return 1;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _PyEval_MatchClass(tstate: &JacPyThreadState, subject: &PyObjectRef,
    type: &PyObjectRef, positional: i64, keywords: &PyObjectRef) -> own PyObjectRef {
    if jacpy_type_check(type) == 0 {
        jacpy_format_objects_error(tstate, jacpy_exception_type(tstate, 0), "called match pattern must be a class", type, type);
        return jacpy_ref_null();
    }
    if PyObject_IsInstance(subject, type) <= 0 { return jacpy_ref_null(); }
    absent: own PyObjectRef = jacpy_ref_null();
    seen: own PyObjectRef = PySet_New(&absent);
    jacpy_ref_close(absent);
    if jacpy_ref_is_null(&seen) != 0 { return seen; }
    attributes: own PyObjectRef = PyList_New(0);
    if jacpy_ref_is_null(&attributes) != 0 {
        jacpy_ref_close(seen);
        return attributes;
    }
    status = jacpy_match_positional(tstate, subject, type, &seen, &attributes, positional);
    index: i64 = 0;
    count = jacpy_eval_tuple_size(keywords);
    while status != 0 and index < count {
        attribute: own PyObjectRef = jacpy_match_class_attr(tstate, subject, type,
            jacpy_eval_tuple_item(keywords, index), &seen);
        if jacpy_ref_is_null(&attribute) != 0 { status = 0; break; }
        append_status = PyList_Append(&attributes, &attribute);
        jacpy_ref_close(attribute);
        if append_status < 0 { status = 0; break; }
        index = wrapping_add(index, 1);
    }
    if status == 0 {
        jacpy_ref_close(seen);
        jacpy_ref_close(attributes);
        return jacpy_ref_null();
    }
    result: own PyObjectRef = PyList_AsTuple(&attributes);
    jacpy_ref_close(attributes);
    jacpy_ref_close(seen);
    return result;
}
