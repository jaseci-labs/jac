# Product-path facade for _opcode.
# Semantics mirror CPython 3.14 ``Modules/_opcode.c`` over the generated
# ``opcode_meta.jac`` metadata tables (no duplicated opcode knowledge).
# get_specialization_stats / get_executor are runtime-only surfaces and are
# deferred; stack_effect covers non-specialized (deopt-stable) opcodes, the
# set the native compiler emits.

import from opcode_meta {
    stack_effect,
    opcode_is_valid,
    opcode_has_arg,
    opcode_has_const,
    opcode_has_name,
    opcode_has_jump,
    opcode_has_free,
    opcode_has_local,
    is_block_push_opcode,
}

def _p2_stack_effect(opcode: int, oparg: int | None, jump: int | None) -> int | None {
    # jump follows the C module: None -> -1 (maximal), else 0/1.
    j = -1;
    if jump is not None {
        j = jump;
    }
    a = 0;
    if oparg is not None {
        a = oparg;
    }
    return stack_effect(opcode, a, j);
}

def _p2_is_valid(opcode: int) -> bool {
    return opcode_is_valid(opcode);
}

def _p2_has_arg(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_arg(opcode);
}

def _p2_has_const(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_const(opcode);
}

def _p2_has_name(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_name(opcode);
}

def _p2_has_jump(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_jump(opcode);
}

def _p2_has_free(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_free(opcode);
}

def _p2_has_local(opcode: int) -> bool {
    return _p2_is_valid(opcode) and opcode_has_local(opcode);
}

def _p2_has_exc(opcode: int) -> bool {
    return _p2_is_valid(opcode) and is_block_push_opcode(opcode);
}

glob _NB_OPS: list[tuple[str, str]] = [
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
        ("NB_SUBSCR", "[]"),

    ];

def _p2_get_nb_ops() -> list {
    pairs: list = [];
    for (name, symbol) in _NB_OPS {
        pairs.append([name, symbol]);
    }
    return pairs;
}
