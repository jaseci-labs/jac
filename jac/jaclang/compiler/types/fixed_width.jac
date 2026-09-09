import from jaclang.compiler.frontend.unitree {
    AtomUnit,
    Expr,
    Float,
    FuncCall,
    Int,
    Name,
    Token,
    UnaryExpr,
    UniNode
}
import from jaclang.compiler.frontend.constant { TOKEN_MAP, Tokens as Tok }
import from jaclang.compiler.frontend.diagnostics { E1126, E1127, E1128, E1130 }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, NumericKind }
import from jaclang.compiler.types.types {
    AnyType,
    ClassType,
    TypeBase,
    UnionType,
    UnknownType
}
import type from jaclang.compiler.types.type_evaluator { TypeEvaluator }

obj AssignVerdict {
    has ok: bool,
        diagnosed: bool = False;
}

def interval_of_op(
    op: str,
    left: (tuple[int, int] | None),
    right: (tuple[int, int] | None),
    target: str
) -> bool {
    if left is None or right is None {
        return False;
    }
    if not JAC_TYPE_REGISTRY.is_sized(target) {
        return False;
    }
    `entry = JAC_TYPE_REGISTRY.get(target);
    if `entry is None or `entry.is_float {
        return False;
    }
    (a_lo, a_hi) = left;
    (b_lo, b_hi) = right;
    if op == "+" {
        (lo, hi) = (a_lo + b_lo, a_hi + b_hi);
    } elif op == "-" {
        (lo, hi) = (a_lo - b_hi, a_hi - b_lo);
    } elif op == "*" {
        ends = [a_lo * b_lo, a_lo * b_hi, a_hi * b_lo, a_hi * b_hi];
        (lo, hi) = (min(ends), max(ends));
    } elif op == "neg" {
        (lo, hi) = (-a_hi, -a_lo);
    } else {
        return False;
    }
    (t_lo, t_hi) = JAC_TYPE_REGISTRY.range_of(target);
    return t_lo <= lo and hi <= t_hi;
}

def interval_of_expr(expr: (Expr | None)) -> (tuple[int, int] | None) {
    if expr is None {
        return None;
    }
    value = folded_number(expr);
    if isinstance(value, int) and not isinstance(value, bool) {
        return (value, value);
    }
    name = numeric_name_of(expr.type);
    if name is None or not JAC_TYPE_REGISTRY.is_sized(name) {
        return None;
    }
    `entry = JAC_TYPE_REGISTRY.get(name);
    if `entry is None or `entry.is_float {
        return None;
    }
    return JAC_TYPE_REGISTRY.range_of(name);
}

def numeric_name_of(t: TypeBase | None) -> str | None {
    if isinstance(t, AnyType) {
        return t.foreign_scalar;
    }
    if not isinstance(t, ClassType) or not t.is_builtin() or not t.is_instance() {
        return None;
    }
    name = t.shared.class_name;
    return name if JAC_TYPE_REGISTRY.is_numeric(name) else None;
}

def folded_number(expr: UniNode | None) -> int | float | None {
    cur = expr;
    while isinstance(cur, AtomUnit) {
        cur = cur.value;
    }
    if isinstance(cur, Int) {
        return int(cur.lit_value);
    }
    if isinstance(cur, Float) {
        return float(cur.lit_value);
    }
    if isinstance(cur, UnaryExpr) and isinstance(cur.op, Token) {
        inner = folded_number(cur.operand);
        if inner is None {
            return None;
        }
        if cur.op.name == Tok.MINUS {
            if isinstance(inner, int) {
                return -inner;
            }
            return -inner;
        }
        if cur.op.name == Tok.PLUS {
            return inner;
        }
    }
    return None;
}

def _numeric_dest(evaluator: TypeEvaluator, dest: TypeBase) -> ClassType | None {
    if isinstance(dest, UnionType) {
        members = [
            m
            for m in dest.types
            if numeric_name_of(m) is not None
        ];
        if len(members) != 1 {
            return None;
        }
        dest = members[0];
    }
    inst = evaluator._convert_to_instance(dest);
    if isinstance(inst, ClassType) and numeric_name_of(inst) is not None {
        return inst;
    }
    return None;
}

def annotate_coercion(expr: Expr | None, target: ClassType) {
    if expr is not None {
        expr.coerce_to = target.shared.class_name;
    }
}

