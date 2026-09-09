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
        return "enforced by the nogc profile";
    }
    _pats = list(getattr(opts, "memory_enforce", []) or []) if opts else [];
    _grand = list(getattr(opts, "memory_exempt", []) or []) if opts else [];
    if not _pats {
        try {
            import from jaclang.project { get_config }
            _cfg = get_config();
            if _cfg {
                _pats = list(_cfg.memory.enforce);
                _grand = list(_cfg.memory.exempt);
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
            return f'enforced by jac.toml [memory] "{_pat}"';
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
    import from jaclang.compiler.types.types { AnyType }
    _by_sym: dict[SymId, list[Assignment]] = {};
    _decl: dict[SymId, Name] = {};
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
        if _sid not in _by_sym {
            _by_sym[_sid] = [];
            _decl[_sid] = _tgt;
        }
        _by_sym[_sid].append(nd);
    }
    for (_sid, _asgs) in _by_sym.items() {
        _kinds: list[OwnershipKind] = [];
        _roots: list[Name] = [];
        _first: (Assignment | None) = None;
        for nd in _asgs {
            (_k, _r) = self._nogc_infer_state(nd.value);
            if _k == OwnershipKind.NONE {
                continue;
            }
            if _first is None {
                _first = nd;
            }
            _kinds.append(_k);
            _roots.extend(_r);
        }
        if _first is None {
            continue;
        }
        _kset = set(_kinds);
        _rebound = len(_asgs) > 1 or any([nd.aug_op is not None for nd in _asgs]);
        if _kset == {OwnershipKind.IMM} and not _rebound {
            self._nogc_bind_inferred(_first, _decl[_sid], OwnershipKind.IMM, []);
        } elif _kset <= {OwnershipKind.OWN, OwnershipKind.IMM} {
            self._nogc_bind_inferred(_first, _decl[_sid], OwnershipKind.OWN, []);
        } elif all([is_borrow_kind(_k) for _k in _kinds]) {
            _kind = OwnershipKind.MUT_BORROW
                if OwnershipKind.MUT_BORROW in _kset
                else OwnershipKind.BORROW;
            self._nogc_bind_inferred(_first, _decl[_sid], _kind, _roots);
        }
    }
}

impl OwnershipCheckPass._nogc_infer_state(
    expr: Expr | None
) -> tuple[OwnershipKind, list[Name]] {
    import from jaclang.compiler.passes.rc_facts_pass { result_ownership, Ownership }
    _none: list[Name] = [];
    while isinstance(expr, CfgExpr) {
        expr = expr.expr;
    }
    if expr is None {
        return (OwnershipKind.NONE, _none);
    }
    _own = result_ownership(expr);
    if _own == Ownership.OWNED {
        return (OwnershipKind.OWN, _none);
    }
    if _own == Ownership.STATIC {
        return (OwnershipKind.IMM, _none);
    }
    if isinstance(expr, BinaryExpr) {
        _op = expr.op.name if isinstance(expr.op, Token) else "";
        if _op in (Tok.PLUS, Tok.STAR_MUL, Tok.MOD)
            and self._nogc_expr_type_is_heap(expr) {
            return (OwnershipKind.OWN, _none);
        }
        return (OwnershipKind.NONE, _none);
    }
    if isinstance(expr, UnaryExpr) {
        if expr.ownership == OwnershipKind.OWN {
            return (OwnershipKind.OWN, _none);
        }
        if is_borrow_kind(expr.ownership) {
            _root = self._place_of(expr.operand);
            if _root is not None and _root.sym is not None {
                return (expr.ownership, [_root]);
            }
        }
        return (OwnershipKind.NONE, _none);
    }
    if isinstance(expr, IfElseExpr) {
        (_k1, _r1) = self._nogc_infer_state(expr.value);
        (_k2, _r2) = self._nogc_infer_state(expr.else_value);
        if _k1 == OwnershipKind.NONE or _k2 == OwnershipKind.NONE {
            return (OwnershipKind.NONE, _none);
        }
        if _k1 == _k2 {
            return (_k1, _r1 + _r2);
        }
        if is_borrow_kind(_k1) and is_borrow_kind(_k2) {
            return (OwnershipKind.BORROW, _r1 + _r2);
        }
        return (OwnershipKind.NONE, _none);
    }
    if isinstance(expr, Name) {
        _s = expr.sym;
        if _s is None {
            return (OwnershipKind.NONE, _none);
        }
        if _s.ownership == OwnershipKind.OWN or _s.ownership == OwnershipKind.IMM {
            return (_s.ownership, _none);
        }
        if is_borrow_kind(_s.ownership) {
            return (_s.ownership, [expr]);
        }
        return (OwnershipKind.NONE, _none);
    }
    if isinstance(expr, AtomTrailer) {
        if self._nogc_str_slice_value(expr) {
            if self._view_base_place(expr) is not None {
                return (OwnershipKind.NONE, _none);
            }
            return (OwnershipKind.OWN, _none);
        }
        _root = self._place_of(expr);
        if _root is None or _root.sym is None {
            return (OwnershipKind.NONE, _none);
        }
        if _root.sym_name == "self"
            or _root.sym.ownership
                in (
                    OwnershipKind.OWN,
                    OwnershipKind.BORROW,
                    OwnershipKind.MUT_BORROW,
                    OwnershipKind.IMM
                ) {
            return (OwnershipKind.BORROW, [_root]);
        }
    }
    return (OwnershipKind.NONE, _none);
}

impl OwnershipCheckPass._nogc_bind_inferred(
    nd: Assignment, tgt: Name, kind: OwnershipKind, roots: list[Name]
) -> None {
    _ts = tgt.sym;
    if _ts is None {
        return;
    }
    _sid = self._name_sym_id(tgt);
    if kind == OwnershipKind.OWN {
        _ts.ownership = OwnershipKind.OWN;
        self.owned_decl[_sid] = tgt;
        return;
    }
    if kind == OwnershipKind.IMM {
        _ts.ownership = OwnershipKind.IMM;
        self.imm_decl[_sid] = tgt;
        return;
    }
    _owners: list[SymId] = [];
    _mut_ok = True;
    for _r in roots {
        _rs = _r.sym;
        if _rs is None {
            continue;
        }
        _rid = self._name_sym_id(_r);
        _meta = self.borrow_meta.get(_rid);
        _oid = _rid;
        if _r is nd.value and _meta is not None and _meta.owner is not None {
            _oid = _meta.owner;
        }
        if _oid not in _owners {
            _owners.append(_oid);
        }
        if _r.sym_name != "self"
            and _rs.ownership not in (OwnershipKind.OWN, OwnershipKind.MUT_BORROW) {
            _mut_ok = False;
        }
    }
    _is_mut = kind == OwnershipKind.MUT_BORROW
        or (_mut_ok and self._name_written_through(tgt));
    _ts.ownership = OwnershipKind.MUT_BORROW if _is_mut else OwnershipKind.BORROW;
    _bm = BorrowMeta(
        name=tgt.sym_name,
        owner=_owners[0] if _owners else None,
        is_mut=_is_mut,
        field=self._single_field_of(nd.value)
            if isinstance(nd.value, AtomTrailer)
            else ""
    );
    for _extra in _owners[1:] {
        _bm.extra_owners.append(_extra);
    }
    self.borrow_meta[_sid] = _bm;
    self.borrow_created_at[_sid] = nd;
}

impl OwnershipCheckPass._nogc_type_is_str(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) or expr.type is None {
        return False;
    }
    try {
        return expr.type.mangle() in _STR_MANGLES;
    } except Exception {
        return False;
    }
}

