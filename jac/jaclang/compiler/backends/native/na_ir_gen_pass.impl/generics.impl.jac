impl NaIRGenPass._mangled_of(t: any) -> (str | None) {
    if t is None or not t?.mangle {
        return None;
    }
    m = t.mangle();
    _map = self._mono_mangle_map;
    if _map {
        import re;
        for (tv, repl) in _map.items() {
            m = re.sub(rf"\b{re.escape(tv)}\b", repl, m);
        }
    }
    if m == "Sequence" or m.startswith("Sequence[") {
        m = "list" + m[len("Sequence"):];
    }
    return m;
}

impl NaIRGenPass._syntactic_bind_type_params(
    tag_node: (uni.UniNode | None), actual: any, tp_names: list[str], solution: dict
) -> None {
    try {
        import from jaclang.compiler.types.types { ClassType as _SbCT }
    } except ImportError {
        return;
    }
    nd = tag_node;
    while isinstance(nd, uni.AtomUnit) and nd.value is not None {
        nd = nd.value;
    }
    if nd is None or actual is None {
        return;
    }
    if isinstance(nd, uni.Name) {
        if nd.value in tp_names and nd.value not in solution {
            _a = actual;
            if isinstance(_a, _SbCT)
                and not _a.is_instance()
                and _a.is_instantiable() {
                _a = _a.clone_as_instance();
            }
            solution[nd.value] = _a;
        }
        return;
    }
    if (
        isinstance(nd, uni.AtomTrailer)
        and isinstance(nd.target, uni.Name)
        and nd.target.value == "type"
        and isinstance(nd.right, uni.IndexSlice)
        and len(nd.right.slices) == 1
        and nd.right.slices[0].start is not None
        and isinstance(actual, _SbCT)
        and not actual.is_instance()
        and actual.is_instantiable()
    ) {
        self._syntactic_bind_type_params(
            nd.right.slices[0].start, actual.clone_as_instance(), tp_names, solution
        );
        return;
    }
    if (
        isinstance(nd, uni.AtomTrailer)
        and isinstance(nd.right, uni.IndexSlice)
        and isinstance(actual, _SbCT)
    ) {
        _args = actual.private.type_args or [];
        for (i, sl) in enumerate(nd.right.slices) {
            if sl.start is not None and i < len(_args) {
                self._syntactic_bind_type_params(
                    sl.start, _args[i], tp_names, solution
                );
            }
        }
    }
}

impl NaIRGenPass._solve_generic_call(
    ability: uni.Ability, nd: uni.FuncCall
) -> (dict | None) {
    try {
        import from jaclang.compiler.types.types {
            TypeVarType as _TVT,
            ClassType as _CT,
            UnionType as _UT
        }
    } except ImportError {
        return None;
    }
    solution: dict = {};

    def unify(decl: any, actual: any) -> None {
        if decl is None or actual is None {
            return;
        }
        _outer = self._mono_solution;
        if isinstance(actual, _TVT) and _outer is not None and actual.name in _outer {
            actual = _outer[actual.name];
        }
        if isinstance(decl, _TVT) {
            if decl.name not in solution {
                solution[decl.name] = actual;
            }
            return;
        }
        if (
            isinstance(decl, _CT)
            and decl._shared is not None
            and decl.shared.class_name == "type"
            and (decl.private.type_args or [])
            and isinstance(actual, _CT)
            and actual.is_instantiable()
            and not actual.is_instance()
        ) {
            unify(decl.private.type_args[0], actual.clone_as_instance());
            return;
        }
        if isinstance(decl, _CT) and isinstance(actual, _CT) {
            d_args = decl.private.type_args or [];
            a_args = actual.private.type_args or [];
            for (i, da) in enumerate(d_args) {
                if i < len(a_args) {
                    unify(da, a_args[i]);
                }
            }
            return;
        }
        if isinstance(decl, _UT) {
            for m in (decl.types or []) {
                if isinstance(m, _TVT) {
                    unify(m, actual);
                    return;
                }
            }
        }
    }

    sig = ability.signature;
    params = sig.get_parameters() if isinstance(sig, uni.FuncSignature) else [];
    _ft = ability.name_ref.type if ability.name_ref is not None else None;
    _ft_params = list(_ft.parameters) if isinstance(_ft, SemanticFunctionType) else [];
    positional: list = [];
    kw_map: dict = {};
    for a in (nd.params or []) {
        if isinstance(a, uni.KWPair) {
            if a.key is not None {
                kw_map[a.key.sym_name] = a.value;
            }
        } else {
            positional.append(a);
        }
    }
    _tp_names: list[str] = [];
    for tp in (ability.type_params or []) {
        if tp?.name {
            _tp_names.append(tp.name.value);
        }
    }
    for (i, p) in enumerate(params) {
        p_name = p.name.sym_name if p?.name and p.name is not None else None;
        chosen = positional[i]
            if i < len(positional)
            else (kw_map.get(p_name) if p_name is not None else None);
        if not isinstance(chosen, uni.Expr) {
            continue;
        }
        decl_t = _ft_params[i].param_type if i < len(_ft_params) else None;
        if decl_t is None and p?.type_tag and p.type_tag is not None {
            decl_t = p.type_tag.tag.type if p.type_tag?.tag else None;
        }
        unify(decl_t, chosen.type);
        _tp_unsolved = False;
        for n in _tp_names {
            if n not in solution {
                _tp_unsolved = True;
                break;
            }
        }
        if (
            _tp_unsolved and p?.type_tag and p.type_tag is not None and p.type_tag?.tag
        ) {
            self._syntactic_bind_type_params(
                p.type_tag.tag, chosen.type, _tp_names, solution
            );
        }
    }
    for tp in (ability.type_params or []) {
        tp_name = tp.name.value if tp?.name and tp.name is not None else None;
        if tp_name is not None and tp_name not in solution {
            return None;
        }
    }
    return solution;
}