def adopt_literal(
    evaluator: TypeEvaluator,
    expr: Expr,
    value: int | float,
    target: ClassType,
    probe: bool = False
) -> AssignVerdict {
    name = target.shared.class_name;
    if JAC_TYPE_REGISTRY.literal_fits(name, value) {
        if not probe {
            annotate_coercion(expr, target);
        }
        return AssignVerdict(ok=True);
    }
    if probe {
        return AssignVerdict(ok=False);
    }
    if JAC_TYPE_REGISTRY.numeric_kind_of(name) == NumericKind.FloatKind {
        import from jaclang.runtime.scalars { float_max }
        evaluator.emit_diag(E1130, expr, value=value, type=name, max=float_max(name));
        return AssignVerdict(ok=False, diagnosed=True);
    }
    if isinstance(value, float) {
        return AssignVerdict(ok=False);
    }
    (lo, hi) = JAC_TYPE_REGISTRY.range_of(name);
    evaluator.emit_diag(E1126, expr, value=value, type=name, min=lo, max=hi);
    return AssignVerdict(ok=False, diagnosed=True);
}

def is_brand(t: TypeBase | None) -> bool {
    return isinstance(t, ClassType) and t.private.distinct_key is not None;
}

def assign_numeric_expr(
    evaluator: TypeEvaluator,
    expr: Expr | None,
    src: TypeBase,
    dest: TypeBase,
    probe: bool = False
) -> AssignVerdict | None {
    if is_brand(src) or is_brand(dest) {
        return None;
    }
    dest_inst = _numeric_dest(evaluator, dest);
    if dest_inst is None {
        return None;
    }
    dn = dest_inst.shared.class_name;
    dest_sized = JAC_TYPE_REGISTRY.is_sized(dn);
    if expr is not None and dest_sized {
        value = folded_number(expr);
        if value is not None {
            verdict = adopt_literal(evaluator, expr, value, dest_inst, probe);
            if verdict.ok or verdict.diagnosed or probe {
                return verdict;
            }
        }
    }
    sn = numeric_name_of(src);
    if sn is None {
        return None;
    }
    if JAC_TYPE_REGISTRY.widens_to(sn, dn) {
        if sn != dn and not probe and (dest_sized or JAC_TYPE_REGISTRY.is_sized(sn)) {
            annotate_coercion(expr, dest_inst);
        }
        return AssignVerdict(ok=True);
    }
    if not (dest_sized or JAC_TYPE_REGISTRY.is_sized(sn)) {
        return None;
    }
    if JAC_TYPE_REGISTRY.numeric_kind_of(sn) == NumericKind.FloatKind
        and JAC_TYPE_REGISTRY.numeric_kind_of(dn) == NumericKind.IntKind {
        return None;
    }
    if expr is not None and not probe {
        evaluator.emit_diag(E1127, expr, src=sn, dest=dn);
        return AssignVerdict(ok=False, diagnosed=True);
    }
    return AssignVerdict(ok=False);
}

def unify_numeric_operands(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    left_node: Expr | None,
    right_node: Expr | None,
    diag_node: UniNode | None,
    op: str
) -> TypeBase | None {
    ln = numeric_name_of(left_type);
    rn = numeric_name_of(right_type);
    if (
        ln is None
        or rn is None
        or not isinstance(left_type, ClassType)
        or not isinstance(right_type, ClassType)
        or is_brand(left_type)
        or is_brand(right_type)
    ) {
        return None;
    }
    left_inst: ClassType = left_type;
    right_inst: ClassType = right_type;
    if JAC_TYPE_REGISTRY.is_sized(rn)
        and not JAC_TYPE_REGISTRY.is_sized(ln)
        and left_node is not None {
        value = folded_number(left_node);
        if value is not None {
            verdict = adopt_literal(evaluator, left_node, value, right_inst);
            if verdict.diagnosed {
                return None;
            }
            if verdict.ok {
                return right_inst;
            }
        }
    }
    if JAC_TYPE_REGISTRY.is_sized(ln)
        and not JAC_TYPE_REGISTRY.is_sized(rn)
        and right_node is not None {
        value = folded_number(right_node);
        if value is not None {
            verdict = adopt_literal(evaluator, right_node, value, left_inst);
            if verdict.diagnosed {
                return None;
            }
            if verdict.ok {
                return left_inst;
            }
        }
    }
    unified = JAC_TYPE_REGISTRY.unify(ln, rn);
    if unified is None {
        if diag_node is not None {
            evaluator.emit_diag(
                E1128, diag_node, op=TOKEN_MAP.get(op, op), left=ln, right=rn
            );
        }
        return None;
    }
    sized_pair = JAC_TYPE_REGISTRY.is_sized(ln) or JAC_TYPE_REGISTRY.is_sized(rn);
    if unified == ln {
        if rn != ln and sized_pair {
            annotate_coercion(right_node, left_inst);
        }
        return left_inst;
    }
    if sized_pair {
        annotate_coercion(left_node, right_inst);
    }
    return right_inst;
}

