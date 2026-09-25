"""Opcode metadata for the dis and opcode modules.

Derived from CPython 3.14.6 Modules/_opcode.c; see ../LICENSE.cpython. The
metadata and stack effects are the native compiler's own tables in
opcode_meta.jac, so dis and the compiler cannot disagree.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_Occurred,
    PyList_Append,
    PyList_New,
    PyLong_AsLong,
    PyObject,
    PyUnicode_FromString,
    PyUnicode_InternFromString,
    Py_NewRef,
    _PyCompile_GetBinaryIntrinsicName,
    _PyCompile_GetUnaryIntrinsicName,
    jacpy_is_code,
    jacpy_is_none,
    jacpy_release
}
import from jaclang.runtime.python.bindings.converters {
    borrowed_none,
    borrowed_true,
    borrowed_false
}
import from jaclang.runtime.python.capi { object_error, object_tuple, type_name }
import from jaclang.runtime.python.opcode_meta {
    opcode_is_valid,
    opcode_has_arg,
    opcode_has_const,
    opcode_has_name,
    opcode_has_jump,
    opcode_has_free,
    opcode_has_local,
    is_block_push_opcode,
    stack_effect
}

glob:pub ENABLE_SPECIALIZATION: i64 = 1,
     ENABLE_SPECIALIZATION_FT: i64 = 1;

glob:priv MAX_INTRINSIC_1: int = 11,
     MAX_INTRINSIC_2: int = 5,
     NB_OPS: list[tuple[str, str]] = [
         ("NB_ADD", "+"),
         ("NB_AND", "&"),
         ("NB_FLOOR_DIVIDE", "//"),
         ("NB_LSHIFT", "<<"),
         ("NB_MATRIX_MULTIPLY", "@"),
         ("NB_MULTIPLY", "*"),
         ("NB_REMAINDER", "%"),
         ("NB_OR", "|"),
         ("NB_POWER", "**"),
         ("NB_RSHIFT", ">>"),
         ("NB_SUBTRACT", "-"),
         ("NB_TRUE_DIVIDE", "/"),
         ("NB_XOR", "^"),
         ("NB_INPLACE_ADD", "+="),
         ("NB_INPLACE_AND", "&="),
         ("NB_INPLACE_FLOOR_DIVIDE", "//="),
         ("NB_INPLACE_LSHIFT", "<<="),
         ("NB_INPLACE_MATRIX_MULTIPLY", "@="),
         ("NB_INPLACE_MULTIPLY", "*="),
         ("NB_INPLACE_REMAINDER", "%="),
         ("NB_INPLACE_OR", "|="),
         ("NB_INPLACE_POWER", "**="),
         ("NB_INPLACE_RSHIFT", ">>="),
         ("NB_INPLACE_SUBTRACT", "-="),
         ("NB_INPLACE_TRUE_DIVIDE", "/="),
         ("NB_INPLACE_XOR", "^="),
         ("NB_SUBSCR", "[]")
     ],
     SPECIAL_METHODS: list[str] = ["__enter__", "__exit__", "__aenter__", "__aexit__"];

def _opcode_stack_effect_impl(
    module: ptr[PyObject], opcode: i32, oparg: ptr[PyObject], jump: ptr[PyObject]
) -> i32 {
    argument = 0;
    if jacpy_is_none(oparg) == 0 {
        argument = int(i32(PyLong_AsLong(oparg)));
        if argument == -1 and PyErr_Occurred() {
            return i32(-1);
        }
    }
    direction = -1;
    if jump == borrowed_true() {
        direction = 1;
    } elif jump == borrowed_false() {
        direction = 0;
    } elif jacpy_is_none(jump) == 0 {
        object_error("ValueError", "stack_effect: jump must be False, True or None");
        return i32(-1);
    }
    effect = stack_effect(int(opcode), argument, direction);
    if effect is None {
        object_error("ValueError", "invalid opcode or oparg");
        return i32(-1);
    }
    return i32(effect);
}

def _opcode_is_valid_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)));
}

def _opcode_has_arg_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_arg(int(opcode)));
}

def _opcode_has_const_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_const(int(opcode)));
}

def _opcode_has_name_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_name(int(opcode)));
}

def _opcode_has_jump_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_jump(int(opcode)));
}

def _opcode_has_free_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_free(int(opcode)));
}

def _opcode_has_local_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and opcode_has_local(int(opcode)));
}

def _opcode_has_exc_impl(module: ptr[PyObject], opcode: i32) -> i32 {
    return i32(opcode_is_valid(int(opcode)) and is_block_push_opcode(int(opcode)));
}

# Py_STATS is off in every release build, so there are no statistics.
def _opcode_get_specialization_stats_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(borrowed_none());
}

# Each append retains its item; release ours, and the partial list on failure.
def:priv collect(items: list[ptr[PyObject]]) -> ptr[PyObject] {
    result = PyList_New(0);
    if not result {
        for item in items {
            jacpy_release(item);
        }
        return NULL;
    }
    failed = False;
    for item in items {
        if not item or failed or PyList_Append(result, item) < 0 {
            failed = True;
        }
        jacpy_release(item);
    }
    if failed {
        jacpy_release(result);
        return NULL;
    }
    return result;
}

def _opcode_get_nb_ops_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    pairs: list[ptr[PyObject]] = [];
    for (name, symbol) in NB_OPS {
        first = PyUnicode_FromString(name);
        second = PyUnicode_FromString(symbol);
        pairs.append(object_tuple([first, second]) if first and second else NULL);
        jacpy_release(first);
        jacpy_release(second);
    }
    return collect(pairs);
}

def _opcode_get_intrinsic1_descs_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return collect(
        [_PyCompile_GetUnaryIntrinsicName(i32(i)) for i in range(MAX_INTRINSIC_1 + 1)]
    );
}

def _opcode_get_intrinsic2_descs_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return collect(
        [_PyCompile_GetBinaryIntrinsicName(i32(i)) for i in range(MAX_INTRINSIC_2 + 1)]
    );
}

def _opcode_get_special_method_names_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return collect([PyUnicode_InternFromString(name) for name in SPECIAL_METHODS]);
}

# Tier-2 executors are not built (Python/optimizer_*.c are pruned).
def _opcode_get_executor_impl(
    module: ptr[PyObject], code: ptr[PyObject], offset: i32
) -> ptr[PyObject] {
    if jacpy_is_code(code) == 0 {
        object_error("TypeError", f"expected a code object, not '{type_name(code)}'");
        return NULL;
    }
    object_error("RuntimeError", "Executors are not available in this build");
    return NULL;
}
