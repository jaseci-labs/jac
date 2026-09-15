/* Read-only CPython ABI tables used by the native evaluator and retained
 * object/specialization runtime. These are data, not opcode implementations.
 * CPython 3.14.6, PSF licensed; see jaclang/runtime/python/LICENSE.cpython.
 */
#ifndef Py_BUILD_CORE
#define Py_BUILD_CORE
#endif
#include "evaluator_metadata.h"
#include "internal/pycore_ceval.h"
#include "internal/pycore_abstract.h"
#include "internal/pycore_function.h"
#include "internal/pycore_object.h"
#include "internal/pycore_opcode_utils.h"
#include "internal/pycore_unicodeobject.h"
#include "opcode.h"

const binaryfunc _PyEval_BinaryOps[] = {
    [NB_ADD] = PyNumber_Add,
    [NB_AND] = PyNumber_And,
    [NB_FLOOR_DIVIDE] = PyNumber_FloorDivide,
    [NB_LSHIFT] = PyNumber_Lshift,
    [NB_MATRIX_MULTIPLY] = PyNumber_MatrixMultiply,
    [NB_MULTIPLY] = PyNumber_Multiply,
    [NB_REMAINDER] = PyNumber_Remainder,
    [NB_OR] = PyNumber_Or,
    [NB_POWER] = _PyNumber_PowerNoMod,
    [NB_RSHIFT] = PyNumber_Rshift,
    [NB_SUBTRACT] = PyNumber_Subtract,
    [NB_TRUE_DIVIDE] = PyNumber_TrueDivide,
    [NB_XOR] = PyNumber_Xor,
    [NB_INPLACE_ADD] = PyNumber_InPlaceAdd,
    [NB_INPLACE_AND] = PyNumber_InPlaceAnd,
    [NB_INPLACE_FLOOR_DIVIDE] = PyNumber_InPlaceFloorDivide,
    [NB_INPLACE_LSHIFT] = PyNumber_InPlaceLshift,
    [NB_INPLACE_MATRIX_MULTIPLY] = PyNumber_InPlaceMatrixMultiply,
    [NB_INPLACE_MULTIPLY] = PyNumber_InPlaceMultiply,
    [NB_INPLACE_REMAINDER] = PyNumber_InPlaceRemainder,
    [NB_INPLACE_OR] = PyNumber_InPlaceOr,
    [NB_INPLACE_POWER] = _PyNumber_InPlacePowerNoMod,
    [NB_INPLACE_RSHIFT] = PyNumber_InPlaceRshift,
    [NB_INPLACE_SUBTRACT] = PyNumber_InPlaceSubtract,
    [NB_INPLACE_TRUE_DIVIDE] = PyNumber_InPlaceTrueDivide,
    [NB_INPLACE_XOR] = PyNumber_InPlaceXor,
    [NB_SUBSCR] = PyObject_GetItem,
};

const conversion_func _PyEval_ConversionFuncs[4] = {
    [FVC_STR] = PyObject_Str,
    [FVC_REPR] = PyObject_Repr,
    [FVC_ASCII] = PyObject_ASCII
};

const _Py_SpecialMethod _Py_SpecialMethods[] = {
    [SPECIAL___ENTER__] = {
        .name = &_Py_ID(__enter__),
        .error = (
            "'%T' object does not support the context manager protocol "
            "(missed __enter__ method)"
        ),
        .error_suggestion = (
            "'%T' object does not support the context manager protocol "
            "(missed __enter__ method) but it supports the asynchronous "
            "context manager protocol. Did you mean to use 'async with'?"
        )
    },
    [SPECIAL___EXIT__] = {
        .name = &_Py_ID(__exit__),
        .error = (
            "'%T' object does not support the context manager protocol "
            "(missed __exit__ method)"
        ),
        .error_suggestion = (
            "'%T' object does not support the context manager protocol "
            "(missed __exit__ method) but it supports the asynchronous "
            "context manager protocol. Did you mean to use 'async with'?"
        )
    },
    [SPECIAL___AENTER__] = {
        .name = &_Py_ID(__aenter__),
        .error = (
            "'%T' object does not support the asynchronous "
            "context manager protocol (missed __aenter__ method)"
        ),
        .error_suggestion = (
            "'%T' object does not support the asynchronous context manager "
            "protocol (missed __aenter__ method) but it supports the context "
            "manager protocol. Did you mean to use 'with'?"
        )
    },
    [SPECIAL___AEXIT__] = {
        .name = &_Py_ID(__aexit__),
        .error = (
            "'%T' object does not support the asynchronous "
            "context manager protocol (missed __aexit__ method)"
        ),
        .error_suggestion = (
            "'%T' object does not support the asynchronous context manager "
            "protocol (missed __aexit__ method) but it supports the context "
            "manager protocol. Did you mean to use 'with'?"
        )
    }
};

const size_t _Py_FunctionAttributeOffsets[] = {
    [MAKE_FUNCTION_CLOSURE] = offsetof(PyFunctionObject, func_closure),
    [MAKE_FUNCTION_ANNOTATIONS] = offsetof(PyFunctionObject, func_annotations),
    [MAKE_FUNCTION_KWDEFAULTS] = offsetof(PyFunctionObject, func_kwdefaults),
    [MAKE_FUNCTION_DEFAULTS] = offsetof(PyFunctionObject, func_defaults),
    [MAKE_FUNCTION_ANNOTATE] = offsetof(PyFunctionObject, func_annotate),
};

const _Py_CODEUNIT jacpy_interpreter_trampoline[] = {
    /* Put a NOP at the start, so that the IP points into
    * the code, rather than before it */
    { .op.code = NOP, .op.arg = 0 },
    { .op.code = INTERPRETER_EXIT, .op.arg = 0 },  /* reached on return */
    { .op.code = NOP, .op.arg = 0 },
    { .op.code = INTERPRETER_EXIT, .op.arg = 0 },  /* reached on yield */
    { .op.code = RESUME, .op.arg = RESUME_OPARG_DEPTH1_MASK | RESUME_AT_FUNC_START }
};
