/* Field, reference and runtime-call ABI primitives for generated native Jac.
 * Derived from CPython 3.14.6 Python/ceval_macros.h and ceval.c, PSF licensed.
 * There are no opcode bodies or dispatch transfers in this header.
 */
#ifndef JAC_EVALUATOR_OPERATIONS_H
#define JAC_EVALUATOR_OPERATIONS_H
#define _PY_INTERPRETER
#include "Python.h"
#include "pycore_abstract.h"      // _PyIndex_Check()
#include "pycore_audit.h"         // _PySys_Audit()
#include "pycore_backoff.h"
#include "pycore_call.h"          // _PyObject_CallNoArgs()
#include "pycore_cell.h"          // PyCell_GetRef()
#include "pycore_ceval.h"         // SPECIAL___ENTER__
#include "pycore_code.h"
#include "pycore_descrobject.h"
#include "pycore_dict.h"
#include "pycore_emscripten_signal.h"  // _Py_CHECK_EMSCRIPTEN_SIGNALS
#include "pycore_floatobject.h"   // _PyFloat_ExactDealloc()
#include "pycore_frame.h"
#include "pycore_function.h"
#include "pycore_genobject.h"     // _PyCoro_GetAwaitableIter()
#include "pycore_import.h"        // _PyImport_IsDefaultImportFunc()
#include "pycore_instruments.h"
#include "pycore_interpframe.h"   // _PyFrame_SetStackPointer()
#include "pycore_interpolation.h" // _PyInterpolation_Build()
#include "pycore_intrinsics.h"
#include "pycore_jit.h"
#include "pycore_list.h"          // _PyList_GetItemRef()
#include "pycore_long.h"          // _PyLong_GetZero()
#include "pycore_moduleobject.h"  // PyModuleObject
#include "pycore_object.h"        // _PyObject_GC_TRACK()
#include "pycore_opcode_metadata.h" // EXTRA_CASES
#include "pycore_opcode_utils.h"  // MAKE_FUNCTION_*
#include "pycore_optimizer.h"     // _PyUOpExecutor_Type
#include "pycore_pyatomic_ft_wrappers.h" // FT_ATOMIC_*
#include "pycore_pyerrors.h"      // _PyErr_GetRaisedException()
#include "pycore_pystate.h"       // _PyInterpreterState_GET()
#include "pycore_range.h"         // _PyRangeIterObject
#include "pycore_setobject.h"     // _PySet_Update()
#include "pycore_sliceobject.h"   // _PyBuildSlice_ConsumeRefs
#include "pycore_sysmodule.h"     // _PySys_GetOptionalAttrString()
#include "pycore_template.h"      // _PyTemplate_Build()
#include "pycore_traceback.h"     // _PyTraceBack_FromFrame
#include "pycore_tuple.h"         // _PyTuple_ITEMS()
#include "pycore_unicodeobject.h"
#include "pycore_uop_ids.h"       // Uops

#include "dictobject.h"
#include "frameobject.h"          // _PyInterpreterFrame_GetLine
#include "opcode.h"
#include "pydtrace.h"
#include "setobject.h"
#include "pycore_stackref.h"

#include <stdbool.h>              // bool


#include "evaluator_metadata.h"
#include "evaluator_recursion.h"
#define monitor_reraise jacpy_monitor_reraise
#define monitor_stop_iteration jacpy_monitor_stop_iteration
#define monitor_unwind jacpy_monitor_unwind
#define monitor_handled jacpy_monitor_handled
#define monitor_throw jacpy_monitor_throw

void monitor_reraise(PyThreadState *tstate,
                 _PyInterpreterFrame *frame,
                 _Py_CODEUNIT *instr);
int monitor_stop_iteration(PyThreadState *tstate,
                 _PyInterpreterFrame *frame,
                 _Py_CODEUNIT *instr,
                 PyObject *value);
void monitor_unwind(PyThreadState *tstate,
                 _PyInterpreterFrame *frame,
                 _Py_CODEUNIT *instr);