impl NaIRGenPass._ct_eval -> any {
    return self.prog.get_type_evaluator().ct_eval;
}

impl NaIRGenPass._ct_value_with_bindings(nd: uni.Expr) -> tuple {
    cv = nd.ct_value;
    if cv is None {
        return (False, None);
    }
    if not cv.is_deferred {
        return (True, cv.v);
    }
    if not self._ct_bindings {
        return (False, None);
    }
    try {
        return (True, self._ct_eval().eval_with_bindings(nd, self._ct_bindings));
    } except Exception {
        return (False, None);
    }
}

impl NaIRGenPass._ct_native_const(v: any, nd: uni.Expr) -> (ir.Value | None) {
    out: (ir.Value | None) = None;
    if isinstance(v, bool) {
        out = ir.Constant(ir.IntType(1), 1 if v else 0);
    } elif isinstance(v, int) {
        out = ir.Constant(ir.IntType(64), v);
    } elif isinstance(v, float) {
        out = ir.Constant(ir.DoubleType(), v);
    } elif isinstance(v, str) {
        out = self._make_global_string(v);
    } elif isinstance(v, bytes) {
        out = self._make_global_bytes(v);
    } elif v is None {
        out = ir.Constant(ir.IntType(8).as_pointer(), None);
    }
    if out is not None and nd.coerce_to is not None {
        return self._lower_coercion(nd, out);
    }
    return out;
}

impl NaIRGenPass._ct_fold(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    import from jaclang.compiler.frontend.constant { ExprCtx }
    if not isinstance(nd, uni.Expr) or nd.ct_value is None {
        return None;
    }
    if isinstance(nd, (uni.Int, uni.Float, uni.Bool, uni.Null, uni.String)) {
        return None;
    }
    if isinstance(nd, uni.NameAtom) and nd.expr_ctx != ExprCtx.LOAD {
        return None;
    }
    par = nd.parent;
    if isinstance(par, uni.FuncCall) and par.target is nd {
        return None;
    }
    if isinstance(par, uni.AtomTrailer) and (par.target is nd or par.right is nd) {
        return None;
    }
    if not self._ct_origin(nd) {
        return None;
    }
    (ok, v) = self._ct_value_with_bindings(nd);
    if not ok {
        return None;
    }
    return self._ct_native_const(v, nd);
}

