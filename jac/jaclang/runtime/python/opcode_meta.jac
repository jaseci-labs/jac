# Originally generated from CPython 3.14.6; maintained directly in Jac.
#
# CPython opcode / code-object metadata (INTEGRATION_PLAN Phase 3).
# Single version-pinned source for opcode numbers, inline-cache counts,
# stack effects, jump/terminator classifiers, operator ids, and flags.
#
#   reference/cpython/Include/opcode_ids.h
#   reference/cpython/Include/opcode.h
#   reference/cpython/Include/cpython/code.h
#   reference/cpython/Include/internal/pycore_code.h
#   reference/cpython/Include/internal/pycore_opcode_metadata.h
#   reference/cpython/Include/internal/pycore_opcode_utils.h
#
# na-clean leaf: no imports, no host calls.

glob MAX_REAL_OPCODE: int = 254;

# ---------------- instruction opcodes (opcode_ids.h) ----------------
glob OP_CACHE: int = 0,
     OP_BINARY_SLICE: int = 1,
     OP_BUILD_TEMPLATE: int = 2,
     OP_BINARY_OP_INPLACE_ADD_UNICODE: int = 3,
     OP_CALL_FUNCTION_EX: int = 4,
     OP_CHECK_EG_MATCH: int = 5,
     OP_CHECK_EXC_MATCH: int = 6,
     OP_CLEANUP_THROW: int = 7,
     OP_DELETE_SUBSCR: int = 8,
     OP_END_FOR: int = 9,
     OP_END_SEND: int = 10,
     OP_EXIT_INIT_CHECK: int = 11,
     OP_FORMAT_SIMPLE: int = 12,
     OP_FORMAT_WITH_SPEC: int = 13,
     OP_GET_AITER: int = 14,
     OP_GET_ANEXT: int = 15,
     OP_GET_ITER: int = 16,
     OP_RESERVED: int = 17,
     OP_GET_LEN: int = 18,
     OP_GET_YIELD_FROM_ITER: int = 19,
     OP_INTERPRETER_EXIT: int = 20,
     OP_LOAD_BUILD_CLASS: int = 21,
     OP_LOAD_LOCALS: int = 22,
     OP_MAKE_FUNCTION: int = 23,
     OP_MATCH_KEYS: int = 24,
     OP_MATCH_MAPPING: int = 25,
     OP_MATCH_SEQUENCE: int = 26,
     OP_NOP: int = 27,
     OP_NOT_TAKEN: int = 28,
     OP_POP_EXCEPT: int = 29,
     OP_POP_ITER: int = 30,
     OP_POP_TOP: int = 31,
     OP_PUSH_EXC_INFO: int = 32,
     OP_PUSH_NULL: int = 33,
     OP_RETURN_GENERATOR: int = 34,
     OP_RETURN_VALUE: int = 35,
     OP_SETUP_ANNOTATIONS: int = 36,
     OP_STORE_SLICE: int = 37,
     OP_STORE_SUBSCR: int = 38,
     OP_TO_BOOL: int = 39,
     OP_UNARY_INVERT: int = 40,
     OP_UNARY_NEGATIVE: int = 41,
     OP_UNARY_NOT: int = 42,
     OP_WITH_EXCEPT_START: int = 43,
     OP_BINARY_OP: int = 44,
     OP_BUILD_INTERPOLATION: int = 45,
     OP_BUILD_LIST: int = 46,
     OP_BUILD_MAP: int = 47,
     OP_BUILD_SET: int = 48,
     OP_BUILD_SLICE: int = 49,
     OP_BUILD_STRING: int = 50,
     OP_BUILD_TUPLE: int = 51,
     OP_CALL: int = 52,
     OP_CALL_INTRINSIC_1: int = 53,
     OP_CALL_INTRINSIC_2: int = 54,
     OP_CALL_KW: int = 55,
     OP_COMPARE_OP: int = 56,
     OP_CONTAINS_OP: int = 57,
     OP_CONVERT_VALUE: int = 58,
     OP_COPY: int = 59,
     OP_COPY_FREE_VARS: int = 60,
     OP_DELETE_ATTR: int = 61,
     OP_DELETE_DEREF: int = 62,
     OP_DELETE_FAST: int = 63,
     OP_DELETE_GLOBAL: int = 64,
     OP_DELETE_NAME: int = 65,
     OP_DICT_MERGE: int = 66,
     OP_DICT_UPDATE: int = 67,
     OP_END_ASYNC_FOR: int = 68,
     OP_EXTENDED_ARG: int = 69,
     OP_FOR_ITER: int = 70,
     OP_GET_AWAITABLE: int = 71,
     OP_IMPORT_FROM: int = 72,
     OP_IMPORT_NAME: int = 73,
     OP_IS_OP: int = 74,
     OP_JUMP_BACKWARD: int = 75,
     OP_JUMP_BACKWARD_NO_INTERRUPT: int = 76,
     OP_JUMP_FORWARD: int = 77,
     OP_LIST_APPEND: int = 78,
     OP_LIST_EXTEND: int = 79,
     OP_LOAD_ATTR: int = 80,
     OP_LOAD_COMMON_CONSTANT: int = 81,
     OP_LOAD_CONST: int = 82,
     OP_LOAD_DEREF: int = 83,
     OP_LOAD_FAST: int = 84,
     OP_LOAD_FAST_AND_CLEAR: int = 85,
     OP_LOAD_FAST_BORROW: int = 86,
     OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW: int = 87,
     OP_LOAD_FAST_CHECK: int = 88,
     OP_LOAD_FAST_LOAD_FAST: int = 89,
     OP_LOAD_FROM_DICT_OR_DEREF: int = 90,
     OP_LOAD_FROM_DICT_OR_GLOBALS: int = 91,
     OP_LOAD_GLOBAL: int = 92,
     OP_LOAD_NAME: int = 93,
     OP_LOAD_SMALL_INT: int = 94,
     OP_LOAD_SPECIAL: int = 95,
     OP_LOAD_SUPER_ATTR: int = 96,
     OP_MAKE_CELL: int = 97,
     OP_MAP_ADD: int = 98,
     OP_MATCH_CLASS: int = 99,
     OP_POP_JUMP_IF_FALSE: int = 100,
     OP_POP_JUMP_IF_NONE: int = 101,
     OP_POP_JUMP_IF_NOT_NONE: int = 102,
     OP_POP_JUMP_IF_TRUE: int = 103,
     OP_RAISE_VARARGS: int = 104,
     OP_RERAISE: int = 105,
     OP_SEND: int = 106,
     OP_SET_ADD: int = 107,
     OP_SET_FUNCTION_ATTRIBUTE: int = 108,
     OP_SET_UPDATE: int = 109,
     OP_STORE_ATTR: int = 110,
     OP_STORE_DEREF: int = 111,
     OP_STORE_FAST: int = 112,
     OP_STORE_FAST_LOAD_FAST: int = 113,
     OP_STORE_FAST_STORE_FAST: int = 114,
     OP_STORE_GLOBAL: int = 115,
     OP_STORE_NAME: int = 116,
     OP_SWAP: int = 117,
     OP_UNPACK_EX: int = 118,
     OP_UNPACK_SEQUENCE: int = 119,
     OP_YIELD_VALUE: int = 120,
     OP_RESUME: int = 128,
     OP_BINARY_OP_ADD_FLOAT: int = 129,
     OP_BINARY_OP_ADD_INT: int = 130,
     OP_BINARY_OP_ADD_UNICODE: int = 131,
     OP_BINARY_OP_EXTEND: int = 132,
     OP_BINARY_OP_MULTIPLY_FLOAT: int = 133,
     OP_BINARY_OP_MULTIPLY_INT: int = 134,
     OP_BINARY_OP_SUBSCR_DICT: int = 135,
     OP_BINARY_OP_SUBSCR_GETITEM: int = 136,
     OP_BINARY_OP_SUBSCR_LIST_INT: int = 137,
     OP_BINARY_OP_SUBSCR_LIST_SLICE: int = 138,
     OP_BINARY_OP_SUBSCR_STR_INT: int = 139,
     OP_BINARY_OP_SUBSCR_TUPLE_INT: int = 140,
     OP_BINARY_OP_SUBTRACT_FLOAT: int = 141,
     OP_BINARY_OP_SUBTRACT_INT: int = 142,
     OP_CALL_ALLOC_AND_ENTER_INIT: int = 143,
     OP_CALL_BOUND_METHOD_EXACT_ARGS: int = 144,
     OP_CALL_BOUND_METHOD_GENERAL: int = 145,
     OP_CALL_BUILTIN_CLASS: int = 146,
     OP_CALL_BUILTIN_FAST: int = 147,
     OP_CALL_BUILTIN_FAST_WITH_KEYWORDS: int = 148,
     OP_CALL_BUILTIN_O: int = 149,
     OP_CALL_ISINSTANCE: int = 150,
     OP_CALL_KW_BOUND_METHOD: int = 151,
     OP_CALL_KW_NON_PY: int = 152,
     OP_CALL_KW_PY: int = 153,
     OP_CALL_LEN: int = 154,
     OP_CALL_LIST_APPEND: int = 155,
     OP_CALL_METHOD_DESCRIPTOR_FAST: int = 156,
     OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS: int = 157,
     OP_CALL_METHOD_DESCRIPTOR_NOARGS: int = 158,
     OP_CALL_METHOD_DESCRIPTOR_O: int = 159,
     OP_CALL_NON_PY_GENERAL: int = 160,
     OP_CALL_PY_EXACT_ARGS: int = 161,
     OP_CALL_PY_GENERAL: int = 162,
     OP_CALL_STR_1: int = 163,
     OP_CALL_TUPLE_1: int = 164,
     OP_CALL_TYPE_1: int = 165,
     OP_COMPARE_OP_FLOAT: int = 166,
     OP_COMPARE_OP_INT: int = 167,
     OP_COMPARE_OP_STR: int = 168,
     OP_CONTAINS_OP_DICT: int = 169,
     OP_CONTAINS_OP_SET: int = 170,
     OP_FOR_ITER_GEN: int = 171,
     OP_FOR_ITER_LIST: int = 172,
     OP_FOR_ITER_RANGE: int = 173,
     OP_FOR_ITER_TUPLE: int = 174,
     OP_JUMP_BACKWARD_JIT: int = 175,
     OP_JUMP_BACKWARD_NO_JIT: int = 176,
     OP_LOAD_ATTR_CLASS: int = 177,
     OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK: int = 178,
     OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN: int = 179,
     OP_LOAD_ATTR_INSTANCE_VALUE: int = 180,
     OP_LOAD_ATTR_METHOD_LAZY_DICT: int = 181,
     OP_LOAD_ATTR_METHOD_NO_DICT: int = 182,
     OP_LOAD_ATTR_METHOD_WITH_VALUES: int = 183,
     OP_LOAD_ATTR_MODULE: int = 184,
     OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT: int = 185,
     OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES: int = 186,
     OP_LOAD_ATTR_PROPERTY: int = 187,
     OP_LOAD_ATTR_SLOT: int = 188,
     OP_LOAD_ATTR_WITH_HINT: int = 189,
     OP_LOAD_CONST_IMMORTAL: int = 190,
     OP_LOAD_CONST_MORTAL: int = 191,
     OP_LOAD_GLOBAL_BUILTIN: int = 192,
     OP_LOAD_GLOBAL_MODULE: int = 193,
     OP_LOAD_SUPER_ATTR_ATTR: int = 194,
     OP_LOAD_SUPER_ATTR_METHOD: int = 195,
     OP_RESUME_CHECK: int = 196,
     OP_SEND_GEN: int = 197,
     OP_STORE_ATTR_INSTANCE_VALUE: int = 198,
     OP_STORE_ATTR_SLOT: int = 199,
     OP_STORE_ATTR_WITH_HINT: int = 200,
     OP_STORE_SUBSCR_DICT: int = 201,
     OP_STORE_SUBSCR_LIST_INT: int = 202,
     OP_TO_BOOL_ALWAYS_TRUE: int = 203,
     OP_TO_BOOL_BOOL: int = 204,
     OP_TO_BOOL_INT: int = 205,
     OP_TO_BOOL_LIST: int = 206,
     OP_TO_BOOL_NONE: int = 207,
     OP_TO_BOOL_STR: int = 208,
     OP_UNPACK_SEQUENCE_LIST: int = 209,
     OP_UNPACK_SEQUENCE_TUPLE: int = 210,
     OP_UNPACK_SEQUENCE_TWO_TUPLE: int = 211,
     OP_INSTRUMENTED_END_FOR: int = 234,
     OP_INSTRUMENTED_POP_ITER: int = 235,
     OP_INSTRUMENTED_END_SEND: int = 236,
     OP_INSTRUMENTED_FOR_ITER: int = 237,
     OP_INSTRUMENTED_INSTRUCTION: int = 238,
     OP_INSTRUMENTED_JUMP_FORWARD: int = 239,
     OP_INSTRUMENTED_NOT_TAKEN: int = 240,
     OP_INSTRUMENTED_POP_JUMP_IF_TRUE: int = 241,
     OP_INSTRUMENTED_POP_JUMP_IF_FALSE: int = 242,
     OP_INSTRUMENTED_POP_JUMP_IF_NONE: int = 243,
     OP_INSTRUMENTED_POP_JUMP_IF_NOT_NONE: int = 244,
     OP_INSTRUMENTED_RESUME: int = 245,
     OP_INSTRUMENTED_RETURN_VALUE: int = 246,
     OP_INSTRUMENTED_YIELD_VALUE: int = 247,
     OP_INSTRUMENTED_END_ASYNC_FOR: int = 248,
     OP_INSTRUMENTED_LOAD_SUPER_ATTR: int = 249,
     OP_INSTRUMENTED_CALL: int = 250,
     OP_INSTRUMENTED_CALL_KW: int = 251,
     OP_INSTRUMENTED_CALL_FUNCTION_EX: int = 252,
     OP_INSTRUMENTED_JUMP_BACKWARD: int = 253,
     OP_INSTRUMENTED_LINE: int = 254,
     OP_ENTER_EXECUTOR: int = 255,
     OP_ANNOTATIONS_PLACEHOLDER: int = 256,
     OP_JUMP: int = 257,
     OP_JUMP_IF_FALSE: int = 258,
     OP_JUMP_IF_TRUE: int = 259,
     OP_JUMP_NO_INTERRUPT: int = 260,
     OP_LOAD_CLOSURE: int = 261,
     OP_POP_BLOCK: int = 262,
     OP_SETUP_CLEANUP: int = 263,
     OP_SETUP_FINALLY: int = 264,
     OP_SETUP_WITH: int = 265,
     OP_STORE_FAST_MAYBE_NULL: int = 266;

