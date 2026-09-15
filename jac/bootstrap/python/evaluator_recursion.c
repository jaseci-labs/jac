/* Platform stack queries and thread-field adapters for native Jac policy.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_recursion.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_interp.h"
#include "internal/pycore_obmalloc.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_pyerrors.h"
#include "internal/pycore_pythonrun.h"
#include "internal/pycore_runtime.h"

_Static_assert(sizeof(void *) == 8 && SYSTEM_PAGE_SIZE == 4096, "pinned stack fallback alignment");

#if defined(__s390x__)
#  define Py_C_STACK_SIZE 320000
#elif defined(_WIN32)
   // Don't define Py_C_STACK_SIZE, ask the O/S
#elif defined(__ANDROID__)
#  define Py_C_STACK_SIZE 1200000
#elif defined(__sparc__)
#  define Py_C_STACK_SIZE 1600000
#elif defined(__hppa__) || defined(__powerpc64__)
#  define Py_C_STACK_SIZE 2000000
#else
#  define Py_C_STACK_SIZE 4000000
#endif

#if defined(__EMSCRIPTEN__)

// Temporary workaround to make `pthread_getattr_np` work on Emscripten.
// Emscripten 4.0.6 will contain a fix:
// https://github.com/emscripten-core/emscripten/pull/23887

#include "emscripten/stack.h"

#define pthread_attr_t workaround_pthread_attr_t
#define pthread_getattr_np workaround_pthread_getattr_np
#define pthread_attr_getguardsize workaround_pthread_attr_getguardsize
#define pthread_attr_getstack workaround_pthread_attr_getstack
#define pthread_attr_destroy workaround_pthread_attr_destroy

typedef struct {
    void *_a_stackaddr;
    size_t _a_stacksize, _a_guardsize;
} pthread_attr_t;

extern __attribute__((__visibility__("hidden"))) unsigned __default_guardsize;

// Modified version of pthread_getattr_np from the upstream PR.

int pthread_getattr_np(pthread_t thread, pthread_attr_t *attr) {
  attr->_a_stackaddr = (void*)emscripten_stack_get_base();
  attr->_a_stacksize = emscripten_stack_get_base() - emscripten_stack_get_end();
  attr->_a_guardsize = __default_guardsize;
  return 0;
}

// These three functions copied without any changes from Emscripten libc.

int pthread_attr_getguardsize(const pthread_attr_t *restrict a, size_t *restrict size)
{
	*size = a->_a_guardsize;
	return 0;
}

int pthread_attr_getstack(const pthread_attr_t *restrict a, void **restrict addr, size_t *restrict size)
{
/// XXX musl is not standard-conforming? It should not report EINVAL if _a_stackaddr is zero, and it should
///     report EINVAL if a is null: http://pubs.opengroup.org/onlinepubs/009695399/functions/pthread_attr_getstack.html
	if (!a) return EINVAL;
//	if (!a->_a_stackaddr)
//		return EINVAL;

	*size = a->_a_stacksize;
	*addr = (void *)(a->_a_stackaddr - *size);
	return 0;
}

int pthread_attr_destroy(pthread_attr_t *a)
{
	return 0;
}

#endif

int32_t jacpy_hardware_stack_bounds(JacPyStackBounds *bounds) {
#ifdef WIN32
    ULONG_PTR low, high;
    GetCurrentThreadStackLimits(&low, &high);
    ULONG guarantee = 0;
    SetThreadStackGuarantee(&guarantee);
    bounds->top = (uintptr_t)high;
    bounds->base = (uintptr_t)low + guarantee;
    return 1;
#elif defined(__APPLE__)
    pthread_t thread = pthread_self();
    void *address = pthread_get_stackaddr_np(thread);
    size_t size = pthread_get_stacksize_np(thread);
    bounds->top = (uintptr_t)address;
    bounds->base = (uintptr_t)address - size;
    return 1;
#else
#  if defined(HAVE_PTHREAD_GETATTR_NP) && !defined(_AIX) && \
        !defined(__NetBSD__) && (defined(__GLIBC__) || !defined(__linux__))
    size_t size, guard;
    void *address;
    pthread_attr_t attributes;
    int error = pthread_getattr_np(pthread_self(), &attributes);
    if (error == 0) {
        error = pthread_attr_getguardsize(&attributes, &guard);
        error |= pthread_attr_getstack(&attributes, &address, &size);
        error |= pthread_attr_destroy(&attributes);
    }
    if (error == 0) {
        bounds->base = (uintptr_t)address + guard;
        bounds->top = (uintptr_t)address + size;
        return 1;
    }
#  endif
    return 0;
#endif
}
JacPyThreadListRef jacpy_threads_begin(PyInterpreterState *interpreter) {
    HEAD_LOCK(interpreter->runtime);
    return interpreter;
}
void jacpy_threads_close(JacPyThreadListRef threads) {
    if (threads != NULL) { HEAD_UNLOCK(threads->runtime); }
}
PyThreadState *jacpy_threads_first(JacPyThreadListRef threads) { return threads->threads.head; }
PyThreadState *jacpy_threads_next(JacPyThreadListRef threads, PyThreadState *thread) {
    (void)threads;
    return thread->next;
}
int32_t jacpy_thread_is_null(PyThreadState *thread) { return thread == NULL; }
int32_t jacpy_recursion_limit(PyInterpreterState *interpreter) { return interpreter->ceval.recursion_limit; }
void jacpy_recursion_set_limit(PyInterpreterState *interpreter, int32_t limit) { interpreter->ceval.recursion_limit = limit; }
int32_t jacpy_thread_recursion_limit(PyThreadState *thread) { return thread->py_recursion_limit; }
int32_t jacpy_thread_recursion_remaining(PyThreadState *thread) { return thread->py_recursion_remaining; }
void jacpy_thread_recursion_update(PyThreadState *thread, int32_t limit, int32_t remaining) {
    thread->py_recursion_limit = limit;
    thread->py_recursion_remaining = remaining;
}
int32_t jacpy_recursion_headroom(PyThreadState *thread) { return thread->recursion_headroom; }
void jacpy_recursion_set_headroom(PyThreadState *thread, int32_t headroom) { thread->recursion_headroom = headroom; }
int32_t jacpy_stack_down(void) { return _Py_STACK_GROWS_DOWN; }
uint64_t jacpy_stack_margin(void) { return _PyOS_STACK_MARGIN_BYTES; }
uint64_t jacpy_stack_scaled_margin(int32_t count) { return count * _PyOS_STACK_MARGIN_BYTES; }
uint64_t jacpy_stack_minimum(void) { return _PyOS_MIN_STACK_SIZE; }
uint64_t jacpy_stack_default_size(void) {
#ifdef Py_C_STACK_SIZE
    return Py_C_STACK_SIZE;
#else
    return 0;  /* Windows always supplies OS bounds. */
