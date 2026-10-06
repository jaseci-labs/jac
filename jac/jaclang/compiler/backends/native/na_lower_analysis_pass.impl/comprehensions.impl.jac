impl NativeLowering._is_boolean_result_expr(nd: (uni.UniNode | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    while isinstance(nd, (uni.CfgExpr, uni.AtomUnit)) {
        nd = nd.expr if isinstance(nd, uni.CfgExpr) else nd.value;
    }
    if isinstance(nd, (uni.CompareExpr, uni.Bool)) {
        return True;
    }
    if isinstance(nd, uni.UnaryExpr) {
        return nd.op.name == Tok.NOT;
    }
    if isinstance(nd, uni.BoolExpr) {
        if not nd.values {
            return False;
        }
        for _operand in nd.values {
            if not self._is_boolean_result_expr(_operand) {
                return False;
            }
        }
        return True;
    }
    if isinstance(nd, uni.Expr) {
        return primitive_type_name_of(nd.type) == "bool";
    }
    return False;
}

impl NativeLowering._compr_walk_body_is_range(collection: uni.Expr) -> bool {
    return isinstance(collection, uni.FuncCall)
        and self._get_name(collection.target) == "range"
        and collection.call_kind == "builtin"
        and len(collection.params or []) <= 2;
}

impl NativeLowering._compr_walk_body_targets(
    loop_target: uni.Expr
) -> (tuple[(uni.TupleVal | None), (str | None), list[str]] | None) {
    unpack_target = loop_target if isinstance(loop_target, uni.TupleVal) else None;
    loop_var_name = self._get_name(loop_target);
    if loop_var_name is None and unpack_target is None {
        return None;
    }
    targets = unpack_target.values if unpack_target is not None else [loop_target];
    names: list[str] = [];
    for target in targets {
        name = self._get_name(target);
        if name is not None {
            names.append(name);
        }
    }
    return (unpack_target, loop_var_name, names);
}

impl NativeLowering._compr_iter_walk_targets(
    loop_target: uni.Expr
) -> tuple[(uni.TupleVal | None), list[uni.Expr], list[str]] {
    unpack_target = loop_target if isinstance(loop_target, uni.TupleVal) else None;
    targets: list[uni.Expr] = list(unpack_target.values or [])
        if unpack_target is not None
        else [loop_target];
    names: list[str] = [];
    for target in targets {
        name = self._get_name(target);
        if name is not None {
            names.append(name);
        }
    }
    return (unpack_target, targets, names);
}