int monitor_handled(PyThreadState *tstate,
                 _PyInterpreterFrame *frame,
                 _Py_CODEUNIT *instr, PyObject *exc);
void monitor_throw(PyThreadState *tstate,
                 _PyInterpreterFrame *frame,
                 _Py_CODEUNIT *instr);

#define get_exception_handler jacpy_get_exception_handler
extern int get_exception_handler(PyCodeObject *, int, int*, int*, int*);
#include "evaluator_binding.h"
#define _PyEvalFramePushAndInit_Ex jacpy_frame_push_ex


int jacpy_eval_raise(PyThreadState *, PyObject *, PyObject *);
#define do_raise jacpy_eval_raise
int32_t jacpy_enter_recursive_py(PyThreadState *);
void jacpy_leave_recursive_py(PyThreadState *);
#define _Py_EnterRecursivePy jacpy_enter_recursive_py
#define _Py_LeaveRecursiveCallPy jacpy_leave_recursive_py
#ifdef Py_STATS
#define INSTRUCTION_STATS(op) \
    do { \
        OPCODE_EXE_INC(op); \
        if (_Py_stats) _Py_stats->opcode_stats[lastopcode].pair_count[op]++; \
        lastopcode = op; \
    } while (0)
#else
#define INSTRUCTION_STATS(op) ((void)0)
#endif


#ifdef Py_GIL_DISABLED
#define QSBR_QUIESCENT_STATE(tstate) _Py_qsbr_quiescent_state(((_PyThreadStateImpl *)tstate)->qsbr)
#else
#define QSBR_QUIESCENT_STATE(tstate)
#endif



/* Tuple access macros */

#ifndef Py_DEBUG
#define GETITEM(v, i) PyTuple_GET_ITEM((v), (i))
#else
static inline PyObject *
GETITEM(PyObject *v, Py_ssize_t i) {
    assert(PyTuple_Check(v));
    assert(i >= 0);
    assert(i < PyTuple_GET_SIZE(v));
    return PyTuple_GET_ITEM(v, i);
}
#endif

/* Code access macros */

/* The integer overflow is checked by an assertion below. */
#define INSTR_OFFSET() ((int)(next_instr - _PyFrame_GetBytecode(frame)))
#define NEXTOPARG()  do { \
        _Py_CODEUNIT word  = {.cache = FT_ATOMIC_LOAD_UINT16_RELAXED(*(uint16_t*)next_instr)}; \
        opcode = word.op.code; \
        oparg = word.op.arg; \
    } while (0)

/* JUMPBY makes the generator identify the instruction as a jump. SKIP_OVER is
 * for advancing to the next instruction, taking into account cache entries
 * and skipped instructions.
 */
#define JUMPBY(x)       (next_instr += (x))
#define SKIP_OVER(x)    (next_instr += (x))

#define STACK_LEVEL()     ((int)(stack_pointer - _PyFrame_Stackbase(frame)))
#define STACK_SIZE()      (_PyFrame_GetCode(frame)->co_stacksize)

#define WITHIN_STACK_BOUNDS() \
   (frame->owner == FRAME_OWNED_BY_INTERPRETER || (STACK_LEVEL() >= 0 && STACK_LEVEL() <= STACK_SIZE()))

/* Data access macros */
#define FRAME_CO_CONSTS (_PyFrame_GetCode(frame)->co_consts)
#define FRAME_CO_NAMES  (_PyFrame_GetCode(frame)->co_names)

/* Local variable macros */

#define LOCALS_ARRAY    (frame->localsplus)
#define GETLOCAL(i)     (frame->localsplus[i])


#ifdef Py_STATS
#define UPDATE_MISS_STATS(INSTNAME)                              \
    do {                                                         \
        STAT_INC(opcode, miss);                                  \
        STAT_INC((INSTNAME), miss);                              \
        /* The counter is always the first cache entry: */       \
        if (ADAPTIVE_COUNTER_TRIGGERS(next_instr->cache)) {       \
            STAT_INC((INSTNAME), deopt);                         \
        }                                                        \
    } while (0)
