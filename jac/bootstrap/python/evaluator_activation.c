/* Activation field/ownership ABI, CPython 3.14.6, PSF licensed. */
#include "evaluator_activation.h"

JacPyVMRef jacpy_vm_begin(JacPyVMStorage *storage, PyThreadState *tstate,
                         JacPyFrameRef frame) {
    JacPyVMRef vm = &storage->vm;
    vm->frame = frame;
    vm->stack_pointer = NULL;
    vm->tstate = tstate;
    vm->next_instr = NULL;
    vm->oparg = 0;
    vm->opcode = 0;
    vm->lastopcode = 0;
    vm->next_uop = NULL;
    vm->current_executor = NULL;
    vm->uopcode = 0;
    vm->lastuop = 0;
    vm->trace_uop_execution_counter = 0;
    vm->_oparg = 0; vm->_operand0 = 0; vm->_operand1 = 0; vm->_target = 0;
    return vm;
}
JacPyVMRef jacpy_vm_begin_error(JacPyVMStorage *storage, PyThreadState *tstate,
                              JacPyFrameRef frame, _Py_CODEUNIT *instruction) {
    JacPyVMRef vm = jacpy_vm_begin(storage, tstate, frame);
    vm->next_instr = instruction;
    vm->stack_pointer = _PyFrame_GetStackPointer(vm->frame);
    return vm;
}
void jacpy_vm_invalid_drop(JacPyVMRef vm) {
    (void)vm;
    /* A linear activation must be transferred or finished. This is an
     * invariant failure, not the Python exception/error path: generated
     * unwind handlers implement that path and consume the activation normally.
     */
    _Py_FatalErrorFunc("native evaluator", "unconsumed linear activation");
}
PyObject *jacpy_vm_unreachable(JacPyVMRef vm, JacPyVMStorage *storage, PyThreadState *tstate) {
    (void)vm; (void)storage; (void)tstate;
    Py_UNREACHABLE();
}

/* Incremented only from the native entry body, independently of compilation.
 * Atomic for interpreters with separate GILs. No per-opcode instrumentation.
 */
static uint64_t native_evaluator_entries;
void jacpy_vm_record_native_entry(void) {
    _Py_atomic_add_uint64(&native_evaluator_entries, 1);
}
PyAPI_FUNC(uint64_t) _PyJac_NativeEvaluatorEntries(void) {
    return _Py_atomic_load_uint64_relaxed(&native_evaluator_entries);
}

void jacpy_jit_step_invalid_drop(JacPyVMRef vm) {
    (void)vm;
    _Py_FatalErrorFunc("native JIT evaluator", "unconsumed linear step permission");
}
