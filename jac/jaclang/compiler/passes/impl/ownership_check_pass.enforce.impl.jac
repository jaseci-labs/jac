import from jaclang.compiler.expr_keys { type_tag_borrows }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
import from jaclang.compiler.frontend.diagnostics {
    E1315,
    E1401,
    E1402,
    E1403,
    E1404,
    E1405,
    E1406
}

glob _NOGC_SCALARS: frozenset[str] = frozenset(
         ["int", "float", "bool", "None", "NoneType", "type"]
             + JAC_TYPE_REGISTRY.sized_scalar_names()
     );

def _nogc_name_candidates(mod_name: str) -> list[str] {
    _cands = [mod_name];
    for _suf in (".na", ".cl") {
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
    _mp = str(self.ir_in.loc.mod_path or "") if self.ir_in?.loc else "";
    if _mp {
        import os as _os;
        import jaclang as _jl;
        _pkg = str(_os.path.dirname(_os.path.abspath(str(_jl.__file__))));
        if str(_os.path.abspath(_mp)).startswith(_pkg + _os.sep) {
            return None;
        }
    }
    opts = self.prog?.options;
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
        self._stamp_view_borrows();
    }
}

impl OwnershipCheckPass._nogc_tag_shape(tag: SubTag | None) -> str {
    if tag is None {
        return "unknown";
    }
    _expr = tag.tag;
    while isinstance(_expr, AtomTrailer) {
        _expr = _expr.target;
    }
    _root: (Name | None) = _expr if isinstance(_expr, Name) else None;
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
        _arch = _root.sym.decl.find_parent_of_type(Archetype);
        if _arch is not None
            and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return "osp";
        }
    }
    return "heap";
}

impl OwnershipCheckPass._nogc_local_shape(nm: Name) -> str {
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
    for _arch in self.ir_in.get_all_sub_nodes(Archetype) {
        if _arch.name.value == _mangled
            and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return "osp";
        }
    }
    return "heap";
}

