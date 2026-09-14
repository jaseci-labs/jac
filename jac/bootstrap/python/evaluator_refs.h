/* Trusted reference boundary for the native Jac evaluator.
 *
 * CPython 3.14.6, GIL, non-debug stack references only. All operations require
 * the GIL. The opaque stack word carries the exact _PyStackRef bits; it is
 * never dereferenced, allocated, traced, or reference-counted by Jac.
 *
 * A new/duplicate/promote result owns a CPython reference (or an immortal,
 * tagged integer, or null). Steal consumes its input. Borrowed arguments
 * remain live for the whole call. A frame borrow needs promotion before the
 * frame can clear/unwind/suspend or another operation can invalidate its slot.
 * DUP alone does not promote a tagged mortal borrow.
 *
 * close/clear can execute arbitrary Python and resurrect objects. Publish the
 * replacement/null in every visible owner before invoking them. In particular
 * do not hold an unprotected frame/container borrow across a reentrant call.
 * CPython exception state is preserved by these reference operations.
 * The primitives never set or consume a Jac exception slot. Object callbacks
 * follow CPython's result/error protocol, including reentrant callbacks.
 */
#ifndef JAC_EVALUATOR_REFS_H
#define JAC_EVALUATOR_REFS_H

#include <Python.h>
#include <stdint.h>

#if PY_VERSION_HEX != 0x030e06f0
#error "Jac evaluator references require pinned CPython 3.14.6"
#endif
#if defined(Py_DEBUG) || defined(Py_STACKREF_DEBUG) || defined(Py_GIL_DISABLED)
#error "Jac evaluator references require a non-debug GIL build"
#endif
#if UINTPTR_MAX != UINT64_MAX
#error "Jac evaluator references require a 64-bit target"
#endif

typedef PyObject *JacPyObjectRef;
typedef uint64_t JacPyStackRef;

JacPyObjectRef jacpy_ref_null(void);
JacPyObjectRef jacpy_ref_new(JacPyObjectRef value);
int64_t jacpy_ref_is_null(JacPyObjectRef value);
void jacpy_ref_close(JacPyObjectRef value);
void jacpy_ref_clear(JacPyObjectRef *slot);

JacPyStackRef jacpy_stack_null(void);
int64_t jacpy_stack_is_null(JacPyStackRef value);
int64_t jacpy_stack_is_heap_safe(JacPyStackRef value);
int64_t jacpy_stack_is_int(JacPyStackRef value);
JacPyStackRef jacpy_stack_new(JacPyObjectRef value);
JacPyStackRef jacpy_stack_steal(JacPyObjectRef value);
/* Only duplicate an already heap-safe owner. Use promote for a frame borrow. */
JacPyStackRef jacpy_stack_dup(JacPyStackRef value);
/* The borrowed source remains valid; the result is independently heap-safe. */
JacPyStackRef jacpy_stack_promote(JacPyStackRef value);
JacPyObjectRef jacpy_stack_object_new(JacPyStackRef value);
/* Borrow is tied to value's owner and must end before that owner is consumed.
 * Tagged integers have no object to borrow: return NULL and set TypeError.
 */
JacPyObjectRef jacpy_stack_object_borrow(JacPyStackRef value);
JacPyObjectRef jacpy_stack_object_steal(JacPyStackRef value);
void jacpy_stack_close(JacPyStackRef value);
void jacpy_stack_clear(JacPyStackRef *slot);

/* These borrow the object and may execute __index__ / set a Python exception.
 * as_ssize clips overflow exactly as PyNumber_AsSsize_t(value, NULL) specifies.
 */
int64_t jacpy_eval_is_none(JacPyObjectRef value);
int64_t jacpy_eval_index_check(JacPyObjectRef value);
int64_t jacpy_as_ssize(JacPyObjectRef value);
int64_t jacpy_eval_error_pending(void);
void jacpy_type_error(const char *message);

int64_t jacpy_coro_check(JacPyObjectRef value);
int64_t jacpy_has_await(JacPyObjectRef value);
/* Requires an exact coroutine, returns a new reference to its current yield. */
JacPyObjectRef jacpy_gen_yieldfrom(JacPyObjectRef value);
int64_t jacpy_asyncgen_check(JacPyObjectRef value);
int64_t jacpy_has_anext(JacPyObjectRef value);
/* Requires a non-null am_anext slot, returns its new reference/error result. */
JacPyObjectRef jacpy_anext_call(JacPyObjectRef value);
/* The trusted message has one %s conversion for the object's type name. */
void jacpy_type_error_for_object(const char *message, JacPyObjectRef value);
void jacpy_type_error_from_cause(const char *message, JacPyObjectRef value);
void jacpy_runtime_error(const char *message);

int64_t jacpy_eval_tuple_check(JacPyObjectRef value);
int64_t jacpy_eval_tuple_size(JacPyObjectRef value);
/* The tuple must remain alive; tuples own their immutable element slots. */
JacPyObjectRef jacpy_eval_tuple_item(JacPyObjectRef value, int64_t index);
int64_t jacpy_eval_exception_class_check(JacPyObjectRef value);
int64_t jacpy_eval_exception_group_subclass(JacPyObjectRef value);
void jacpy_eval_type_error(PyThreadState *tstate, const char *message);

#endif
