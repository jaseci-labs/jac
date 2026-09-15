"""Evaluator support ported from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. These entry points use borrowed Python
objects, preserve CPython exception state, and allocate no Jac resources.
The C boundary exposes object-runtime primitives only.
"""

import from jaclang.runtime.python.references {
    PyObjectRef, JacPyThreadState,
    jacpy_ref_null, jacpy_ref_is_null, jacpy_ref_close, jacpy_ref_new
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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
@foreign_call(requires=["gil"], errors="python", reentrant=True)
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

import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_topmost_exception(tstate: &JacPyThreadState) -> &PyObjectRef from tstate;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_exception_instance_check(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_eval_exception_type_new(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyObject_CallNoArgs(callable: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def _PyErr_SetRaisedException(tstate: &JacPyThreadState, value: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def PyErr_SetObject(exception: &PyObjectRef, value: &PyObjectRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def PyException_SetCause(value: &PyObjectRef, cause: own PyObjectRef);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_runtime_error(tstate: &JacPyThreadState, message: str);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_eval_bad_exception_result(tstate: &JacPyThreadState, factory: &PyObjectRef, result: &PyObjectRef);
}

# CPython Python/ceval.c:2191 (do_raise). The C opcode caller transfers both
# references. A null exception denotes bare raise and requires a null cause.
# Return one only for a successful bare reraise; all other paths return zero
# with CPython's exception state set. Cleanup below follows CPython's order.
@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_eval_raise(tstate: &JacPyThreadState, exception: own PyObjectRef,
                     cause: own PyObjectRef) -> i32 {
    if jacpy_ref_is_null(&exception) != 0 {
        active: &PyObjectRef from tstate = jacpy_eval_topmost_exception(tstate);
        if jacpy_ref_is_null(active) != 0 or jacpy_eval_is_none(active) != 0 {
            jacpy_eval_runtime_error(tstate, "No active exception to reraise");
            return 0;
        }
        raised: own PyObjectRef = jacpy_ref_new(active);
        _PyErr_SetRaisedException(tstate, raised);
        return 1;
    }

    exception_type: own PyObjectRef = jacpy_ref_null();
    value: own PyObjectRef = jacpy_ref_null();
    ready: i64 = 0;
    if jacpy_eval_exception_class_check(&exception) != 0 {
        exception_type = exception;
        value = PyObject_CallNoArgs(&exception_type);
        if jacpy_ref_is_null(&value) == 0 {
            if jacpy_eval_exception_instance_check(&value) != 0 {
                ready = 1;
            } else {
                jacpy_eval_bad_exception_result(tstate, &exception_type, &value);
            }
        }
    } elif jacpy_eval_exception_instance_check(&exception) != 0 {
        value = exception;
        exception_type = jacpy_eval_exception_type_new(&value);
        ready = 1;
    } else {
        # Invalid raise operands are released before installing TypeError.
        jacpy_ref_close(exception);
        jacpy_eval_type_error(tstate, "exceptions must derive from BaseException");
    }

    if ready != 0 and jacpy_ref_is_null(&cause) == 0 {
        fixed_cause: own PyObjectRef = jacpy_ref_null();
        if jacpy_eval_exception_class_check(&cause) != 0 {
            fixed_cause = PyObject_CallNoArgs(&cause);
            if jacpy_ref_is_null(&fixed_cause) != 0 {
                ready = 0;
            } elif jacpy_eval_exception_instance_check(&fixed_cause) == 0 {
                jacpy_eval_bad_exception_result(tstate, &cause, &fixed_cause);
                # Match the early release before value, type, and original cause.
                jacpy_ref_close(fixed_cause);
                fixed_cause = jacpy_ref_null();
                ready = 0;
            } else {
                jacpy_ref_close(cause);
                cause = jacpy_ref_null();
            }
        } elif jacpy_eval_exception_instance_check(&cause) != 0 {
            fixed_cause = cause;
            cause = jacpy_ref_null();
        } elif jacpy_eval_is_none(&cause) != 0 {
            jacpy_ref_close(cause);
            cause = jacpy_ref_null();
        } else {
            jacpy_eval_type_error(tstate, "exception causes must derive from BaseException");
            ready = 0;
        }
        if ready != 0 {
            PyException_SetCause(&value, fixed_cause);
        }
    }
    if ready != 0 {
        # The evaluator requires tstate to be the current attached thread.
        PyErr_SetObject(&exception_type, &value);
    }
    jacpy_ref_close(value);
    jacpy_ref_close(exception_type);
    jacpy_ref_close(cause);
    return 0;
}