impl OwnershipCheckPass._nogc_infer_locals -> None {
    import from jaclang.compiler.passes.rc_facts_pass { result_ownership, Ownership }
    import from jaclang.compiler.types.types { AnyType }
    for nd in self.idx_assignments {
        if len(nd.target) != 1 {
            continue;
        }
        _tgt = nd.target[0];
        if not (isinstance(_tgt, Name) and _tgt.sym) {
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

        if nd.value is not None
            and isinstance(nd.value.type, AnyType)
            and nd.value.type.is_foreign {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        if nd.value is not None and result_ownership(nd.value) == Ownership.OWNED {
            _tgt.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[_sid] = _tgt;
            continue;
        }
        if self._nogc_str_slice_value(nd.value) {
            if self._view_base_place(nd.value) is not None {
                continue;
            }
            _tgt.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[_sid] = _tgt;
            continue;
        }
        if isinstance(nd.value, Name)
            and nd.value.sym is not None
            and nd.value.sym.ownership == OwnershipKind.OWN {
            _tgt.sym.ownership = OwnershipKind.OWN;
            self.owned_decl[_sid] = _tgt;
        }
    }
}

impl OwnershipCheckPass._nogc_str_slice_value(expr: Expr | None) -> bool {
    if not isinstance(expr, AtomTrailer) {
        return False;
    }
    if not isinstance(expr.right, IndexSlice) {
        return False;
    }
    _m = "";
    try {
        _m = expr.type.mangle() if expr.type is not None else "";
    } except Exception {
        return False;
    }
    return _m == "str";
}

impl OwnershipCheckPass._nogc_str_elem_ok(
    expr: Expr | None, idx_ctx: bool = False
) -> bool {
    if not isinstance(expr, Expr) {
        return False;
    }
    _m = "";
    try {
        _m = expr.type.mangle() if expr.type is not None else "";
    } except Exception {
        return False;
    }
    if _m != "str" {
        return False;
    }
    if idx_ctx {
        return True;
    }
    if isinstance(expr, (String, MultiString, FString)) {
        return True;
    }
    if isinstance(expr, (FuncCall, BinaryExpr)) {
        return True;
    }
    if isinstance(expr, Name) {
        if self._sym_id(expr) in self.view_syms {
            return True;
        }
        _root = self._place_of(expr);
        return (
            _root is not None
            and _root.sym is not None
            and _root.sym.ownership == OwnershipKind.OWN
        );
    }
    return self._nogc_str_slice_value(expr);
}

impl OwnershipCheckPass._nogc_local_shape_expr_heap(expr: Expr | None) -> bool {
    if expr is None {
        return False;
    }
    if isinstance(expr, Name) {
        _root = self._place_of(expr);
        if _root is not None and _root.sym is not None {
            if _root.sym.ownership == OwnershipKind.OWN {
                return True;
            }
            return self._nogc_local_shape(_root) == "heap";
        }
    }
    import from jaclang.compiler.passes.rc_facts_pass { result_ownership, Ownership }
    _own = result_ownership(expr);
    if _own == Ownership.STATIC or _own == Ownership.BORROWED {
        return False;
    }

    return self._nogc_expr_type_is_heap(expr);
}

impl OwnershipCheckPass._nogc_expr_type_is_heap(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) or expr.type is None {
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
    for _arch in self.ir_in.get_all_sub_nodes(Archetype) {
        if _arch.name.value == _m
            and _arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._expr_scalar_typed(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) or expr.type is None {
        return False;
    }
    _m = "";
    try {
        _m = expr.type.mangle();
    } except Exception {
        return False;
    }
    return _m in _NOGC_SCALARS;
}

impl OwnershipCheckPass._nogc_is_container_expr(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) or expr.type is None {
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

impl OwnershipCheckPass._nogc_is_list_expr(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) or expr.type is None {
        return False;
    }
    _tk = "";
    try {
        _tk = expr.type.mangle();
    } except Exception {
        return False;
    }
    return _tk == "list" or _tk.startswith("list[");
}

impl OwnershipCheckPass._nogc_container_grow_method(call: FuncCall) -> (str | None) {
    _tgt = call.target;
    if not isinstance(_tgt, AtomTrailer) or not _tgt.is_attr {
        return None;
    }
    _r = _tgt.right;
    if not isinstance(_r, Name) or _r.sym_name not in ("append", "add", "insert") {
        return None;
    }
    if not self._nogc_is_container_expr(_tgt.target) {
        return None;
    }
    return _r.sym_name;
}

impl OwnershipCheckPass._nogc_module_enforced(mod_name: str) -> bool {
    opts = self.prog?.options;
    if opts is not None and opts.nogc_enforced_for(mod_name) {
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

impl OwnershipCheckPass._nogc_fresh_scalar_list(expr: Expr | None) -> bool {
    if not isinstance(expr, ListVal) {
        return False;
    }
    for _v in (expr.values or []) {
        if not self._expr_scalar_typed(_v) {
            return False;
        }
    }
    return True;
}

impl OwnershipCheckPass._nogc_fresh_arch_elem(expr: Expr | None) -> bool {
    if not isinstance(expr, FuncCall) {
        return False;
    }
    _t = expr.target;
    if not isinstance(_t, Name) or _t.sym is None or _t.sym.decl is None {
        return False;
    }
    _arch = _t.sym.decl.find_parent_of_type(Archetype);
    return _arch is not None and _arch.arch_type.name == Tok.KW_OBJECT;
}

impl OwnershipCheckPass._own_field_target(tgt: AtomTrailer) -> bool {
    if not (tgt.is_attr and isinstance(tgt.right, Name)) {
        return False;
    }
    fsym = tgt.right.sym;
    if fsym is None or not fsym.defn {
        return False;
    }
    hv = fsym.defn[0].find_parent_of_type(HasVar);
    if hv is None or hv.type_tag is None {
        return False;
    }
    if hv.type_tag.ownership == OwnershipKind.OWN {
        return True;
    }
    inner = hv.type_tag.tag;
    return isinstance(inner, UnaryExpr) and inner.ownership == OwnershipKind.OWN;
}

impl OwnershipCheckPass._nogc_check_call(call: FuncCall, prov: str) -> None {
    _stdlib_root = _stdlib_attr_call_root(call);
    if _stdlib_root is not None and _stdlib_root in _NONRETAINING_STDLIB_MODULES {
        return;
    }
    if isinstance(call.target, AtomTrailer)
        and isinstance(call.target.right, Name)
        and call.target.right.value in _NONRETAINING_METHOD_CALLS {
        return;
    }
    _callee_root: (Name | None) = None;
    if isinstance(call.target, Name) {
        _callee_root = call.target;
    } elif isinstance(call.target, AtomTrailer) {
        _callee_root = self._place_of(call.target);
    }
    if _callee_root is None {
        return;
    }

    _opts_c = self.prog?.options;
    _hl_c = getattr(_opts_c, "na_gc_mode", "cycles") == "none" if _opts_c else False;
    _heap_args: list[Name] = [];
    for _arg in self._call_params(call) {
        _a = _arg.value if isinstance(_arg, KWPair) else _arg;
        if isinstance(_a, FuncCall)
            and isinstance(_a.target, Name)
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

    if isinstance(call.target, AtomTrailer)
        and _callee_root.sym is not None
        and _callee_root.sym.storage == SymbolStorage.MODULE_GLOBAL {
        self.emit(
            E1402, node_override=call, name=_heap_args[0].sym_name, provenance=prov
        );
        return;
    }

    _dbg_opts = self.prog?.options;
    if _dbg_opts?.nogc_debug {
        import sys as _dbg_sys;
        _dbg_sys.stderr.write(
            f"nogc-dbg call callee={_callee_root.sym_name} "
            f"sym={_callee_root.sym is not None} "
            f"tgt_is_name={isinstance(call.target, Name)} "
            f"heap_args={[a.sym_name for a in _heap_args]}\n"
        );
    }
    if isinstance(call.target, Name) and _callee_root.sym is not None {
        _defn_nodes = list(_callee_root.sym.defn or []);
        if _callee_root.sym.decl is not None {
            _defn_nodes.append(_callee_root.sym.decl);
        }
        for _dn in _defn_nodes {
            _decl_mod = _dn.find_parent_of_type(Module);
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

    _opts = self.prog?.options;
    _headerless = getattr(_opts, "na_gc_mode", "cycles") == "none" if _opts else False;
    if _headerless {
        for _lv in self.ir_in.get_all_sub_nodes(ListVal) {
            if _lv.find_parent_of_type(SubTag) is not None
                or _lv.find_parent_of_type(FuncSignature) is not None {
                continue;
            }
            _idx_ctx = _lv.find_parent_of_type(IndexSlice) is not None;
            for _le in (_lv.values or []) {
                if self._nogc_str_elem_ok(_le, idx_ctx=_idx_ctx)
                    or (
                        not _idx_ctx
                        and (
                            self._nogc_fresh_arch_elem(_le)
                            or self._nogc_fresh_scalar_list(_le)
                        )
                    ) {
                    continue;
                }
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
        for _sv in self.ir_in.get_all_sub_nodes(SetVal) {
            if _sv.find_parent_of_type(SubTag) is not None
                or _sv.find_parent_of_type(FuncSignature) is not None {
                continue;
            }
            for _se in (_sv.values or []) {
                if self._nogc_str_elem_ok(_se) {
                    continue;
                }
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
        for _dv in self.ir_in.get_all_sub_nodes(DictVal) {
            if _dv.find_parent_of_type(SubTag) is not None
                or _dv.find_parent_of_type(FuncSignature) is not None {
                continue;
            }
            for _kv in (_dv.kv_pairs or []) {
                _key_bad = (
                    not self._nogc_str_elem_ok(_kv.key, idx_ctx=True)
                    and self._nogc_local_shape_expr_heap(_kv.key)
                );
                _val_bad = (
                    not self._nogc_str_elem_ok(_kv.value)
                    and self._nogc_local_shape_expr_heap(_kv.value)
                );
                if _key_bad or _val_bad {
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
        for _mc in self.ir_in.get_all_sub_nodes(FuncCall) {
            _grow = self._nogc_container_grow_method(_mc);
            if _grow is None {
                continue;
            }
            _grow_recv = (
                self._place_of(_mc.target.target)
                    if isinstance(_mc.target, AtomTrailer)
                    else None
            );
            if _grow_recv is not None
                and _grow_recv.sym is not None
                and self._name_sym_id(_grow_recv) in self.arch_view_syms {
                continue;
            }
            for _garg in self._call_params(_mc) {
                _gav = _garg.value if isinstance(_garg, KWPair) else _garg;
                if isinstance(_gav, FuncCall)
                    and isinstance(_gav.target, Name)
                    and _gav.target.sym_name == "managed" {
                    continue;
                }
                _is_str = False;
                try {
                    _is_str = (_gav.type.mangle() if _gav.type is not None else "")
                        == "str";
                } except Exception {
                    _is_str = False;
                }
                if _is_str {
                    if not self._nogc_str_elem_ok(_gav) {
                        self.emit(
                            E1406,
                            node_override=_mc,
                            name=f"{_grow}() of a heap element",
                            provenance=_prov
                        );
                        break;
                    }
                    continue;
                }
                if _grow in ("append", "insert")
                    and (
                        self._nogc_fresh_arch_elem(_gav)
                        or self._nogc_fresh_scalar_list(_gav)
                    ) {
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
        for _gv in self.ir_in.get_all_sub_nodes(GlobalVars) {
            for _ga in _gv.get_all_sub_nodes(Assignment) {
                if _ga.type_tag is not None
                    and _ga.type_tag.ownership == OwnershipKind.OWN {
                    continue;
                }
                for _gt in _ga.target {
                    if isinstance(_gt, Name)
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
        if not (isinstance(_nm, Name) and _nm.sym) {
            continue;
        }
        if param.find_parent_of_type(Import) is not None {
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
        if isinstance(_tgt, Name)
            and _tgt.sym is not None
            and _tgt.sym.ownership == OwnershipKind.NONE
            and _tgt.sym.storage != SymbolStorage.MODULE_GLOBAL
            and _tgt.find_parent_of_type(GlobalVars) is None
            and _tgt.find_parent_of_type(UniEnum) is None {
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
        if isinstance(_tgt, AtomTrailer) {
            _root = self._place_of(_tgt);
            if _root is not None
                and _root.sym is not None
                and _root.sym.storage == SymbolStorage.MODULE_GLOBAL {
                _val_root = self._place_of(nd.value);
                _is_owned_val = _val_root is not None
                    and _val_root.sym is not None
                    and _val_root.sym.ownership == OwnershipKind.OWN;
                _own_world_store = (
                    self._own_field_target(_tgt)
                    and _root.sym.ownership == OwnershipKind.OWN
                    and _root.find_parent_of_type(GlobalVars) is None
                );
                if not _own_world_store
                    and (
                        _is_owned_val
                        or (
                            nd.value is not None
                            and self._nogc_local_shape_expr_heap(nd.value)
                        )
                    ) {
                    _val_name = (
                        _val_root.sym_name
                            if _val_root is not None and _val_root.sym is not None
                            else _root.sym_name
                    );
                    self.emit(
                        E1402, node_override=_tgt, name=_val_name, provenance=_prov
                    );
                }
            } elif _headerless
                and not _tgt.is_attr
                and self._nogc_is_container_expr(_tgt.target)
                and nd.value is not None
                and not self._nogc_str_elem_ok(nd.value)
                and not (
                    self._nogc_is_list_expr(_tgt.target)
                    and self._nogc_fresh_arch_elem(nd.value)
                )
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

    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        self._nogc_check_call(call, _prov);
    }

    for _lam in self.ir_in.get_all_sub_nodes(LambdaExpr) {
        for _nm in _lam.get_all_sub_nodes(Name) {
            if _nm.sym is None {
                continue;
            }
            if _nm.sym.ownership == OwnershipKind.OWN
                or self._nogc_local_shape(_nm) == "heap" {
                _decl = _nm.sym.decl;
                if _decl is not None
                    and _decl.find_parent_of_type(LambdaExpr) is not _lam {
                    self.emit(
                        E1405, node_override=_nm, name=_nm.sym_name, provenance=_prov
                    );
                    break;
                }
            }
        }
    }
}

impl OwnershipCheckPass._view_base_place(expr: Expr | None) -> (Name | None) {
    if not isinstance(expr, AtomTrailer) {
        return None;
    }
    _isl = expr.right;
    if not isinstance(_isl, IndexSlice) or not _isl.is_range or len(_isl.slices) != 1 {
        return None;
    }
    _sl = _isl.slices[0];
    if not isinstance(_sl, Slice) or _sl.step is not None {
        return None;
    }
    _m = "";
    try {
        _m = expr.type.mangle() if expr.type is not None else "";
    } except Exception {
        return None;
    }
    if _m != "str" {
        return None;
    }
    _base = self._place_of(expr.target);
    if _base is None or _base.sym is None {
        return None;
    }
    if _base.sym_name == "self"
        or _base.sym.ownership
            in (
                OwnershipKind.OWN,
                OwnershipKind.BORROW,
                OwnershipKind.MUT_BORROW,
                OwnershipKind.IMM
            ) {
        return _base;
    }
    return None;
}

impl OwnershipCheckPass._view_root_owner(sym_id: SymId) -> SymId {
    _cur = sym_id;
    _hops = 0;
    while _cur in self.borrow_meta and _hops < 32 {
        _own = self.borrow_meta[_cur].owner;
        if _own is None {
            break;
        }
        _cur = _own;
        _hops += 1;
    }
    return _cur;
}

impl OwnershipCheckPass._sym_is_param(sym_id: SymId) -> bool {
    for _nm in self.name_uses_by_sym.get(sym_id, []) {
        if _nm.sym is not None {
            return (
                _nm.sym.storage == SymbolStorage.PARAM
                and (
                    is_borrow_kind(_nm.sym.ownership)
                    or _nm.sym.ownership == OwnershipKind.IMM
                )
            );
        }
    }
    return False;
}

impl OwnershipCheckPass._view_of_expr(expr: Expr | None) -> (SymId | None) {
    if isinstance(expr, Name) {
        _sid = self._sym_id(expr);
        if _sid is not None and _sid in self.view_syms and _sid in self.borrow_meta {
            return self.borrow_meta[_sid].owner;
        }
        return None;
    }
    _base = self._view_base_place(expr);
    if _base is not None {
        return self._name_sym_id(_base);
    }
    if isinstance(expr, FuncCall) {
        _ctor_owners = self._view_ctor_owners(expr);
        if _ctor_owners {
            return _ctor_owners[0];
        }
        return self._view_call_owner(expr);
    }
    return None;
}

impl OwnershipCheckPass._is_view_expr(expr: Expr | None) -> bool {
    if self._view_of_expr(expr) is not None {
        return True;
    }
    if isinstance(expr, Name) {
        _sid = self._sym_id(expr);
        return _sid is not None and _sid in self.view_syms;
    }
    return self._view_ctor_owners(expr) is not None;
}

impl OwnershipCheckPass._compute_view_archs -> None {
    self.view_archs = set();
    self.view_arch_memo = {};
}

impl OwnershipCheckPass._is_view_arch(arch: Archetype | None) -> bool {
    if arch is None or arch.name is None {
        return False;
    }
    key = id(arch);
    if key in self.view_arch_memo {
        return self.view_arch_memo[key];
    }
    self.view_arch_memo[key] = False;
    local_archs: dict[str, Archetype] = {};
    for other in self.ir_in.get_all_sub_nodes(Archetype) {
        if other.name is not None {
            local_archs[other.name.value] = other;
        }
    }
    result = False;
    for hv in arch.get_all_sub_nodes(HasVar) {
        if hv.find_parent_of_type(Archetype) is not arch or hv.type_tag is None {
            continue;
        }
        if type_tag_borrows(hv.type_tag) {
            result = True;
            break;
        }
        for nm in hv.type_tag.get_all_sub_nodes(Name) {
            if not isinstance(nm, Name) {
                continue;
            }
            inner = local_archs.get(nm.value);
            if inner is not None and inner is not arch and self._is_view_arch(inner) {
                result = True;
                break;
            }
        }
        if result {
            break;
        }
    }
    self.view_arch_memo[key] = result;
    if result {
        self.view_archs.add(arch.name.value);
    }
    return result;
}

impl OwnershipCheckPass._view_arch_of_call(call: FuncCall) -> (Archetype | None) {
    tgt = call.target;
    if not isinstance(tgt, Name) or tgt.sym is None or tgt.sym.decl is None {
        return None;
    }
    decl = tgt.sym.decl;
    arch = decl if isinstance(decl, Archetype) else decl.find_parent_of_type(Archetype);
    if arch is None or arch.name is None or arch.name.value != tgt.sym_name {
        return None;
    }
    return arch if self._is_view_arch(arch) else None;
}

impl OwnershipCheckPass._view_ctor_owners(expr: Expr | None) -> (list[SymId] | None) {
    if not isinstance(expr, FuncCall) or self._view_arch_of_call(expr) is None {
        return None;
    }
    owners: list[SymId] = [];
    for param in self._call_params(expr) {
        arg = param.value if isinstance(param, KWPair) else param;
        base_expr = arg.operand if isinstance(arg, UnaryExpr) else arg;
        base = self._place_of(base_expr);
        if base is None or base.sym is None {
            continue;
        }
        owner_root = self._derivation_root(base);
        if owner_root is None {
            if not (isinstance(arg, UnaryExpr) and is_borrow_kind(arg.ownership)) {
                continue;
            }
            owner_root = self._name_sym_id(base);
        }
        if owner_root not in owners {
            owners.append(owner_root);
        }
    }
    return owners;
}

impl OwnershipCheckPass._derivation_root(base: Name) -> (SymId | None) {
    if base.sym is None {
        return None;
    }
    sid = self._name_sym_id(base);
    if sid in self.borrow_meta {
        return self._view_root_owner(sid);
    }
    if base.sym.storage == SymbolStorage.PARAM
        and (
            is_borrow_kind(base.sym.ownership)
            or base.sym.ownership == OwnershipKind.IMM
        ) {
        return sid;
    }
    if sid in self.owned_decl {
        return sid;
    }
    decl = base.sym.decl;
    loop = decl.find_parent_of_type(InForStmt) if decl is not None else None;
    if loop is not None and loop.target is decl {
        coll = loop.collection;
        if isinstance(coll, UnaryExpr) and is_borrow_kind(coll.ownership) {
            src = self._place_of(coll.operand);
            if src is not None and src.sym is not None and src is not base {
                return self._derivation_root(src);
            }
        }
    }
    return None;
}

impl OwnershipCheckPass._stamp_arch_view_bindings -> None {
    for nd in self.idx_assignments {
        if len(nd.target) != 1 or nd.aug_op is not None {
            continue;
        }
        _tgt = nd.target[0];
        if not (isinstance(_tgt, Name) and _tgt.sym) {
            continue;
        }
        if _tgt.find_parent_of_type(GlobalVars) is not None {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        owners = self._view_ctor_owners(nd.value);
        declared_view = nd.type_tag is not None
            and type_tag_borrows(nd.type_tag)
            and (nd.type_tag.ownership == OwnershipKind.NONE);
        if owners is None and not declared_view {
            continue;
        }
        self.owned_decl.pop(_sid, None);
        _tgt.sym.ownership = OwnershipKind.BORROW;
        primary = owners[0] if owners else None;
        extras = owners[1:] if owners else [];
        meta = BorrowMeta(name=_tgt.sym_name, owner=primary);
        meta.extra_owners = list(extras);
        self.borrow_meta[_sid] = meta;
        self.borrow_created_at[_sid] = nd;
        self.view_syms.add(_sid);
        self.arch_view_syms.add(_sid);
    }
    for _mc in self.ir_in.get_all_sub_nodes(FuncCall) {
        _grow = self._nogc_container_grow_method(_mc);
        if _grow is None or not isinstance(_mc.target, AtomTrailer) {
            continue;
        }
        recv = self._place_of(_mc.target.target);
        if recv is None or recv.sym is None {
            continue;
        }
        rsid = self._name_sym_id(recv);
        if rsid not in self.arch_view_syms {
            continue;
        }
        meta = self.borrow_meta[rsid];
        for param in self._call_params(_mc) {
            arg = param.value if isinstance(param, KWPair) else param;
            base_expr = arg.operand if isinstance(arg, UnaryExpr) else arg;
            base = self._place_of(base_expr);
            if base is None or base.sym is None {
                continue;
            }
            owner_root = self._derivation_root(base);
            if owner_root is None or owner_root == rsid {
                continue;
            }
            if meta.owner is None {
                meta.owner = owner_root;
            } elif owner_root != meta.owner and owner_root not in meta.extra_owners {
                meta.extra_owners.append(owner_root);
            }
        }
    }
}

impl OwnershipCheckPass._view_call_owner(call: FuncCall) -> (SymId | None) {
    _tgt = call.target;
    _ab: (Ability | None) = None;
    if isinstance(_tgt, Name) and _tgt.sym is not None and _tgt.sym.decl is not None {
        _ab = _tgt.sym.decl.find_parent_of_type(Ability);
    } elif isinstance(_tgt, AtomTrailer)
        and _tgt.is_attr
        and isinstance(_tgt.right, Name)
        and _tgt.right.sym is not None
        and _tgt.right.sym.decl is not None {
        _ab = _tgt.right.sym.decl.find_parent_of_type(Ability);
    }
    if _ab is None or id(_ab) not in self.view_elision_fns {
        return None;
    }
    _fct = self.view_elision_fns[id(_ab)];
    if _fct == -1 {
        if isinstance(_tgt, AtomTrailer) {
            _recv = self._place_of(_tgt.target);
            if _recv is not None and _recv.sym is not None {
                return self._name_sym_id(_recv);
            }
        }
        return None;
    }
    _params = list(self._call_params(call));
    if _fct >= len(_params) {
        return None;
    }
    _arg = _params[_fct];
    if isinstance(_arg, KWPair) {
        return None;
    }
    _a = _arg.operand if isinstance(_arg, UnaryExpr) else _arg;
    _pl = self._place_of(_a);
    if _pl is None or _pl.sym is None {
        return None;
    }
    return self._name_sym_id(_pl);
}

impl OwnershipCheckPass._stamp_view_borrows -> None {
    for nd in self.idx_assignments {
        if len(nd.target) != 1 or nd.aug_op is not None {
            continue;
        }
        if nd.type_tag is not None and nd.type_tag.ownership != OwnershipKind.NONE {
            continue;
        }
        _tgt = nd.target[0];
        if not (isinstance(_tgt, Name) and _tgt.sym) {
            continue;
        }
        if _tgt.sym.storage == SymbolStorage.MODULE_GLOBAL {
            continue;
        }
        _base = self._view_base_place(nd.value);
        if _base is None {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        if _sid in self.owned_decl {
            continue;
        }
        _tgt.sym.ownership = OwnershipKind.BORROW;
        self.borrow_meta[_sid] = BorrowMeta(
            name=_tgt.sym_name, owner=self._name_sym_id(_base)
        );
        self.borrow_created_at[_sid] = nd;
        self.view_syms.add(_sid);
    }

    for nd in self.idx_assignments {
        if len(nd.target) != 1 or nd.aug_op is not None or nd.type_tag is not None {
            continue;
        }
        _tgt = nd.target[0];
        if not (
            isinstance(_tgt, Name)
            and _tgt.sym
            and _tgt.sym.ownership == OwnershipKind.NONE
        ) {
            continue;
        }
        if not isinstance(nd.value, Name) {
            continue;
        }
        _src = self._sym_id(nd.value);
        if _src is None or _src not in self.view_syms or _src not in self.borrow_meta {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        _tgt.sym.ownership = OwnershipKind.BORROW;
        self.borrow_meta[_sid] = BorrowMeta(
            name=_tgt.sym_name, owner=self.borrow_meta[_src].owner
        );
        self.borrow_created_at[_sid] = nd;
        self.view_syms.add(_sid);
    }

    _seen: set[int] = set();
    for _ab in self.ir_in.get_all_sub_nodes(Ability) {
        self._stamp_view_call_results(_ab, _seen);
        _all_params = [
            p
            for p in self.idx_params
            if p.find_parent_of_type(Ability) is _ab
        ];
        _cands = [
            p
            for p in _all_params
            if p.type_tag is not None
                and (
                    is_borrow_kind(p.type_tag.ownership)
                    or p.type_tag.ownership == OwnershipKind.IMM
                )
        ];
        for ret in self.idx_returns {
            if ret.find_parent_of_type(Ability) is not _ab {
                continue;
            }
            _own_sid = self._view_of_expr(ret.expr);
            if _own_sid is None {
                continue;
            }
            _root = self._view_root_owner(_own_sid);
            _root_nm = "";
            for _u in self.name_uses_by_sym.get(_root, []) {
                _root_nm = _u.sym_name;
                break;
            }
            if not _root_nm {
                _bpd = self._view_base_place(ret.expr);
                if _bpd is not None {
                    _root_nm = _bpd.sym_name;
                }
            }
            if _root_nm == "self" {
                if _cands {
                    self.emit(
                        E1315,
                        node_override=ret,
                        name=f"a view return with `self` and"
                        f" {len(_cands)} more candidate parameters"
                    );
                } else {
                    self.view_elision_fns[id(_ab)] = -1;
                }
                continue;
            }
            _cand_hit = -1;
            for (_i, _p) in enumerate(_all_params) {
                if _p in _cands
                    and isinstance(_p.name, Name)
                    and _p.name.sym is not None
                    and self._name_sym_id(_p.name) == _root {
                    _cand_hit = _i;
                    break;
                }
            }
            if _cand_hit >= 0 {
                self.view_elision_fns[id(_ab)] = _cand_hit;
                continue;
            }
            if isinstance(ret.expr, Name) {
                continue;
            }
            self.emit(
                E1315, node_override=ret, name=f"returning a view of '{_root_nm}'"
            );
        }
    }
    self._stamp_view_call_results(self.ir_in, _seen);
}

impl OwnershipCheckPass._stamp_view_call_results(
    scope: UniNode, seen_ids: set[int]
) -> None {
    for nd in self.idx_assignments {
        if id(nd) in seen_ids {
            continue;
        }
        _encl = nd.find_parent_of_type(Ability);
        if scope is self.ir_in {
            if _encl is not None {
                continue;
            }
        } elif _encl is not scope {
            continue;
        }
        seen_ids.add(id(nd));
        if len(nd.target) != 1 or nd.aug_op is not None {
            continue;
        }
        if nd.type_tag is not None and nd.type_tag.ownership != OwnershipKind.NONE {
            continue;
        }
        _tgt = nd.target[0];
        if not (isinstance(_tgt, Name) and _tgt.sym) {
            continue;
        }
        if _tgt.sym.storage == SymbolStorage.MODULE_GLOBAL {
            continue;
        }
        if not isinstance(nd.value, FuncCall) {
            continue;
        }
        _own_sid = self._view_call_owner(nd.value);
        if _own_sid is None {
            continue;
        }
        _sid = self._name_sym_id(_tgt);
        self.owned_decl.pop(_sid, None);
        _tgt.sym.ownership = OwnershipKind.BORROW;
        self.borrow_meta[_sid] = BorrowMeta(name=_tgt.sym_name, owner=_own_sid);
        self.borrow_created_at[_sid] = nd;
        self.view_syms.add(_sid);
    }
}

impl OwnershipCheckPass._emit_view_diagnostics -> None {
    if self.nogc_prov is None and not self.arch_view_syms {
        return;
    }
    for nd in self.idx_assignments {
        if nd.type_tag is not None
            and nd.type_tag.ownership == OwnershipKind.OWN
            and self._is_view_expr(nd.value) {
            self.emit(E1315, node_override=nd, name="an `own` binding of a view");
        }
        if len(nd.target) == 1 and nd.aug_op is None {
            _gt = nd.target[0];
            if isinstance(_gt, Name)
                and _gt.sym is not None
                and _gt.sym.storage == SymbolStorage.MODULE_GLOBAL
                and _gt.sym.decl is not None
                and _gt.sym.decl.find_parent_of_type(GlobalVars) is not None
                and self._is_view_expr(nd.value) {
                self.emit(
                    E1315,
                    node_override=nd,
                    name=f"storing a view into module global '{_gt.sym_name}'"
                );
            }
        }
        for _t2 in nd.target {
            if isinstance(_t2, AtomTrailer)
                and not isinstance(nd.value, Name)
                and self._is_view_expr(nd.value) {
                self.emit(
                    E1315,
                    node_override=nd.value,
                    name="storing a view into a field or element"
                );
                break;
            }
        }
    }
    for _mc in self.ir_in.get_all_sub_nodes(FuncCall) {
        _grow = self._nogc_container_grow_method(_mc);
        if _grow is None {
            continue;
        }
        _recv = self._place_of(_mc.target.target)
            if isinstance(_mc.target, AtomTrailer)
            else None;
        if _recv is not None
            and _recv.sym is not None
            and self._name_sym_id(_recv) in self.arch_view_syms {
            continue;
        }
        for _garg in self._call_params(_mc) {
            _gav = _garg.value if isinstance(_garg, KWPair) else _garg;
            if self._view_of_expr(_gav) is not None {
                self.emit(
                    E1315,
                    node_override=_gav,
                    name=f"storing a view into a container ({_grow}())"
                );
            }
        }
    }
    for _lv in self.ir_in.get_all_sub_nodes(ListVal) {
        if _lv.find_parent_of_type(IndexSlice) is not None {
            continue;
        }
        for _e in (_lv.values or []) {
            if self._view_of_expr(_e) is not None {
                self.emit(
                    E1315, node_override=_e, name="a view in a container literal"
                );
            }
        }
    }
    for _sv in self.ir_in.get_all_sub_nodes(SetVal) {
        if _sv.find_parent_of_type(IndexSlice) is not None {
            continue;
        }
        for _e in (_sv.values or []) {
            if self._view_of_expr(_e) is not None {
                self.emit(
                    E1315, node_override=_e, name="a view in a container literal"
                );
            }
        }
    }
    for _dv in self.ir_in.get_all_sub_nodes(DictVal) {
        if _dv.find_parent_of_type(IndexSlice) is not None {
            continue;
        }
        for _kv in (_dv.kv_pairs or []) {
            for _e in (_kv.key, _kv.value) {
                if self._view_of_expr(_e) is not None {
                    self.emit(
                        E1315, node_override=_e, name="a view in a container literal"
                    );
                }
            }
        }
    }
}