# ---------------- binary-operator ids (opcode.h NB_*) ----------------
glob NB_ADD: int = 0,
     NB_AND: int = 1,
     NB_FLOOR_DIVIDE: int = 2,
     NB_LSHIFT: int = 3,
     NB_MATRIX_MULTIPLY: int = 4,
     NB_MULTIPLY: int = 5,
     NB_REMAINDER: int = 6,
     NB_OR: int = 7,
     NB_POWER: int = 8,
     NB_RSHIFT: int = 9,
     NB_SUBTRACT: int = 10,
     NB_TRUE_DIVIDE: int = 11,
     NB_XOR: int = 12,
     NB_INPLACE_ADD: int = 13,
     NB_INPLACE_AND: int = 14,
     NB_INPLACE_FLOOR_DIVIDE: int = 15,
     NB_INPLACE_LSHIFT: int = 16,
     NB_INPLACE_MATRIX_MULTIPLY: int = 17,
     NB_INPLACE_MULTIPLY: int = 18,
     NB_INPLACE_REMAINDER: int = 19,
     NB_INPLACE_OR: int = 20,
     NB_INPLACE_POWER: int = 21,
     NB_INPLACE_RSHIFT: int = 22,
     NB_INPLACE_SUBTRACT: int = 23,
     NB_INPLACE_TRUE_DIVIDE: int = 24,
     NB_INPLACE_XOR: int = 25,
     NB_SUBSCR: int = 26,
     NB_OPARG_LAST: int = 26;

# ---------------- rich-compare kinds (cmp_op tuple order) ----------------
glob CMP_LT: int = 0,
     CMP_LE: int = 1,
     CMP_EQ: int = 2,
     CMP_NE: int = 3,
     CMP_GT: int = 4,
     CMP_GE: int = 5;

# ---------------- compare masks (pycore_code.h COMPARISON_*) ----------------
glob COMPARISON_EQUALS: int = 8,
     COMPARISON_GREATER_THAN: int = 4,
     COMPARISON_LESS_THAN: int = 2,
     COMPARISON_NOT_EQUALS: int = 7,
     COMPARISON_UNORDERED: int = 1;

# COMPARE_OP oparg low bits (codegen.c compare_masks[]).
def compare_mask(cmp_kind: int) -> int {
    if cmp_kind == CMP_LT {
        return 2;
    }
    if cmp_kind == CMP_LE {
        return 10;
    }
    if cmp_kind == CMP_EQ {
        return 8;
    }
    if cmp_kind == CMP_NE {
        return 7;
    }
    if cmp_kind == CMP_GT {
        return 4;
    }
    if cmp_kind == CMP_GE {
        return 12;
    }
    return 0;
}

# cmp_kind in top three bits, compare mask in low four (codegen.c).
def compare_oparg(cmp_kind: int) -> int {
    return (cmp_kind << 5) | compare_mask(cmp_kind);
}

# Bool-context filters set the fifth-lowest bit (codegen.c).
def compare_filter_oparg(cmp_kind: int) -> int {
    return compare_oparg(cmp_kind) | 16;
}

# ---------------- code-object flags (code.h CO_*) ----------------
glob CO_OPTIMIZED: int = 1,
     CO_NEWLOCALS: int = 2,
     CO_VARARGS: int = 4,
     CO_VARKEYWORDS: int = 8,
     CO_NESTED: int = 16,
     CO_GENERATOR: int = 32,
     CO_COROUTINE: int = 128,
     CO_ITERABLE_COROUTINE: int = 256,
     CO_ASYNC_GENERATOR: int = 512,
     CO_FUTURE_DIVISION: int = 131072,
     CO_FUTURE_WITH_STATEMENT: int = 524288,
     CO_FUTURE_PRINT_FUNCTION: int = 1048576,
     CO_FUTURE_UNICODE_LITERALS: int = 2097152,
     CO_FUTURE_BARRY_AS_BDFL: int = 4194304,
     CO_FUTURE_GENERATOR_STOP: int = 8388608,
     CO_FUTURE_ANNOTATIONS: int = 16777216,
     CO_NO_MONITORING_EVENTS: int = 33554432,
     CO_HAS_DOCSTRING: int = 67108864,
     CO_METHOD: int = 134217728;

# co_localspluskinds bits (Include/internal/pycore_code.h).
glob CO_FAST_HIDDEN: int = 16,
     CO_FAST_LOCAL: int = 32,
     CO_FAST_CELL: int = 64,
     CO_FAST_FREE: int = 128;

