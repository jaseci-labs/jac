import from jaclang.compiler.frontend.constant { OwnershipKind }

impl NativeLowering._nogc_owned_param(p: uni.ParamVar) -> bool {
    if not self._nogc_owned_world() or p.type_tag is None {
        return False;
    }
    return p.type_tag.ownership == OwnershipKind.OWN;
}

impl NativeLowering._normalize_type_key(key: str) -> str {
    if " | " in key or ("|" in key and "type[" in key) {
        sep = " | " if " | " in key else "|";
        for part in key.split(sep) {
            _p = part.strip();
            if _p.startswith("type[") and _p.endswith("]") {
                _p = _p[5:-1];
            }
            if _p not in ("None", "NoneType") {
                return _p;
            }
        }
    }
    if key.startswith("type[") and key.endswith("]") {
        key = key[5:-1];
    }
    return key;
}

impl NativeLowering._elem_keys_of_annotation(
    ann: (uni.UniNode | None)
) -> (list[str | None] | None) {
    if ann is None {
        return None;
    }

    if isinstance(ann, uni.AtomUnit) {
        return self._elem_keys_of_annotation(ann.value);
    }
    if (isinstance(ann, uni.BinaryExpr) and getattr(ann.op, 'value', '') == "|") {
        return (
            self._elem_keys_of_annotation(ann.left)
            or self._elem_keys_of_annotation(ann.right)
        );
    }
    elems: list[uni.UniNode] = [];
    if isinstance(ann, uni.TupleVal) {
        elems = list(ann.values or []);
    } elif isinstance(ann, uni.AtomTrailer) and isinstance(ann.right, uni.IndexSlice) {
        for s in ann.right.slices {
            inner = s.start if s.start is not None else s;
            if isinstance(inner, uni.TupleVal) {
                elems.extend(list(inner.values or []));
            } else {
                elems.append(inner);
            }
        }
    }
    if not elems {
        return None;
    }
    keys: list[str | None] = [];
    for e in elems {
        while (isinstance(e, uni.BinaryExpr) and getattr(e.op, 'value', '') == "|") {
            e = e.left;
        }
        _ek: (str | None) = None;
        _etb = e?.type if isinstance(e, uni.Expr) else None;
        if _etb is not None {
            try {
                mangled = self._mangled_of(_etb);
                if mangled is not None {
                    _ek = self._normalize_type_key(mangled);
                }
            } except Exception {}
        }
        keys.append(_ek);
    }
    return keys;
}

impl NativeLowering._record_ret_facts(
    name: str, sig: uni.FuncSignature, imported: (NativeFuncLayout | None) = None
) -> None {
    _rt = sig.return_type;
    if _rt is None {
        return;
    }
    if isinstance(_rt, uni.BinaryExpr) and getattr(_rt.op, 'value', '') == "|" {
        _rt = _rt.left;
    }
    _rtb = _rt?.type;
    if _rtb is not None {
        try {
            mangled = self._mangled_of(_rtb);
            if mangled is not None {
                self.func_ret_type_key[name] = self._normalize_type_key(mangled);
            }
        } except Exception {}
    }
    if imported is not None and imported.ret_enum_type {
        self.func_ret_type_key.setdefault(name, imported.ret_enum_type);
    }
    keys = imported.ret_elem_keys
        if imported is not None
        else self._elem_keys_of_annotation(_rt);
    if keys {
        self.func_ret_elem_keys[name] = keys;
    }
}

impl NativeLowering._ability_is_generator(nd: uni.Ability) -> bool {
    """Whether the ability's own body yields -- inline, or in its impl annex.""";
    owner: uni.UniNode = nd.body if isinstance(nd.body, uni.ImplDef) else nd;
    for y in owner.get_all_sub_nodes(typ=uni.YieldExpr) {
        _cur = y.parent;
        while _cur is not None
            and _cur is not owner
            and not isinstance(_cur, (uni.Ability, uni.ImplDef, uni.LambdaExpr)) {
            _cur = _cur.parent;
        }
        if _cur is owner {
            return True;
        }
    }
    return False;
}

impl NativeLowering._forward_declare_functions_stmts(
    module: uni.Module
) -> list[uni.ElementStmt] {
    return ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE);
}

impl NativeLowering._maybe_declare_ability_decorable(nd: uni.Ability) -> bool {
    return bool(
        nd.decorators
        and not isinstance(nd.parent, uni.Archetype)
        and nd.find_parent_of_type(uni.Ability) is None
    );
}

