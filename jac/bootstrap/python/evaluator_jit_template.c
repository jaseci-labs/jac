/* CPython JIT patch-point ABI for a native Jac uop.
 * CPython 3.14.6, PSF licensed; see runtime/python/LICENSE.cpython.
 * There is no instruction body here: the native body returns a continuation.
 * link_jit.py inlines that body and its ABI expressions into this stencil.
 */
#include "evaluator_activation.h"
#include "jit.h"

extern int32_t JAC_NATIVE_STEP(JacPyVMStorage *, PyThreadState *, JacPyVMRef);
#include "evaluator_jit_abi.c"

__attribute__((preserve_none)) _Py_CODEUNIT *
_JIT_ENTRY(_PyInterpreterFrame *frame, _PyStackRef *stack_pointer, PyThreadState *tstate)
{
    PATCH_VALUE(_PyExecutorObject *, executor, _JIT_EXECUTOR)
    PATCH_VALUE(uint16_t, argument, _JIT_OPARG)
    PATCH_VALUE(uint64_t, operand0, _JIT_OPERAND0)
    PATCH_VALUE(uint64_t, operand1, _JIT_OPERAND1)
    PATCH_VALUE(uint32_t, target, _JIT_TARGET)
    JacPyVMStorage storage;
    JacPyVMRef vm = &storage.vm;
    vm->frame = frame;
    vm->stack_pointer = stack_pointer;
    vm->tstate = tstate;
    vm->next_instr = NULL;
    vm->oparg = 0;
    vm->opcode = 0;
    vm->lastopcode = 0;
    vm->next_uop = NULL;
    vm->current_executor = executor;
    vm->uopcode = _JIT_OPCODE;
    vm->lastuop = 0;
    vm->trace_uop_execution_counter = 0;
    vm->_oparg = argument;
    vm->_operand0 = operand0;
    vm->_operand1 = operand1;
    vm->_target = target;
    OPT_STAT_INC(uops_executed);
    UOP_STAT_INC(_JIT_OPCODE, execution_count);

    /* The caller lends the activation to the native body for one uop. The
     * linear step permission is consumed before these fields are read again.
     */
    int32_t continuation = JAC_NATIVE_STEP(&storage, tstate, vm);
    frame = vm->frame;
    stack_pointer = vm->stack_pointer;
    tstate = vm->tstate;
    switch (continuation) {
        case 0: {
            PATCH_VALUE(jit_func_preserve_none, next, _JIT_CONTINUE)
            __attribute__((musttail)) return next(frame, stack_pointer, tstate);
        }
        case 1: {
            PATCH_VALUE(jit_func_preserve_none, jump, _JIT_JUMP_TARGET)
            __attribute__((musttail)) return jump(frame, stack_pointer, tstate);
        }
        case 2: {
            PATCH_VALUE(jit_func_preserve_none, error, _JIT_ERROR_TARGET)
            __attribute__((musttail)) return error(frame, stack_pointer, tstate);
        }
        case 3:
            return vm->next_instr;
        case 4: {
            jit_func_preserve_none next = vm->current_executor->jit_side_entry;
            __attribute__((musttail)) return next(frame, stack_pointer, tstate);
        }
        default:
            Py_UNREACHABLE();
    }
}