# CPython locals-plus kind bit flags (marshal reader / symtable contract).
glob LP_LOCAL: int = 32,
     LP_CELL: int = 64,
     LP_FREE: int = 128;

# Inline-cache unit counts (_PyOpcode_Caches).
glob _OPCODE_CACHE_COUNT: dict[int, int] = {
         OP_STORE_SUBSCR: 1,
         OP_TO_BOOL: 3,
         OP_BINARY_OP: 5,
         OP_CALL: 3,
         OP_CALL_KW: 3,
         OP_COMPARE_OP: 1,
         OP_CONTAINS_OP: 1,
         OP_FOR_ITER: 1,
         OP_JUMP_BACKWARD: 1,
         OP_LOAD_ATTR: 9,
         OP_LOAD_GLOBAL: 4,
         OP_LOAD_SUPER_ATTR: 1,
         OP_POP_JUMP_IF_FALSE: 1,
         OP_POP_JUMP_IF_NONE: 1,
         OP_POP_JUMP_IF_NOT_NONE: 1,
         OP_POP_JUMP_IF_TRUE: 1,
         OP_SEND: 1,
         OP_STORE_ATTR: 4,
         OP_UNPACK_SEQUENCE: 1
     };

def opcode_cache_count(op: int) -> int {
    return _OPCODE_CACHE_COUNT.get(op, 0);
}

glob _OPCODE_DEOPT_MAP: dict[int, int] = {
         OP_BINARY_OP_INPLACE_ADD_UNICODE: 44,
         OP_BINARY_OP_ADD_FLOAT: 44,
         OP_BINARY_OP_ADD_INT: 44,
         OP_BINARY_OP_ADD_UNICODE: 44,
         OP_BINARY_OP_EXTEND: 44,
         OP_BINARY_OP_MULTIPLY_FLOAT: 44,
         OP_BINARY_OP_MULTIPLY_INT: 44,
         OP_BINARY_OP_SUBSCR_DICT: 44,
         OP_BINARY_OP_SUBSCR_GETITEM: 44,
         OP_BINARY_OP_SUBSCR_LIST_INT: 44,
         OP_BINARY_OP_SUBSCR_LIST_SLICE: 44,
         OP_BINARY_OP_SUBSCR_STR_INT: 44,
         OP_BINARY_OP_SUBSCR_TUPLE_INT: 44,
         OP_BINARY_OP_SUBTRACT_FLOAT: 44,
         OP_BINARY_OP_SUBTRACT_INT: 44,
         OP_CALL_ALLOC_AND_ENTER_INIT: 52,
         OP_CALL_BOUND_METHOD_EXACT_ARGS: 52,
         OP_CALL_BOUND_METHOD_GENERAL: 52,
         OP_CALL_BUILTIN_CLASS: 52,
         OP_CALL_BUILTIN_FAST: 52,
         OP_CALL_BUILTIN_FAST_WITH_KEYWORDS: 52,
         OP_CALL_BUILTIN_O: 52,
         OP_CALL_ISINSTANCE: 52,
         OP_CALL_KW_BOUND_METHOD: 55,
         OP_CALL_KW_NON_PY: 55,
         OP_CALL_KW_PY: 55,
         OP_CALL_LEN: 52,
         OP_CALL_LIST_APPEND: 52,
         OP_CALL_METHOD_DESCRIPTOR_FAST: 52,
         OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS: 52,
         OP_CALL_METHOD_DESCRIPTOR_NOARGS: 52,
         OP_CALL_METHOD_DESCRIPTOR_O: 52,
         OP_CALL_NON_PY_GENERAL: 52,
         OP_CALL_PY_EXACT_ARGS: 52,
         OP_CALL_PY_GENERAL: 52,
         OP_CALL_STR_1: 52,
         OP_CALL_TUPLE_1: 52,
         OP_CALL_TYPE_1: 52,
         OP_COMPARE_OP_FLOAT: 56,
         OP_COMPARE_OP_INT: 56,
         OP_COMPARE_OP_STR: 56,
         OP_CONTAINS_OP_DICT: 57,
         OP_CONTAINS_OP_SET: 57,
         OP_FOR_ITER_GEN: 70,
         OP_FOR_ITER_LIST: 70,
         OP_FOR_ITER_RANGE: 70,
         OP_FOR_ITER_TUPLE: 70,
         OP_JUMP_BACKWARD_JIT: 75,
         OP_JUMP_BACKWARD_NO_JIT: 75,
         OP_LOAD_ATTR_CLASS: 80,
         OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK: 80,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN: 80,
         OP_LOAD_ATTR_INSTANCE_VALUE: 80,
         OP_LOAD_ATTR_METHOD_LAZY_DICT: 80,
         OP_LOAD_ATTR_METHOD_NO_DICT: 80,
         OP_LOAD_ATTR_METHOD_WITH_VALUES: 80,
         OP_LOAD_ATTR_MODULE: 80,
         OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT: 80,
         OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES: 80,
         OP_LOAD_ATTR_PROPERTY: 80,
         OP_LOAD_ATTR_SLOT: 80,
         OP_LOAD_ATTR_WITH_HINT: 80,
         OP_LOAD_CONST_IMMORTAL: 82,
         OP_LOAD_CONST_MORTAL: 82,
         OP_LOAD_GLOBAL_BUILTIN: 92,
         OP_LOAD_GLOBAL_MODULE: 92,
         OP_LOAD_SUPER_ATTR_ATTR: 96,
         OP_LOAD_SUPER_ATTR_METHOD: 96,
         OP_RESUME_CHECK: 128,
         OP_SEND_GEN: 106,
         OP_STORE_ATTR_INSTANCE_VALUE: 110,
         OP_STORE_ATTR_SLOT: 110,
         OP_STORE_ATTR_WITH_HINT: 110,
         OP_STORE_SUBSCR_DICT: 38,
         OP_STORE_SUBSCR_LIST_INT: 38,
         OP_TO_BOOL_ALWAYS_TRUE: 39,
         OP_TO_BOOL_BOOL: 39,
         OP_TO_BOOL_INT: 39,
         OP_TO_BOOL_LIST: 39,
         OP_TO_BOOL_NONE: 39,
         OP_TO_BOOL_STR: 39,
         OP_UNPACK_SEQUENCE_LIST: 119,
         OP_UNPACK_SEQUENCE_TUPLE: 119,
         OP_UNPACK_SEQUENCE_TWO_TUPLE: 119
     };

def opcode_deopt_target(op: int) -> int {
    if op < 0 or op > 254 {
        return op;
    }
    return _OPCODE_DEOPT_MAP.get(op, op);
}

