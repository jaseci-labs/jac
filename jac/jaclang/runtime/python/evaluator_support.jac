"""Evaluator support ported from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. These entry points use borrowed Python
objects, preserve CPython exception state, and allocate no Jac resources.
The C boundary exposes object-runtime primitives only.
"""

import from jaclang.runtime.python.references {
    PyObjectRef, jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_close
}

import from c {
    obj JacPySsizeSlot { has value: i64; }
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_is_none(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_index_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_as_ssize(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_error_pending -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_type_error(message: str);
}

# CPython Python/ceval.c:3073 (_PyEval_SliceIndex).
def _PyEval_SliceIndex(value: &PyObjectRef, result: &mut JacPySsizeSlot) -> i32 {
    if jacpy_eval_is_none(value) == 0 {
        if jacpy_eval_index_check(value) == 0 {
            jacpy_type_error(
                "slice indices must be integers or None or have an __index__ method"
            );
            return 0;
        }
        index = jacpy_as_ssize(value);
        if index == -1 and jacpy_eval_error_pending() != 0 {
            return 0;
        }
        result.value = index;
    }
    return 1;
}

# CPython Python/ceval.c:3095 (_PyEval_SliceIndexNotNone).
def _PyEval_SliceIndexNotNone(value: &PyObjectRef, result: &mut JacPySsizeSlot) -> i32 {
    if jacpy_eval_index_check(value) == 0 {
        jacpy_type_error("slice indices must be integers or have an __index__ method");
        return 0;
    }
    index = jacpy_as_ssize(value);
    if index == -1 and jacpy_eval_error_pending() != 0 {
        return 0;
    }
    result.value = index;
    return 1;
}

import from c {
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyCoro_GetAwaitableIter(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_coro_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_has_await(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_gen_yieldfrom(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_type_error_for_object(message: str, value: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_runtime_error(message: str);
}

# CPython Python/ceval.c:3641 (_PyEval_GetAwaitable).
def _PyEval_GetAwaitable(iterable: &PyObjectRef, oparg: i32) -> own PyObjectRef {
    iterator: own PyObjectRef = _PyCoro_GetAwaitableIter(iterable);
    if jacpy_ref_is_null(&iterator) != 0 {
        if jacpy_has_await(iterable) == 0 {
            if oparg == 1 {
                jacpy_type_error_for_object(
                    "'async with' received an object from __aenter__ that does not implement __await__: %.100s",
                    iterable
                );
            } elif oparg == 2 {
                jacpy_type_error_for_object(
                    "'async with' received an object from __aexit__ that does not implement __await__: %.100s",
                    iterable
                );
            }
        }
    } elif jacpy_coro_check(&iterator) != 0 {
        yielded: own PyObjectRef = jacpy_gen_yieldfrom(&iterator);
        if jacpy_ref_is_null(&yielded) == 0 {
            jacpy_ref_close(yielded);
            iterator = jacpy_ref_null();
            jacpy_runtime_error("coroutine is being awaited already");
        }
    }
    return iterator;
}

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_asyncgen_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_has_anext(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_anext_call(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_type_error_from_cause(message: str, value: &PyObjectRef);
}

# CPython Python/ceval.c:3562 (_PyEval_GetANext).
def _PyEval_GetANext(iterator: &PyObjectRef) -> own PyObjectRef {
    if jacpy_asyncgen_check(iterator) != 0 {
        return jacpy_anext_call(iterator);
    }
    if jacpy_has_anext(iterator) == 0 {
        jacpy_type_error_for_object(
            "'async for' requires an iterator with __anext__ method, got %.100s",
            iterator
        );
        return jacpy_ref_null();
    }
    next_iterator: own PyObjectRef = jacpy_anext_call(iterator);
    if jacpy_ref_is_null(&next_iterator) != 0 {
        return next_iterator;
    }
    awaitable: own PyObjectRef = _PyCoro_GetAwaitableIter(&next_iterator);
    if jacpy_ref_is_null(&awaitable) != 0 {
        jacpy_type_error_from_cause(
            "'async for' received an invalid object from __anext__: %.100s",
            &next_iterator
        );
    }
    jacpy_ref_close(next_iterator);
    return awaitable;
}

import from c {
    obj JacPyThreadState;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_tuple_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_tuple_size(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_tuple_item(value: &PyObjectRef, index: i64) -> &PyObjectRef from value;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_exception_class_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_exception_group_subclass(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_type_error(tstate: &JacPyThreadState, message: str);
}

# CPython Python/ceval.c:3328 (_PyEval_CheckExceptTypeValid).
def _PyEval_CheckExceptTypeValid(tstate: &JacPyThreadState, right: &PyObjectRef) -> i32 {
    if jacpy_eval_tuple_check(right) != 0 {
        length = jacpy_eval_tuple_size(right);
        index: i64 = 0;
        while index < length {
            exception: &PyObjectRef from right = jacpy_eval_tuple_item(right, index);
            if jacpy_eval_exception_class_check(exception) == 0 {
                jacpy_eval_type_error(tstate,
                    "catching classes that do not inherit from BaseException is not allowed");
                return -1;
            }
            # 0 <= index < length <= PY_SSIZE_T_MAX proves this cannot wrap.
            index = wrapping_add(index, 1);
        }
    } elif jacpy_eval_exception_class_check(right) == 0 {
        jacpy_eval_type_error(tstate,
            "catching classes that do not inherit from BaseException is not allowed");
        return -1;
    }
    return 0;
}

# CPython Python/ceval.c:3353 (_PyEval_CheckExceptStarTypeValid).
def _PyEval_CheckExceptStarTypeValid(tstate: &JacPyThreadState, right: &PyObjectRef) -> i32 {
    # Complete ordinary validation before checking any ExceptionGroup entries.
    # This preserves which error wins for a tuple containing both kinds.
    if jacpy_eval_tuple_check(right) != 0 {
        length = jacpy_eval_tuple_size(right);
        index: i64 = 0;
        while index < length {
            exception: &PyObjectRef from right = jacpy_eval_tuple_item(right, index);
            if jacpy_eval_exception_class_check(exception) == 0 {
                jacpy_eval_type_error(tstate,
                    "catching classes that do not inherit from BaseException is not allowed");
                return -1;
            }
            # Bounded by tuple length, so the increment cannot overflow.
            index = wrapping_add(index, 1);
        }
    } elif jacpy_eval_exception_class_check(right) == 0 {
        jacpy_eval_type_error(tstate,
            "catching classes that do not inherit from BaseException is not allowed");
        return -1;
    }
    subclass: i64 = 0;
    if jacpy_eval_tuple_check(right) != 0 {
        length = jacpy_eval_tuple_size(right);
        index: i64 = 0;
        while index < length {
            exception: &PyObjectRef from right = jacpy_eval_tuple_item(right, index);
            subclass = jacpy_eval_exception_group_subclass(exception);
            if subclass < 0 { return -1; }
            if subclass != 0 { break; }
            index = wrapping_add(index, 1);
        }
    } else {
        subclass = jacpy_eval_exception_group_subclass(right);
        if subclass < 0 { return -1; }
    }
    if subclass != 0 {
        jacpy_eval_type_error(tstate,
            "catching ExceptionGroup with except* is not allowed. Use except instead.");
        return -1;
    }
    return 0;
}
