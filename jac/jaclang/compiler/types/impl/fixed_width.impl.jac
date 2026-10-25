impl value_in_range(value: int, t_lo: int, t_hi: int, wide: bool) -> bool {
    if wide {
        return value >= 0;
    }
    return t_lo <= value and value <= t_hi;
}

impl corner_in_range(
    op: str, x: int, y: int, t_lo: int, t_hi: int, wide: bool
) -> bool {
    if op == "neg" {
        if x == I64_BOTTOM {
            return wide;
        }
        return value_in_range(-x, t_lo, t_hi, wide);
    }
    if op == "+" {
        if y > 0 and x > I64_TOP - y {
            return wide;
        }
        if y < 0 and x < I64_BOTTOM - y {
            return False;
        }
        return value_in_range(x + y, t_lo, t_hi, wide);
    }
    if op == "-" {
        if y < 0 and x > I64_TOP + y {
            return wide;
        }
        if y > 0 and x < I64_BOTTOM + y {
            return False;
        }
        return value_in_range(x - y, t_lo, t_hi, wide);
    }
    if op != "*" {
        return False;
    }
    if x == 0 or y == 0 {
        return value_in_range(0, t_lo, t_hi, wide);
    }
    if x == I64_BOTTOM or y == I64_BOTTOM {
        other = y if x == I64_BOTTOM else x;
        if other == 1 {
            return value_in_range(I64_BOTTOM, t_lo, t_hi, wide);
        }
        return wide and other == -1;
    }
    ax = x if x > 0 else -x;
    ay = y if y > 0 else -y;
    quotient = I64_TOP // ay;
    rest = I64_TOP - quotient * ay;
    if ax <= quotient {
        return value_in_range(x * y, t_lo, t_hi, wide);
    }
    if (x < 0) != (y < 0) {
        return ax == quotient + 1
            and rest == ay - 1
            and value_in_range(I64_BOTTOM, t_lo, t_hi, wide);
    }

    reach = 2 * quotient + (1 if 2 * rest + 1 >= ay else 0);
    return wide and ax <= reach;
}

impl unsigned_top_in_range(
    op: str, top_left: bool, o_lo: int, o_hi: int, wide: bool, signed_wide: bool
) -> bool {
    zero = o_lo == 0 and o_hi == 0;
    if op == "*" {
        return (o_lo >= 0 and o_hi <= 1) if wide else zero;
    }
    if op == "+" {
        if wide {
            return zero;
        }
        return signed_wide and o_lo == I64_BOTTOM and o_hi == I64_BOTTOM;
    }
    if op == "-" {
        if top_left {
            return wide and zero;
        }
        return signed_wide and o_lo == I64_TOP and o_hi == I64_TOP;
    }
    return False;
}

impl interval_of_op(
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
    if op not in ("+", "-", "*", "neg") {
        return False;
    }
    (a_lo, a_hi) = left;
    (b_lo, b_hi) = right;
    wide = `entry.width >= 64 and not `entry.signed;
    t_lo = 0;
    t_hi = 0;
    if not wide {
        (t_lo, t_hi) = JAC_TYPE_REGISTRY.range_of(target);
    }
    a_top = a_hi < a_lo;
    b_top = b_hi < b_lo;
    if a_top and b_top {
        return False;
    }
    if a_top or b_top {
        (o_lo, o_hi) = right if a_top else left;
        return unsigned_top_in_range(
            op, a_top, o_lo, o_hi, wide, `entry.width >= 64 and `entry.signed
        );
    }
    for x in [a_lo, a_hi] {
        for y in [b_lo, b_hi] {
            if not corner_in_range(op, x, y, t_lo, t_hi, wide) {
                return False;
            }
        }
    }
    return True;
}

impl interval_of_expr(expr: (Expr | None)) -> (tuple[int, int] | None) {
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
    if `entry.width >= 64 and not `entry.signed {
        return (0, -1);
    }
    return JAC_TYPE_REGISTRY.range_of(name);
}

impl numeric_name_of(t: TypeBase | None) -> str | None {
    if isinstance(t, AnyType) {
        return t.foreign_scalar;
    }
    if not isinstance(t, ClassType) or not t.is_builtin() or not t.is_instance() {
        return None;
    }
    name = t.shared.class_name;
    return name if JAC_TYPE_REGISTRY.is_numeric(name) else None;
}

impl folded_number(expr: UniNode | None) -> int | float | None {
    cur = expr;
    while isinstance(cur, AtomUnit) {
        cur = cur.value;
    }
    if isinstance(cur, Int) {
        value = int_literal_i64(cur.value);
        if value is not None {
            return value;
        }
        return WideLiteral(
            text=cur.value, magnitude_bits=int_literal_u64_bits(cur.value)
        );
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
            return _negated(inner);
        }
        if cur.op.name == Tok.PLUS {
            return inner;
        }
    }
    return None;
}

