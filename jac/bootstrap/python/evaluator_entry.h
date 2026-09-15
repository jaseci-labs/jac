/* Native evaluator entry storage ABI, CPython 3.14.6. PSF licensed. */
#ifndef JAC_EVALUATOR_ENTRY_H
#define JAC_EVALUATOR_ENTRY_H
#include "evaluator_frames.h"
typedef struct JacPyEvalStorage JacPyEvalStorage;
int32_t jacpy_entry_recursive_guard(PyThreadState *tstate);
JacPyFrameRef jacpy_entry_link(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyFrameRef frame);
JacPyObjectRef jacpy_entry_executor(PyThreadState *tstate);
void jacpy_entry_save_executor(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyStackRef executor);
void jacpy_thread_remaining_set(PyThreadState *tstate, int32_t remaining);
void jacpy_entry_unlink(PyThreadState *tstate, JacPyFrameRef frame);
void jacpy_entry_finish_early(JacPyEvalStorage *storage, PyThreadState *tstate);
void jacpy_entry_instrument(PyThreadState *tstate, JacPyFrameRef frame);
_Py_CODEUNIT *jacpy_entry_instruction(JacPyFrameRef frame);
JacPyObjectRef jacpy_entry_dispatch_start(JacPyEvalStorage *storage, PyThreadState *tstate, JacPyFrameRef frame);
JacPyObjectRef jacpy_entry_dispatch_error(JacPyEvalStorage *storage, PyThreadState *tstate,
    JacPyFrameRef frame, _Py_CODEUNIT *instruction);
#endif
