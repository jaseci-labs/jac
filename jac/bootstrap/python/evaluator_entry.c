/* Interpreter trampoline storage and C entry ABI.
 * Entry and generated opcode control flow are native Jac. The outer C frame
 * owns activation storage across all native tail transfers.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_activation.h"
#include "evaluator_metadata.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_frame.h"
#include "internal/pycore_interpframe.h"
#include "internal/pycore_interp.h"
#include "internal/pycore_instruments.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_stats.h"

extern PyObject *jacpy_eval_frame_entry(JacPyVMStorage *, PyThreadState *, JacPyFrameRef, int32_t);

PyObject *_PyEval_EvalFrameDefault(PyThreadState *tstate, _PyInterpreterFrame *frame, int throwflag) {
    _Py_EnsureTstateNotNULL(tstate);
    CALL_STAT_INC(pyeval_calls);
    JacPyVMStorage storage;
    return jacpy_eval_frame_entry(&storage, tstate, frame, throwflag);
}
int32_t jacpy_entry_recursive_guard(PyThreadState *tstate) {
    return _Py_EnterRecursiveCallTstate(tstate, "");
}
JacPyFrameRef jacpy_entry_link(JacPyVMStorage *storage, PyThreadState *tstate, JacPyFrameRef frame) {
    storage->stack[0] = PyStackRef_NULL;
    storage->frame.f_executable = PyStackRef_None;
    storage->frame.instr_ptr = (_Py_CODEUNIT *)jacpy_interpreter_trampoline + 1;
    storage->frame.stackpointer = storage->stack;
    storage->frame.owner = FRAME_OWNED_BY_INTERPRETER;
    storage->frame.visited = 0;
    storage->frame.return_offset = 0;
    storage->frame.previous = tstate->current_frame;
    frame->previous = &storage->frame;
    tstate->current_frame = frame;
    storage->frame.localsplus[0] = PyStackRef_NULL;
    return frame;
}
JacPyObjectRef jacpy_entry_executor(PyThreadState *tstate) {
#ifdef _Py_TIER2
    return tstate->current_executor;
#else
    (void)tstate;
    return NULL;
#endif
}
void jacpy_entry_save_executor(JacPyVMStorage *storage, PyThreadState *tstate, JacPyStackRef executor) {
#ifdef _Py_TIER2
    storage->frame.localsplus[0].bits = executor;
    tstate->current_executor = NULL;
#else
    (void)storage; (void)tstate; (void)executor;
    Py_UNREACHABLE();
#endif
}
void jacpy_thread_remaining_set(PyThreadState *tstate, int32_t remaining) { tstate->py_recursion_remaining = remaining; }
void jacpy_entry_unlink(PyThreadState *tstate, JacPyFrameRef frame) { tstate->current_frame = frame->previous; }
void jacpy_entry_finish_early(JacPyVMStorage *storage, PyThreadState *tstate) {
    assert(tstate->current_frame == &storage->frame);
    storage->frame.return_offset = 0;
    tstate->current_frame = storage->frame.previous;
}
void jacpy_entry_instrument(PyThreadState *tstate, JacPyFrameRef frame) {
    (void)_Py_Instrument(_PyFrame_GetCode(frame), tstate->interp);
}
_Py_CODEUNIT *jacpy_entry_instruction(JacPyFrameRef frame) { return frame->instr_ptr; }