glob _POPPED_0_SET: set[int] = {
         OP_ANNOTATIONS_PLACEHOLDER,
         OP_CACHE,
         OP_COPY_FREE_VARS,
         OP_DELETE_DEREF,
         OP_DELETE_FAST,
         OP_DELETE_GLOBAL,
         OP_DELETE_NAME,
         OP_ENTER_EXECUTOR,
         OP_EXTENDED_ARG,
         OP_INSTRUMENTED_INSTRUCTION,
         OP_INSTRUMENTED_JUMP_BACKWARD,
         OP_INSTRUMENTED_JUMP_FORWARD,
         OP_INSTRUMENTED_LINE,
         OP_INSTRUMENTED_NOT_TAKEN,
         OP_INSTRUMENTED_RESUME,
         OP_JUMP,
         OP_JUMP_BACKWARD,
         OP_JUMP_BACKWARD_JIT,
         OP_JUMP_BACKWARD_NO_INTERRUPT,
         OP_JUMP_BACKWARD_NO_JIT,
         OP_JUMP_FORWARD,
         OP_JUMP_NO_INTERRUPT,
         OP_LOAD_BUILD_CLASS,
         OP_LOAD_CLOSURE,
         OP_LOAD_COMMON_CONSTANT,
         OP_LOAD_CONST,
         OP_LOAD_CONST_IMMORTAL,
         OP_LOAD_CONST_MORTAL,
         OP_LOAD_DEREF,
         OP_LOAD_FAST,
         OP_LOAD_FAST_AND_CLEAR,
         OP_LOAD_FAST_BORROW,
         OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
         OP_LOAD_FAST_CHECK,
         OP_LOAD_FAST_LOAD_FAST,
         OP_LOAD_GLOBAL,
         OP_LOAD_GLOBAL_BUILTIN,
         OP_LOAD_GLOBAL_MODULE,
         OP_LOAD_LOCALS,
         OP_LOAD_NAME,
         OP_LOAD_SMALL_INT,
         OP_MAKE_CELL,
         OP_NOP,
         OP_NOT_TAKEN,
         OP_POP_BLOCK,
         OP_PUSH_NULL,
         OP_RESERVED,
         OP_RESUME,
         OP_RESUME_CHECK,
         OP_RETURN_GENERATOR,
         OP_SETUP_ANNOTATIONS,
         OP_SETUP_CLEANUP,
         OP_SETUP_FINALLY,
         OP_SETUP_WITH
     },
     _POPPED_1_SET: set[int] = {
         OP_CALL_INTRINSIC_1,
         OP_CONVERT_VALUE,
         OP_DELETE_ATTR,
         OP_END_FOR,
         OP_EXIT_INIT_CHECK,
         OP_FORMAT_SIMPLE,
         OP_FOR_ITER,
         OP_FOR_ITER_GEN,
         OP_FOR_ITER_LIST,
         OP_FOR_ITER_RANGE,
         OP_FOR_ITER_TUPLE,
         OP_GET_AITER,
         OP_GET_ANEXT,
         OP_GET_AWAITABLE,
         OP_GET_ITER,
         OP_GET_LEN,
         OP_GET_YIELD_FROM_ITER,
         OP_IMPORT_FROM,
         OP_INSTRUMENTED_FOR_ITER,
         OP_INSTRUMENTED_POP_ITER,
         OP_INSTRUMENTED_POP_JUMP_IF_FALSE,
         OP_INSTRUMENTED_POP_JUMP_IF_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_NOT_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_TRUE,
         OP_INSTRUMENTED_RETURN_VALUE,
         OP_INSTRUMENTED_YIELD_VALUE,
         OP_INTERPRETER_EXIT,
         OP_JUMP_IF_FALSE,
         OP_JUMP_IF_TRUE,
         OP_LOAD_ATTR,
         OP_LOAD_ATTR_CLASS,
         OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN,
         OP_LOAD_ATTR_INSTANCE_VALUE,
         OP_LOAD_ATTR_METHOD_LAZY_DICT,
         OP_LOAD_ATTR_METHOD_NO_DICT,
         OP_LOAD_ATTR_METHOD_WITH_VALUES,
         OP_LOAD_ATTR_MODULE,
         OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT,
         OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES,
         OP_LOAD_ATTR_PROPERTY,
         OP_LOAD_ATTR_SLOT,
         OP_LOAD_ATTR_WITH_HINT,
         OP_LOAD_FROM_DICT_OR_DEREF,
         OP_LOAD_FROM_DICT_OR_GLOBALS,
         OP_LOAD_SPECIAL,
         OP_MAKE_FUNCTION,
         OP_MATCH_MAPPING,
         OP_MATCH_SEQUENCE,
         OP_POP_EXCEPT,
         OP_POP_ITER,
         OP_POP_JUMP_IF_FALSE,
         OP_POP_JUMP_IF_NONE,
         OP_POP_JUMP_IF_NOT_NONE,
         OP_POP_JUMP_IF_TRUE,
         OP_POP_TOP,
         OP_PUSH_EXC_INFO,
         OP_RETURN_VALUE,
         OP_STORE_DEREF,
         OP_STORE_FAST,
         OP_STORE_FAST_LOAD_FAST,
         OP_STORE_FAST_MAYBE_NULL,
         OP_STORE_GLOBAL,
         OP_STORE_NAME,
         OP_TO_BOOL,
         OP_TO_BOOL_ALWAYS_TRUE,
         OP_TO_BOOL_BOOL,
         OP_TO_BOOL_INT,
         OP_TO_BOOL_LIST,
         OP_TO_BOOL_NONE,
         OP_TO_BOOL_STR,
         OP_UNARY_INVERT,
         OP_UNARY_NEGATIVE,
         OP_UNARY_NOT,
         OP_UNPACK_EX,
         OP_UNPACK_SEQUENCE,
         OP_UNPACK_SEQUENCE_LIST,
         OP_UNPACK_SEQUENCE_TUPLE,
         OP_UNPACK_SEQUENCE_TWO_TUPLE,
         OP_YIELD_VALUE
     },
     _POPPED_2_SET: set[int] = {
         OP_BINARY_OP,
         OP_BINARY_OP_ADD_FLOAT,
         OP_BINARY_OP_ADD_INT,
         OP_BINARY_OP_ADD_UNICODE,
         OP_BINARY_OP_EXTEND,
         OP_BINARY_OP_INPLACE_ADD_UNICODE,
         OP_BINARY_OP_MULTIPLY_FLOAT,
         OP_BINARY_OP_MULTIPLY_INT,
         OP_BINARY_OP_SUBSCR_DICT,
         OP_BINARY_OP_SUBSCR_GETITEM,
         OP_BINARY_OP_SUBSCR_LIST_INT,
         OP_BINARY_OP_SUBSCR_LIST_SLICE,
         OP_BINARY_OP_SUBSCR_STR_INT,
         OP_BINARY_OP_SUBSCR_TUPLE_INT,
         OP_BINARY_OP_SUBTRACT_FLOAT,
         OP_BINARY_OP_SUBTRACT_INT,
         OP_BUILD_TEMPLATE,
         OP_CALL_INTRINSIC_2,
         OP_CHECK_EG_MATCH,
         OP_CHECK_EXC_MATCH,
         OP_COMPARE_OP,
         OP_COMPARE_OP_FLOAT,
         OP_COMPARE_OP_INT,
         OP_COMPARE_OP_STR,
         OP_CONTAINS_OP,
         OP_CONTAINS_OP_DICT,
         OP_CONTAINS_OP_SET,
         OP_DELETE_SUBSCR,
         OP_END_ASYNC_FOR,
         OP_END_SEND,
         OP_FORMAT_WITH_SPEC,
         OP_IMPORT_NAME,
         OP_INSTRUMENTED_END_ASYNC_FOR,
         OP_INSTRUMENTED_END_FOR,
         OP_INSTRUMENTED_END_SEND,
         OP_IS_OP,
         OP_MATCH_KEYS,
         OP_SEND,
         OP_SEND_GEN,
         OP_SET_FUNCTION_ATTRIBUTE,
         OP_STORE_ATTR,
         OP_STORE_ATTR_INSTANCE_VALUE,
         OP_STORE_ATTR_SLOT,
         OP_STORE_ATTR_WITH_HINT,
         OP_STORE_FAST_STORE_FAST
     },
     _POPPED_3_SET: set[int] = {
         OP_BINARY_SLICE,
         OP_CALL_LEN,
         OP_CALL_LIST_APPEND,
         OP_CALL_STR_1,
         OP_CALL_TUPLE_1,
         OP_CALL_TYPE_1,
         OP_CLEANUP_THROW,
         OP_INSTRUMENTED_LOAD_SUPER_ATTR,
         OP_LOAD_SUPER_ATTR,
         OP_LOAD_SUPER_ATTR_ATTR,
         OP_LOAD_SUPER_ATTR_METHOD,
         OP_MATCH_CLASS,
         OP_STORE_SUBSCR,
         OP_STORE_SUBSCR_DICT,
         OP_STORE_SUBSCR_LIST_INT
     };

def _opcode_num_popped(op: int, oparg: int) -> int {
    if op in _POPPED_0_SET {
        return 0;
    }
    if op in _POPPED_1_SET {
        return 1;
    }
    if op in _POPPED_2_SET {
        return 2;
    }
    if op in _POPPED_3_SET {
        return 3;
    }

    if op == OP_BUILD_INTERPOLATION {
        return 2 + (oparg & 1);
    }
    if op == OP_BUILD_LIST {
        return oparg;
    }
    if op == OP_BUILD_MAP {
        return oparg * 2;
    }
    if op == OP_BUILD_SET {
        return oparg;
    }
    if op == OP_BUILD_SLICE {
        return oparg;
    }
    if op == OP_BUILD_STRING {
        return oparg;
    }
    if op == OP_BUILD_TUPLE {
        return oparg;
    }
    if op == OP_CALL {
        return 2 + oparg;
    }
    if op == OP_CALL_ALLOC_AND_ENTER_INIT {
        return 2 + oparg;
    }
    if op == OP_CALL_BOUND_METHOD_EXACT_ARGS {
        return 2 + oparg;
    }
    if op == OP_CALL_BOUND_METHOD_GENERAL {
        return 2 + oparg;
    }
    if op == OP_CALL_BUILTIN_CLASS {
        return 2 + oparg;
    }
    if op == OP_CALL_BUILTIN_FAST {
        return 2 + oparg;
    }
    if op == OP_CALL_BUILTIN_FAST_WITH_KEYWORDS {
        return 2 + oparg;
    }
    if op == OP_CALL_BUILTIN_O {
        return 2 + oparg;
    }
    if op == OP_CALL_FUNCTION_EX {
        return 4;
    }
    if op == OP_CALL_ISINSTANCE {
        return 2 + oparg;
    }
    if op == OP_CALL_KW {
        return 3 + oparg;
    }
    if op == OP_CALL_KW_BOUND_METHOD {
        return 3 + oparg;
    }
    if op == OP_CALL_KW_NON_PY {
        return 3 + oparg;
    }
    if op == OP_CALL_KW_PY {
        return 3 + oparg;
    }
    if op == OP_CALL_METHOD_DESCRIPTOR_FAST {
        return 2 + oparg;
    }
    if op == OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS {
        return 2 + oparg;
    }
    if op == OP_CALL_METHOD_DESCRIPTOR_NOARGS {
        return 2 + oparg;
    }
    if op == OP_CALL_METHOD_DESCRIPTOR_O {
        return 2 + oparg;
    }
    if op == OP_CALL_NON_PY_GENERAL {
        return 2 + oparg;
    }
    if op == OP_CALL_PY_EXACT_ARGS {
        return 2 + oparg;
    }
    if op == OP_CALL_PY_GENERAL {
        return 2 + oparg;
    }
    if op == OP_COPY {
        return 1 + (oparg - 1);
    }
    if op == OP_DICT_MERGE {
        return 5 + (oparg - 1);
    }
    if op == OP_DICT_UPDATE {
        return 2 + (oparg - 1);
    }
    if op == OP_INSTRUMENTED_CALL {
        return 2 + oparg;
    }
    if op == OP_INSTRUMENTED_CALL_FUNCTION_EX {
        return 4;
    }
    if op == OP_INSTRUMENTED_CALL_KW {
        return 3 + oparg;
    }
    if op == OP_LIST_APPEND {
        return 2 + (oparg - 1);
    }
    if op == OP_LIST_EXTEND {
        return 2 + (oparg - 1);
    }
    if op == OP_MAP_ADD {
        return 3 + (oparg - 1);
    }
    if op == OP_RAISE_VARARGS {
        return oparg;
    }
    if op == OP_RERAISE {
        return 1 + oparg;
    }
    if op == OP_SET_ADD {
        return 2 + (oparg - 1);
    }
    if op == OP_SET_UPDATE {
        return 2 + (oparg - 1);
    }
    if op == OP_STORE_SLICE {
        return 4;
    }
    if op == OP_SWAP {
        return 2 + (oparg - 2);
    }
    if op == OP_WITH_EXCEPT_START {
        return 5;
    }
    return -1;
}

