"""Recursion and native-stack policy from CPython 3.14.6 Python/ceval.c.

PSF licensed; see LICENSE.cpython. Addresses here are numeric stack bounds,
not Python object handles. Platform queries and thread fields use the C ABI.
"""
import from jaclang.runtime.python.references { JacPyThreadState }
import from jaclang.runtime.python.evaluator_monitoring {
    JacPyInterpreterState, PyThreadState_Get, jacpy_thread_interpreter
}
import from jaclang.runtime.python.evaluator_errors { JacPyCString }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_threads_close,
                  aliasing="shared", reentrant_drop=False)
obj PyThreadListRef;

import from c {
    obj JacPyStackBounds { has base: u64, top: u64; }
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_threads_begin(interpreter: &JacPyInterpreterState) -> lin PyThreadListRef from interpreter;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_threads_close(threads: own PyThreadListRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_threads_first(threads: &PyThreadListRef) -> &JacPyThreadState from threads;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_threads_next(threads: &PyThreadListRef, thread: &JacPyThreadState) -> &JacPyThreadState from threads;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_is_null(thread: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def _PyEval_StopTheWorld(interpreter: &JacPyInterpreterState);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def _PyEval_StartTheWorld(interpreter: &JacPyInterpreterState);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_recursion_limit(interpreter: &JacPyInterpreterState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_recursion_set_limit(interpreter: &JacPyInterpreterState, limit: i32);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_recursion_limit(thread: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_recursion_remaining(thread: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_thread_recursion_update(thread: &JacPyThreadState, limit: i32, remaining: i32);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_recursion_headroom(thread: &JacPyThreadState) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_recursion_set_headroom(thread: &JacPyThreadState, headroom: i32);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_down() -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_margin() -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_scaled_margin(count: i32) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_minimum() -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_default_size() -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_sanitizer() -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_hardware_stack_bounds(bounds: &mut JacPyStackBounds) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_soft(thread: &JacPyThreadState) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_hard(thread: &JacPyThreadState) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_top(thread: &JacPyThreadState) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_initial_base(thread: &JacPyThreadState) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_initial_top(thread: &JacPyThreadState) -> u64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_publish(thread: &JacPyThreadState, top: u64, hard: u64, soft: u64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_save_initial(thread: &JacPyThreadState, base: u64, top: u64);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def _Py_InitializeRecursionLimits(thread: &JacPyThreadState);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_kbytes(bytes: u64) -> i32;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_fatal(kbytes: i32, where: &JacPyCString);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_unchecked_fatal();
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_python_recursion_fatal();
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_stack_overflow(thread: &JacPyThreadState, kbytes: i32, where: &JacPyCString);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_recursion_overflow(thread: &JacPyThreadState);
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_stack_size_error(minimum: u64);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def Py_GetRecursionLimit() -> i32 { return jacpy_recursion_limit(jacpy_thread_interpreter(PyThreadState_Get())); }

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def Py_SetRecursionLimit(limit: i32) {
    tstate: &JacPyThreadState = PyThreadState_Get();
    interpreter: &JacPyInterpreterState from tstate = jacpy_thread_interpreter(tstate);
    _PyEval_StopTheWorld(interpreter);
    jacpy_recursion_set_limit(interpreter, limit);
    threads: lin PyThreadListRef from interpreter = jacpy_threads_begin(interpreter);
    thread: &JacPyThreadState from threads = jacpy_threads_first(&threads);
    while jacpy_thread_is_null(thread) == 0 {
        depth = wrapping_sub(jacpy_thread_recursion_limit(thread), jacpy_thread_recursion_remaining(thread));
        jacpy_thread_recursion_update(thread, limit, wrapping_sub(limit, depth));
        thread = jacpy_threads_next(&threads, thread);
    }
    jacpy_threads_close(threads);
    _PyEval_StartTheWorld(interpreter);
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_set_stack(thread: &JacPyThreadState, base: u64, top: u64) {
    low = base;
    high = top;
    if jacpy_stack_sanitizer() != 0 {
        half = wrapping_sub(high, low) >> 1;
        if jacpy_stack_down() != 0 { low = wrapping_add(low, half); }
        else { high = wrapping_sub(high, half); }
    }
    margin = jacpy_stack_margin();
    twice = wrapping_mul(margin, u64(2));
    if jacpy_stack_down() != 0 {
        jacpy_stack_publish(thread, high, wrapping_add(low, margin), wrapping_add(low, twice));
    } else {
        jacpy_stack_publish(thread, low, wrapping_sub(high, margin), wrapping_sub(high, twice));
    }
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_initialize_recursion(thread: &JacPyThreadState, bounds: &mut JacPyStackBounds, address: u64) {
    if jacpy_hardware_stack_bounds(bounds) == 0 {
        mask: u64 = 18446744073709547520;
        if jacpy_stack_down() != 0 {
            bounds.top = wrapping_add(wrapping_add(address, u64(64)), u64(4095)) & mask;
            bounds.base = wrapping_sub(bounds.top, jacpy_stack_default_size());
        } else {
            bounds.base = wrapping_sub(address, u64(64)) & mask;
            bounds.top = wrapping_add(bounds.base, jacpy_stack_default_size());
        }
    }
    jacpy_set_stack(thread, bounds.base, bounds.top);
    jacpy_stack_save_initial(thread, bounds.base, bounds.top);
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_set_stack_protection(thread: &JacPyThreadState, base: u64, size: u64) -> i32 {
    if size < jacpy_stack_minimum() {
        jacpy_stack_size_error(jacpy_stack_minimum());
        return -1;
    }
    jacpy_set_stack(thread, base, wrapping_add(base, size));
    return 0;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def PyUnstable_ThreadState_ResetStackProtection(thread: &JacPyThreadState) {
    top = jacpy_stack_initial_top(thread);
    if top != 0 {
        jacpy_set_stack(thread, jacpy_stack_initial_base(thread), top);
    } else { _Py_InitializeRecursionLimits(thread); }
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_reached_recursion_margin(thread: &JacPyThreadState, margin_count: i32, address: u64) -> i32 {
    soft = jacpy_stack_soft(thread);
    margin = jacpy_stack_scaled_margin(margin_count);
    if jacpy_stack_down() != 0 {
        if address > wrapping_add(soft, margin) { return 0; }
    } else {
        if address <= wrapping_sub(soft, margin) { return 0; }
    }
    if jacpy_stack_hard(thread) == 0 { _Py_InitializeRecursionLimits(thread); }
    soft = jacpy_stack_soft(thread);
    twice = wrapping_mul(jacpy_stack_margin(), u64(2));
    if jacpy_stack_down() != 0 {
        if address <= wrapping_add(soft, margin) and address >= wrapping_sub(soft, twice) { return 1; }
    } else {
        if address > wrapping_sub(soft, margin) and address <= wrapping_add(soft, twice) { return 1; }
    }
    return 0;
}

@foreign_call(requires=["gil"], errors="none", reentrant=False)
def jacpy_enter_recursion_unchecked(thread: &JacPyThreadState, address: u64) {
    hard = jacpy_stack_hard(thread);
    if (jacpy_stack_down() != 0 and address < hard) or (jacpy_stack_down() == 0 and address > hard) {
        jacpy_stack_unchecked_fatal();
    }
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def jacpy_check_recursion(thread: &JacPyThreadState, where: &JacPyCString, address: u64) -> i32 {
    down = jacpy_stack_down();
    hard = jacpy_stack_hard(thread);
    used = wrapping_sub(jacpy_stack_top(thread), address);
    if down == 0 { used = wrapping_sub(address, jacpy_stack_top(thread)); }
    if (down != 0 and address < hard) or (down == 0 and address > hard) {
        jacpy_stack_fatal(jacpy_stack_kbytes(used), where);
    }
    if jacpy_recursion_headroom(thread) != 0 { return 0; }
    jacpy_recursion_set_headroom(thread, wrapping_add(jacpy_recursion_headroom(thread), i32(1)));
    jacpy_stack_overflow(thread, jacpy_stack_kbytes(used), where);
    jacpy_recursion_set_headroom(thread, wrapping_sub(jacpy_recursion_headroom(thread), i32(1)));
    return -1;
}

@foreign_call(requires=["gil"], errors="python", reentrant=True)
def _Py_CheckRecursiveCallPy(thread: &JacPyThreadState) -> i32 {
    if jacpy_recursion_headroom(thread) != 0 {
        if jacpy_thread_recursion_remaining(thread) < -50 { jacpy_python_recursion_fatal(); }
    } elif jacpy_thread_recursion_remaining(thread) <= 0 {
        jacpy_recursion_set_headroom(thread, wrapping_add(jacpy_recursion_headroom(thread), i32(1)));
        jacpy_recursion_overflow(thread);
        jacpy_recursion_set_headroom(thread, wrapping_sub(jacpy_recursion_headroom(thread), i32(1)));
        return -1;
    }
    return 0;
}
