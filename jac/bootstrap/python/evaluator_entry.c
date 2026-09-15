/* Interpreter trampoline storage and C ABI dispatch adapters.
 * The entry algorithm is native Jac. Opcode handlers are still CPython C;
 * these adapters must be retired with those handlers, not counted as a port.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_entry.h"
#include "evaluator_metadata.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_frame.h"
#include "internal/pycore_interpframe.h"
#include "internal/pycore_interp.h"
#include "internal/pycore_instruments.h"
#include "internal/pycore_pystate.h"
#include "internal/pycore_stats.h"

struct JacPyEvalStorage {
    _PyInterpreterFrame frame;
    _PyStackRef stack[1];
};
extern PyObject *jacpy_eval_frame_entry(JacPyEvalStorage *, PyThreadState *, JacPyFrameRef, int32_t);

#if Py_TAIL_CALL_INTERP
/* This bridge uses the precise pinned C handler convention and optional stats
 * argument. Native generated handlers will replace both bridge declarations.
 */
#define JAC_TAIL_CC __attribute__((preserve_none))
#if Py_STATS
#define JAC_TAIL_STATS_PARAM , int
#define JAC_TAIL_STATS_ARG , 0
#else
#define JAC_TAIL_STATS_PARAM
#define JAC_TAIL_STATS_ARG
#endif
extern JAC_TAIL_CC PyObject *_TAIL_CALL_start_frame(_PyInterpreterFrame *, _PyStackRef *,
    PyThreadState *, _Py_CODEUNIT *, int JAC_TAIL_STATS_PARAM);
extern JAC_TAIL_CC PyObject *_TAIL_CALL_error(_PyInterpreterFrame *, _PyStackRef *,
    PyThreadState *, _Py_CODEUNIT *, int JAC_TAIL_STATS_PARAM);

PyObject *_PyEval_EvalFrameDefault(PyThreadState *tstate, _PyInterpreterFrame *frame, int throwflag) {
    _Py_EnsureTstateNotNULL(tstate);
    CALL_STAT_INC(pyeval_calls);
    JacPyEvalStorage storage;
    return jacpy_eval_frame_entry(&storage, tstate, frame, throwflag);
}
JacPyObjectRef jacpy_entry_dispatch_start(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyFrameRef frame) {
    (void)storage;
    return _TAIL_CALL_start_frame(frame, NULL, tstate, NULL, 0 JAC_TAIL_STATS_ARG);
}
JacPyObjectRef jacpy_entry_dispatch_error(JacPyEvalStorage *storage, PyThreadState *tstate,
    JacPyFrameRef frame, _Py_CODEUNIT *instruction) {
    (void)storage;
    _PyStackRef *stack = _PyFrame_GetStackPointer(frame);
    return _TAIL_CALL_error(frame, stack, tstate, instruction, 0 JAC_TAIL_STATS_ARG);
}
#endif
int32_t jacpy_entry_recursive_guard(PyThreadState *tstate) {
    return _Py_EnterRecursiveCallTstate(tstate, "");
}
JacPyFrameRef jacpy_entry_link(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyFrameRef frame) {
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
void jacpy_entry_save_executor(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyStackRef executor) {
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
void jacpy_entry_finish_early(JacPyEvalStorage *storage, PyThreadState *tstate) {
    assert(tstate->current_frame == &storage->frame);
    storage->frame.return_offset = 0;
    tstate->current_frame = storage->frame.previous;
}
void jacpy_entry_instrument(PyThreadState *tstate, JacPyFrameRef frame) {
    (void)_Py_Instrument(_PyFrame_GetCode(frame), tstate->interp);
}
_Py_CODEUNIT *jacpy_entry_instruction(JacPyFrameRef frame) { return frame->instr_ptr; }
