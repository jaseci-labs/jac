import from jaclang.jac0core.diagnostics { E1401, E1402, E1403, E1404, E1405, E1406 }

glob _NOGC_SCALARS: tuple = ("int", "float", "bool", "None", "NoneType", "type");

def _nogc_name_candidates(mod_name: str) -> list[str] {
    _cands = [mod_name];
    for _suf in (".na", ".cl", ".sv") {
        if mod_name.endswith(_suf) {
            _cands.append(mod_name[:-len(_suf)]);
        }
    }
    return _cands;
}

glob _NOGC_ALIASING_BUILTINS: dict[str, str] = {
         "iter": "iter() retains a raw reference to its collection",
         "globals": "globals() aliases module state",
         "locals": "locals() aliases frame state"
     };

impl OwnershipCheckPass._nogc_resolve_provenance -> (str | None) {
    opts = self.prog?._compile_options;
    if opts is not None and getattr(opts, "nogc_enforce_all", False) {
        return "enforced by --enforce-nogc";
    }
    _cli_target = getattr(opts, "nogc_cli_target", "") if opts else "";
    if _cli_target and _cli_target in _nogc_name_candidates(self.ir_in.name) {
        return "enforced by --enforce-nogc";
    }
    _pats = list(getattr(opts, "nogc_enforce_modules", []) or []) if opts else [];
    _grand = list(getattr(opts, "nogc_grandfathered", []) or []) if opts else [];
    if not _pats {
        try {
            import from jaclang.project { get_config }
            _cfg = get_config();
            if _cfg {
                _pats = list(_cfg.gc.enforce.modules);
                _grand = list(_cfg.gc.enforce.grandfathered);
            }
        } except Exception {
            return None;
        }
    }
    if not _pats {
        return None;
    }
    import fnmatch;
    _mod = self.ir_in.name;
    for _pat in _grand {
        if fnmatch.fnmatchcase(_mod, _pat) {
            return None;
        }
    }
    for _pat in _pats {
        if fnmatch.fnmatchcase(_mod, _pat) {
            return f'enforced by jac.toml [gc.enforce] "{_pat}"';
        }
    }
    return None;
}

impl OwnershipCheckPass._nogc_setup -> None {
    self.nogc_prov = self._nogc_resolve_provenance();
    self.ir_in.gen.nogc_enforced = self.nogc_prov is not None;
    self.ir_in.gen.nogc_provenance = self.nogc_prov or '';
    if self.nogc_prov is not None {
        self._nogc_infer_locals();
    }
}

impl OwnershipCheckPass._nogc_tag_shape(tag: uni.SubTag | None) -> str {
    if tag is None {
        return "unknown";
    }
    _expr = tag.tag;
    while isinstance(_expr, uni.AtomTrailer) {
        _expr = _expr.target;
    }
    _root: (uni.Name | None) = _expr if isinstance(_expr, uni.Name) else None;
    if _root is None {
        return "unknown";
    }
    _tname = _root.sym_name;
    if _tname in _NOGC_SCALARS {
        return "scalar";
    }
    if _tname == "any" {
        return "any";
    }
    if _root.sym is not None and _root.sym.decl is not None {
        _arch = _root.sym.decl.find_parent_of_type(uni.Archetype);
        if _arch is not None
        and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return "osp";
        }
    }
    return "heap";
}

impl OwnershipCheckPass._nogc_local_shape(nm: uni.Name) -> str {
    _t = nm.type;
    if _t is None {
        return "unknown";
    }
    _mangled = "";
    try {
        _mangled = _t.mangle();
    } except Exception {
        return "unknown";
    }
    if _mangled in _NOGC_SCALARS {
        return "scalar";
    }
    if _mangled in ("any", "Unknown", "") {
        return "any";
    }
    for _arch in self.ir_in.get_all_sub_nodes(uni.Archetype) {
        if _arch.name.value == _mangled
        and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return "osp";
        }
    }
    return "heap";
}

