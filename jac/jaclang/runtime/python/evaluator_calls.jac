"""Evaluator call setup from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Call storage owns its temporary buffer and
any entries not yet handed to frame binding. It is released before evaluation.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, PyStackRef, JacPyThreadState, jacpy_ref_is_null, jacpy_ref_new,
    jacpy_ref_close, jacpy_ref_null, jacpy_stack_new
}
import from jaclang.runtime.python.evaluator_frames { PyFrameRef, jacpy_frame_close }
import from jaclang.runtime.python.evaluator_support { jacpy_eval_tuple_size }
import from jaclang.runtime.python.evaluator_binding { PyErr_NoMemory }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_callargs_close,
                  aliasing="shared", reentrant_drop=True)
obj PyCallArgsRef;

import from c {
    obj JacPyCallStorage;
    obj JacPyObjectArray;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_begin(storage: &JacPyCallStorage) -> lin PyCallArgsRef from storage;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_callargs_close(arguments: own PyCallArgsRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_use_small(arguments: &PyCallArgsRef, count: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_allocate(arguments: &PyCallArgsRef, count: i64) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_copy_next(arguments: &PyCallArgsRef, value: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_pending(arguments: &PyCallArgsRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_callargs_discard_next(arguments: &PyCallArgsRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_callargs_release(storage: &JacPyCallStorage, arguments: lin PyCallArgsRef from storage);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_object_array_item(values: &JacPyObjectArray, index: i64) -> &PyObjectRef from values;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_previous_null(tstate: &JacPyThreadState) -> &PyFrameRef from tstate;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_frame_is_null(frame: &PyFrameRef) -> i32;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_callargs_push_frame(tstate: &JacPyThreadState, arguments: &PyCallArgsRef,
        previous: &PyFrameRef, function: lin PyStackRef from previous, locals: own PyObjectRef,
        positional: i64, keywords: &PyObjectRef) -> lin PyFrameRef from (tstate, previous);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_vector_stat();
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_owned_frame(tstate: &JacPyThreadState,
        frame: lin PyFrameRef from tstate, throwflag: i32) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="none", reentrant=True)
def jacpy_callargs_close_impl(storage: &JacPyCallStorage, arguments: lin PyCallArgsRef from storage) {
    while jacpy_callargs_pending(&arguments) > 0 { jacpy_callargs_discard_next(&arguments); }
    jacpy_callargs_release(storage, arguments);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_eval_vector_impl(storage: &JacPyCallStorage, tstate: &JacPyThreadState,
    function: &PyObjectRef, locals: &PyObjectRef, input: &JacPyObjectArray,
    positional: i64, keywords: &PyObjectRef) -> own PyObjectRef {
    total = positional;
    if jacpy_ref_is_null(keywords) == 0 { total = wrapping_add(total, jacpy_eval_tuple_size(keywords)); }
    arguments: lin PyCallArgsRef from storage = jacpy_callargs_begin(storage);
    if total <= 8 {
        jacpy_callargs_use_small(&arguments, total);
    } elif jacpy_callargs_allocate(&arguments, total) == 0 {
        failure: own PyObjectRef = PyErr_NoMemory();
        jacpy_callargs_close(arguments);
        return failure;
    }
    local_owner: own PyObjectRef = jacpy_ref_new(locals);
    index: i64 = 0;
    while index < total {
        jacpy_callargs_copy_next(&arguments, jacpy_object_array_item(input, index));
        index = wrapping_add(index, 1);
    }
    function_owner: lin PyStackRef = jacpy_stack_new(function);
    previous: &PyFrameRef from tstate = jacpy_frame_previous_null(tstate);
    frame: lin PyFrameRef from tstate = jacpy_callargs_push_frame(tstate, &arguments, previous,
        function_owner, local_owner, positional, keywords);
    jacpy_callargs_close(arguments);
    if jacpy_frame_is_null(&frame) != 0 {
        jacpy_frame_close(frame);
        return jacpy_ref_null();
    }
    jacpy_eval_vector_stat();
    return jacpy_eval_owned_frame(tstate, frame, 0);
}

import from jaclang.runtime.python.references { jacpy_stack_close }
import from jaclang.runtime.python.evaluator_support { jacpy_eval_tuple_item }
import from jaclang.runtime.python.evaluator_binding { jacpy_frame_null }

import from c {
    # The pinned private entry consumes locals only once argument preparation
    # reaches frame push. The C caller retains this slot on an earlier error.
    obj JacPyLocalTransferSlot;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_locals_transfer(slot: &JacPyLocalTransferSlot) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_call_dict_size(dictionary: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_callargs_unpack(arguments: &PyCallArgsRef, tstate: &JacPyThreadState,
        values: &PyObjectRef, positional: i64, keywords: &PyObjectRef) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_convert_next(arguments: &PyCallArgsRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_filled(arguments: &PyCallArgsRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_capacity(arguments: &PyCallArgsRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_callargs_keywords(arguments: &PyCallArgsRef) -> &PyObjectRef from arguments;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_frame_push_ex_impl(storage: &JacPyCallStorage, tstate: &JacPyThreadState,
    previous: &PyFrameRef, function: lin PyStackRef from previous,
    locals: &JacPyLocalTransferSlot, positional: i64,
    values: own PyObjectRef, keywords: own PyObjectRef) -> lin PyFrameRef from (tstate, previous) {
    arguments: lin PyCallArgsRef from storage = jacpy_callargs_begin(storage);
    if jacpy_ref_is_null(&keywords) == 0 and jacpy_call_dict_size(&keywords) > 0 {
        if jacpy_callargs_unpack(&arguments, tstate, &values, positional, &keywords) == 0 {
            jacpy_stack_close(function);
            jacpy_callargs_close(arguments);
            jacpy_ref_close(values);
            jacpy_ref_close(keywords);
            return jacpy_frame_null();
        }
        while jacpy_callargs_filled(&arguments) < jacpy_callargs_capacity(&arguments) {
            jacpy_callargs_convert_next(&arguments);
        }
    } else {
        if positional <= 8 {
            jacpy_callargs_use_small(&arguments, positional);
        } elif jacpy_callargs_allocate(&arguments, positional) == 0 {
            failure: own PyObjectRef = PyErr_NoMemory();
            jacpy_ref_close(failure);
            jacpy_stack_close(function);
            jacpy_callargs_close(arguments);
            jacpy_ref_close(values);
            jacpy_ref_close(keywords);
            return jacpy_frame_null();
        }
        index: i64 = 0;
        while index < positional {
            jacpy_callargs_copy_next(&arguments, jacpy_eval_tuple_item(&values, index));
            index = wrapping_add(index, 1);
        }
    }
    local_owner: own PyObjectRef = jacpy_locals_transfer(locals);
    frame: lin PyFrameRef from (tstate, previous) = jacpy_callargs_push_frame(tstate, &arguments,
        previous, function, local_owner, positional, jacpy_callargs_keywords(&arguments));
    jacpy_callargs_close(arguments);
    jacpy_ref_close(values);
    jacpy_ref_close(keywords);
    return frame;
}
