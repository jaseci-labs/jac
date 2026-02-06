"""
Provides type evaluation logic for unary, binary, augmented assignment and ternary operators.

PyrightReference: packages/pyright-internal/src/analyzer/operations.ts
"""
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
     },
     ARITHMETIC_OPERATORS: set[str] = {Tok.PLUS,Tok.MINUS,Tok.STAR_MUL,Tok.DIV,Tok.FLOOR_DIV,Tok.MOD,Tok.STAR_POW};

"""
Apply numeric type promotion for arithmetic operations.

Rules:
- int op int -> int (except for / which always returns float)
- int op float -> float
- float op int -> float
- float op float -> float

Returns the promoted result type, or None if types are not numeric.
"""
def get_numeric_promotion_type(
    evaluator: 'TypeEvaluator',
    left_type: jtypes.TypeBase,
    right_type: jtypes.TypeBase,
    op: str
) -> jtypes.TypeBase | None {
    # Check if both types are numeric (int or float)
    if not isinstance(left_type, jtypes.ClassType)
    or not isinstance(right_type, jtypes.ClassType) {
        return None;
    }
    left_is_int = left_type.is_builtin("int");
    left_is_float = left_type.is_builtin("float");
    right_is_int = right_type.is_builtin("int");
    right_is_float = right_type.is_builtin("float");

    # Both must be numeric
    if not ((left_is_int or left_is_float) and (right_is_int or right_is_float)) {
        return None;
    }

    # Division always returns float
    if op == Tok.DIV {
        return evaluator._convert_to_instance(evaluator.prefetch.float_class);
    }

    # If either operand is float, result is float (int promoted to float)
    if left_is_float or right_is_float {
        return evaluator._convert_to_instance(evaluator.prefetch.float_class);
    }

    # Both are int, result is int
    return evaluator._convert_to_instance(evaluator.prefetch.int_class);
}

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
        def is_annotation_type(ty: jtypes.TypeBase) -> bool {
            if ty.is_instantiable() or isinstance(ty, jtypes.UnionType) {
                return True;
            }
            # Althought None is not a valid class, it can be used as a class in the type annotation.
            if isinstance(ty, jtypes.ClassType) {
                return ty.shared == evaluator.prefetch.none_type_class.shared;
            }
            return False;
        }
        if expr.op.name == Tok.BW_OR {
            # TODO: Handle None instance used
            if is_annotation_type(left_type) and is_annotation_type(right_type) {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
        }
        (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];
        # Apply numeric type promotion for arithmetic operations (int -> float)
        if expr.op.name in ARITHMETIC_OPERATORS {
            promoted_type = get_numeric_promotion_type(
                evaluator, left_type, right_type, expr.op.name
            );
            if promoted_type is not None {
                return promoted_type;
            }
        }
        # Try forward magic method first (e.g., left.__add__(right))
        result = evaluator.get_type_of_magic_method_call(
            left_type, magic, [expr.right], None
        );
        # If forward method fails, try reverse magic method (e.g., right.__radd__(left))
        if result is None {
            result = evaluator.get_type_of_magic_method_call(
                right_type, rmagic, [expr.left], None
            );
        }
        # If both methods fail, handle specially for | operator, else emit diagnostic
        if result is None {
            # For | operator, fall back to UnionType when magic method fails.
            # This handles type annotation contexts where | is used for union types
            # but operands weren't detected as annotation types by is_annotation_type().
            if expr.op.name == Tok.BW_OR {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
            evaluator.add_diagnostic(
                expr,
                f'No matching overload found for method "{magic}" with the given arguments'
            );
            return jtypes.UnknownType();
        }
        return result;
    }

    # Connection operations
    if isinstance(expr.op, (uni.ConnectOp, uni.DisconnectOp)) {
        def is_node_type_instance(t: jtypes.TypeBase) -> bool {
            return (
                isinstance(t, jtypes.ClassType)
                and t.is_node_type()
                and t.is_instance()
            );
        }
        # Check whether a type is a valid node operand for connections.
        # Accepts: node instances, UnionType where all members are node instances,
        # AnyType, and UnknownType (not enough info to diagnose).
        def is_valid_node_operand(t: jtypes.TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, jtypes.UnknownType) {
                return True;
            }
            if is_node_type_instance(t) {
                return True;
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_valid_node_operand(m) for m in t.types);
            }
            return False;
        }
        # TODO: In strict mode, UnknownType, AnyType, TypeVarType, and object should be errors
        if not is_valid_node_operand(left_type) {
            evaluator.add_diagnostic(
                expr.left, 'Connection left operand must be a node instance'
            );
        }
        # Check if right operand is a valid node operand or a collection of node instances
        def is_valid_right_operand(t: jtypes.TypeBase) -> bool {
            if is_valid_node_operand(t) {
                return True;
            }
            if not isinstance(t, jtypes.ClassType) {
                return False;
            }
            # Collection of node instances (list, tuple, set, frozenset)
            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                # If type_args are available, check them
                if (t.private.type_args is not None and len(t.private.type_args) > 0) {
                    elem_type = t.private.type_args[0];
                    if is_valid_node_operand(elem_type) {
                        return True;
                    }
                } else {
                    # Unparameterized collection - allow it since element type
                    # inference for list literals is not yet implemented (TODO).
                    # In strict mode, this should be an error.
                    return True;
                }
            }
            return False;
        }
        if not is_valid_right_operand(right_type) {
            evaluator.add_diagnostic(
                expr.right, 'Connection right operand must be a node instance'
            );
        }
        if isinstance(expr.op, uni.ConnectOp) {
            if expr.op.conn_type {
                conn_type = evaluator.get_type_of_expression(expr.op.conn_type);
                if (
                    not conn_type.is_any_type()
                    and not isinstance(conn_type, jtypes.UnknownType)
                    and (
                        not isinstance(conn_type, jtypes.ClassType)
                        or not conn_type.is_edge_type()
                    )
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
    #  walrus assignment
    if isinstance(expr.op, uni.Token) and expr.op.name == Tok.WALRUS_EQ {
        # Walrus operator: (x := expr) assigns right to left and returns right's type
        if isinstance(expr.left, uni.Name) and expr.left.sym {
            expr.left.sym.type = right_type;
            expr.left.type = right_type;
        }
        return right_type;
    }
    return jtypes.UnknownType();
}
# Arithmetic operators that support numeric type promotion (int -> float)
