"""Iterable unpacking from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. The result stack owns pushed references.
Failure cleanup runs from its current top before releasing the iterator.
"""
import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState, jacpy_ref_is_null, jacpy_ref_close
}
import from jaclang.runtime.python.evaluator_support {
    jacpy_eval_error_pending, jacpy_type_error_for_object
}
import from jaclang.runtime.python.evaluator_errors {
    jacpy_object_has_iter, PySequence_Check, PyErr_ExceptionMatches, jacpy_exception_type
}
import from jaclang.runtime.python.evaluator_arguments { jacpy_list_size }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_unpack_close,
                  aliasing="shared", reentrant_drop=True)
obj PyUnpackRef;

import from c {
    obj JacPyUnpackStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_unpack_close(stack: own PyUnpackRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_pending(stack: &PyUnpackRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_unpack_discard(stack: &PyUnpackRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_commit(storage: &JacPyUnpackStorage, stack: lin PyUnpackRef from storage);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_finish_error(storage: &JacPyUnpackStorage, stack: lin PyUnpackRef from storage);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_push(stack: &PyUnpackRef, value: own PyObjectRef) -> &PyObjectRef from stack;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_list_item(stack: &PyUnpackRef, values: &PyObjectRef, index: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_shrink_list(values: &PyObjectRef, count: i64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_unpack_exact_size(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_unpack_error(tstate: &JacPyThreadState, format: str, expected: i32, actual: i64);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_GetIter(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyIter_Next(iterator: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PySequence_List(value: &PyObjectRef) -> own PyObjectRef;
}

@foreign_call(requires=["gil"], errors="none", reentrant=True)
def jacpy_unpack_close_impl(storage: &JacPyUnpackStorage, stack: lin PyUnpackRef from storage) {
    while jacpy_unpack_pending(&stack) > 0 { jacpy_unpack_discard(&stack); }
    jacpy_unpack_finish_error(storage, stack);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_unpack_iterable(storage: &JacPyUnpackStorage, stack: lin PyUnpackRef from storage,
    tstate: &JacPyThreadState, value: &PyObjectRef, before: i32, after: i32) -> i32 {
    iterator: own PyObjectRef = PyObject_GetIter(value);
    if jacpy_ref_is_null(&iterator) != 0 {
        if PyErr_ExceptionMatches(jacpy_exception_type(tstate, 0)) != 0
            and jacpy_object_has_iter(value) == 0 and PySequence_Check(value) == 0 {
            jacpy_type_error_for_object("cannot unpack non-iterable %.200s object", value);
        }
        jacpy_unpack_close(stack);
        jacpy_ref_close(iterator);
        return 0;
    }
    status = jacpy_unpack_body(&stack, tstate, value, &iterator, before, after);
    if status == 0 { jacpy_unpack_close(stack); }
    else { jacpy_unpack_commit(storage, stack); }
    jacpy_ref_close(iterator);
    return status;
}

# Between moving list tail entries and reducing the list size, no operation
# may fail or reenter Python. This checked helper keeps that interval explicit.
@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_unpack_tail(stack: &PyUnpackRef, values: &PyObjectRef, size: i64, count: i64) {
    remaining = count;
    while remaining > 0 {
        jacpy_unpack_list_item(stack, values, wrapping_sub(size, remaining));
        remaining = wrapping_sub(remaining, 1);
    }
    jacpy_unpack_shrink_list(values, wrapping_sub(size, count));
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_unpack_body(stack: &PyUnpackRef, tstate: &JacPyThreadState,
    value: &PyObjectRef, iterator: &PyObjectRef, before: i32, after: i32) -> i32 {
    index: i32 = 0;
    while index < before {
        item: own PyObjectRef = PyIter_Next(iterator);
        if jacpy_ref_is_null(&item) != 0 {
            if jacpy_eval_error_pending() == 0 {
                if after == -1 {
                    jacpy_unpack_error(tstate, "not enough values to unpack (expected %d, got %zd)", before, i64(index));
                } else {
                    jacpy_unpack_error(tstate, "not enough values to unpack (expected at least %d, got %zd)",
                        wrapping_add(before, after), i64(index));
                }
            }
            return 0;
        }
        jacpy_unpack_push(stack, item);
        index = wrapping_add(index, i32(1));
    }
    if after == -1 {
        extra: own PyObjectRef = PyIter_Next(iterator);
        if jacpy_ref_is_null(&extra) != 0 {
            if jacpy_eval_error_pending() != 0 { return 0; }
            return 1;
        }
        jacpy_ref_close(extra);
        size = jacpy_unpack_exact_size(value);
        if size > i64(before) {
            jacpy_unpack_error(tstate, "too many values to unpack (expected %d, got %zd)", before, size);
        } else {
            jacpy_unpack_error(tstate, "too many values to unpack (expected %d)", before, 0);
        }
        return 0;
    }
    rest: own PyObjectRef = PySequence_List(iterator);
    if jacpy_ref_is_null(&rest) != 0 { return 0; }
    values: &PyObjectRef from stack = jacpy_unpack_push(stack, rest);
    size = jacpy_list_size(values);
    if size < i64(after) {
        jacpy_unpack_error(tstate, "not enough values to unpack (expected at least %d, got %zd)",
            wrapping_add(before, after), wrapping_add(i64(before), size));
        return 0;
    }
    jacpy_unpack_tail(stack, values, size, i64(after));
    return 1;
}
