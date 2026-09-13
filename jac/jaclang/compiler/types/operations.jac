import from jaclang.compiler.frontend.unitree {
    BinaryExpr,
    ConnectOp,
    DisconnectOp,
    Expr,
    FuncCall,
    KWPair,
    Name,
    Token,
    TupleVal,
    UniNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from .types {
    AnyType,
    ClassType,
    FunctionType,
    NeverType,
    TypeBase,
    TypeVarType,
    UnionType,
    UnknownType
}
import from jaclang.compiler.frontend.diagnostics {
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
import from .fixed_width {
    both_numeric,
    folded_number,
    numeric_name_of,
    shift_result_type,
    unify_numeric_operands
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

def _is_runtime_archetype_instance(t: TypeBase, base_name: str) -> bool {
    if not (isinstance(t, ClassType) and t.is_instance()) {
        return False;
    }
    for cls in (t.shared.mro or []) {
        if cls.shared.class_name == base_name {
            return True;
        }
    }
    return False;
}

def _has_gradual_type_args(t: TypeBase) -> bool {
    if not isinstance(t, ClassType) {
        return False;
    }
    for a in (t.private.type_args or []) {
        if isinstance(a, (AnyType, UnknownType)) {
            return True;
        }
        if isinstance(a, ClassType) and a.is_any_instance() {
            return True;
        }
    }
    return False;
}

glob BITWISE_OPERATORS: set[str] = {Tok.BW_AND, Tok.BW_OR, Tok.BW_XOR},
     SHIFT_OPERATORS: set[str] = {Tok.LSHIFT, Tok.RSHIFT};

def get_numeric_promotion_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    op: str,
    left_node: Expr | None = None,
    right_node: Expr | None = None,
    diag_node: UniNode | None = None
) -> TypeBase | None {
    if not both_numeric(left_type, right_type) {
        return None;
    }
    float_class = evaluator.prefetch.float_class;
    if float_class is None {
        return None;
    }
    if op in SHIFT_OPERATORS {
        if not is_int_kind_type(left_type) or not is_int_kind_type(right_type) {
            return None;
        }
        return shift_result_type(
            evaluator, left_type, right_type, left_node, right_node
        );
    }
    if op in BITWISE_OPERATORS
        and not (is_int_kind_type(left_type) and is_int_kind_type(right_type)) {
        return None;
    }
    unified = unify_numeric_operands(
        evaluator,
        left_type,
        right_type,
        left_node,
        right_node,
        diag_node if diag_node is not None else left_node,
        op
    );
    if unified is None {
        return UnknownType(is_diagnosed=True);
    }
    if op == Tok.DIV {
        return evaluator._convert_to_instance(float_class);
    }
    return unified;
}

def is_int_kind_type(t: TypeBase) -> bool {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, NumericKind }
    name = numeric_name_of(t);
    return name is not None
        and JAC_TYPE_REGISTRY.numeric_kind_of(name) == NumericKind.IntKind;
}

def get_pow_result_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    right_node: (Expr | None),
    left_node: Expr | None = None,
    diag_node: UniNode | None = None
) -> (TypeBase | None) {
    import from jaclang.compiler.frontend.const_fold { fold_const }
    float_class = evaluator.prefetch.float_class;
    if float_class is None or not both_numeric(left_type, right_type) {
        return None;
    }
    (rok, rv) = fold_const(right_node);
    if rok and isinstance(rv, int) and not isinstance(rv, bool) and rv < 0 {
        return evaluator._convert_to_instance(float_class);
    }
    promoted = get_numeric_promotion_type(
        evaluator, left_type, right_type, Tok.STAR_POW, left_node, right_node, diag_node
    );
    if promoted is None or isinstance(promoted, UnknownType) {
        return promoted;
    }
    if not is_int_kind_type(promoted) {
        return evaluator._convert_to_instance(float_class);
    }
    if rok and isinstance(rv, int) and not isinstance(rv, bool) {
        return promoted;
    }
    return evaluator._convert_to_instance(float_class);
}

