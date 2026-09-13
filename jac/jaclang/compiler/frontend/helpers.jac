import type from jaclang.compiler.frontend.unitree { Expr }

def _is_version_info_access(expr: Expr) -> bool {
    import jaclang.compiler.frontend.unitree as uni;

    if not isinstance(expr, uni.AtomTrailer) {
        return False;
    }
    if not expr.is_attr {
        return False;
    }
    return (
        isinstance(expr.target, uni.Name)
        and expr.target.value == "sys"
        and isinstance(expr.right, uni.Name)
        and expr.right.value == "version_info"
    );
}

def _is_type_checking_ref(expr: Expr) -> bool {
    import jaclang.compiler.frontend.unitree as uni;

    inner = expr;
    if isinstance(expr, uni.AtomUnit) {
        unwrapped = expr.value;
        if not isinstance(unwrapped, uni.Expr) {
            return False;
        }
        inner = unwrapped;
    }
    if isinstance(inner, uni.Name) {
        return inner.value == "TYPE_CHECKING";
    }
    if isinstance(inner, uni.AtomTrailer) and inner.is_attr {
        return (
            isinstance(inner.right, uni.Name) and inner.right.value == "TYPE_CHECKING"
        );
    }
    return False;
}

def _extract_version_tuple(expr: Expr) -> tuple[int, int] | None {
    import jaclang.compiler.frontend.unitree as uni;

    if not isinstance(expr, uni.TupleVal) {
        return None;
    }
    if len(expr.values) < 2 {
        return None;
    }
    (major, minor) = (expr.values[0], expr.values[1]);
    if not isinstance(major, uni.Int) or not isinstance(minor, uni.Int) {
        return None;
    }
    return (major.lit_value, minor.lit_value);
}

def evaluate_version_condition(condition: Expr) -> bool | None {
    import sys;
    import jaclang.compiler.frontend.unitree as uni;
    import from jaclang.compiler.frontend.constant { Tokens as Tok }

    cond = condition;
    if isinstance(condition, uni.AtomUnit) {
        unwrapped = condition.value;
        if not isinstance(unwrapped, uni.Expr) {
            return None;
        }
        cond = unwrapped;
    }

    if _is_type_checking_ref(cond) {
        return True;
    }
    if isinstance(cond, uni.UnaryExpr)
        and cond.op.name == Tok.NOT
        and _is_type_checking_ref(cond.operand) {
        return False;
    }
    if not isinstance(cond, uni.CompareExpr) {
        return None;
    }
    if not _is_version_info_access(cond.left) {
        return None;
    }
    if len(cond.ops) != 1 or len(cond.rights) != 1 {
        return None;
    }

    target = _extract_version_tuple(cond.rights[0]);
    if target is None {
        return None;
    }

    current = (sys.version_info.major, sys.version_info.minor);
    op_str = cond.ops[0].value;
    if op_str in (">=", "GtE") {
        return current >= target;
    }
    if op_str in (">", "Gt") {
        return current > target;
    }
    if op_str in ("<=", "LtE") {
        return current <= target;
    }
    if op_str in ("<", "Lt") {
        return current < target;
    }
    if op_str in ("==", "Eq") {
        return current == target;
    }
    if op_str in ("!=", "NotEq") {
        return current != target;
    }
    return None;
}