impl OwnershipCheckPass._nogc_place_text(expr: Expr | None) -> str {
    while isinstance(expr, CfgExpr) {
        expr = expr.expr;
    }
    if isinstance(expr, Name) {
        return expr.sym_name;
    }
    if isinstance(expr, UnaryExpr) {
        return self._nogc_place_text(expr.operand);
    }
    if isinstance(expr, AtomTrailer) {
        _base = self._nogc_place_text(expr.target);
        if isinstance(expr.right, Name) {
            return f"{_base}.{expr.right.sym_name}";
        }
        if isinstance(expr.right, IndexSlice) {
            _idx = "...";
            if len(expr.right.slices) == 1 {
                _sl = expr.right.slices[0];
                _st = _sl.start if isinstance(_sl, Slice) else _sl;
                if isinstance(_st, Name) {
                    _idx = _st.sym_name;
                } elif isinstance(_st, Int) {
                    _idx = str(_st.value);
                }
            }
            return f"{_base}[{_idx}]";
        }
        return _base;
    }
    return "the value";
}

impl OwnershipCheckPass._nogc_elem_fixit(
    elem: Expr | None, dest: str, verb: str
) -> tuple[str, str] {
    _text = self._nogc_place_text(elem);
    _is_str = self._nogc_type_is_str(elem);
    _copy = "";
    if _is_str {
        _copy = f"copy it in with `{verb}(own {_text})`"
            if verb
            else f"copy it in with `own {_text}`";
    }
    _fresh = (
        "build the element fresh at the store (a constructor, literal, f-string"
        " or call result moves in)"
    );
    if isinstance(elem, Name) and elem.sym is not None {
        _sid = self._name_sym_id(elem);
        _meta = self.borrow_meta.get(_sid);
        if is_borrow_kind(elem.sym.ownership) or _meta is not None {
            _owner = "";
            if _meta is not None and _meta.owner is not None {
                _owner = self._owned_name(_meta.owner, "");
                if not _owner and _meta.owner in self.borrow_meta {
                    _owner = self.borrow_meta[_meta.owner].name;
                }
            }
            _of = f"a borrow of '{_owner}'" if _owner else "a borrowed value";
            _msg = f"'{_text}', {_of}, cannot enter {dest}, which owns its elements";
            _by_value = "";
            if isinstance(self.borrow_created_at.get(_sid), InForStmt) and _owner {
                _by_value = (
                    f"iterate by value (`for {_text} in {_owner}`) so each element moves"
                );
            }
            _opts = [
                o
                for o in [_copy, _by_value]
                if o
            ];
            if not _opts {
                _opts = [_fresh];
            }
            return (_msg, ", or ".join(_opts) + ".");
        }
        if elem.sym.ownership == OwnershipKind.IMM {
            _msg = f"'{_text}', an `imm` value, cannot enter {dest}, which owns its elements";
            return (_msg, (_copy or _fresh) + ".");
        }
        if elem.sym.ownership == OwnershipKind.NONE {
            _msg = (
                f"'{_text}', which has no ownership state, cannot enter {dest},"
                " which owns its elements"
            );
            return (
                _msg,
                f"bind it `own` (`{_text}: own T = ...`) so the store moves it, or {_fresh}."
            );
        }
    }
    if isinstance(elem, AtomTrailer) {
        _root = self._place_of(elem);
        _rn = _root.sym_name if _root is not None else "its owner";
        _msg = (
            f"'{_text}', a read of a place owned by '{_rn}', cannot enter {dest},"
            " which owns its elements"
        );
        _move = "" if _is_str else f"move it out with `take({_text})`";
        return (_msg, (_copy or _move or _fresh) + ".");
    }
    _msg = f"a value that is neither fresh nor owned cannot enter {dest}, which owns its elements";
    return (_msg, _fresh + ".");
}

