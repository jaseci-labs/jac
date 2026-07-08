import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from . { types as jtypes }
import from jaclang.jac0core.diagnostics {
    E1010,
    E1033,
    E1035,
    E1055,
    E1096,
    E1097,
    E1098,
    E1114,
    E1115,
    E1118
}
import type from .type_evaluator { TypeEvaluator }

glob BINARY_OPERATOR_MAP: dict[str, tuple[str, str]] = {
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
     ARITHMETIC_OPERATORS: set[str] = {
         Tok.PLUS,
         Tok.MINUS,
         Tok.STAR_MUL,
         Tok.DIV,
         Tok.FLOOR_DIV,
         Tok.MOD,
         Tok.STAR_POW
     },
     INT_LIKE_WIDTHS: dict[str, int] = {
         "i8": 8,
         "u8": 8,
         "i16": 16,
         "u16": 16,
         "i32": 32,
         "u32": 32,
         "i64": 64,
         "u64": 64
     },
     FLOAT_LIKE_NAMES: set[str] = {"f32", "f64"},
     AUG_OPERATOR_MAP: dict[str, str] = {
         Tok.ADD_EQ: '__iadd__',
         Tok.SUB_EQ: '__isub__',
         Tok.MUL_EQ: '__imul__',
         Tok.DIV_EQ: '__itruediv__',
         Tok.FLOOR_DIV_EQ: '__ifloordiv__',
         Tok.MOD_EQ: '__imod__',
         Tok.STAR_POW_EQ: '__ipow__',
         Tok.LSHIFT_EQ: '__ilshift__',
         Tok.RSHIFT_EQ: '__irshift__',
         Tok.BW_AND_EQ: '__iand__',
         Tok.BW_OR_EQ: '__ior__',
         Tok.BW_XOR_EQ: '__ixor__',
         Tok.MATMUL_EQ: '__imatmul__'
     },
     AUG_TO_BINARY_MAP: dict[str, str] = {
         Tok.ADD_EQ: Tok.PLUS,
         Tok.SUB_EQ: Tok.MINUS,
         Tok.MUL_EQ: Tok.STAR_MUL,
         Tok.DIV_EQ: Tok.DIV,
         Tok.FLOOR_DIV_EQ: Tok.FLOOR_DIV,
         Tok.MOD_EQ: Tok.MOD,
         Tok.STAR_POW_EQ: Tok.STAR_POW,
         Tok.LSHIFT_EQ: Tok.LSHIFT,
         Tok.RSHIFT_EQ: Tok.RSHIFT,
         Tok.BW_AND_EQ: Tok.BW_AND,
         Tok.BW_OR_EQ: Tok.BW_OR,
         Tok.BW_XOR_EQ: Tok.BW_XOR,
         Tok.MATMUL_EQ: Tok.DECOR_OP
     };

def _is_int_like(t: jtypes.ClassType) -> bool {
    return t.is_builtin("int")
    or (t.is_builtin() and t.shared.class_name in INT_LIKE_WIDTHS);
}

def _is_float_like(t: jtypes.ClassType) -> bool {
    return t.is_builtin("float")
    or (t.is_builtin() and t.shared.class_name in FLOAT_LIKE_NAMES);
}

def get_numeric_promotion_type(
    evaluator: 'TypeEvaluator',
    left_type: jtypes.TypeBase,
    right_type: jtypes.TypeBase,
    op: str
) -> jtypes.TypeBase | None {
    if not isinstance(left_type, jtypes.ClassType)
    or not isinstance(right_type, jtypes.ClassType) {
        return None;
    }
    left_is_int = _is_int_like(left_type);
    left_is_float = _is_float_like(left_type);
    right_is_int = _is_int_like(right_type);
    right_is_float = _is_float_like(right_type);

    if not ((left_is_int or left_is_float) and (right_is_int or right_is_float)) {
        return None;
    }

    float_class = evaluator.prefetch.float_class;
    int_class = evaluator.prefetch.int_class;
    if float_class is None or int_class is None {
        return None;
    }

    if op == Tok.DIV {
        return evaluator._convert_to_instance(float_class);
    }

    if left_is_float or right_is_float {
        return evaluator._convert_to_instance(float_class);
    }

    left_name = left_type.shared.class_name;
    right_name = right_type.shared.class_name;
    left_fw = left_name in INT_LIKE_WIDTHS;
    right_fw = right_name in INT_LIKE_WIDTHS;

    if not left_fw or not right_fw {
        return evaluator._convert_to_instance(int_class);
    }

    if INT_LIKE_WIDTHS[left_name] >= INT_LIKE_WIDTHS[right_name] {
        return evaluator._convert_to_instance(left_type);
    }
    return evaluator._convert_to_instance(right_type);
}

def get_type_of_binary_operation(
    evaluator: 'TypeEvaluator', expr: uni.BinaryExpr
) -> jtypes.TypeBase {
    left_type = evaluator.get_type_of_expression(expr.left);
    right_type = evaluator.get_type_of_expression(expr.right);

    if isinstance(expr.op, uni.Token)
    and expr.op.name in BINARY_OPERATOR_MAP
    and expr.op.name != Tok.BW_OR {
        if isinstance(left_type, jtypes.TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, jtypes.ClassType) {
                        result = evaluator.get_type_of_magic_method_call(
                            constraint_type, magic, [expr.right], None
                        );
                        if not result {
                            evaluator.emit_diag(
                                E1010, expr, op=magic, type=str(constraint_type)
                            );
                        }
                    }
                }
                return jtypes.UnknownType();
            }
            if left_type.bound and isinstance(left_type.bound, jtypes.ClassType) {
                result = evaluator.get_type_of_magic_method_call(
                    left_type.bound, magic, [expr.right], None
                );
                if result {
                    return result;
                }

                evaluator.emit_diag(E1010, expr, op=magic, type=str(left_type.bound));
                return jtypes.UnknownType();
            }

            evaluator.emit_diag(E1010, expr, op=magic, type=left_type.name);
            return jtypes.UnknownType();
        }
        if isinstance(right_type, jtypes.TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

            if right_type.constraints {
                for constraint_type in right_type.constraints {
                    if isinstance(constraint_type, jtypes.ClassType) {
                        result = evaluator.get_type_of_magic_method_call(
                            constraint_type, rmagic, [expr.left], None
                        );
                        if not result {
                            evaluator.emit_diag(
                                E1010, expr, op=rmagic, type=str(constraint_type)
                            );
                        }
                    }
                }
                return jtypes.UnknownType();
            }
            if right_type.bound and isinstance(right_type.bound, jtypes.ClassType) {
                result = evaluator.get_type_of_magic_method_call(
                    right_type.bound, rmagic, [expr.left], None
                );
                if result {
                    return result;
                }

                evaluator.emit_diag(E1010, expr, op=rmagic, type=str(right_type.bound));
                return jtypes.UnknownType();
            }

            evaluator.emit_diag(E1010, expr, op=rmagic, type=right_type.name);
            return jtypes.UnknownType();
        }
    }

    if left_type.is_any_type() or right_type.is_any_type() {
        if not (isinstance(expr.op, uni.Token) and expr.op.name == Tok.BW_OR) {
            return jtypes.UnknownType();
        }
    }

    if (
        (expr.op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN))
        and (evaluator.prefetch.bool_class is not None)
    ) {
        return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
    }

    if (isinstance(expr.op, uni.Token) and (expr.op.name in BINARY_OPERATOR_MAP)) {
        def is_annotation_type(ty: jtypes.TypeBase) -> bool {
            if ty.is_instantiable() or isinstance(ty, jtypes.UnionType) {
                return True;
            }

            if isinstance(ty, jtypes.TypeVarType) {
                return True;
            }

            if isinstance(ty, jtypes.FunctionType)
            and ty.is_from_callable_annotation() {
                return True;
            }

            if isinstance(ty, jtypes.NeverType) {
                return True;
            }

            none_type_class = evaluator.prefetch.none_type_class;
            if isinstance(ty, jtypes.ClassType) and none_type_class is not None {
                return ty.shared == none_type_class.shared;
            }
            return False;
        }
        if expr.op.name == Tok.BW_OR {
            if is_annotation_type(left_type) and is_annotation_type(right_type) {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
        }
        (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

        if expr.op.name in ARITHMETIC_OPERATORS {
            promoted_type = get_numeric_promotion_type(
                evaluator, left_type, right_type, expr.op.name
            );
            if promoted_type is not None {
                return promoted_type;
            }
        }

        result = evaluator.get_type_of_magic_method_call(
            left_type, magic, [expr.right], None
        );

        if result is None {
            result = evaluator.get_type_of_magic_method_call(
                right_type, rmagic, [expr.left], None
            );
        }

        if result is None {
            if expr.op.name == Tok.BW_OR {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
            evaluator.emit_diag(E1055, expr, method=magic);
            return jtypes.UnknownType();
        }
        return result;
    }

    if isinstance(expr.op, (uni.ConnectOp, uni.DisconnectOp)) {
        def is_node_type_instance(t: jtypes.TypeBase) -> bool {
            return (
                isinstance(t, jtypes.ClassType) and t.is_node_type() and t.is_instance()
            );
        }

        def unparameterized_connect_collection(t: jtypes.TypeBase) -> str | None {
            if not isinstance(t, jtypes.ClassType) {
                return None;
            }
            if not t.is_builtin() {
                return None;
            }
            if t.shared.class_name not in ("list", "tuple", "set", "frozenset") {
                return None;
            }
            if t.private.type_args and len(t.private.type_args) > 0 {
                return None;
            }
            return t.shared.class_name;
        }

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

            if isinstance(t, jtypes.ClassType)
            and t.is_builtin()
            and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return is_valid_node_operand(t.private.type_args[0]);
                }

                return False;
            }
            return False;
        }

        if (
            left_unparam := unparameterized_connect_collection(left_type)
        ) is not None {
            evaluator.emit_diag(E1118, expr.left, side="left", type=left_unparam);
        } elif not is_valid_node_operand(left_type) {
            evaluator.emit_diag(E1096, expr.left);
        }

        def is_valid_right_operand(t: jtypes.TypeBase) -> bool {
            if is_valid_node_operand(t) {
                return True;
            }
            if not isinstance(t, jtypes.ClassType) {
                return False;
            }

            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                if (t.private.type_args is not None and len(t.private.type_args) > 0) {
                    elem_type = t.private.type_args[0];
                    if is_valid_node_operand(elem_type) {
                        return True;
                    }
                }
            }
            return False;
        }
        if (
            right_unparam := unparameterized_connect_collection(right_type)
        ) is not None {
            evaluator.emit_diag(E1118, expr.right, side="right", type=right_unparam);
        } elif not is_valid_right_operand(right_type) {
            evaluator.emit_diag(E1097, expr.right);
        }

        def validate_conn_type(type_expr: uni.Expr) -> jtypes.TypeBase {
            ct = evaluator.get_type_of_expression(type_expr);
            if (
                not ct.is_any_type()
                and not isinstance(ct, jtypes.UnknownType)
                and (not isinstance(ct, jtypes.ClassType) or not ct.is_edge_type())
            ) {
                evaluator.emit_diag(E1098, type_expr);
                return jtypes.UnknownType();
            }
            return ct;
        }
        if isinstance(expr.op, uni.ConnectOp) {
            if expr.op.conn_type {
                conn_type = validate_conn_type(expr.op.conn_type);
                if (
                    not isinstance(conn_type, jtypes.UnknownType)
                    and (assign_compr := expr.op.conn_assign)
                ) {
                    for assign in assign_compr.assigns {
                        edge_inst_type = evaluator._convert_to_instance(conn_type);
                        if (assign.key is not None)
                        and isinstance(edge_inst_type, jtypes.ClassType) {
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

                                if not evaluator.assign_type(
                                    src_type,
                                    dest_type,
                                    strict=evaluator._is_strict_site(assign.value)
                                ) {
                                    evaluator.emit_diag(
                                        E1035,
                                        assign.value,
                                        src=str(src_type),
                                        dest=str(dest_type)
                                    );
                                }
                            } else {
                                evaluator.emit_diag(
                                    E1033,
                                    assign.key,
                                    member=assign.key.sym_name,
                                    type=str(conn_type)
                                );
                            }
                        }
                    }
                }
            }

            return right_type;
        }
        if isinstance(expr.op, uni.DisconnectOp) {
            fcond = expr.op.edge_spec.filter_cond;
            if fcond is not None and fcond.f_type is not None {
                validate_conn_type(fcond.f_type);
            }

            if evaluator.prefetch and evaluator.prefetch.bool_class {
                return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
            }
        }
    }

    if isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_SPAWN {
        def is_walker_instance(t: jtypes.TypeBase) -> bool {
            if isinstance(t, jtypes.ClassType)
            and t.is_walker_type()
            and t.is_instance() {
                return True;
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_walker_instance(m) for m in t.types);
            }

            if isinstance(t, jtypes.ClassType)
            and t.is_builtin()
            and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return is_walker_instance(t.private.type_args[0]);
                }
            }
            return False;
        }
        def is_archetype_target(t: jtypes.TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, jtypes.UnknownType) {
                return True;
            }
            if isinstance(t, jtypes.ClassType) {
                if t.is_node_type() or t.is_edge_type() {
                    return True;
                }
                if (
                    t.is_builtin()
                    and t.shared.class_name in ("list", "tuple", "set", "frozenset")
                ) {
                    if t.private.type_args and len(t.private.type_args) > 0 {
                        return all(is_archetype_target(a) for a in t.private.type_args);
                    }

                    return True;
                }
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_archetype_target(m) for m in t.types);
            }
            return False;
        }

        left_unknown = (
            left_type.is_any_type() or isinstance(left_type, jtypes.UnknownType)
        );
        right_unknown = (
            right_type.is_any_type() or isinstance(right_type, jtypes.UnknownType)
        );
        left_walker = is_walker_instance(left_type);
        right_walker = is_walker_instance(right_type);
        if not left_walker and not right_walker {
            if not (left_unknown or right_unknown) {
                evaluator.emit_diag(
                    E1114, expr, left=str(left_type), right=str(right_type)
                );
            }
            return right_type;
        }

        target_node = expr.right if left_walker else expr.left;
        target_type = right_type if left_walker else left_type;
        if not is_archetype_target(target_type) {
            evaluator.emit_diag(E1115, target_node, type=str(target_type));
        }

        return left_type if left_walker else right_type;
    }

    if isinstance(expr.op, uni.Token) and expr.op.name == Tok.WALRUS_EQ {
        if isinstance(expr.left, uni.Name) and expr.left.sym {
            expr.left.type = right_type;
        }
        return right_type;
    }

    if isinstance(expr.op, uni.Token)
    and expr.op.name in [
        Tok.PIPE_FWD,
        Tok.A_PIPE_FWD,
        Tok.PIPE_BKWD,
        Tok.A_PIPE_BKWD
    ] {
        is_forward = expr.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD];
        callable_node = expr.right if is_forward else expr.left;
        arg_node = expr.left if is_forward else expr.right;
        params: list[uni.Expr | uni.KWPair] = (
            `list(arg_node.values)
                if (isinstance(arg_node, uni.TupleVal) and arg_node.values)
                else [arg_node]
        );

        synth_call = uni.FuncCall(
            target=callable_node, params=params, genai_call=None, kid=expr.kid
        );
        synth_call.parent = expr.parent;
        return evaluator.validate_call_args(synth_call);
    }
    return jtypes.UnknownType();
}
