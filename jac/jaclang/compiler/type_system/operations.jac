"""Provides type evaluation logic for unary, binary, augmented assignment and ternary operators.\n\nPyrightReference: packages/pyright-internal/src/analyzer/operations.ts\n"""
import from typing { TYPE_CHECKING }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from . { types as jtypes }

with entry {
    if TYPE_CHECKING {
        import from .type_evaluator { TypeEvaluator }
    }
}

# FIX: py2jac bug - module-level constants must be declared with glob outside with entry block
# Otherwise they become Field descriptors when accessed from functions
glob BINARY_OPERATOR_MAP:
    dict[str, tuple[str, str]] = {
    Tok.PLUS: ('__add__', '__radd__'),
    Tok.MINUS: ('__sub__', '__rsub__'),
    Tok.STAR_MUL: ('__mul__', '__rmul__'),
    Tok.FLOOR_DIV: ('__floordiv__', '__rfloordiv__'),
    Tok.DIV: ('__truediv__', '__rtruediv__'),
    Tok.MOD: ('__mod__', '__rmod__'),
    Tok.STAR_POW: ('__pow__', '__rpow__'),
    Tok.DECOR_OP: ('__matmul__', '__rmatmul__'),
    Tok.BW_AND: ('__and__', '__rand__'),
    Tok.BW_OR: ('__or__', '__ror__'),
    Tok.BW_XOR: ('__xor__', '__rxor__'),
    Tok.LSHIFT: ('__lshift__', '__rlshift__'),
    Tok.RSHIFT: ('__rshift__', '__rrshift__'),
    Tok.EE: ('__eq__', '__eq__'),
    Tok.NE: ('__ne__', '__ne__'),
    Tok.LT: ('__lt__', '__gt__'),
    Tok.LTE: ('__le__', '__ge__'),
    Tok.GT: ('__gt__', '__lt__'),
    Tok.GTE: ('__ge__', '__le__')
};

"""Return the binary operator's jtype."""
def get_type_of_binary_operation(
    evaluator: 'TypeEvaluator', expr: uni.BinaryExpr
) -> jtypes.TypeBase {
    left_type = evaluator.get_type_of_expression(expr.left);
    right_type = evaluator.get_type_of_expression(expr.right);
    # Boolean operations
    if (
        (expr.op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN))
        and (evaluator.prefetch.bool_class is not None)
    ) {
        evaluator._convert_to_instance(evaluator.prefetch.bool_class);
    }

    # Magic method lookup for other binary operations
    if (isinstance(expr.op, uni.Token) and (expr.op.name in BINARY_OPERATOR_MAP)) {
        # Handle '|' in the context of Union types
        #
        # TODO: Pyright checks if the types support '__or__' and '__ror__' before returning UnionType
        # If they support, we can treat them as binary operands, instead of Union types.
        if expr.op.name == Tok.BW_OR {
            # TODO: Handle None instance used
            if left_type.is_instantiable() and right_type.is_instantiable() {
                return jtypes.UnionType([left_type, right_type]);
            }
        }
        (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];
        return (
            evaluator.get_type_of_magic_method_call(left_type, magic)
            or evaluator.get_type_of_magic_method_call(right_type, rmagic)
            or jtypes.UnknownType()
        );
    }

    # Connection operations
    if isinstance(expr.op, (uni.ConnectOp, uni.DisconnectOp)) {
        if (
            not isinstance(left_type, jtypes.ClassType)
            or not left_type.is_node_type()
            or not left_type.is_instance()
        ) {
            evaluator.add_diagnostic(
                expr.left, 'Connection left operand must be a node instance'
            );
        }
        if (
            not isinstance(right_type, jtypes.ClassType)
            or not right_type.is_node_type()
            or not right_type.is_instance()
        ) {
            evaluator.add_diagnostic(
                expr.right, 'Connection right operand must be a node instance'
            );
        }
        if isinstance(expr.op, uni.ConnectOp) {
            if expr.op.conn_type {
                conn_type = evaluator.get_type_of_expression(expr.op.conn_type);
                if (
                    not isinstance(conn_type, jtypes.ClassType)
                    or not conn_type.is_edge_type()
                ) {
                    evaluator.add_diagnostic(
                        expr.op.conn_type, 'Connection type must be an edge instance'
                    );
                } elif (assign_compr := expr.op.conn_assign) {
                    for assign in assign_compr.assigns {
                        if (assign.key is not None) {
                            edge_inst_type = evaluator._convert_to_instance(conn_type);
                            if (
                                member := evaluator._lookup_object_member(
                                    edge_inst_type, assign.key.sym_name
                                )
                            ) {
                                dest_type = evaluator._set_symbol_to_expr(
                                    assign.key, member.symbol
                                );
                                src_type = evaluator.get_type_of_expression(
                                    assign.value
                                );
                                if not evaluator.assign_type(src_type, dest_type) {
                                    msg = 'Type "{}" is not assignable to type "{}"'.format(
                                        src_type, dest_type
                                    );
                                    evaluator.add_diagnostic(assign.value, msg);
                                }
                            } else {
                                msg = 'Edge type "{}" has no member named "{}"'.format(
                                    conn_type, assign.key.sym_name
                                );
                                evaluator.add_diagnostic(assign.key, msg);
                            }
                        }
                    }
                }
            }
            return right_type;
        }
    }
    return jtypes.UnknownType();
}
