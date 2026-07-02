import jaclang.jac0core.unitree as uni;

glob SLOT_SENTINEL: str = "__c2jac_directir__";

def is_slot_placeholder(nd: uni.UniNode) -> bool {
    if not isinstance(nd, uni.ExprStmt) {
        return False;
    }
    expr = nd.expr;
    if not isinstance(expr, uni.FuncCall) {
        return False;
    }
    target = expr.target;
    if not isinstance(target, uni.Name) {
        return False;
    }
    return target.value == SLOT_SENTINEL;
}

def slot_id_of(placeholder: uni.ExprStmt) -> int | None {
    params = placeholder.expr.params;
    if params and len(params) == 1 and isinstance(params[0], uni.Int) {
        try {
            return int(params[0].value);
        } except ValueError { }
    }
    return None;
}