impl NaIRGenPass._ct_origin(nd: uni.Expr) -> bool {
    if isinstance(nd, uni.FuncCall) {
        if nd.callee_decl is not None and nd.callee_decl.is_comptime {
            return True;
        }
        return isinstance(nd.target, uni.Name) and self._ct_only_name(nd.target);
    }
    if isinstance(nd, uni.AtomTrailer)
        and nd.is_attr
        and isinstance(nd.right, uni.Name) {
        return self._ct_origin(nd.right);
    }
    if not isinstance(nd, uni.Name) {
        return False;
    }
    if nd.sym_name in self._ct_bindings {
        return True;
    }
    sym = nd.sym;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    owner = decl.parent if isinstance(decl, uni.Name) else None;
    if isinstance(owner, uni.ParamVar) {
        return owner.is_comptime;
    }
    if isinstance(owner, uni.Assignment) {
        return owner.is_comptime;
    }
    if isinstance(owner, uni.InForStmt) {
        return owner.is_comptime;
    }
    return False;
}

impl NaIRGenPass._ability_has_ct_params(ability: uni.Ability) -> bool {
    sig = ability.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return False;
    }
    for p in sig.get_parameters() {
        if p.is_comptime {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._solve_ct_args(
    ability: uni.Ability, nd: uni.FuncCall
) -> (dict | None) {
    sig = ability.signature;
    params = sig.get_parameters() if isinstance(sig, uni.FuncSignature) else [];
    positional: list = [];
    kw_map: dict = {};
    for a in (nd.params or []) {
        if isinstance(a, uni.KWPair) {
            if a.key is not None {
                kw_map[a.key.sym_name] = a.value;
            }
        } else {
            positional.append(a);
        }
    }
    out: dict = {};
    for (i, p) in enumerate(params) {
        if not p.is_comptime {
            continue;
        }
        pname = p.name.value;
        chosen = positional[i] if i < len(positional) else kw_map.get(pname);
        if chosen is None {
            chosen = p.value;
        }
        if chosen is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="call argument",
                name=pname,
                help_text=f"comptime parameter '{pname}' has no argument and no default."
            );
            return None;
        }
        (ok, v) = self._ct_value_with_bindings(chosen);
        if not ok {
            self.emit(
                E5092,
                node_override=chosen,
                kind="argument for comptime parameter",
                name=pname,
                help_text="The argument must be known at compile time so the callee can be specialized on it."
            );
            return None;
        }
        out[pname] = v;
    }
    return out;
}

impl NaIRGenPass._bind_ct_target(tgt: uni.UniNode, v: any) -> None {
    if isinstance(tgt, uni.AtomUnit) {
        self._bind_ct_target(tgt.value, v);
        return;
    }
    if isinstance(tgt, uni.Name) {
        self._ct_bindings[tgt.value] = v;
        return;
    }
    if isinstance(tgt, (uni.TupleVal, uni.ListVal)) {
        items = list(v);
        for (i, t) in enumerate(tgt.values) {
            if i < len(items) {
                self._bind_ct_target(t, items[i]);
            }
        }
    }
}

impl NaIRGenPass._instantiate_generic(
    nd: uni.FuncCall, func_name: str
) -> (ir.Function | None) {
    import from jaclang.compiler.types.ct_value { ct_mangle }
    ability = self.generic_fns[func_name];
    solution = self._solve_generic_call(ability, nd);
    if solution is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text="Could not solve this call's type arguments for monomorphization; annotate the arguments with concrete types."
        );
        return None;
    }
    ct_bind = self._solve_ct_args(ability, nd);
    if ct_bind is None {
        return None;
    }
    _mangles: dict = {};
    for (k, v) in solution.items() {
        _mangles[k] = v.mangle() if v?.mangle else "any";
    }
    parts = sorted([f"{k}={m}" for (k, m) in _mangles.items()]);
    parts.extend(sorted([f"ct_{k}={ct_mangle(v)}" for (k, v) in ct_bind.items()]));
    key = func_name + "|" + ",".join(parts);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    import re;
    import hashlib as _mono_hash;
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    _kd = _mono_hash.sha256(key.encode()).hexdigest()[:8];
    spec_name = f"__jac_mono_{func_name}_{safe}_{_kd}";
    saved_sol = self._mono_solution;
    saved_map = self._mono_mangle_map;
    saved_ct = self._ct_bindings;
    self._mono_solution = solution;
    self._mono_mangle_map = _mangles;
    self._ct_bindings = dict(ct_bind);
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
        self._mono_mangle_map = saved_map;
        self._ct_bindings = saved_ct;
    }
    return fn;
}