impl _negated(value: int | float | WideLiteral) -> int | float | WideLiteral {
    """A literal past a signed 64-bit int stays a `WideLiteral`, so no fold
    computes a value the native compiler cannot hold; -2**63 is the one
    negation that crosses back.""";
    if isinstance(value, WideLiteral) {
        if not value.negative and value.magnitude_bits == I64_BOTTOM {
            return I64_BOTTOM;
        }
        return WideLiteral(
            text=value.text,
            negative=not value.negative,
            magnitude_bits=value.magnitude_bits
        );
    }
    if isinstance(value, int) and value == I64_BOTTOM {
        return WideLiteral(text="9223372036854775808", magnitude_bits=I64_BOTTOM);
    }
    return -value;
}

impl WideLiteral.fits_u64 -> bool {
    return not self.negative and self.magnitude_bits is not None;
}

impl WideLiteral.written -> str {
    return f"-{self.text}" if self.negative else self.text;
}

impl _wide_unsigned(name: str) -> bool {
    `entry = JAC_TYPE_REGISTRY.get(name);
    return `entry is not None
        and not `entry.is_float
        and not `entry.signed
        and `entry.width >= 64;
}

impl _range_text(name: str) -> tuple[str, str] {
    """A u64's top, 2**64 - 1, is no native int, so the range is reported as
    text.""";
    if _wide_unsigned(name) {
        return ("0", "18446744073709551615");
    }
    (lo, hi) = JAC_TYPE_REGISTRY.range_of(name);
    return (str(lo), str(hi));
}

impl _numeric_dest(evaluator: TypeEvaluator, dest: TypeBase) -> ClassType | None {
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

impl annotate_coercion(expr: Expr | None, target: ClassType) {
    if expr is not None {
        expr.coerce_to = target.shared.class_name;
    }
}

impl adopt_literal(
    evaluator: TypeEvaluator,
    expr: Expr,
    value: int | float | WideLiteral,
    target: ClassType,
    probe: bool = False
) -> AssignVerdict {
    name = target.shared.class_name;
    fits = False;
    if not isinstance(value, WideLiteral) {
        fits = JAC_TYPE_REGISTRY.literal_fits(name, value);
    } elif JAC_TYPE_REGISTRY.numeric_kind_of(name) == NumericKind.FloatKind {
        magnitude = int_literal_float(value.text);
        fits = JAC_TYPE_REGISTRY.literal_fits(
            name, -magnitude if value.negative else magnitude
        );
    } else {
        fits = value.fits_u64() and _wide_unsigned(name);
    }
    if fits {
        if not probe {
            annotate_coercion(expr, target);
        }
        return AssignVerdict(ok=True);
    }
    if probe {
        return AssignVerdict(ok=False);
    }
    shown = value.written() if isinstance(value, WideLiteral) else value;
    if JAC_TYPE_REGISTRY.numeric_kind_of(name) == NumericKind.FloatKind {
        import from jaclang.runtime.scalars { float_max }
        evaluator.emit_diag(E1130, expr, value=shown, type=name, max=float_max(name));
        return AssignVerdict(ok=False, diagnosed=True);
    }
    if isinstance(value, float) {
        return AssignVerdict(ok=False);
    }
    (lo, hi) = _range_text(name);
    evaluator.emit_diag(E1126, expr, value=shown, type=name, min=lo, max=hi);
    return AssignVerdict(ok=False, diagnosed=True);
}

impl is_brand(t: TypeBase | None) -> bool {
    return isinstance(t, ClassType) and t.private.distinct_key is not None;
}

impl assign_numeric_expr(
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

impl unify_numeric_operands(
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

impl arithmetic_result_type(evaluator: TypeEvaluator, t: TypeBase) -> TypeBase {
    int_class = evaluator.prefetch.int_class if evaluator.prefetch else None;
    if numeric_name_of(t) == "bool" and int_class is not None {
        return evaluator._convert_to_instance(int_class);
    }
    return t;
}

impl both_numeric(left_type: TypeBase, right_type: TypeBase) -> bool {
    return numeric_name_of(left_type) is not None
        and numeric_name_of(right_type) is not None;
}

impl is_unsigned_type(t: TypeBase | None) -> bool {
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

impl _is_jac_builtin_fn(evaluator: TypeEvaluator, callee: Expr, name: str) -> bool {
    if not isinstance(callee, Name) or callee.sym_name != name {
        return False;
    }
    sym = callee.sym;
    stub = evaluator.jac_builtins_module;
    stub_sym = stub.names_in_scope.get(name);
    if sym is None or stub_sym is None {
        return False;
    }
    if sym is stub_sym {
        return True;
    }

    home = sym.decl.loc.mod_path if sym.decl.loc else "";
    return bool(home) and home == stub.loc.mod_path;
}

impl fixed_width_call_type(
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
            and isinstance(value, (int, WideLiteral)) {
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

impl shift_result_type(
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