impl OwnershipCheckPass._nogc_infer_locals -> None {
    import from jaclang.compiler.passes.main.rc_facts_pass {
        result_ownership,
        Ownership
    }
    for nd in self.idx_assignments {
        if len(nd.target) != 1 {
            continue;
        }
        _tgt = nd.target[0];
        if not (isinstance(_tgt, uni.Name) and _tgt.sym) {
            continue;
        }
        if _tgt.sym.ownership != OwnershipKind.NONE {
            continue;
        }
        if _tgt.sym.storage == SymbolStorage.MODULE_GLOBAL {
            continue;
        }
        if self._nogc_local_shape(_tgt) in ("osp", "scalar") {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        if nd.value is not None and result_ownership(nd.value) == Ownership.OWNED {
            _tgt.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[_sid] = _tgt;
            continue;
        }
        if isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.ownership == OwnershipKind.OWN {
            _tgt.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[_sid] = _tgt;
        }
    }
}

impl OwnershipCheckPass._nogc_local_shape_expr_heap(expr: uni.Expr | None) -> bool {
    if expr is None {
        return False;
    }
    _root = self._place_of(expr);
    if _root is not None and _root.sym is not None {
        if _root.sym.ownership == OwnershipKind.OWN {
            return True;
        }
        return self._nogc_local_shape(_root) == "heap";
    }
    import from jaclang.compiler.passes.main.rc_facts_pass {
        result_ownership,
        Ownership
    }
    _own = result_ownership(expr);
    if _own == Ownership.STATIC or _own == Ownership.BORROWED {
        return False;
    }

