/* Native recursion policy ABI, pinned CPython 3.14.6. PSF licensed. */
#ifndef JAC_EVALUATOR_RECURSION_H
#define JAC_EVALUATOR_RECURSION_H
#include "evaluator_refs.h"
typedef PyInterpreterState *JacPyThreadListRef;
typedef struct { uint64_t base, top; } JacPyStackBounds;
JacPyThreadListRef jacpy_threads_begin(PyInterpreterState *interpreter);
void jacpy_threads_close(JacPyThreadListRef threads);
PyThreadState *jacpy_threads_first(JacPyThreadListRef threads);
PyThreadState *jacpy_threads_next(JacPyThreadListRef threads, PyThreadState *thread);
int32_t jacpy_thread_is_null(PyThreadState *thread);
int32_t jacpy_recursion_limit(PyInterpreterState *interpreter);
void jacpy_recursion_set_limit(PyInterpreterState *interpreter, int32_t limit);
int32_t jacpy_thread_recursion_limit(PyThreadState *thread);
int32_t jacpy_thread_recursion_remaining(PyThreadState *thread);
void jacpy_thread_recursion_update(PyThreadState *thread, int32_t limit, int32_t remaining);
int32_t jacpy_recursion_headroom(PyThreadState *thread);
void jacpy_recursion_set_headroom(PyThreadState *thread, int32_t headroom);
int32_t jacpy_stack_down(void);
uint64_t jacpy_stack_margin(void);
uint64_t jacpy_stack_scaled_margin(int32_t count);
uint64_t jacpy_stack_minimum(void);
uint64_t jacpy_stack_default_size(void);
int32_t jacpy_stack_sanitizer(void);
int32_t jacpy_hardware_stack_bounds(JacPyStackBounds *bounds);
uint64_t jacpy_stack_soft(PyThreadState *thread);
uint64_t jacpy_stack_hard(PyThreadState *thread);
uint64_t jacpy_stack_top(PyThreadState *thread);
uint64_t jacpy_stack_initial_base(PyThreadState *thread);
uint64_t jacpy_stack_initial_top(PyThreadState *thread);
void jacpy_stack_publish(PyThreadState *thread, uint64_t top, uint64_t hard, uint64_t soft);
void jacpy_stack_save_initial(PyThreadState *thread, uint64_t base, uint64_t top);
int32_t jacpy_stack_kbytes(uint64_t bytes);
void jacpy_stack_fatal(int32_t kbytes, const char *where);
void jacpy_stack_unchecked_fatal(void);
void jacpy_python_recursion_fatal(void);
void jacpy_stack_overflow(PyThreadState *thread, int32_t kbytes, const char *where);
void jacpy_recursion_overflow(PyThreadState *thread);
void jacpy_stack_size_error(uint64_t minimum);
#endif