glob _PUSHED_0_SET: set[int] = {
         OP_ANNOTATIONS_PLACEHOLDER,
         OP_BINARY_OP_INPLACE_ADD_UNICODE,
         OP_BINARY_OP_SUBSCR_GETITEM,
         OP_CACHE,
         OP_CALL_ALLOC_AND_ENTER_INIT,
         OP_CALL_BOUND_METHOD_EXACT_ARGS,
         OP_CALL_BOUND_METHOD_GENERAL,
         OP_CALL_KW_BOUND_METHOD,
         OP_CALL_KW_PY,
         OP_CALL_LIST_APPEND,
         OP_CALL_PY_EXACT_ARGS,
         OP_CALL_PY_GENERAL,
         OP_COPY_FREE_VARS,
         OP_DELETE_ATTR,
         OP_DELETE_DEREF,
         OP_DELETE_FAST,
         OP_DELETE_GLOBAL,
         OP_DELETE_NAME,
         OP_DELETE_SUBSCR,
         OP_END_ASYNC_FOR,
         OP_END_FOR,
         OP_ENTER_EXECUTOR,
         OP_EXIT_INIT_CHECK,
         OP_EXTENDED_ARG,
         OP_INSTRUMENTED_END_ASYNC_FOR,
         OP_INSTRUMENTED_INSTRUCTION,
         OP_INSTRUMENTED_JUMP_BACKWARD,
         OP_INSTRUMENTED_JUMP_FORWARD,
         OP_INSTRUMENTED_LINE,
         OP_INSTRUMENTED_NOT_TAKEN,
         OP_INSTRUMENTED_POP_ITER,
         OP_INSTRUMENTED_POP_JUMP_IF_FALSE,
         OP_INSTRUMENTED_POP_JUMP_IF_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_NOT_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_TRUE,
         OP_INSTRUMENTED_RESUME,
         OP_INTERPRETER_EXIT,
         OP_JUMP,
         OP_JUMP_BACKWARD,
         OP_JUMP_BACKWARD_JIT,
         OP_JUMP_BACKWARD_NO_INTERRUPT,
         OP_JUMP_BACKWARD_NO_JIT,
         OP_JUMP_FORWARD,
         OP_JUMP_NO_INTERRUPT,
         OP_LOAD_ATTR_PROPERTY,
         OP_MAKE_CELL,
         OP_NOP,
         OP_NOT_TAKEN,
         OP_POP_BLOCK,
         OP_POP_EXCEPT,
         OP_POP_ITER,
         OP_POP_JUMP_IF_FALSE,
         OP_POP_JUMP_IF_NONE,
         OP_POP_JUMP_IF_NOT_NONE,
         OP_POP_JUMP_IF_TRUE,
         OP_POP_TOP,
         OP_RAISE_VARARGS,
         OP_RESERVED,
         OP_RESUME,
         OP_RESUME_CHECK,
         OP_SETUP_ANNOTATIONS,
         OP_STORE_ATTR,
         OP_STORE_ATTR_INSTANCE_VALUE,
         OP_STORE_ATTR_SLOT,
         OP_STORE_ATTR_WITH_HINT,
         OP_STORE_DEREF,
         OP_STORE_FAST,
         OP_STORE_FAST_MAYBE_NULL,
         OP_STORE_FAST_STORE_FAST,
         OP_STORE_GLOBAL,
         OP_STORE_NAME,
         OP_STORE_SLICE,
         OP_STORE_SUBSCR,
         OP_STORE_SUBSCR_DICT,
         OP_STORE_SUBSCR_LIST_INT
     },
     _PUSHED_1_SET: set[int] = {
         OP_BINARY_OP,
         OP_BINARY_OP_ADD_FLOAT,
         OP_BINARY_OP_ADD_INT,
         OP_BINARY_OP_ADD_UNICODE,
         OP_BINARY_OP_EXTEND,
         OP_BINARY_OP_MULTIPLY_FLOAT,
         OP_BINARY_OP_MULTIPLY_INT,
         OP_BINARY_OP_SUBSCR_DICT,
         OP_BINARY_OP_SUBSCR_LIST_INT,
         OP_BINARY_OP_SUBSCR_LIST_SLICE,
         OP_BINARY_OP_SUBSCR_STR_INT,
         OP_BINARY_OP_SUBSCR_TUPLE_INT,
         OP_BINARY_OP_SUBTRACT_FLOAT,
         OP_BINARY_OP_SUBTRACT_INT,
         OP_BINARY_SLICE,
         OP_BUILD_INTERPOLATION,
         OP_BUILD_LIST,
         OP_BUILD_MAP,
         OP_BUILD_SET,
         OP_BUILD_SLICE,
         OP_BUILD_STRING,
         OP_BUILD_TEMPLATE,
         OP_BUILD_TUPLE,
         OP_CALL,
         OP_CALL_BUILTIN_CLASS,
         OP_CALL_BUILTIN_FAST,
         OP_CALL_BUILTIN_FAST_WITH_KEYWORDS,
         OP_CALL_BUILTIN_O,
         OP_CALL_FUNCTION_EX,
         OP_CALL_INTRINSIC_1,
         OP_CALL_INTRINSIC_2,
         OP_CALL_ISINSTANCE,
         OP_CALL_KW,
         OP_CALL_KW_NON_PY,
         OP_CALL_LEN,
         OP_CALL_METHOD_DESCRIPTOR_FAST,
         OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS,
         OP_CALL_METHOD_DESCRIPTOR_NOARGS,
         OP_CALL_METHOD_DESCRIPTOR_O,
         OP_CALL_NON_PY_GENERAL,
         OP_CALL_STR_1,
         OP_CALL_TUPLE_1,
         OP_CALL_TYPE_1,
         OP_COMPARE_OP,
         OP_COMPARE_OP_FLOAT,
         OP_COMPARE_OP_INT,
         OP_COMPARE_OP_STR,
         OP_CONTAINS_OP,
         OP_CONTAINS_OP_DICT,
         OP_CONTAINS_OP_SET,
         OP_CONVERT_VALUE,
         OP_END_SEND,
         OP_FORMAT_SIMPLE,
         OP_FORMAT_WITH_SPEC,
         OP_FOR_ITER_GEN,
         OP_GET_AITER,
         OP_GET_AWAITABLE,
         OP_GET_ITER,
         OP_GET_YIELD_FROM_ITER,
         OP_IMPORT_NAME,
         OP_INSTRUMENTED_CALL,
         OP_INSTRUMENTED_CALL_FUNCTION_EX,
         OP_INSTRUMENTED_CALL_KW,
         OP_INSTRUMENTED_END_FOR,
         OP_INSTRUMENTED_END_SEND,
         OP_INSTRUMENTED_RETURN_VALUE,
         OP_INSTRUMENTED_YIELD_VALUE,
         OP_IS_OP,
         OP_JUMP_IF_FALSE,
         OP_JUMP_IF_TRUE,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN,
         OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT,
         OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES,
         OP_LOAD_BUILD_CLASS,
         OP_LOAD_CLOSURE,
         OP_LOAD_COMMON_CONSTANT,
         OP_LOAD_CONST,
         OP_LOAD_CONST_IMMORTAL,
         OP_LOAD_CONST_MORTAL,
         OP_LOAD_DEREF,
         OP_LOAD_FAST,
         OP_LOAD_FAST_AND_CLEAR,
         OP_LOAD_FAST_BORROW,
         OP_LOAD_FAST_CHECK,
         OP_LOAD_FROM_DICT_OR_DEREF,
         OP_LOAD_FROM_DICT_OR_GLOBALS,
         OP_LOAD_LOCALS,
         OP_LOAD_NAME,
         OP_LOAD_SMALL_INT,
         OP_LOAD_SUPER_ATTR_ATTR,
         OP_MAKE_FUNCTION,
         OP_MATCH_CLASS,
         OP_PUSH_NULL,
         OP_RETURN_GENERATOR,
         OP_RETURN_VALUE,
         OP_SEND_GEN,
         OP_SETUP_FINALLY,
         OP_SETUP_WITH,
         OP_SET_FUNCTION_ATTRIBUTE,
         OP_STORE_FAST_LOAD_FAST,
         OP_TO_BOOL,
         OP_TO_BOOL_ALWAYS_TRUE,
         OP_TO_BOOL_BOOL,
         OP_TO_BOOL_INT,
         OP_TO_BOOL_LIST,
         OP_TO_BOOL_NONE,
         OP_TO_BOOL_STR,
         OP_UNARY_INVERT,
         OP_UNARY_NEGATIVE,
         OP_UNARY_NOT,
         OP_YIELD_VALUE
     },
     _PUSHED_2_SET: set[int] = {
         OP_CHECK_EG_MATCH,
         OP_CHECK_EXC_MATCH,
         OP_CLEANUP_THROW,
         OP_FOR_ITER,
         OP_FOR_ITER_LIST,
         OP_FOR_ITER_RANGE,
         OP_FOR_ITER_TUPLE,
         OP_GET_ANEXT,
         OP_GET_LEN,
         OP_IMPORT_FROM,
         OP_INSTRUMENTED_FOR_ITER,
         OP_LOAD_ATTR_METHOD_LAZY_DICT,
         OP_LOAD_ATTR_METHOD_NO_DICT,
         OP_LOAD_ATTR_METHOD_WITH_VALUES,
         OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
         OP_LOAD_FAST_LOAD_FAST,
         OP_LOAD_SPECIAL,
         OP_LOAD_SUPER_ATTR_METHOD,
         OP_MATCH_MAPPING,
         OP_MATCH_SEQUENCE,
         OP_PUSH_EXC_INFO,
         OP_SEND,
         OP_SETUP_CLEANUP,
         OP_UNPACK_SEQUENCE_TWO_TUPLE
     };

