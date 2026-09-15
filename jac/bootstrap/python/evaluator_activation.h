/* Linear evaluator activation and stable scratch storage, CPython 3.14.6.
 * PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 *
 * The outer evaluation entry owns the storage. The linear native VM handle
 * owns the active frame chain and its in-flight reference obligations. Scratch
 * fields preserve the upstream transfer ledger: reading a field does not grant
 * an independent reference, and transient aliases are never blindly decrefed.
 * Native branch/error/suspension code chooses every transition. ABI expressions
 * retain exact CPython slot operations and reference representations.
 */
#ifndef JAC_EVALUATOR_ACTIVATION_H
#define JAC_EVALUATOR_ACTIVATION_H
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_operations.h"
#include "evaluator_entry.h"
#include "evaluator_scratch.h"

typedef struct JacPyVM *JacPyVMRef;
struct JacPyVM {
    _PyInterpreterFrame * frame;
    _PyStackRef * stack_pointer;
    PyThreadState * tstate;
    _Py_CODEUNIT * next_instr;
    int oparg;
    int opcode;
    int lastopcode;
    const _PyUOpInstruction * next_uop;
    _PyExecutorObject * current_executor;
    uint16_t uopcode;
    int lastuop;
    uint64_t trace_uop_execution_counter;
    union JacPyVMScratch scratch;
};
struct JacPyVMStorage {
    _PyInterpreterFrame frame;
    _PyStackRef stack[1];
    struct JacPyVM vm;
};
#define JAC_VM_REGISTERS(vm) \
    _PyInterpreterFrame * frame = (vm)->frame; \
    _PyStackRef * stack_pointer = (vm)->stack_pointer; \
    PyThreadState * tstate = (vm)->tstate; \
    _Py_CODEUNIT * next_instr = (vm)->next_instr; \
    int oparg = (vm)->oparg; \
    int opcode = (vm)->opcode; \
    int lastopcode = (vm)->lastopcode; \
    const _PyUOpInstruction * next_uop = (vm)->next_uop; \
    _PyExecutorObject * current_executor = (vm)->current_executor; \
    uint16_t uopcode = (vm)->uopcode; \
    int lastuop = (vm)->lastuop; \
    uint64_t trace_uop_execution_counter = (vm)->trace_uop_execution_counter
#define JAC_VM_SAVE_REGISTERS(vm) \
    (vm)->frame = frame; \
    (vm)->stack_pointer = stack_pointer; \
    (vm)->tstate = tstate; \
    (vm)->next_instr = next_instr; \
    (vm)->oparg = oparg; \
    (vm)->opcode = opcode; \
    (vm)->lastopcode = lastopcode; \
    (vm)->next_uop = next_uop; \
    (vm)->current_executor = current_executor; \
    (vm)->uopcode = uopcode; \
    (vm)->lastuop = lastuop; \
    (vm)->trace_uop_execution_counter = trace_uop_execution_counter

JacPyVMRef jacpy_vm_begin(JacPyVMStorage *, PyThreadState *, JacPyFrameRef);
JacPyVMRef jacpy_vm_begin_error(JacPyVMStorage *, PyThreadState *, JacPyFrameRef, _Py_CODEUNIT *);
void jacpy_vm_invalid_drop(JacPyVMRef);
void jacpy_vm_record_native_entry(void);
PyAPI_FUNC(uint64_t) _PyJac_NativeEvaluatorEntries(void);
PyObject *jacpy_vm_unreachable(JacPyVMRef, JacPyVMStorage *, PyThreadState *);
#endif