    return self._nogc_expr_type_is_heap(expr);
}

impl OwnershipCheckPass._nogc_expr_type_is_heap(expr: uni.Expr | None) -> bool {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return False;
    }
    _m = "";
    try {
        _m = expr.type.mangle();
    } except Exception {
        return False;
    }
    if _m in _NOGC_SCALARS or _m in ("any", "Unknown", "") {
        return False;
    }
    for _arch in self.ir_in.get_all_sub_nodes(uni.Archetype) {
        if _arch.name.value == _m
        and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._nogc_is_container_expr(expr: uni.Expr | None) -> bool {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return False;
    }
    _tk = "";
    try {
        _tk = expr.type.mangle();
    } except Exception {
        return False;
    }
    for _nm in ("list", "set", "dict") {
        if _tk == _nm or _tk.startswith(_nm + "[") {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._nogc_container_grow_method(
    call: uni.FuncCall
) -> (str | None) {
    _tgt = call.target;
    if not isinstance(_tgt, uni.AtomTrailer) or not _tgt.is_attr {
        return None;
    }
    _r = _tgt.right;
    if not isinstance(_r, uni.Name) or _r.sym_name not in ("append", "add", "insert") {
        return None;
    }
    if not self._nogc_is_container_expr(_tgt.target) {
        return None;
    }
    return _r.sym_name;
}

impl OwnershipCheckPass._nogc_module_enforced(mod_name: str) -> bool {
    opts = self.prog?._compile_options;
    if opts is not None and getattr(opts, "nogc_enforce_all", False) {
        return True;
    }
    if opts is not None and getattr(opts, "nogc_cli_target", "") == mod_name {
        return True;
    }
    _pats = list(getattr(opts, "nogc_enforce_modules", []) or []) if opts else [];
    _grand = list(getattr(opts, "nogc_grandfathered", []) or []) if opts else [];
    if not _pats {
        try {
            import from jaclang.project { get_config }
            _cfg = get_config();
            if _cfg {
                _pats = list(_cfg.gc.enforce.modules);
                _grand = list(_cfg.gc.enforce.grandfathered);
            }
        } except Exception {
            return False;
        }
    }
    import fnmatch;
    for _pat in _grand {
        if fnmatch.fnmatchcase(mod_name, _pat) {
            return False;
        }
    }
    for _pat in _pats {
        if fnmatch.fnmatchcase(mod_name, _pat) {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._nogc_check_call(call: uni.FuncCall, prov: str) -> None {
    _callee_root: (uni.Name | None) = None;
    if isinstance(call.target, uni.Name) {
        _callee_root = call.target;
    } elif isinstance(call.target, uni.AtomTrailer) {
        _callee_root = self._place_of(call.target);
    }
    if _callee_root is None {
        return;
    }

    _opts_c = self.prog?._compile_options;
    _hl_c = getattr(_opts_c, "na_gc_mode", "cycles") == "none" if _opts_c else False;
    _heap_args: list[uni.Name] = [];
    for _arg in self._call_params(call) {
        _a = _arg.value if isinstance(_arg, uni.KWPair) else _arg;
        if isinstance(_a, uni.FuncCall)
        and isinstance(_a.target, uni.Name)
        and _a.target.sym_name == "managed" {
            if _hl_c {
                _m_params = list(_a.params or []);
                _m_root = self._place_of(_m_params[0]) if _m_params else None;
                if _m_root is not None
                and _m_root.sym is not None
                and (
                    _m_root.sym.ownership == OwnershipKind.OWN
                    or self._nogc_local_shape(_m_root) == "heap"
                ) {
                    self.emit(
                        E1406,
                        node_override=_a,
                        name="managed() of a heap value under --gc none",
                        provenance=prov
                    );
                }
            }
            continue;
        }
        _root = self._place_of(_a);
        if _root is None or _root.sym is None {
            continue;
        }
        if _root.sym.ownership == OwnershipKind.OWN
        or self._nogc_local_shape(_root) == "heap" {
            _heap_args.append(_root);
        }
    }
    if not _heap_args {
        return;
    }

    if _callee_root.sym_name in _NOGC_ALIASING_BUILTINS {
        self.emit(
            E1406, node_override=call, name=_callee_root.sym_name, provenance=prov
        );
        return;
    }

    if isinstance(call.target, uni.AtomTrailer)
    and _callee_root.sym is not None
    and _callee_root.sym.storage == SymbolStorage.MODULE_GLOBAL {
        self.emit(
            E1402, node_override=call, name=_heap_args[0].sym_name, provenance=prov
        );
        return;
    }

    import os as _dbg_os;
    if _dbg_os.environ.get("JAC_NOGC_DEBUG") {
        import sys as _dbg_sys;
        _dbg_sys.stderr.write(
            f"nogc-dbg call callee={_callee_root.sym_name} "
            f"sym={_callee_root.sym is not None} "
            f"tgt_is_name={isinstance(call.target, uni.Name)} "
            f"heap_args={[a.sym_name for a in _heap_args]}\n"
        );
    }
    if isinstance(call.target, uni.Name) and _callee_root.sym is not None {
        _defn_nodes = list(_callee_root.sym.defn or []);
        if _callee_root.sym.decl is not None {
            _defn_nodes.append(_callee_root.sym.decl);
        }
        for _dn in _defn_nodes {
            _decl_mod = _dn.find_parent_of_type(uni.Module);
            if _decl_mod is not None
            and _decl_mod is not self.ir_in
            and str(_decl_mod.loc.mod_path).endswith(".jac")
            and not self._nogc_module_enforced(_decl_mod.name) {
                self.emit(
                    E1403,
                    node_override=call,
                    name=_heap_args[0].sym_name,
                    provenance=prov
                );
                return;
            }
        }
    }
}

impl OwnershipCheckPass._emit_enforcement_diagnostics -> None {
    if self.nogc_prov is None {
        return;
    }
    _prov = self.nogc_prov;

    _opts = self.prog?._compile_options;
    _headerless = getattr(_opts, "na_gc_mode", "cycles") == "none" if _opts else False;
    if _headerless {
        for _lv in self.ir_in.get_all_sub_nodes(uni.ListVal) {
            if _lv.find_parent_of_type(uni.SubTag) is not None {
                continue;
            }
            for _le in (_lv.values or []) {
                if self._nogc_local_shape_expr_heap(_le) {
                    self.emit(
                        E1406,
                        node_override=_lv,
                        name="container of heap elements",
                        provenance=_prov
                    );
                    break;
                }
            }
        }
        for _sv in self.ir_in.get_all_sub_nodes(uni.SetVal) {
            if _sv.find_parent_of_type(uni.SubTag) is not None {
                continue;
            }
            for _se in (_sv.values or []) {
                if self._nogc_local_shape_expr_heap(_se) {
                    self.emit(
                        E1406,
                        node_override=_sv,
                        name="container of heap elements",
                        provenance=_prov
                    );
                    break;
                }
            }
        }
        for _dv in self.ir_in.get_all_sub_nodes(uni.DictVal) {
            if _dv.find_parent_of_type(uni.SubTag) is not None {
                continue;
            }
            for _kv in (_dv.kv_pairs or []) {
                if self._nogc_local_shape_expr_heap(_kv.key)
                or self._nogc_local_shape_expr_heap(_kv.value) {
                    self.emit(
                        E1406,
                        node_override=_dv,
                        name="container of heap elements",
                        provenance=_prov
                    );
                    break;
                }
            }
        }
        for _mc in self.ir_in.get_all_sub_nodes(uni.FuncCall) {
            _grow = self._nogc_container_grow_method(_mc);
            if _grow is None {
                continue;
            }
            for _garg in self._call_params(_mc) {
                _gav = _garg.value if isinstance(_garg, uni.KWPair) else _garg;
                if isinstance(_gav, uni.FuncCall)
                and isinstance(_gav.target, uni.Name)
                and _gav.target.sym_name == "managed" {
                    continue;
                }
                if self._nogc_local_shape_expr_heap(_gav) {
                    self.emit(
                        E1406,
                        node_override=_mc,
                        name=f"{_grow}() of a heap element",
                        provenance=_prov
                    );
                    break;
                }
            }
        }
        for _gv in self.ir_in.get_all_sub_nodes(uni.GlobalVars) {
            for _ga in _gv.get_all_sub_nodes(uni.Assignment) {
                for _gt in _ga.target {
                    if isinstance(_gt, uni.Name)
                    and self._nogc_local_shape(_gt) == "heap" {
                        self.emit(
                            E1406,
                            node_override=_gt,
                            name=f"module global '{_gt.sym_name}'",
                            provenance=_prov
                        );
                    }
                }
            }
        }
    }

    for param in self.idx_params {
        _nm = param.name;
        if not (isinstance(_nm, uni.Name) and _nm.sym) {
            continue;
        }
        if _nm.sym_name in ("self", "here", "visitor", "props") {
            continue;
        }
        if _nm.sym.ownership != OwnershipKind.NONE {
            continue;
        }
        _shape = self._nogc_tag_shape(param.type_tag);
        if _shape == "heap" {
            self.emit(
                E1401,
                node_override=_nm,
                position="parameter",
                name=_nm.sym_name,
                provenance=_prov
            );
        } elif _shape in ("any", "unknown") {
            self.emit(E1404, node_override=_nm, name=_nm.sym_name, provenance=_prov);
        }
    }

    for nd in self.idx_assignments {
        if len(nd.target) != 1 {
            continue;
        }
        _tgt = nd.target[0];
        if isinstance(_tgt, uni.Name)
        and _tgt.sym is not None
        and _tgt.sym.ownership == OwnershipKind.NONE
        and _tgt.sym.storage != SymbolStorage.MODULE_GLOBAL
        and _tgt.find_parent_of_type(uni.GlobalVars) is None {
            _shape = self._nogc_local_shape(_tgt);
            if _shape == "heap" {
                self.emit(
                    E1401,
                    node_override=_tgt,
                    position="local",
                    name=_tgt.sym_name,
                    provenance=_prov
                );
            }
            continue;
        }
        if isinstance(_tgt, uni.AtomTrailer) {
            _root = self._place_of(_tgt);
            if _root is not None
            and _root.sym is not None
            and _root.sym.storage == SymbolStorage.MODULE_GLOBAL {
                _val_root = self._place_of(nd.value);
                _is_owned_val = _val_root is not None
                and _val_root.sym is not None
                and _val_root.sym.ownership == OwnershipKind.OWN;
                if _is_owned_val
                or (
                    nd.value is not None and self._nogc_local_shape_expr_heap(nd.value)
                ) {
                    self.emit(
                        E1402, node_override=_tgt, name=_root.sym_name, provenance=_prov
                    );
                }
            } elif _headerless
            and not _tgt.is_attr
            and self._nogc_is_container_expr(_tgt.target)
            and nd.value is not None
            and self._nogc_local_shape_expr_heap(nd.value) {
                self.emit(
                    E1406,
                    node_override=_tgt,
                    name="container of heap elements",
                    provenance=_prov
                );
            }
        }
    }

    for call in self.ir_in.get_all_sub_nodes(uni.FuncCall) {
        self._nogc_check_call(call, _prov);
    }

    for _lam in self.ir_in.get_all_sub_nodes(uni.LambdaExpr) {
        for _nm in _lam.get_all_sub_nodes(uni.Name) {
            if _nm.sym is None {
                continue;
            }
            if _nm.sym.ownership == OwnershipKind.OWN
            or self._nogc_local_shape(_nm) == "heap" {
                _decl = _nm.sym.decl;
                if _decl is not None
                and _decl.find_parent_of_type(uni.LambdaExpr) is not _lam {
                    self.emit(
                        E1405, node_override=_nm, name=_nm.sym_name, provenance=_prov
                    );
                    break;
                }
            }
        }
    }

    for _reg in self.ir_in.get_all_sub_nodes(uni.RegionStmt) {
        self.emit(E1406, node_override=_reg, name="region { } block", provenance=_prov);
    }
}