impl NaIRGenPass._stamp_mono_fn(
    ability: uni.Ability, spec_name: str, memo_key: str
) -> (ir.Function | None) {
    self.ir_in.record_comptime_dependency(ability.loc.mod_path, body=True);
    name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
    sig = ability.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return None;
    }
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }
    ret_type = self._resolve_jac_type(sig.return_type);
    fnty = ir.FunctionType(ret_type, param_types);
    fn = ir.Function(self.llvm_module, fnty, name=spec_name);
    fn.linkage = "private";
    for (i, p) in enumerate(sig.get_parameters()) {
        fn.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self._mono_fns[memo_key] = fn;
    self._record_ret_facts(spec_name, sig);

    saved_symtab = dict(self.func_symtab);
    self.func_symtab[name] = fn;
    try {
        self._codegen_ability(ability);
    } finally {
        self.func_symtab = saved_symtab;
    }
    return fn;
}

impl NaIRGenPass._instantiate_generic_for_target(
    func_name: str, tag_node: uni.UniNode
) -> (ir.Function | None) {
    try {
        import from jaclang.compiler.types.types {
            FunctionType as _A5FnType,
            TypeVarType as _A5TypeVar
        }
    } except ImportError {
        return None;
    }
    tag_t = tag_node.type if isinstance(tag_node, uni.Expr) else None;
    if not isinstance(tag_t, _A5FnType) {
        return None;
    }
    ability = self.generic_fns.get(func_name);
    if ability is None {
        return None;
    }
    sig = ability.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return None;
    }
    _tgt_params = tag_t.parameters or [];
    solution: dict = {};
    for (i, p) in enumerate(sig.get_parameters()) {
        _pt = None;
        if p.type_tag and p.type_tag.tag and isinstance(p.type_tag.tag, uni.Expr) {
            _pt = p.type_tag.tag.type;
        }
        if isinstance(_pt, _A5TypeVar) and i < len(_tgt_params) {
            _sol_t = _tgt_params[i].param_type;
            if _sol_t is not None and _pt.name not in solution {
                solution[_pt.name] = _sol_t;
            }
        }
    }
    _rt = sig.return_type.type if isinstance(sig.return_type, uni.Expr) else None;
    if (
        isinstance(_rt, _A5TypeVar)
        and _rt.name not in solution
        and tag_t.return_type is not None
    ) {
        solution[_rt.name] = tag_t.return_type;
    }
    if not solution {
        return None;
    }
    _mangles: dict = {};
    for (k, v) in solution.items() {
        _mangles[k] = v.mangle() if v?.mangle else "any";
    }
    parts = sorted([f"{k}={m}" for (k, m) in _mangles.items()]);
    key = func_name + "|" + ",".join(parts);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    import re;
    import hashlib as _mono_hash;
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    _kd = _mono_hash.sha256(key.encode()).hexdigest()[:8];
    spec_name = f"__jac_mono_{func_name}_{safe}_{_kd}";
    saved_sol = self._mono_solution;
    saved_map = self._mono_mangle_map;
    self._mono_solution = solution;
    self._mono_mangle_map = _mangles;
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
        self._mono_mangle_map = saved_map;
    }
    return fn;
}

impl NaIRGenPass._instantiate_generic_method(
    nd: uni.FuncCall, owner_arch: str, method_name: str
) -> (ir.Function | None) {
    ability = self._generic_methods[f"{owner_arch}.{method_name}"];
    solution = self._solve_generic_call(ability, nd);
    if not solution {
        self.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{owner_arch}.{method_name}",
            help_text="Could not solve this call's type arguments for monomorphization; annotate the arguments with concrete types."
        );
        return None;
    }
    _mangles: dict = {};
    for (k, v) in solution.items() {
        _mangles[k] = v.mangle() if v?.mangle else "any";
    }
    parts = sorted([f"{k}={m}" for (k, m) in _mangles.items()]);
    key = f"{owner_arch}.{method_name}|" + ",".join(parts);
    _hit = self._mono_fns.get(key);
    if _hit is not None {
        return _hit;
    }
    import re;
    import hashlib as _mono_hash;
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    _kd = _mono_hash.sha256(key.encode()).hexdigest()[:8];
    spec_name = f"__jac_mono_{owner_arch}_{method_name}_{safe}_{_kd}";
    saved_sol = self._mono_solution;
    saved_map = self._mono_mangle_map;
    self._mono_solution = solution;
    self._mono_mangle_map = _mangles;
    try {
        fn = self._stamp_mono_method(ability, owner_arch, method_name, spec_name, key);
    } finally {
        self._mono_solution = saved_sol;
        self._mono_mangle_map = saved_map;
    }
    return fn;
}