impl OwnershipCheckPass._nogc_str_slice_value(expr: Expr | None) -> bool {
    if not isinstance(expr, AtomTrailer) {
        return False;
    }
    if not isinstance(expr.right, IndexSlice) {
        return False;
    }
    return self._nogc_type_is_str(expr);
}

impl OwnershipCheckPass._nogc_str_elem_ok(
    expr: Expr | None, idx_ctx: bool = False
) -> bool {
    if not isinstance(expr, Expr) {
        return False;
    }
    if not self._nogc_type_is_str(expr) {
        return False;
    }
    if idx_ctx {
        return True;
    }
    if isinstance(expr, (String, MultiString, FString)) {
        return True;
    }
    if isinstance(expr, UnaryExpr) and expr.ownership == OwnershipKind.OWN {
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
    _pats = list(getattr(opts, "memory_enforce", []) or []) if opts else [];
    _grand = list(getattr(opts, "memory_exempt", []) or []) if opts else [];
    if not _pats {
        try {
            import from jaclang.project { get_config }
            _cfg = get_config();
            if _cfg {
                _pats = list(_cfg.memory.enforce);
                _grand = list(_cfg.memory.exempt);
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

impl OwnershipCheckPass._emit_raises_diagnostics -> None {
    if self.nogc_prov is None {
        return;
    }
    import from jaclang.compiler.frontend.diagnostics { E1407 }
    for mc in self.ir_in.get_all_sub_nodes(ModuleCode) {
        for exc in sorted(self._local_raises(mc)) {
            reported = False;
            for call in mc.get_all_sub_nodes(FuncCall) {
                owner = call.find_parent_of_type(Ability);
                if owner is not None and self._node_within(owner, mc) {
                    continue;
                }
                callee = self._callee_ability(call);
                if callee is None
                    or exc not in callee.raises
                    or self._handled_by_enclosing_try(call, exc, mc) {
                    continue;
                }
                cname = callee.name_ref.sym_name
                    if callee.name_ref is not None
                    else "call";
                self.emit(E1407, node_override=call, name=cname, exc=exc);
                reported = True;
                break;
            }
            if not reported {
                for rs in mc.get_all_sub_nodes(RaiseStmt) {
                    if self._raise_type_name(rs) == exc
                        and not self._handled_by_enclosing_try(rs, exc, mc) {
                        self.emit(E1407, node_override=rs, name="raise", exc=exc);
                        break;
                    }
                }
            }
        }
    }
}

impl OwnershipCheckPass._nogc_moved_arch_elem(expr: Expr | None) -> bool {
    if not isinstance(expr, Name) or self._owned_sym_of(expr) is None {
        return False;
    }
    return not self._nogc_type_is_str(expr);
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
                _m_arg = _m_params[0] if _m_params else None;
                _m_value = _m_arg.value if isinstance(_m_arg, KWPair) else _m_arg;
                _m_root = self._place_of(_m_value);
                if _m_root is not None
                    and _m_root.sym is not None
                    and (
                        _m_root.sym.ownership == OwnershipKind.OWN
                        or self._nogc_local_shape(_m_root) == "heap"
                    ) {
                    self.emit(
                        E1406,
                        node_override=_a,
                        name="'managed()' on a heap value re-enters the reference-counted world, which a nogc build does not have",
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
                            or self._nogc_moved_arch_elem(_le)
                        )
                    ) {
                    continue;
                }
                if self._nogc_local_shape_expr_heap(_le) {
                    (_lmsg, _lhelp) = self._nogc_elem_fixit(_le, "a list literal", "");
                    self.emit(
                        E1406,
                        node_override=_lv,
                        name=_lmsg,
                        provenance=_prov,
                        help_text=_lhelp
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
                    (_smsg, _shelp) = self._nogc_elem_fixit(_se, "a set literal", "");
                    if not self._nogc_type_is_str(_se) {
                        _shelp = (
                            "a set holds str or scalar members only; keep archetypes"
                            " in a list or a dict."
                        );
                    }
                    self.emit(
                        E1406,
                        node_override=_sv,
                        name=_smsg,
                        provenance=_prov,
                        help_text=_shelp
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
                    and not self._nogc_fresh_arch_elem(_kv.value)
                    and not self._nogc_moved_arch_elem(_kv.value)
                    and self._nogc_local_shape_expr_heap(_kv.value)
                );
                if _key_bad or _val_bad {
                    (_dmsg, _dhelp) = self._nogc_elem_fixit(
                        _kv.key if _key_bad else _kv.value,
                        "a dict literal as a key" if _key_bad else "a dict literal",
                        ""
                    );
                    self.emit(
                        E1406,
                        node_override=_dv,
                        name=_dmsg,
                        provenance=_prov,
                        help_text=_dhelp
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
                _recv_text = (
                    self._nogc_place_text(_mc.target.target)
                        if isinstance(_mc.target, AtomTrailer)
                        else "the container"
                );
                if self._nogc_type_is_str(_gav) {
                    if not self._nogc_str_elem_ok(_gav) {
                        (_gmsg, _ghelp) = self._nogc_elem_fixit(
                            _gav, f"'{_recv_text}'", f"{_recv_text}.{_grow}"
                        );
                        self.emit(
                            E1406,
                            node_override=_mc,
                            name=_gmsg,
                            provenance=_prov,
                            help_text=_ghelp
                        );
                        break;
                    }
                    continue;
                }
                if _grow in ("append", "insert")
                    and (
                        self._nogc_fresh_arch_elem(_gav)
                        or self._nogc_fresh_scalar_list(_gav)
                        or self._nogc_moved_arch_elem(_gav)
                    ) {
                    continue;
                }
                if self._nogc_local_shape_expr_heap(_gav) {
                    (_gmsg, _ghelp) = self._nogc_elem_fixit(
                        _gav, f"'{_recv_text}'", f"{_recv_text}.{_grow}"
                    );
                    self.emit(
                        E1406,
                        node_override=_mc,
                        name=_gmsg,
                        provenance=_prov,
                        help_text=_ghelp
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
                            name=f"module global '{_gt.sym_name}' would hold heap storage for the program's lifetime, which the owned world cannot free",
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
                and not self._nogc_fresh_arch_elem(nd.value)
                and not self._nogc_moved_arch_elem(nd.value)
                and self._nogc_local_shape_expr_heap(nd.value) {
                (_imsg, _ihelp) = self._nogc_elem_fixit(
                    nd.value, f"'{self._nogc_place_text(_tgt.target)}'", ""
                );
                self.emit(
                    E1406,
                    node_override=_tgt,
                    name=_imsg,
                    provenance=_prov,
                    help_text=_ihelp
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
    if not self._nogc_type_is_str(expr) {
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

impl OwnershipCheckPass._view_arch_of_call(call: FuncCall) -> (Archetype | None) {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.ownership { contains_borrow }
    target_type = call.target.type;
    if not isinstance(target_type, ClassType)
        or target_type._shared is None
        or not target_type.is_instantiable() {
        return None;
    }
    arch = target_type.shared.symbol_table;
    if not isinstance(arch, Archetype) {
        return None;
    }
    return arch
        if contains_borrow(call.type) or type_tag_borrows(call.target)
        else None;
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
        _tgt.sym.is_view = True;
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
