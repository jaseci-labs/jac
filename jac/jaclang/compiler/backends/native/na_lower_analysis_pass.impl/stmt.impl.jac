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

impl NativeLowering._delete_location_subscript(
    target: uni.AtomTrailer, nd: uni.DeleteStmt
) -> (tuple[bool, uni.Slice] | None) {
    _islice = target.right;
    if isinstance(_islice, uni.IndexSlice)
        and _islice.is_range
        and len(_islice.slices) == 1 {
        return (True, _islice.slices[0]);
    }
    if (not isinstance(_islice, uni.IndexSlice))
        or _islice.is_range
        or len(_islice.slices) != 1 {
        self.emit(E5092, node_override=nd, kind="statement", name="DeleteStmt");
        return None;
    }
    return (False, _islice.slices[0]);
}

impl NativeLowering._delete_list_slice_unstepped(
    slice_node: uni.Slice, nd: uni.DeleteStmt
) -> bool {
    if slice_node.step is not None {
        self.emit(
            E5092, node_override=nd, kind="statement", name="stepped slice deletion"
        );
        return False;
    }
    return True;
}

impl NativeLowering._if_ct_taken(nd: uni.IfStmt) -> (bool | None) {
    taken = nd.ct_taken;
    if taken is None {
        (ok, v) = self._ct_value_with_bindings(nd.condition);
        if not ok or v is None {
            self.emit(
                E5092,
                node_override=nd.condition,
                kind="comptime if condition",
                name="comptime if",
                help_text="The condition depends on a comptime parameter or loop variable that has no binding in this specialization."
            );
            return None;
        }
        taken = ct_truthy(v);
    }
    return taken;
}

impl NativeLowering._match_tuple_seq_heads(
    pat: uni.MatchSequence
) -> (list[uni.MatchPattern] | None) {
    (heads, star, tails) = self._match_seq_parts(pat);
    if star is not None {
        self.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchStar",
            help_text="Star sub-patterns over a tuple-typed match subject are not lowered natively; match a list subject instead."
        );
        return None;
    }
    return heads;
}

impl NativeLowering._assignment_environ_store(
    nd: uni.Assignment, target_expr: uni.AtomTrailer
) -> bool {
    _env_sub_t = target_expr.target;
    if (
        isinstance(_env_sub_t, uni.AtomTrailer)
        and _env_sub_t.is_attr
        and self._get_name(_env_sub_t.target) == "os"
        and self._get_name(_env_sub_t.right) == "environ"
        and self._native_stdlib_modules
        and "os" in self._native_stdlib_modules
        and nd.aug_op is None
        and isinstance(target_expr.right, uni.IndexSlice)
        and target_expr.right.slices
    ) {
        return True;
    }
    return False;
}

impl NativeLowering._assignment_tag_bare_container(tag: uni.Expr) -> bool {
    bare_name: (str | None) = None;
    if isinstance(tag, uni.Name) {
        bare_name = tag.value;
    } elif uni?.BuiltinType and isinstance(tag, uni.BuiltinType) {
        bare_name = tag.value;
    }
    return bare_name in {"list", "dict", "set", "frozenset"};
}

impl NativeLowering._assignment_borrows_source(nd: uni.Assignment) -> bool {
    if (
        self._nogc_headerless()
        and isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.storage == uni.SymbolStorage.MODULE_GLOBAL
    )
        or self._nogc_borrow_local_assign(nd) {
        return True;
    }
    return False;
}

impl NativeLowering._assignment_sole_target_owned(nd: uni.Assignment) -> bool {
    if len(nd.target) == 1
        and isinstance(nd.target[0], uni.Name)
        and nd.target[0].sym is not None
        and nd.target[0].sym.ownership == OwnershipKind.OWN {
        return True;
    }
    return False;
}

impl NativeLowering._assignment_target_module_global(target_expr: uni.Expr) -> bool {
    if isinstance(target_expr, uni.NameAtom)
        and target_expr.sym is not None
        and target_expr.sym.storage == uni.SymbolStorage.MODULE_GLOBAL {
        return True;
    }
    return False;
}

impl NativeLowering._for_ct_items(nd: uni.InForStmt) -> (CtValue | None) {
    (ok, items) = self._ct_value_with_bindings(nd.collection);
    if not ok or items is None {
        self.emit(
            E5092,
            node_override=nd.collection,
            kind="comptime for collection",
            name="comptime for",
            help_text="The collection depends on a comptime parameter or loop variable that has no binding in this specialization."
        );
        return None;
    }
    return items;
}

impl NativeLowering._for_dict_items_unpack(nd: uni.InForStmt) -> bool {
    if isinstance(nd.target, uni.TupleVal)
        and isinstance(nd.collection, uni.FuncCall)
        and isinstance(nd.collection.target, uni.AtomTrailer)
        and nd.collection.target.is_attr
        and self._get_name(nd.collection.target.right) == "items" {
        return True;
    }
    return False;
}

impl NativeLowering._for_builtin_range(nd: uni.InForStmt) -> bool {
    if isinstance(nd.collection, uni.FuncCall)
        and self._get_name(nd.collection.target) == "range"
        and nd.collection.call_kind == "builtin" {
        return True;
    }
    return False;
}

impl NativeLowering._try_flow_for_parallel_is_flow(nd: uni.InForStmt) -> bool {
    if nd.else_body is not None {
        return False;
    }
    _is_flow = False;
    for k in [nd->:Kid:->] {
        if isinstance(k, uni.Token) and k.name == Tok.KW_FLOW {
            _is_flow = True;
            break;
        }
    }
    return _is_flow;
}

impl NativeLowering._try_flow_for_parallel_reduce_candidates(
    nd: uni.InForStmt
) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for st in (nd.body or []) {
        _r_asgns = ([st] if isinstance(st, uni.Assignment) else [])
            + list(st.get_all_sub_nodes(uni.Assignment));
        for _ra in _r_asgns {
            if _ra.na_flow_reduce
                and len(_ra.target) == 1
                and isinstance(_ra.target[0], uni.Name) {
                out.append((_ra.target[0].sym_name, _ra.na_flow_reduce));
            }
        }
    }
    return out;
}

impl NativeLowering._try_flow_for_parallel_body_names(
    nd: uni.InForStmt
) -> list[uni.Name] {
    out: list[uni.Name] = [];
    for st in (nd.body or []) {
        for anm in st.get_all_sub_nodes(uni.Name) {
            out.append(anm);
        }
    }
    return out;
}

impl NativeLowering._try_flow_for_parallel_decl_inside(
    anm: uni.Name, nd: uni.InForStmt
) -> bool {
    _decl = anm.sym.decl if anm.sym is not None else None;
    _inside = False;
    _cur: (uni.UniNode | None) = _decl;
    while _cur is not None {
        if _cur is nd {
            _inside = True;
            break;
        }
        _cur = _cur.parent;
    }
    return _inside;
}

impl NativeLowering._for_indexed_has_yield(nd: uni.InForStmt) -> bool {
    return bool(nd.get_all_sub_nodes(typ=uni.YieldExpr));
}