def both_numeric(left_type: TypeBase, right_type: TypeBase) -> bool {
    return numeric_name_of(left_type) is not None
        and numeric_name_of(right_type) is not None;
}

def is_unsigned_type(t: TypeBase | None) -> bool {
    name = numeric_name_of(t);
    if name is None {
        return False;
    }
    `entry = JAC_TYPE_REGISTRY.get(name);
    return `entry is not None
        and `entry.sized
        and not `entry.is_float
        and not `entry.signed;
}

glob WRAPPING_BINARY_BUILTINS: list[str] = [
         "wrapping_add",
         "wrapping_sub",
         "wrapping_mul",
         "wrapping_shl"
     ],
     WRAPPING_UNARY_BUILTINS: list[str] = ["wrapping_neg"];

def _is_jac_builtin_fn(evaluator: TypeEvaluator, callee: Expr, name: str) -> bool {
    if not isinstance(callee, Name) or callee.sym_name != name {
        return False;
    }
    stub_sym = evaluator.jac_builtins_module.names_in_scope.get(name);
    return stub_sym is not None and callee.sym is stub_sym;
}

def fixed_width_call_type(
    evaluator: TypeEvaluator, call: FuncCall, callee_type: TypeBase
) -> TypeBase | None {
    args = [
        a
        for a in (call.params or [])
        if isinstance(a, Expr)
    ];
    if len(args) != len(call.params or []) {
        return None;
    }
    if (
        isinstance(callee_type, ClassType)
        and callee_type.is_builtin()
        and not callee_type.is_instance()
        and JAC_TYPE_REGISTRY.is_sized(callee_type.shared.class_name)
        and len(args) == 1
    ) {
        arg_type = evaluator.get_type_of_expression(args[0]);
        if numeric_name_of(arg_type) is None {
            return None;
        }
        target = evaluator._convert_to_instance(callee_type);
        value = folded_number(args[0]);
        if isinstance(target, ClassType)
            and value is not None
            and isinstance(value, int) {
            adopt_literal(evaluator, args[0], value, target);
        }
        return target;
    }
    callee = call.target;
    for name in WRAPPING_BINARY_BUILTINS {
        if _is_jac_builtin_fn(evaluator, callee, name) and len(args) == 2 {
            left_type = evaluator.get_type_of_expression(args[0]);
            right_type = evaluator.get_type_of_expression(args[1]);
            if not both_numeric(left_type, right_type) {
                return None;
            }
            unified = unify_numeric_operands(
                evaluator, left_type, right_type, args[0], args[1], call, name
            );
            if unified is None {
                return UnknownType(is_diagnosed=True);
            }
            if JAC_TYPE_REGISTRY.is_sized(numeric_name_of(unified) or "") {
                return unified;
            }
            return None;
        }
    }
    for name in WRAPPING_UNARY_BUILTINS {
        if _is_jac_builtin_fn(evaluator, callee, name) and len(args) == 1 {
            operand_type = evaluator.get_type_of_expression(args[0]);
            operand = numeric_name_of(operand_type);
            if operand is not None and JAC_TYPE_REGISTRY.is_sized(operand) {
                return operand_type;
            }
            return None;
        }
    }
    return None;
}

def shift_result_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    left_node: Expr | None,
    right_node: Expr | None
) -> TypeBase | None {
    ln = numeric_name_of(left_type);
    rn = numeric_name_of(right_type);
    if (
        ln is None
        or rn is None
        or not isinstance(left_type, ClassType)
        or not isinstance(right_type, ClassType)
    ) {
        return None;
    }
    if JAC_TYPE_REGISTRY.is_sized(rn)
        and not JAC_TYPE_REGISTRY.is_sized(ln)
        and left_node is not None {
        value = folded_number(left_node);
        if value is not None {
            verdict = adopt_literal(evaluator, left_node, value, right_type);
            if verdict.diagnosed {
                return UnknownType(is_diagnosed=True);
            }
            if verdict.ok {
                return right_type;
            }
        }
    }
    if JAC_TYPE_REGISTRY.is_sized(ln)
        and not JAC_TYPE_REGISTRY.is_sized(rn)
        and right_node is not None {
        value = folded_number(right_node);
        if value is not None {
            verdict = adopt_literal(evaluator, right_node, value, left_type);
            if verdict.diagnosed {
                return UnknownType(is_diagnosed=True);
            }
        }
    }
    return left_type;
}