impl NativeLowering._maybe_declare_ability_decorator_names(nd: uni.Ability) -> list[str] {
    _dec_names: list[str] = [];
    if not nd.decorators {
        return _dec_names;
    }
    for _dx in nd.decorators {
        if isinstance(_dx, uni.Name) {
            _dec_names.append(_dx.value);
        }
    }
    if len(_dec_names) != len(nd.decorators) {
        _dec_names = [];
    }
    return _dec_names;
}

impl NativeLowering._maybe_declare_ability_symbol(nd: uni.Ability, name: str) -> str {
    _def_m = nd.find_parent_of_type(uni.Module);
    _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
    return self._symbol_for(name, _def_m, _is_pub);
}

impl NativeLowering._ability_skipped(nd: uni.Ability) -> bool {
    if nd.is_comptime {
        return True;
    }
    if (nd.type_params or self._ability_has_ct_params(nd))
        and self._mono_solution is None {
        return True;
    }
    return False;
}

impl NativeLowering._ability_body_empty(nd: uni.Ability) -> bool {
    _cb = ModuleFacts.unwrap_body(nd);
    if _cb is None or len(_cb) == 0 {
        return True;
    }
    return False;
}

impl NativeLowering._ability_generic_generator(nd: uni.Ability) -> bool {
    return bool(
        nd.type_params
        and self._mono_solution is not None
        and self._ability_is_generator(nd)
    );
}

impl NativeLowering._ability_scanned_body(
    nd: uni.Ability
) -> (Sequence[uni.UniNode] | None) {
    body = ModuleFacts.unwrap_body(nd);
    if body is not None {
        _scan_owner = nd.body if isinstance(nd.body, uni.ImplDef) else nd;
        self._scan_closure_escapes(_scan_owner, body);
    }
    return body;
}

impl NativeLowering._nested_ability_refused(nd: uni.Ability, name: str) -> bool {
    sig = nd.signature;
    if sig is not None and not isinstance(sig, uni.FuncSignature) {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=name,
            help_text="An event ability (`can ... with entry/exit`) cannot lower as a nested native function; it belongs on an archetype in a server context."
        );
        return True;
    }
    return False;
}

impl NativeLowering._nested_ability_capture_names(nd: uni.Ability) -> list[str] {
    return [s.sym_name for s in nd.get_enclosing_captures()];
}

impl NativeLowering._nested_ability_rebound(nd: uni.Ability) -> set[str] {
    rebound: set[str] = set();
    for _scope in ([nd] + nd.get_all_sub_nodes(typ=uni.UniScopeNode)) {
        for _rn in _scope.implicit_rebinds {
            rebound.add(_rn);
        }
    }
    return rebound;
}

impl NativeLowering._nested_ability_name_refs(nd: uni.Ability) -> list[str] {
    return [_nm.value for _nm in nd.get_all_sub_nodes(typ=uni.Name)];
}

impl NativeLowering._predeclare_nested_siblings_frame(
    nd: uni.Ability
) -> (tuple[uni.UniNode, list[tuple[uni.Ability, str]]] | None) {
    _p = nd.parent;
    _frame: (uni.UniNode | None) = None;
    while _p is not None {
        if isinstance(
            _p,
            (
                uni.Ability,
                uni.ImplDef,
                uni.LambdaExpr,
                uni.Test,
                uni.ModuleCode,
                uni.Module
            )
        ) {
            _frame = _p;
            break;
        }
        _p = _p.parent;
    }
    if not isinstance(_frame, (uni.Ability, uni.ImplDef)) {
        return None;
    }
    _fbody = ModuleFacts.unwrap_body(_frame);
    if not _fbody {
        return None;
    }
    _cands: list[tuple[uni.Ability, str]] = [];
    for _st in _fbody {
        if (
            isinstance(_st, uni.Ability)
            and _st.name_ref is not None
            and (_st.signature is None or isinstance(_st.signature, uni.FuncSignature))
            and not self._ability_is_generator(_st)
            and not _st?.type_params
        ) {
            _cands.append((_st, _st.name_ref.sym_name));
        }
    }
    return (_frame, _cands);
}

