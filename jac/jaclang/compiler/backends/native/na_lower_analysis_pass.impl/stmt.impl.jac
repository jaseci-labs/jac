impl NativeLowering._del_target_holds_graph(target: uni.Expr) -> bool {
    if uni.DeleteStmt.type_has_graph_member(target.type) {
        return True;
    }
    _model = self.module.gen.native_osp_model;
    _type_key = self._type_key_of(target);
    if (_model is None) or (_type_key is None) {
        return False;
    }
    _flat = _type_key;
    for _ch in "[](),|" {
        _flat = _flat.replace(_ch, " ");
    }
    for _part in _flat.split() {
        if _model.arch_kind.get(_part) is not None {
            return True;
        }
    }
    return False;
}

impl NativeLowering._match_subj_ty(expr: (uni.UniNode | None)) -> (TypeBase | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    if expr.type is not None {
        return expr.type;
    }
    if not isinstance(expr, uni.NameAtom) or expr.sym is None {
        return None;
    }
    decl = expr.sym.decl;
    if decl is None {
        return None;
    }
    holder = decl.find_parent_of_type(uni.Assignment)
        or decl.find_parent_of_type(uni.ParamVar)
        or decl.find_parent_of_type(uni.HasVar);
    tag = holder.type_tag if holder is not None else None;
    tag_expr = tag.tag if tag is not None else None;
    if isinstance(tag_expr, uni.Expr) and tag_expr.type is not None {
        try {
            import from jaclang.compiler.types.type_utils { convert_to_instance }
            return convert_to_instance(tag_expr.type);
        } except ImportError {
            return tag_expr.type;
        }
    }
    return None;
}

impl NativeLowering._match_seq_parts(
    pat: uni.MatchSequence
) -> tuple[list[uni.MatchPattern], uni.MatchStar | None, list[uni.MatchPattern]] {
    heads: list[uni.MatchPattern] = [];
    tails: list[uni.MatchPattern] = [];
    star: (uni.MatchStar | None) = None;
    for sub in pat.values {
        if isinstance(sub, uni.MatchStar) {
            star = sub;
        } elif star is not None {
            tails.append(sub);
        } else {
            heads.append(sub);
        }
    }
    return (heads, star, tails);
}

impl NativeLowering._match_elem_ty_of(
    subj_ty: (TypeBase | None), prefix: str, idx: int
) -> (TypeBase | None) {
    if not isinstance(subj_ty, ClassType) {
        return None;
    }
    mangled = self._mangled_of(subj_ty);
    if mangled is None or not mangled.startswith(prefix) {
        return None;
    }
    targs: list[TypeBase] = subj_ty.private.type_args or [];
    if idx < len(targs) {
        return targs[idx];
    }
    return None;
}

impl NativeLowering._match_arch_fields(
    pat: uni.MatchArch, arch_name: str
) -> (list[tuple[str, uni.MatchPattern]] | None) {
    out: list[tuple[str, uni.MatchPattern]] = [];
    args = list(pat.arg_patterns) if pat.arg_patterns else [];
    if args {
        order = self.struct_field_order.get(arch_name);
        if order is None or len(args) > len(order) {
            return None;
        }
        for (i, sub_pat) in enumerate(args) {
            out.append((order[i], sub_pat));
        }
    }
    for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
        fname = self._get_name(kv.key);
        if fname is None {
            return None;
        }
        out.append((fname, kv.value));
    }
    return out;
}

impl NativeLowering._na_chunks_shape(expr: object) -> (tuple[uni.Expr, uni.Expr] | None) {
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    _t = expr.target;
    if not (
        isinstance(_t, uni.AtomTrailer)
        and _t.is_attr
        and isinstance(_t.right, uni.Name)
        and _t.right.sym_name == "chunks"
    ) {
        return None;
    }
    _params = [
        (p.value if isinstance(p, uni.KWPair) else p) for p in (expr.params or [])
    ];
    if len(_params) != 1 {
        return None;
    }
    return (_t.target, _params[0]);
}
