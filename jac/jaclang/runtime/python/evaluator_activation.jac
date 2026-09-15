"""Ownership boundary for a native evaluator activation.

The caller allocates stable C storage. A linear handle owns its active frame
chain and the reference-transfer obligations held in typed scratch slots.
The C expressions preserve CPython's slot protocol; Jac checks the aggregate
cannot be copied, implicitly dropped, or detached from its storage/thread.
This aggregate contract does not claim per-slot lifetime proof by Jac.
"""
import from jaclang.runtime.python.references { JacPyThreadState }
import from jaclang.runtime.python.evaluator_frames { PyFrameRef }
import from jaclang.runtime.python.evaluator_monitoring { JacPyCodeUnit }

@foreign_resource(abi="pointer", empty=0, drop=jacpy_vm_invalid_drop,
                  aliasing="shared", reentrant_drop=False)
obj PyVMRef;

import from c {
    obj JacPyVMStorage;
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_vm_invalid_drop(vm: own PyVMRef);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_vm_begin(storage: &JacPyVMStorage, tstate: &JacPyThreadState,
        frame: lin PyFrameRef from (storage, tstate)) -> lin PyVMRef from (storage, tstate);
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_vm_begin_error(storage: &JacPyVMStorage, tstate: &JacPyThreadState,
        frame: lin PyFrameRef from (storage, tstate), instruction: &JacPyCodeUnit from frame)
        -> lin PyVMRef from (storage, tstate);
}

# A JIT stencil lends its activation to one native uop. Consuming this linear
# permission publishes a continuation to the caller's storage; the trampoline
# regains the activation only after the native body returns. It cannot escape.
@foreign_resource(abi="pointer", empty=0, drop=jacpy_jit_step_invalid_drop,
                  aliasing="shared", reentrant_drop=False)
obj PyJITStepRef;
import from c {
    @foreign_call(requires=["gil"], errors="none", reentrant=False)
    def jacpy_jit_step_invalid_drop(step: own PyJITStepRef);
}