impl NativeLowering._predeclare_nested_siblings_captures(
    nd: uni.Ability,
    _frame: uni.UniNode,
    named: list[tuple[uni.Ability, str]],
    local_names: set[str]
) -> (
    tuple[
        list[uni.Ability],
        dict[uni.Ability, str],
        dict[uni.Ability, list[str]],
        dict[uni.Ability, dict[str, str]],
        dict[str, uni.Symbol]
    ]
    | None
) {
    import from jaclang.compiler.frontend.constant { SymbolType }
    sibs: list[uni.Ability] = [];
    sib_names: dict[uni.Ability, str] = {};
    for (_st, _stn) in named {
        sibs.append(_st);
        sib_names[_st] = _stn;
    }
    _found_self = False;
    for _s in sibs {
        if _s is nd {
            _found_self = True;
            break;
        }
    }
    if not _found_self {
        return None;
    }
    _sib_by_name: dict[str, uni.Ability] = {
        name: sib for (sib, name) in sib_names.items()
    };
    _cap_order: dict[uni.Ability, list[str]] = {};
    _cap_modes: dict[uni.Ability, dict[str, str]] = {};
    _sib_refs: dict[uni.Ability, set[str]] = {};
    _cap_syms: dict[str, uni.Symbol] = {};
    for s in sibs {
        _reb: set = set();
        for _scope in ([s] + s.get_all_sub_nodes(typ=uni.UniScopeNode)) {
            for _rn in _scope.implicit_rebinds {
                _reb.add(_rn);
            }
        }
        _ord: list[str] = [];
        _md: dict[str, str] = {};
        for _sym in s.get_enclosing_captures() {
            if _sym.sym_name in _md or _sym.sym_name in _sib_by_name {
                continue;
            }
            if _sym.sym_type in (SymbolType.ABILITY, SymbolType.TEST) {
                continue;
            }
            if _sym.sym_name in local_names
                or uni.same_lexical_scope(_sym.parent_tab, _frame) {
                _ord.append(_sym.sym_name);
                _md[_sym.sym_name] = "ptr" if _sym.sym_name in _reb else "val";
                if _sym.sym_name not in _cap_syms {
                    _cap_syms[_sym.sym_name] = _sym;
                }
            }
        }
        _cap_order[s] = _ord;
        _cap_modes[s] = _md;
        _rf: set = set();
        for _nm in s.get_all_sub_nodes(typ=uni.Name) {
            if _nm.value in _sib_by_name and _sib_by_name[_nm.value] is not s {
                _rf.add(_nm.value);
            }
        }
        _sib_refs[s] = _rf;
    }

    _changed = True;
    while _changed {
        _changed = False;
        for s in sibs {
            for _tn in _sib_refs[s] {
                _t = _sib_by_name[_tn];
                for _cn in _cap_order[_t] {
                    _cm = _cap_modes[_t][_cn];
                    if _cn not in _cap_modes[s] {
                        _cap_order[s].append(_cn);
                        _cap_modes[s][_cn] = _cm;
                        _changed = True;
                    } elif _cm == "ptr" and _cap_modes[s][_cn] != "ptr" {
                        _cap_modes[s][_cn] = "ptr";
                        _changed = True;
                    }
                }
            }
        }
    }
    return (sibs, sib_names, _cap_order, _cap_modes, _cap_syms);
}

impl NativeLowering._predeclare_nested_siblings_cap_type(
    csym: (uni.Symbol | None)
) -> (TypeBase | None) {
    return csym.decl.type if csym is not None and csym.decl?.type is not None else None;
}

impl NativeLowering._generator_elem_type_args(nd: uni.Ability) -> (list[TypeBase] | None) {
    sig = nd.signature;
    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return None;
    }
    rt = sig.return_type;
    if not isinstance(rt, uni.Expr) {
        return None;
    }
    return_type = rt.type;
    if not isinstance(return_type, ClassType) {
        return None;
    }
    mangled = self._mangled_of(return_type);
    if mangled is None {
        return None;
    }
    if mangled.startswith("type[") {
        mangled = mangled[5:];
    }
    for prefix in ("Iterator[", "Generator[", "Iterable[") {
        if mangled.startswith(prefix) {
            targs = return_type.private.type_args;
            if targs {
                return targs;
            }
        }
    }
    return None;
}

impl NativeLowering._generator_param_names(
    nd: uni.Ability, self_arch: (str | None)
) -> list[str] {
    sig = nd.signature;
    sig_params = sig.get_parameters() if isinstance(sig, uni.FuncSignature) else [];
    _names: list[str] = [];
    if self_arch is not None and not (nd.is_static or nd.is_classmethod) {
        if sig_params
            and sig_params[0].name
            and sig_params[0].name.value == "self" {
            sig_params = sig_params[1:];
        }
        _names.append("self");
    }
    for (i, p) in enumerate(sig_params) {
        _names.append(p.name.value if p.name else f"arg{i}");
    }
    return _names;
}
