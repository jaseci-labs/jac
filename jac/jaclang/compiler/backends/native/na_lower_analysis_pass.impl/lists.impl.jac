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

impl NativeLowering._list_val_dest_type_tag(
    nd: uni.ListVal
) -> (uni.SubTag[uni.Expr] | None) {
    destination = nd.parent;
    tag = destination.type_tag
        if isinstance(destination, (uni.Assignment, uni.HasVar))
            and destination.value is nd
        else None;
    return tag;
}

impl NativeLowering._list_val_bare_list_decl(nd: uni.ListVal) -> bool {
    _decl_par = nd.parent;
    _bare_list_decl = False;
    if isinstance(_decl_par, (uni.Assignment, uni.HasVar))
        and _decl_par.value is nd
        and _decl_par.type_tag is not None {
        _lt_tag = _decl_par.type_tag.tag;
        _lt_name: (str | None) = None;
        if isinstance(_lt_tag, uni.Name) {
            _lt_name = _lt_tag.value;
        } elif uni?.BuiltinType and isinstance(_lt_tag, uni.BuiltinType) {
            _lt_name = _lt_tag.value;
        }
        _bare_list_decl = _lt_name == "list";
    }
    return _bare_list_decl;
}