#endif
}
int32_t jacpy_stack_sanitizer(void) {
#ifdef _Py_THREAD_SANITIZER
    return 1;
#else
    return 0;
#endif
}
uint64_t jacpy_stack_soft(PyThreadState *thread) { return ((_PyThreadStateImpl *)thread)->c_stack_soft_limit; }
uint64_t jacpy_stack_hard(PyThreadState *thread) { return ((_PyThreadStateImpl *)thread)->c_stack_hard_limit; }
uint64_t jacpy_stack_top(PyThreadState *thread) { return ((_PyThreadStateImpl *)thread)->c_stack_top; }
uint64_t jacpy_stack_initial_base(PyThreadState *thread) { return ((_PyThreadStateImpl *)thread)->c_stack_init_base; }
uint64_t jacpy_stack_initial_top(PyThreadState *thread) { return ((_PyThreadStateImpl *)thread)->c_stack_init_top; }
void jacpy_stack_publish(PyThreadState *thread, uint64_t top, uint64_t hard, uint64_t soft) {
    _PyThreadStateImpl *state = (_PyThreadStateImpl *)thread;
    state->c_stack_top = top;
    state->c_stack_hard_limit = hard;
    state->c_stack_soft_limit = soft;
}
void jacpy_stack_save_initial(PyThreadState *thread, uint64_t base, uint64_t top) {
    _PyThreadStateImpl *state = (_PyThreadStateImpl *)thread;
    state->c_stack_init_base = base;
    state->c_stack_init_top = top;
}
/* Preserve C's signed narrowing before division when formatting stack usage. */
int32_t jacpy_stack_kbytes(uint64_t bytes) { return (int)bytes / 1024; }
void jacpy_stack_fatal(int32_t kbytes, const char *where) {
    char buffer[80];
    snprintf(buffer, sizeof(buffer), "Unrecoverable stack overflow (used %d kB)%s", (int)kbytes, where);
    _Py_FatalErrorFunc("_Py_CheckRecursiveCall", buffer);
}
void jacpy_stack_unchecked_fatal(void) {
    _Py_FatalErrorFunc("_Py_EnterRecursiveCallUnchecked", "Unchecked stack overflow.");
}
void jacpy_python_recursion_fatal(void) {
    _Py_FatalErrorFunc("_Py_CheckRecursiveCallPy", "Cannot recover from Python stack overflow.");
}
void jacpy_stack_overflow(PyThreadState *thread, int32_t kbytes, const char *where) {
    _PyErr_Format(thread, PyExc_RecursionError, "Stack overflow (used %d kB)%s", (int)kbytes, where);
}
void jacpy_recursion_overflow(PyThreadState *thread) {
    _PyErr_Format(thread, PyExc_RecursionError, "maximum recursion depth exceeded");
}
void jacpy_stack_size_error(uint64_t minimum) {
    PyErr_Format(PyExc_ValueError, "stack_size must be at least %zu bytes", (size_t)minimum);
}