def is_annotation_type(evaluator: TypeEvaluator, ty: TypeBase) -> bool {
    if ty.is_instantiable() or isinstance(ty, UnionType) {
        return True;
    }

    if isinstance(ty, TypeVarType) {
        return True;
    }

    if isinstance(ty, FunctionType) and ty.is_from_callable_annotation() {
        return True;
    }

    if isinstance(ty, NeverType) {
        return True;
    }

    none_type_class = evaluator.prefetch.none_type_class;
    if isinstance(ty, ClassType) and none_type_class is not None {
        return ty.shared.same_class(none_type_class.shared);
    }
    return False;
}

def get_type_of_binary_operation(
    evaluator: TypeEvaluator, expr: BinaryExpr
) -> TypeBase {
    left_type = evaluator.get_type_of_expression(expr.left);
    right_type = evaluator.get_type_of_expression(expr.right);

    if isinstance(expr.op, Token)
        and expr.op.name in BINARY_OPERATOR_MAP
        and expr.op.name != Tok.BW_OR {
        for operand_type in (left_type, right_type) {
            if isinstance(operand_type, AnyType) or operand_type.is_any_instance() {
                return operand_type;
            }
            if isinstance(operand_type, UnknownType) {
                if operand_type.is_diagnosed or operand_type.is_incomplete {
                    return operand_type;
                }
                evaluator.emit_diag(
                    E1055, expr, method=BINARY_OPERATOR_MAP[expr.op.name][0]
                );
                return UnknownType(is_diagnosed=True);
            }
        }
        if isinstance(left_type, TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, ClassType) {
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
                return UnknownType();
            }
            if left_type.bound and isinstance(left_type.bound, ClassType) {
                result = evaluator.get_type_of_magic_method_call(
                    left_type.bound, magic, [expr.right], None
                );
                if result {
                    return result;
                }

                evaluator.emit_diag(E1010, expr, op=magic, type=str(left_type.bound));
                return UnknownType();
            }

            evaluator.emit_diag(E1010, expr, op=magic, type=left_type.name);
            return UnknownType();
        }
        if isinstance(right_type, TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

            if right_type.constraints {
                for constraint_type in right_type.constraints {
                    if isinstance(constraint_type, ClassType) {
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
                return UnknownType();
            }
            if right_type.bound and isinstance(right_type.bound, ClassType) {
                result = evaluator.get_type_of_magic_method_call(
                    right_type.bound, rmagic, [expr.left], None
                );
                if result {
                    return result;
                }

                evaluator.emit_diag(E1010, expr, op=rmagic, type=str(right_type.bound));
                return UnknownType();
            }

            evaluator.emit_diag(E1010, expr, op=rmagic, type=right_type.name);
            return UnknownType();
        }
    }

    _l_anycls = evaluator.is_explicit_any(left_type);
    _r_anycls = evaluator.is_explicit_any(right_type);
    if (
        left_type.is_any_type() or right_type.is_any_type() or (_l_anycls and _r_anycls)
    ) {
        if not (isinstance(expr.op, Token) and expr.op.name == Tok.BW_OR) {
            return UnknownType();
        }
    }

    if (
        (expr.op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN))
        and (evaluator.prefetch.bool_class is not None)
    ) {
        return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
    }

    if (isinstance(expr.op, Token) and (expr.op.name in BINARY_OPERATOR_MAP)) {
        if expr.op.name == Tok.BW_OR {
            if is_annotation_type(evaluator, left_type)
                and is_annotation_type(evaluator, right_type) {
                return UnionType(
                    types=[
                        evaluator._convert_to_instance(left_type),
                        evaluator._convert_to_instance(right_type)
                    ]
                );
            }
        }
        (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];

        if expr.op.name not in (Tok.EE, Tok.NE, Tok.BW_OR) {
            for operand_type in (left_type, right_type) {
                if evaluator._diag_unnarrowed_optional(
                    expr, operand_type, "a binary operand"
                ) {
                    return UnknownType(is_diagnosed=True);
                }
            }
        }

        if expr.op.name in ARITHMETIC_OPERATORS
            or expr.op.name in BITWISE_OPERATORS
            or expr.op.name in SHIFT_OPERATORS {
            if expr.op.name == Tok.STAR_POW {
                pow_type = get_pow_result_type(
                    evaluator, left_type, right_type, expr.right, expr.left, expr
                );
                if pow_type is not None {
                    return pow_type;
                }
            }
            promoted_type = get_numeric_promotion_type(
                evaluator,
                left_type,
                right_type,
                expr.op.name,
                expr.left,
                expr.right,
                expr
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
                return UnionType(types=[left_type, right_type]);
            }
            if _has_gradual_type_args(left_type)
                or _has_gradual_type_args(right_type) {
                return UnknownType();
            }
            evaluator.emit_diag(E1055, expr, method=magic);
            return UnknownType();
        }
        return result;
    }

    if isinstance(expr.op, (ConnectOp, DisconnectOp)) {
        def is_node_type_instance(t: TypeBase) -> bool {
            if isinstance(t, TypeVarType) and t.bound is not None {
                bound = t.bound.clone_as_instance()
                    if isinstance(t.bound, ClassType)
                    else t.bound;
                return is_node_type_instance(bound);
            }
            if isinstance(t, ClassType) and t.is_node_type() and t.is_instance() {
                return True;
            }
            return _is_runtime_archetype_instance(t, "NodeArchetype");
        }

        def unparameterized_connect_collection(t: TypeBase) -> str | None {
            if not isinstance(t, ClassType) {
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

        def is_valid_node_operand(t: TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, UnknownType) {
                return True;
            }
            if is_node_type_instance(t) {
                return True;
            }
            if isinstance(t, UnionType) {
                return all(is_valid_node_operand(m) for m in t.types);
            }

            if isinstance(t, ClassType)
                and t.is_builtin()
                and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    elem = t.private.type_args[0];
                    members = elem.types if isinstance(elem, UnionType) else [elem];
                    return all(
                        m.is_any_type()
                            or isinstance(m, UnknownType)
                            or is_node_type_instance(m) for m in members
                    );
                }

                return False;
            }
            return False;
        }

        if (left_unparam := unparameterized_connect_collection(left_type))
            is not None {
            evaluator.emit_diag(E1118, expr.left, side="left", type=left_unparam);
        } elif not is_valid_node_operand(left_type) {
            evaluator.emit_diag(E1096, expr.left);
        }

        def is_valid_right_operand(t: TypeBase) -> bool {
            if is_valid_node_operand(t) {
                return True;
            }
            if not isinstance(t, ClassType) {
                return False;
            }

            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                if (t.private.type_args is not None and len(t.private.type_args) > 0) {
                    elem_type = t.private.type_args[0];
                    if elem_type.is_any_type()
                        or isinstance(elem_type, UnknownType)
                        or is_node_type_instance(elem_type) {
                        return True;
                    }
                }
            }
            return False;
        }
        if (right_unparam := unparameterized_connect_collection(right_type))
            is not None {
            evaluator.emit_diag(E1118, expr.right, side="right", type=right_unparam);
        } elif not is_valid_right_operand(right_type) {
            evaluator.emit_diag(E1097, expr.right);
        }

        def validate_conn_type(type_expr: Expr) -> TypeBase {
            ct = evaluator.get_type_of_expression(type_expr);

            if isinstance(ct, ClassType) and evaluator._is_type_subscript(ct) {
                ct = evaluator._get_type_for_member_lookup(ct);
            }
            if (
                not ct.is_any_type()
                and not isinstance(ct, UnknownType)
                and (not isinstance(ct, ClassType) or not ct.is_edge_type())
            ) {
                evaluator.emit_diag(E1098, type_expr);
                return UnknownType();
            }
            return ct;
        }
        if isinstance(expr.op, ConnectOp) {
            if expr.op.conn_type {
                conn_type = validate_conn_type(expr.op.conn_type);
                if (
                    not isinstance(conn_type, UnknownType)
                    and (assign_compr := expr.op.conn_assign)
                ) {
                    for assign in assign_compr.assigns {
                        edge_inst_type = evaluator._convert_to_instance(conn_type);
                        if (assign.key is not None)
                            and isinstance(edge_inst_type, ClassType) {
                            if (
                                member
                                := evaluator._lookup_object_member(
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

            if expr.op.capture_edges and evaluator.prefetch.list_class {
                edge_type = evaluator._get_class_from_module(
                    evaluator.jac_builtins_module, "Edge"
                );
                if edge_type is not None {
                    result = evaluator.prefetch.list_class.clone_as_instance();
                    result.private.type_args = [edge_type.clone_as_instance()];
                    return result;
                }
            }
            return left_type if expr.op.edge_dir.value == 1 else right_type;
        }
        if isinstance(expr.op, DisconnectOp) {
            fcond = expr.op.edge_spec.filter_cond;
            if fcond is not None and fcond.f_type is not None {
                validate_conn_type(fcond.f_type);
            }

            if evaluator.prefetch and evaluator.prefetch.bool_class {
                return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
            }
        }
    }

    if isinstance(expr.op, Token) and expr.op.name == Tok.KW_SPAWN {
        def is_walker_instance(t: TypeBase) -> bool {
            if isinstance(t, ClassType) and t.is_walker_type() and t.is_instance() {
                return True;
            }
            if _is_runtime_archetype_instance(t, "WalkerArchetype") {
                return True;
            }
            if isinstance(t, UnionType) {
                return all(is_walker_instance(m) for m in t.types);
            }

            if isinstance(t, ClassType)
                and t.is_builtin()
                and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return is_walker_instance(t.private.type_args[0]);
                }
            }
            return False;
        }
        def is_archetype_target(t: TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, UnknownType) {
                return True;
            }
            if isinstance(t, ClassType) {
                if t.is_node_type() or t.is_edge_type() {
                    return True;
                }
                if _is_runtime_archetype_instance(t, "NodeArchetype")
                    or _is_runtime_archetype_instance(t, "EdgeArchetype") {
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
            if isinstance(t, UnionType) {
                return all(is_archetype_target(m) for m in t.types);
            }
            return False;
        }

        def bridged_spawn_type(side: Expr, t: TypeBase) -> TypeBase | None {
            if not (isinstance(side, FuncCall) and evaluator._is_sv_async_call(side)) {
                return None;
            }
            if not (
                isinstance(t, ClassType)
                and t.is_builtin("Coroutine")
                and t.private.type_args
                and is_walker_instance(t.private.type_args[-1])
            ) {
                return None;
            }
            return t;
        }
        for (side, side_type) in ((expr.left, left_type), (expr.right, right_type)) {
            bridged = bridged_spawn_type(side, side_type);
            if bridged is not None {
                return bridged;
            }
        }

        left_unknown = left_type.is_any_type() or isinstance(left_type, UnknownType);
        right_unknown = right_type.is_any_type() or isinstance(right_type, UnknownType);
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
        _jid_target = (
            isinstance(target_type, ClassType)
            and target_type.is_builtin("str")
            and expr.in_client_context()
        );
        if not _jid_target and not is_archetype_target(target_type) {
            evaluator.emit_diag(E1115, target_node, type=str(target_type));
        }

        return left_type if left_walker else right_type;
    }

    if isinstance(expr.op, Token) and expr.op.name == Tok.WALRUS_EQ {
        if isinstance(expr.left, Name) and expr.left.sym {
            expr.left.type = right_type;
        }
        return right_type;
    }

    if isinstance(expr.op, Token)
        and expr.op.name
            in [Tok.PIPE_FWD, Tok.A_PIPE_FWD, Tok.PIPE_BKWD, Tok.A_PIPE_BKWD] {
        is_forward = expr.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD];
        callable_node = expr.right if is_forward else expr.left;
        arg_node = expr.left if is_forward else expr.right;
        params: list[Expr | KWPair] = (
            `list(arg_node.values)
                if (isinstance(arg_node, TupleVal) and arg_node.values)
                else [arg_node]
        );

        synth_call = FuncCall(
            target=callable_node, params=params, genai_call=None, kid=expr.kid
        );
        if expr.parent is not None {
            synth_call.set_parent(expr.parent);
        }
        return evaluator.validate_call_args(synth_call);
    }
    return UnknownType();
}
