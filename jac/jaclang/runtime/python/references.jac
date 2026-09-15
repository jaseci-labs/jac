"""Typed reference boundary for the native CPython evaluator.

Compile with the nogc profile. These opaque owners hold CPython references,
not Jac allocations. Shared borrows protect that reference's lifetime without
claiming exclusive or immutable access to the Python object. Object operations
may reenter Python; frame/container borrows need their own owner across such
calls. A borrowed mortal stack reference requires promotion before suspension.

The C declarations are the trusted ABI in bootstrap/python/evaluator_refs.h.
The object-borrow result is tied to the stack owner passed to it. A raw frame
borrow must not be relabeled as an independent owner. All operations require
the GIL. Object null and stack null have different representations, so test
them through the relevant ABI.
"""

@foreign_resource(abi="pointer", empty=0, drop=jacpy_ref_close,
                  aliasing="shared", reentrant_drop=True)
obj PyObjectRef;

@foreign_resource(abi="word", empty=1, drop=jacpy_stack_close,
                  aliasing="shared", reentrant_drop=True)
obj PyStackRef;

import from c {
    obj JacPyThreadState;

    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_ref_null -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_ref_is_null(value: &PyObjectRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_ref_new(value: &PyObjectRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_ref_close(value: own PyObjectRef);

    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_null -> own PyStackRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_is_null(value: &PyStackRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_is_heap_safe(value: &PyStackRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_is_int(value: &PyStackRef) -> i64;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_new(value: &PyObjectRef) -> own PyStackRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_steal(value: own PyObjectRef) -> own PyStackRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_dup(value: &PyStackRef) -> own PyStackRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_stack_promote(value: &PyStackRef) -> own PyStackRef;

    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_stack_object_borrow(value: &PyStackRef) -> &PyObjectRef from value;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_stack_object_new(value: &PyStackRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="python", reentrant=True)
    def jacpy_stack_object_steal(value: own PyStackRef) -> own PyObjectRef;
    @foreign_call(requires=["gil"], errors="none", reentrant=True)
    def jacpy_stack_close(value: own PyStackRef);
}