extern void jacpy_initialize_recursion(PyThreadState *, JacPyStackBounds *, uint64_t);
extern int32_t jacpy_set_stack_protection(PyThreadState *, uint64_t, uint64_t);
extern int32_t jacpy_reached_recursion_margin(PyThreadState *, int32_t, uint64_t);
extern void jacpy_enter_recursion_unchecked(PyThreadState *, uint64_t);
extern int32_t jacpy_check_recursion(PyThreadState *, const char *, uint64_t);
/* Capture the machine address at the C entry, before entering the native
 * helper. No address of a native Jac local becomes a reference owner.
 */
void _Py_InitializeRecursionLimits(PyThreadState *thread) {
    uintptr_t address = _Py_get_machine_stack_pointer();
    JacPyStackBounds bounds = {0};
    jacpy_initialize_recursion(thread, &bounds, address);
}
int PyUnstable_ThreadState_SetStackProtection(PyThreadState *thread, void *start, size_t size) {
    return jacpy_set_stack_protection(thread, (uintptr_t)start, size);
}
int _Py_ReachedRecursionLimitWithMargin(PyThreadState *thread, int margin) {
    return jacpy_reached_recursion_margin(thread, margin, _Py_get_machine_stack_pointer());
}
void _Py_EnterRecursiveCallUnchecked(PyThreadState *thread) {
    jacpy_enter_recursion_unchecked(thread, _Py_get_machine_stack_pointer());
}
int _Py_CheckRecursiveCall(PyThreadState *thread, const char *where) {
    return jacpy_check_recursion(thread, where, _Py_get_machine_stack_pointer());
}
int Py_EnterRecursiveCall(const char *where) { return _Py_EnterRecursiveCall(where); }
void Py_LeaveRecursiveCall(void) { _Py_LeaveRecursiveCall(); }
