impl NativeLowering._gc_mode -> str {
    _mode = getattr(self.prog.options, "na_gc_mode", "cycles");
    if _mode not in ("cycles", "rc", "none") {
        return "cycles";
    }
    return _mode;
}

impl NativeLowering._nogc_borrow_local_assign(nd: object) -> bool {
    if not self._nogc_headerless() or not isinstance(nd, uni.Assignment) {
        return False;
    }
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.Name) {
        return False;
    }
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    _sym = nd.target[0].sym;
    if _sym is not None and is_borrow_kind(_sym.ownership) {
        return True;
    }
    return isinstance(nd.value, uni.UnaryExpr) and is_borrow_kind(nd.value.ownership);
}

impl NativeLowering._str_desc_kind -> str {
    return "jacstr2" if self._nogc_headerless() else "jacstr3";
}

impl NativeLowering._nogc_owned_world -> bool {
    if not self._nogc_headerless() {
        return False;
    }
    _opts = self.prog.options;
    try {
        return bool(_opts.nogc_enforced_for(self.module.name));
    } except Exception {
        return False;
    }
}

impl NativeLowering._arch_is_acyclic(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(arch_name);
    return lay is not None and lay.is_acyclic;
}

impl NativeLowering._arch_is_osp_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(arch_name);
    return lay is not None and lay.is_osp;
}

impl NativeLowering._arch_is_walker_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(arch_name);
    return lay is not None and lay.arch_type == "walker";
}

impl NativeLowering._nogc_headerless -> bool {
    return getattr(self.module.gen, "nogc_enforced", False)
        and self._gc_mode() == "none";
}

impl NativeLowering._drop_member_of(owner: str) -> (uni.Ability | None) {
    arch = self.arch_ast_map.get(owner);
    if arch is None or arch.body is None {
        return None;
    }
    for ability in arch.get_all_sub_nodes(uni.Ability) {
        if ability.find_parent_of_type(uni.Archetype) is arch
            and ability.name_ref is not None
            and ability.name_ref.sym_name == "drop" {
            return ability;
        }
    }
    for stmt in arch._get_impl_resolved_body() {
        if isinstance(stmt, uni.Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name == "drop" {
            return stmt;
        }
    }
    return None;
}

impl NativeLowering._nogc_type_arg_mangles_of_str(m: str) -> list[str] {
    _open = m.find("[");
    if _open < 0 or not m.endswith("]") {
        return [];
    }
    _inner = m[_open + 1:-1];
    _args: list[str] = [];
    _depth = 0;
    _cur = "";
    for _ch in _inner {
        if _ch == "[" {
            _depth += 1;
        } elif _ch == "]" {
            _depth -= 1;
        }
        if _ch == "," and _depth == 0 {
            _args.append(_cur.strip());
            _cur = "";
        } else {
            _cur += _ch;
        }
    }
    if _cur.strip() {
        _args.append(_cur.strip());
    }
    return _args;
}

impl NativeLowering._nogc_type_arg_mangles(expr: uni.UniNode | None) -> list[str] {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return [];
    }
    import from jaclang.compiler.passes.layout_pass { native_type_key }
    return self._nogc_type_arg_mangles_of_str(native_type_key(expr.type));
}

impl NativeLowering._is_move_site(expr: uni.UniNode | None) -> bool {
    if not isinstance(expr, uni.Name) {
        return False;
    }
    _eid = id(expr);
    return _eid in self.module.own_move_sites or _eid in self.module.rc_move_in;
}

impl NativeLowering._nogc_opt_slots_owned -> bool {
    return not self._nogc_headerless() or self._nogc_owned_world();
}