#else
#define UPDATE_MISS_STATS(INSTNAME) ((void)0)
#endif


// Try to lock an object in the free threading build, if it's not already
// locked. Use with a DEOPT_IF() to deopt if the object is already locked.
// These are no-ops in the default GIL build. The general pattern is:
//
// DEOPT_IF(!LOCK_OBJECT(op));
// if (/* condition fails */) {
//     UNLOCK_OBJECT(op);
//     DEOPT_IF(true);
//  }
//  ...
//  UNLOCK_OBJECT(op);
//
// NOTE: The object must be unlocked on every exit code path and you should
// avoid any potentially escaping calls (like PyStackRef_CLOSE) while the
// object is locked.
#ifdef Py_GIL_DISABLED
#  define LOCK_OBJECT(op) PyMutex_LockFast(&(_PyObject_CAST(op))->ob_mutex)
#  define UNLOCK_OBJECT(op) PyMutex_Unlock(&(_PyObject_CAST(op))->ob_mutex)
#else
#  define LOCK_OBJECT(op) (1)
#  define UNLOCK_OBJECT(op) ((void)0)
#endif

#define GLOBALS() frame->f_globals
#define BUILTINS() frame->f_builtins
#define LOCALS() frame->f_locals
#define CONSTS() _PyFrame_GetCode(frame)->co_consts
#define NAMES() _PyFrame_GetCode(frame)->co_names

/* This takes a uint16_t instead of a _Py_BackoffCounter,
 * because it is used directly on the cache entry in generated code,
 * which is always an integral type. */
#define ADAPTIVE_COUNTER_TRIGGERS(COUNTER) \
    backoff_counter_triggers(forge_backoff_counter((COUNTER)))

#define ADVANCE_ADAPTIVE_COUNTER(COUNTER) \
    do { \
        (COUNTER) = advance_backoff_counter((COUNTER)); \
    } while (0);

#define PAUSE_ADAPTIVE_COUNTER(COUNTER) \
    do { \
        (COUNTER) = pause_backoff_counter((COUNTER)); \
    } while (0);

#ifdef ENABLE_SPECIALIZATION_FT
/* Multiple threads may execute these concurrently if thread-local bytecode is
 * disabled and they all execute the main copy of the bytecode. Specialization
 * is disabled in that case so the value is unused, but the RMW cycle should be
 * free of data races.
 */
#define RECORD_BRANCH_TAKEN(bitset, flag) \
    FT_ATOMIC_STORE_UINT16_RELAXED(       \
        bitset, (FT_ATOMIC_LOAD_UINT16_RELAXED(bitset) << 1) | (flag))
#else
#define RECORD_BRANCH_TAKEN(bitset, flag)
#endif

#define UNBOUNDLOCAL_ERROR_MSG \
    "cannot access local variable '%s' where it is not associated with a value"
#define UNBOUNDFREE_ERROR_MSG \
    "cannot access free variable '%s' where it is not associated with a value" \
    " in enclosing scope"
#define NAME_ERROR_MSG "name '%.200s' is not defined"

// If a trace function sets a new f_lineno and
// *then* raises, we use the destination when searching
// for an exception handler, displaying the traceback, and so on

#define CURRENT_OPARG()    (next_uop[-1].oparg)
#define CURRENT_OPERAND0() (next_uop[-1].operand0)
#define CURRENT_OPERAND1() (next_uop[-1].operand1)
#define CURRENT_TARGET()   (next_uop[-1].target)


#define LOAD_SP() (stack_pointer = _PyFrame_GetStackPointer(frame))
#define SAVE_SP() _PyFrame_SetStackPointer(frame, stack_pointer)
#define CONVERSION_FAILED(NAME) ((NAME) == NULL)
#endif
