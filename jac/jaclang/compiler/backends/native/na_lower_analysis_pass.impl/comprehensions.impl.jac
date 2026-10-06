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
