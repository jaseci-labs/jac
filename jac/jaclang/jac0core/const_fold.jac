import jaclang.jac0core.unitree as uni;

def fold_const(expr: (uni.UniNode | None)) -> tuple {
    if expr is None {
        return (False, None);
    }
    if isinstance(expr, uni.Int) or isinstance(expr, uni.Float) {
        return (True, expr.lit_value);
    }
    if isinstance(expr, uni.Bool) {
        return (True, bool(expr.lit_value));
    }
    if isinstance(expr, uni.String) {
        v = expr.lit_value;
        return (isinstance(v, str), v if isinstance(v, str) else None);
    }
    if isinstance(expr, uni.MultiString) {
        parts: list[str] = [];
        for s in (expr.strings or []) {
            (ok, v) = fold_const(s);
            if not ok or not isinstance(v, str) {
                return (False, None);
            }
            parts.append(v);
        }
        return (True, "".join(parts));
    }
    if isinstance(expr, uni.AtomUnit) {
        return fold_const(expr.value);
    }
    if isinstance(expr, uni.UnaryExpr) {
        (ok, v) = fold_const(expr.operand);
        if not ok {
            return (False, None);
        }
        opv = getattr(expr.op, "value", "");
        try {
            if opv == "-" and isinstance(v, (int, float)) {
                return (True, -v);
            }
            if opv == "+" and isinstance(v, (int, float)) {
                return (True, v);
            }
            if opv == "not" {
                return (True, not v);
            }
            if opv == "~" and isinstance(v, int) {
                return (True, ~v);
            }
        } except Exception {
            return (False, None);
        }
        return (False, None);
    }
    if isinstance(expr, uni.BinaryExpr) {
        (lok, lv) = fold_const(expr.left);
        if not lok {
            return (False, None);
        }
        (rok, rv) = fold_const(expr.right);
        if not rok {
            return (False, None);
        }
        opv = getattr(expr.op, "value", "");
        _num = isinstance(lv, (int, float)) and isinstance(rv, (int, float));
        _bools = isinstance(lv, bool) or isinstance(rv, bool);
        try {
            if opv == "+" {
                if _num and not _bools {
                    return (True, lv + rv);
                }
                if isinstance(lv, str) and isinstance(rv, str) {
                    return (True, lv + rv);
                }
            }
            if _num and not _bools {
                if opv == "-" {
                    return (True, lv - rv);
                }
                if opv == "*" {
                    return (True, lv * rv);
                }
                if opv == "//" and rv != 0 {
                    return (True, lv // rv);
                }
                if opv == "%" and rv != 0 {
                    return (True, lv % rv);
                }
                if opv == "**"
                and isinstance(lv, int)
                and isinstance(rv, int)
                and rv >= 0
                and abs(lv) < 1024
                and rv < 63 {
                    return (True, lv ** rv);
                }
                if opv == "<<"
                and isinstance(lv, int)
                and isinstance(rv, int)
                and 0 <= rv
                and rv < 64 {
                    return (True, lv << rv);
                }
                if opv == ">>"
                and isinstance(lv, int)
                and isinstance(rv, int)
                and 0 <= rv
                and rv < 64 {
                    return (True, lv >> rv);
                }
                if opv == "&" and isinstance(lv, int) and isinstance(rv, int) {
                    return (True, lv & rv);
                }
                if opv == "|" and isinstance(lv, int) and isinstance(rv, int) {
                    return (True, lv | rv);
                }
                if opv == "^" and isinstance(lv, int) and isinstance(rv, int) {
                    return (True, lv ^ rv);
                }
            }
            if opv == "*"
            and isinstance(lv, str)
            and isinstance(rv, int)
            and 0 <= rv
            and rv < 4096 {
                return (True, lv * rv);
            }
        } except Exception {
            return (False, None);
        }
        return (False, None);
    }
    return (False, None);
}