impl NaIRGenPass._stamp_mono_method(
    ability: uni.Ability,
    arch_name: str,
    method_name: str,
    spec_name: str,
    memo_key: str
) -> (ir.Function | None) {
    self.ir_in.record_comptime_dependency(ability.loc.mod_path, body=True);
    full_name = f"{arch_name}.{method_name}";
    if full_name in self._native_skipped_methods {
        return None;
    }
    struct_type = self.struct_types.get(arch_name);
    sig = ability.signature;
    if struct_type is None
        or not isinstance(sig, uni.FuncSignature)
        or ability.is_static
        or ability.is_classmethod {
        self.emit(E5092, node_override=ability, kind="method", name=full_name);
        return None;
    }
    param_types: list[ir.Type] = [struct_type.as_pointer()];
    for p in sig.get_parameters() {
        param_types.append(
            self._resolve_jac_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }
    ret_type = self._resolve_jac_type(sig.return_type);
    fnty = ir.FunctionType(ret_type, param_types);
    fn = ir.Function(self.llvm_module, fnty, name=spec_name);
    fn.linkage = "private";
    fn.args[0].name = "self";
    for (i, p) in enumerate(sig.get_parameters()) {
        fn.args[i + 1].name = p.name.value if p.name else f"arg{i}";
    }
    self._mono_fns[memo_key] = fn;

    saved_gen_ctx = self._gen_ctx;
    self._gen_ctx = None;
    _saved_mf = self.method_funcs.get(full_name);
    self.method_funcs[full_name] = fn;
    try {
        self._codegen_method(arch_name, ability);
    } finally {
        if _saved_mf is not None {
            self.method_funcs[full_name] = _saved_mf;
        } else {
            self.method_funcs.pop(full_name, None);
        }
        self._gen_ctx = saved_gen_ctx;
    }
    if full_name in self._native_skipped_methods {
        self._mono_fns.pop(memo_key, None);
        self.llvm_module.globals.pop(fn.name, None);
        return None;
    }
    return fn;
}

impl NaIRGenPass._find_source_ability(
    mod_name: str, func_name: str
) -> (uni.Ability | None) {
    import os;
    import from jaclang.compiler.frontend.codeinfo { resolve_native_module }
    _base = os.path.dirname(self.ir_in.loc.mod_path);
    _clean = mod_name[:-3] if mod_name.endswith(".na") else mod_name;
    (_src, full_path) = resolve_native_module(_clean, _base);
    if full_path is None {
        return None;
    }
    imported_mod = self.prog.mod.hub.get(full_path);
    if imported_mod is None {
        imported_mod = self.prog.mod.hub.get(os.path.abspath(full_path));
    }
    if imported_mod is None and os.path.isfile(full_path) {
        _saved_opts = self.prog.options;
        try {
            imported_mod = self.prog.compile(
                full_path, no_cgen=True, symtab_ir_only=True
            );
        } except Exception {
            imported_mod = None;
        } finally {
            self.prog.options = _saved_opts;
        }
    }
    if imported_mod is not None and self._is_catalog_module(imported_mod) {
        imported_mod = self._full_ast_of(full_path);
    }
    if imported_mod is None {
        return None;
    }
    for stmt in (imported_mod.body or []) {
        if (
            isinstance(stmt, uni.Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name == func_name
            and isinstance(stmt.signature, uni.FuncSignature)
        ) {
            return stmt;
        }
    }
    return None;
}

impl NaIRGenPass._ct_only_name(nd: uni.Name) -> bool {
    sym = nd.sym;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    imp = decl.find_parent_of_type(uni.Import) if isinstance(decl, uni.Name) else None;
    if imp is not None and imp.is_comptime {
        return True;
    }
    mod = nd.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    for imp2 in mod.get_all_sub_nodes(uni.Import) {
        if not imp2.is_comptime {
            continue;
        }
        for item in imp2.items {
            bound = item.alias
                if item.alias is not None
                else (item.name if isinstance(item, uni.ModuleItem) else None);
            if isinstance(bound, uni.Name) and bound.sym_name == nd.sym_name {
                return True;
            }
        }
    }
    return False;
}
