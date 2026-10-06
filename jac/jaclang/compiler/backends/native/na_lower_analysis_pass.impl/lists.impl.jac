import from jaclang.compiler.expr_keys { type_tag_borrows }

impl NativeLowering._container_is_view(nd: uni.UniNode) -> bool {
    _p = nd.parent;
    while isinstance(_p, (uni.CfgExpr, uni.IfElseExpr)) {
        _p = _p.parent;
    }
    if isinstance(_p, (uni.Assignment, uni.HasVar)) and _p.type_tag is not None {
        return type_tag_borrows(_p.type_tag);
    }
    return False;
}