def _opcode_num_pushed(op: int, oparg: int) -> int {
    if op in _PUSHED_0_SET {
        return 0;
    }
    if op in _PUSHED_1_SET {
        return 1;
    }
    if op in _PUSHED_2_SET {
        return 2;
    }

    if op == OP_COPY {
        return 2 + (oparg - 1);
    }
    if op == OP_DICT_MERGE {
        return 4 + (oparg - 1);
    }
    if op == OP_DICT_UPDATE {
        return 1 + (oparg - 1);
    }
    if op == OP_INSTRUMENTED_LOAD_SUPER_ATTR {
        return 1 + (oparg & 1);
    }
    if op == OP_LIST_APPEND {
        return 1 + (oparg - 1);
    }
    if op == OP_LIST_EXTEND {
        return 1 + (oparg - 1);
    }
    if op == OP_LOAD_ATTR {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_CLASS {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_INSTANCE_VALUE {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_MODULE {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_SLOT {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_ATTR_WITH_HINT {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_GLOBAL {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_GLOBAL_BUILTIN {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_GLOBAL_MODULE {
        return 1 + (oparg & 1);
    }
    if op == OP_LOAD_SUPER_ATTR {
        return 1 + (oparg & 1);
    }
    if op == OP_MAP_ADD {
        return 1 + (oparg - 1);
    }
    if op == OP_MATCH_KEYS {
        return 3;
    }
    if op == OP_RERAISE {
        return oparg;
    }
    if op == OP_SET_ADD {
        return 1 + (oparg - 1);
    }
    if op == OP_SET_UPDATE {
        return 1 + (oparg - 1);
    }
    if op == OP_SWAP {
        return 2 + (oparg - 2);
    }
    if op == OP_UNPACK_EX {
        return 1 + (oparg & 0xFF) + (oparg >> 8);
    }
    if op == OP_UNPACK_SEQUENCE {
        return oparg;
    }
    if op == OP_UNPACK_SEQUENCE_LIST {
        return oparg;
    }
    if op == OP_UNPACK_SEQUENCE_TUPLE {
        return oparg;
    }
    if op == OP_WITH_EXCEPT_START {
        return 6;
    }
    return -1;
}

# Net stack effect (flowgraph.c get_stack_effects). jump: 0=fallthrough,
# 1=taken target, -1=maximal (unused on the CFG path).
def stack_effect(op: int, oparg: int, jump: int) -> int | None {
    if op < 0 {
        return None;
    }
    if op <= MAX_REAL_OPCODE {
        deopt = opcode_deopt_target(op);
        if deopt != op {
            return None;
        }
    }
    popped = _opcode_num_popped(op, oparg);
    pushed = _opcode_num_pushed(op, oparg);
    if popped < 0 or pushed < 0 {
        return None;
    }
    if is_block_push_opcode(op) and jump == 0 {
        return 0;
    }
    return pushed - popped;
}

def is_block_push_opcode(op: int) -> bool {
    if op == OP_SETUP_FINALLY or op == OP_SETUP_WITH or op == OP_SETUP_CLEANUP {
        return True;
    }
    return False;
}

def has_target(op: int) -> bool {
    if op == OP_END_ASYNC_FOR
        or op == OP_FOR_ITER
        or op == OP_FOR_ITER_LIST
        or op == OP_FOR_ITER_RANGE
        or op == OP_FOR_ITER_TUPLE
        or op == OP_INSTRUMENTED_END_ASYNC_FOR
        or op == OP_INSTRUMENTED_FOR_ITER
        or op == OP_JUMP
        or op == OP_JUMP_BACKWARD
        or op == OP_JUMP_BACKWARD_JIT
        or op == OP_JUMP_BACKWARD_NO_INTERRUPT
        or op == OP_JUMP_BACKWARD_NO_JIT
        or op == OP_JUMP_FORWARD
        or op == OP_JUMP_IF_FALSE
        or op == OP_JUMP_IF_TRUE
        or op == OP_JUMP_NO_INTERRUPT
        or op == OP_POP_JUMP_IF_FALSE
        or op == OP_POP_JUMP_IF_NONE
        or op == OP_POP_JUMP_IF_NOT_NONE
        or op == OP_POP_JUMP_IF_TRUE
        or op == OP_SEND
        or op == OP_SETUP_CLEANUP
        or op == OP_SETUP_FINALLY
        or op == OP_SETUP_WITH {
        return True;
    }
    return False;
}

def is_unconditional_jump_opcode(op: int) -> bool {
    if op == OP_JUMP
        or op == OP_JUMP_NO_INTERRUPT
        or op == OP_JUMP_FORWARD
        or op == OP_JUMP_BACKWARD
        or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
        return True;
    }
    return False;
}

def is_scope_exit_opcode(op: int) -> bool {
    if op == OP_RETURN_VALUE or op == OP_RAISE_VARARGS or op == OP_RERAISE {
        return True;
    }
    return False;
}

def is_assembler_opcode(op: int) -> bool {
    if op == OP_JUMP_FORWARD
        or op == OP_JUMP_BACKWARD
        or op == OP_JUMP_BACKWARD_NO_INTERRUPT {
        return True;
    }
    return False;
}

glob _OPCODE_IS_VALID_SET: set[int] = {
         OP_CACHE,
         OP_BINARY_SLICE,
         OP_BUILD_TEMPLATE,
         OP_BINARY_OP_INPLACE_ADD_UNICODE,
         OP_CALL_FUNCTION_EX,
         OP_CHECK_EG_MATCH,
         OP_CHECK_EXC_MATCH,
         OP_CLEANUP_THROW,
         OP_DELETE_SUBSCR,
         OP_END_FOR,
         OP_END_SEND,
         OP_EXIT_INIT_CHECK,
         OP_FORMAT_SIMPLE,
         OP_FORMAT_WITH_SPEC,
         OP_GET_AITER,
         OP_GET_ANEXT,
         OP_GET_ITER,
         OP_RESERVED,
         OP_GET_LEN,
         OP_GET_YIELD_FROM_ITER,
         OP_INTERPRETER_EXIT,
         OP_LOAD_BUILD_CLASS,
         OP_LOAD_LOCALS,
         OP_MAKE_FUNCTION,
         OP_MATCH_KEYS,
         OP_MATCH_MAPPING,
         OP_MATCH_SEQUENCE,
         OP_NOP,
         OP_NOT_TAKEN,
         OP_POP_EXCEPT,
         OP_POP_ITER,
         OP_POP_TOP,
         OP_PUSH_EXC_INFO,
         OP_PUSH_NULL,
         OP_RETURN_GENERATOR,
         OP_RETURN_VALUE,
         OP_SETUP_ANNOTATIONS,
         OP_STORE_SLICE,
         OP_STORE_SUBSCR,
         OP_TO_BOOL,
         OP_UNARY_INVERT,
         OP_UNARY_NEGATIVE,
         OP_UNARY_NOT,
         OP_WITH_EXCEPT_START,
         OP_BINARY_OP,
         OP_BUILD_INTERPOLATION,
         OP_BUILD_LIST,
         OP_BUILD_MAP,
         OP_BUILD_SET,
         OP_BUILD_SLICE,
         OP_BUILD_STRING,
         OP_BUILD_TUPLE,
         OP_CALL,
         OP_CALL_INTRINSIC_1,
         OP_CALL_INTRINSIC_2,
         OP_CALL_KW,
         OP_COMPARE_OP,
         OP_CONTAINS_OP,
         OP_CONVERT_VALUE,
         OP_COPY,
         OP_COPY_FREE_VARS,
         OP_DELETE_ATTR,
         OP_DELETE_DEREF,
         OP_DELETE_FAST,
         OP_DELETE_GLOBAL,
         OP_DELETE_NAME,
         OP_DICT_MERGE,
         OP_DICT_UPDATE,
         OP_END_ASYNC_FOR,
         OP_EXTENDED_ARG,
         OP_FOR_ITER,
         OP_GET_AWAITABLE,
         OP_IMPORT_FROM,
         OP_IMPORT_NAME,
         OP_IS_OP,
         OP_JUMP_BACKWARD,
         OP_JUMP_BACKWARD_NO_INTERRUPT,
         OP_JUMP_FORWARD,
         OP_LIST_APPEND,
         OP_LIST_EXTEND,
         OP_LOAD_ATTR,
         OP_LOAD_COMMON_CONSTANT,
         OP_LOAD_CONST,
         OP_LOAD_DEREF,
         OP_LOAD_FAST,
         OP_LOAD_FAST_AND_CLEAR,
         OP_LOAD_FAST_BORROW,
         OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
         OP_LOAD_FAST_CHECK,
         OP_LOAD_FAST_LOAD_FAST,
         OP_LOAD_FROM_DICT_OR_DEREF,
         OP_LOAD_FROM_DICT_OR_GLOBALS,
         OP_LOAD_GLOBAL,
         OP_LOAD_NAME,
         OP_LOAD_SMALL_INT,
         OP_LOAD_SPECIAL,
         OP_LOAD_SUPER_ATTR,
         OP_MAKE_CELL,
         OP_MAP_ADD,
         OP_MATCH_CLASS,
         OP_POP_JUMP_IF_FALSE,
         OP_POP_JUMP_IF_NONE,
         OP_POP_JUMP_IF_NOT_NONE,
         OP_POP_JUMP_IF_TRUE,
         OP_RAISE_VARARGS,
         OP_RERAISE,
         OP_SEND,
         OP_SET_ADD,
         OP_SET_FUNCTION_ATTRIBUTE,
         OP_SET_UPDATE,
         OP_STORE_ATTR,
         OP_STORE_DEREF,
         OP_STORE_FAST,
         OP_STORE_FAST_LOAD_FAST,
         OP_STORE_FAST_STORE_FAST,
         OP_STORE_GLOBAL,
         OP_STORE_NAME,
         OP_SWAP,
         OP_UNPACK_EX,
         OP_UNPACK_SEQUENCE,
         OP_YIELD_VALUE,
         OP_RESUME,
         OP_BINARY_OP_ADD_FLOAT,
         OP_BINARY_OP_ADD_INT,
         OP_BINARY_OP_ADD_UNICODE,
         OP_BINARY_OP_EXTEND,
         OP_BINARY_OP_MULTIPLY_FLOAT,
         OP_BINARY_OP_MULTIPLY_INT,
         OP_BINARY_OP_SUBSCR_DICT,
         OP_BINARY_OP_SUBSCR_GETITEM,
         OP_BINARY_OP_SUBSCR_LIST_INT,
         OP_BINARY_OP_SUBSCR_LIST_SLICE,
         OP_BINARY_OP_SUBSCR_STR_INT,
         OP_BINARY_OP_SUBSCR_TUPLE_INT,
         OP_BINARY_OP_SUBTRACT_FLOAT,
         OP_BINARY_OP_SUBTRACT_INT,
         OP_CALL_ALLOC_AND_ENTER_INIT,
         OP_CALL_BOUND_METHOD_EXACT_ARGS,
         OP_CALL_BOUND_METHOD_GENERAL,
         OP_CALL_BUILTIN_CLASS,
         OP_CALL_BUILTIN_FAST,
         OP_CALL_BUILTIN_FAST_WITH_KEYWORDS,
         OP_CALL_BUILTIN_O,
         OP_CALL_ISINSTANCE,
         OP_CALL_KW_BOUND_METHOD,
         OP_CALL_KW_NON_PY,
         OP_CALL_KW_PY,
         OP_CALL_LEN,
         OP_CALL_LIST_APPEND,
         OP_CALL_METHOD_DESCRIPTOR_FAST,
         OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS,
         OP_CALL_METHOD_DESCRIPTOR_NOARGS,
         OP_CALL_METHOD_DESCRIPTOR_O,
         OP_CALL_NON_PY_GENERAL,
         OP_CALL_PY_EXACT_ARGS,
         OP_CALL_PY_GENERAL,
         OP_CALL_STR_1,
         OP_CALL_TUPLE_1,
         OP_CALL_TYPE_1,
         OP_COMPARE_OP_FLOAT,
         OP_COMPARE_OP_INT,
         OP_COMPARE_OP_STR,
         OP_CONTAINS_OP_DICT,
         OP_CONTAINS_OP_SET,
         OP_FOR_ITER_GEN,
         OP_FOR_ITER_LIST,
         OP_FOR_ITER_RANGE,
         OP_FOR_ITER_TUPLE,
         OP_JUMP_BACKWARD_JIT,
         OP_JUMP_BACKWARD_NO_JIT,
         OP_LOAD_ATTR_CLASS,
         OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN,
         OP_LOAD_ATTR_INSTANCE_VALUE,
         OP_LOAD_ATTR_METHOD_LAZY_DICT,
         OP_LOAD_ATTR_METHOD_NO_DICT,
         OP_LOAD_ATTR_METHOD_WITH_VALUES,
         OP_LOAD_ATTR_MODULE,
         OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT,
         OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES,
         OP_LOAD_ATTR_PROPERTY,
         OP_LOAD_ATTR_SLOT,
         OP_LOAD_ATTR_WITH_HINT,
         OP_LOAD_CONST_IMMORTAL,
         OP_LOAD_CONST_MORTAL,
         OP_LOAD_GLOBAL_BUILTIN,
         OP_LOAD_GLOBAL_MODULE,
         OP_LOAD_SUPER_ATTR_ATTR,
         OP_LOAD_SUPER_ATTR_METHOD,
         OP_RESUME_CHECK,
         OP_SEND_GEN,
         OP_STORE_ATTR_INSTANCE_VALUE,
         OP_STORE_ATTR_SLOT,
         OP_STORE_ATTR_WITH_HINT,
         OP_STORE_SUBSCR_DICT,
         OP_STORE_SUBSCR_LIST_INT,
         OP_TO_BOOL_ALWAYS_TRUE,
         OP_TO_BOOL_BOOL,
         OP_TO_BOOL_INT,
         OP_TO_BOOL_LIST,
         OP_TO_BOOL_NONE,
         OP_TO_BOOL_STR,
         OP_UNPACK_SEQUENCE_LIST,
         OP_UNPACK_SEQUENCE_TUPLE,
         OP_UNPACK_SEQUENCE_TWO_TUPLE,
         OP_INSTRUMENTED_END_FOR,
         OP_INSTRUMENTED_POP_ITER,
         OP_INSTRUMENTED_END_SEND,
         OP_INSTRUMENTED_FOR_ITER,
         OP_INSTRUMENTED_INSTRUCTION,
         OP_INSTRUMENTED_JUMP_FORWARD,
         OP_INSTRUMENTED_NOT_TAKEN,
         OP_INSTRUMENTED_POP_JUMP_IF_TRUE,
         OP_INSTRUMENTED_POP_JUMP_IF_FALSE,
         OP_INSTRUMENTED_POP_JUMP_IF_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_NOT_NONE,
         OP_INSTRUMENTED_RESUME,
         OP_INSTRUMENTED_RETURN_VALUE,
         OP_INSTRUMENTED_YIELD_VALUE,
         OP_INSTRUMENTED_END_ASYNC_FOR,
         OP_INSTRUMENTED_LOAD_SUPER_ATTR,
         OP_INSTRUMENTED_CALL,
         OP_INSTRUMENTED_CALL_KW,
         OP_INSTRUMENTED_CALL_FUNCTION_EX,
         OP_INSTRUMENTED_JUMP_BACKWARD,
         OP_INSTRUMENTED_LINE,
         OP_ENTER_EXECUTOR,
         OP_ANNOTATIONS_PLACEHOLDER,
         OP_JUMP,
         OP_JUMP_IF_FALSE,
         OP_JUMP_IF_TRUE,
         OP_JUMP_NO_INTERRUPT,
         OP_LOAD_CLOSURE,
         OP_POP_BLOCK,
         OP_SETUP_CLEANUP,
         OP_SETUP_FINALLY,
         OP_SETUP_WITH,
         OP_STORE_FAST_MAYBE_NULL
     };

def opcode_is_valid(op: int) -> bool {
    return op in _OPCODE_IS_VALID_SET;
}

glob _OPCODE_HAS_ARG_SET: set[int] = {
         OP_BINARY_OP,
         OP_BUILD_INTERPOLATION,
         OP_BUILD_LIST,
         OP_BUILD_MAP,
         OP_BUILD_SET,
         OP_BUILD_SLICE,
         OP_BUILD_STRING,
         OP_BUILD_TUPLE,
         OP_CALL,
         OP_CALL_INTRINSIC_1,
         OP_CALL_INTRINSIC_2,
         OP_CALL_KW,
         OP_COMPARE_OP,
         OP_CONTAINS_OP,
         OP_CONVERT_VALUE,
         OP_COPY,
         OP_COPY_FREE_VARS,
         OP_DELETE_ATTR,
         OP_DELETE_DEREF,
         OP_DELETE_FAST,
         OP_DELETE_GLOBAL,
         OP_DELETE_NAME,
         OP_DICT_MERGE,
         OP_DICT_UPDATE,
         OP_END_ASYNC_FOR,
         OP_EXTENDED_ARG,
         OP_FOR_ITER,
         OP_GET_AWAITABLE,
         OP_IMPORT_FROM,
         OP_IMPORT_NAME,
         OP_IS_OP,
         OP_JUMP_BACKWARD,
         OP_JUMP_BACKWARD_NO_INTERRUPT,
         OP_JUMP_FORWARD,
         OP_LIST_APPEND,
         OP_LIST_EXTEND,
         OP_LOAD_ATTR,
         OP_LOAD_COMMON_CONSTANT,
         OP_LOAD_CONST,
         OP_LOAD_DEREF,
         OP_LOAD_FAST,
         OP_LOAD_FAST_AND_CLEAR,
         OP_LOAD_FAST_BORROW,
         OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
         OP_LOAD_FAST_CHECK,
         OP_LOAD_FAST_LOAD_FAST,
         OP_LOAD_FROM_DICT_OR_DEREF,
         OP_LOAD_FROM_DICT_OR_GLOBALS,
         OP_LOAD_GLOBAL,
         OP_LOAD_NAME,
         OP_LOAD_SMALL_INT,
         OP_LOAD_SPECIAL,
         OP_LOAD_SUPER_ATTR,
         OP_MAKE_CELL,
         OP_MAP_ADD,
         OP_MATCH_CLASS,
         OP_POP_JUMP_IF_FALSE,
         OP_POP_JUMP_IF_NONE,
         OP_POP_JUMP_IF_NOT_NONE,
         OP_POP_JUMP_IF_TRUE,
         OP_RAISE_VARARGS,
         OP_RERAISE,
         OP_SEND,
         OP_SET_ADD,
         OP_SET_FUNCTION_ATTRIBUTE,
         OP_SET_UPDATE,
         OP_STORE_ATTR,
         OP_STORE_DEREF,
         OP_STORE_FAST,
         OP_STORE_FAST_LOAD_FAST,
         OP_STORE_FAST_STORE_FAST,
         OP_STORE_GLOBAL,
         OP_STORE_NAME,
         OP_SWAP,
         OP_UNPACK_EX,
         OP_UNPACK_SEQUENCE,
         OP_YIELD_VALUE,
         OP_RESUME,
         OP_CALL_ALLOC_AND_ENTER_INIT,
         OP_CALL_BOUND_METHOD_EXACT_ARGS,
         OP_CALL_BOUND_METHOD_GENERAL,
         OP_CALL_BUILTIN_CLASS,
         OP_CALL_BUILTIN_FAST,
         OP_CALL_BUILTIN_FAST_WITH_KEYWORDS,
         OP_CALL_BUILTIN_O,
         OP_CALL_ISINSTANCE,
         OP_CALL_KW_BOUND_METHOD,
         OP_CALL_KW_NON_PY,
         OP_CALL_KW_PY,
         OP_CALL_LIST_APPEND,
         OP_CALL_METHOD_DESCRIPTOR_FAST,
         OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS,
         OP_CALL_METHOD_DESCRIPTOR_NOARGS,
         OP_CALL_METHOD_DESCRIPTOR_O,
         OP_CALL_NON_PY_GENERAL,
         OP_CALL_PY_EXACT_ARGS,
         OP_CALL_PY_GENERAL,
         OP_CALL_STR_1,
         OP_CALL_TUPLE_1,
         OP_CALL_TYPE_1,
         OP_COMPARE_OP_FLOAT,
         OP_COMPARE_OP_INT,
         OP_COMPARE_OP_STR,
         OP_CONTAINS_OP_DICT,
         OP_CONTAINS_OP_SET,
         OP_FOR_ITER_GEN,
         OP_FOR_ITER_LIST,
         OP_FOR_ITER_RANGE,
         OP_FOR_ITER_TUPLE,
         OP_JUMP_BACKWARD_JIT,
         OP_JUMP_BACKWARD_NO_JIT,
         OP_LOAD_ATTR_CLASS,
         OP_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN,
         OP_LOAD_ATTR_INSTANCE_VALUE,
         OP_LOAD_ATTR_METHOD_LAZY_DICT,
         OP_LOAD_ATTR_METHOD_NO_DICT,
         OP_LOAD_ATTR_METHOD_WITH_VALUES,
         OP_LOAD_ATTR_MODULE,
         OP_LOAD_ATTR_NONDESCRIPTOR_NO_DICT,
         OP_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES,
         OP_LOAD_ATTR_PROPERTY,
         OP_LOAD_ATTR_SLOT,
         OP_LOAD_ATTR_WITH_HINT,
         OP_LOAD_CONST_IMMORTAL,
         OP_LOAD_CONST_MORTAL,
         OP_LOAD_GLOBAL_BUILTIN,
         OP_LOAD_GLOBAL_MODULE,
         OP_LOAD_SUPER_ATTR_ATTR,
         OP_LOAD_SUPER_ATTR_METHOD,
         OP_SEND_GEN,
         OP_STORE_ATTR_WITH_HINT,
         OP_UNPACK_SEQUENCE_LIST,
         OP_UNPACK_SEQUENCE_TUPLE,
         OP_UNPACK_SEQUENCE_TWO_TUPLE,
         OP_INSTRUMENTED_FOR_ITER,
         OP_INSTRUMENTED_JUMP_FORWARD,
         OP_INSTRUMENTED_POP_JUMP_IF_TRUE,
         OP_INSTRUMENTED_POP_JUMP_IF_FALSE,
         OP_INSTRUMENTED_POP_JUMP_IF_NONE,
         OP_INSTRUMENTED_POP_JUMP_IF_NOT_NONE,
         OP_INSTRUMENTED_RESUME,
         OP_INSTRUMENTED_YIELD_VALUE,
         OP_INSTRUMENTED_END_ASYNC_FOR,
         OP_INSTRUMENTED_LOAD_SUPER_ATTR,
         OP_INSTRUMENTED_CALL,
         OP_INSTRUMENTED_CALL_KW,
         OP_INSTRUMENTED_JUMP_BACKWARD,
         OP_ENTER_EXECUTOR,
         OP_JUMP,
         OP_JUMP_IF_FALSE,
         OP_JUMP_IF_TRUE,
         OP_JUMP_NO_INTERRUPT,
         OP_LOAD_CLOSURE,
         OP_SETUP_CLEANUP,
         OP_SETUP_FINALLY,
         OP_SETUP_WITH,
         OP_STORE_FAST_MAYBE_NULL
     };

def opcode_has_arg(op: int) -> bool {
    return op in _OPCODE_HAS_ARG_SET;
}

glob _OPCODE_HAS_CONST_SET: set[int] = {
         OP_LOAD_CONST,
         OP_LOAD_CONST_IMMORTAL,
         OP_LOAD_CONST_MORTAL
     },
     _OPCODE_HAS_NAME_SET: set[int] = {
         OP_DELETE_ATTR,
         OP_DELETE_GLOBAL,
         OP_DELETE_NAME,
         OP_IMPORT_FROM,
         OP_IMPORT_NAME,
         OP_LOAD_ATTR,
         OP_LOAD_FROM_DICT_OR_GLOBALS,
         OP_LOAD_GLOBAL,
         OP_LOAD_NAME,
         OP_LOAD_SUPER_ATTR,
         OP_STORE_ATTR,
         OP_STORE_GLOBAL,
         OP_STORE_NAME,
         OP_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN,
         OP_LOAD_ATTR_WITH_HINT,
         OP_LOAD_SUPER_ATTR_ATTR,
         OP_LOAD_SUPER_ATTR_METHOD,
         OP_STORE_ATTR_WITH_HINT,
         OP_INSTRUMENTED_LOAD_SUPER_ATTR
     },
     _OPCODE_HAS_LOCAL_SET: set[int] = {
         OP_BINARY_OP_INPLACE_ADD_UNICODE,
         OP_DELETE_FAST,
         OP_LOAD_DEREF,
         OP_LOAD_FAST,
         OP_LOAD_FAST_AND_CLEAR,
         OP_LOAD_FAST_BORROW,
         OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
         OP_LOAD_FAST_CHECK,
         OP_LOAD_FAST_LOAD_FAST,
         OP_STORE_FAST,
         OP_STORE_FAST_LOAD_FAST,
         OP_STORE_FAST_STORE_FAST,
         OP_LOAD_CLOSURE,
         OP_STORE_FAST_MAYBE_NULL
     };

def opcode_has_const(op: int) -> bool {
    return op in _OPCODE_HAS_CONST_SET;
}

def opcode_has_name(op: int) -> bool {
    return op in _OPCODE_HAS_NAME_SET;
}

glob _OPCODE_HAS_JUMP_SET: set[int] = {
         OP_END_ASYNC_FOR,
         OP_FOR_ITER,
         OP_JUMP_BACKWARD,
         OP_JUMP_BACKWARD_NO_INTERRUPT,
         OP_JUMP_FORWARD,
         OP_POP_JUMP_IF_FALSE,
         OP_POP_JUMP_IF_NONE,
         OP_POP_JUMP_IF_NOT_NONE,
         OP_POP_JUMP_IF_TRUE,
         OP_SEND,
         OP_FOR_ITER_LIST,
         OP_FOR_ITER_RANGE,
         OP_FOR_ITER_TUPLE,
         OP_JUMP_BACKWARD_JIT,
         OP_JUMP_BACKWARD_NO_JIT,
         OP_INSTRUMENTED_FOR_ITER,
         OP_INSTRUMENTED_END_ASYNC_FOR,
         OP_JUMP,
         OP_JUMP_IF_FALSE,
         OP_JUMP_IF_TRUE,
         OP_JUMP_NO_INTERRUPT
     };

def opcode_has_jump(op: int) -> bool {
    return op in _OPCODE_HAS_JUMP_SET;
}

glob _OPCODE_HAS_FREE_SET: set[int] = {
         OP_DELETE_DEREF,
         OP_LOAD_FROM_DICT_OR_DEREF,
         OP_MAKE_CELL,
         OP_STORE_DEREF
     };

def opcode_has_free(op: int) -> bool {
    return op in _OPCODE_HAS_FREE_SET;
}

def opcode_has_local(op: int) -> bool {
    return op in _OPCODE_HAS_LOCAL_SET;
}

def instruction_width(op: int) -> int {
    return 2 + opcode_cache_count(op);
}

# Advance ip past one instruction (including EXTENDED_ARG prefix chain).
def next_instruction_ip(code: list[int], ip: int) -> int {
    ext = 0;
    while ip < len(code) {
        op = code[ip];
        arg = code[ip + 1];
        arg = arg | (ext << 8);
        ext = 0;
        if op == OP_EXTENDED_ARG {
            ext = arg;
            ip = ip + 2;
            continue;
        }
        return ip + instruction_width(op);
    }
    return ip;
}
