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
    return m;
}

impl NaIRGenPass._solve_generic_call(
    ability: uni.Ability, nd: uni.FuncCall
) -> (dict | None) {
    try {
        import from jaclang.compiler.type_system.types {
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
    params = sig.get_parameters() if sig is not None else [];
    _ft = ability.name_ref.type if ability.name_ref is not None else None;
    _ft_params = list(_ft.parameters or [])
        if _ft is not None and _ft?.parameters
        else [];
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
    }
    for tp in (ability.type_params or []) {
        tp_name = tp.name.value if tp?.name and tp.name is not None else None;
        if tp_name is not None and tp_name not in solution {
            return None;
        }
    }
    return solution;
}

impl NaIRGenPass._instantiate_generic(
    nd: uni.FuncCall, func_name: str
) -> (ir.Function | None) {
    ability = self.generic_fns[func_name];
    solution = self._solve_generic_call(ability, nd);
    if not solution {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text="Could not solve this call's type arguments for monomorphization; annotate the arguments with concrete types."
        );
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
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    spec_name = f"__jac_mono_{func_name}_{safe}";
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

impl NaIRGenPass._stamp_mono_fn(
    ability: uni.Ability, spec_name: str, memo_key: str
) -> (ir.Function | None) {
    name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
    sig = ability.signature;
    param_types: list = [];
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

    saved_builder = self._builder;
    saved_locals = self.local_vars if self?.local_vars else {};
    saved_param_vars = self.param_vars;
    saved_nogc = self.nogc_stack_vars;
    saved_region = self.region_handle_vars;
    saved_list_struct = self.var_list_elem_struct;
    saved_cell_vars = self.closure_cell_vars;
    saved_cell_handles = self.closure_cell_handles;
    saved_symtab = dict(self.func_symtab);
    saved_gen_ctx = self._gen_ctx;
    self._gen_ctx = None;
    self.func_symtab[name] = fn;
    try {
        self._codegen_ability(ability);
    } finally {
        self._builder = saved_builder;
        self.local_vars = saved_locals;
        self.param_vars = saved_param_vars;
        self.nogc_stack_vars = saved_nogc;
        self.region_handle_vars = saved_region;
        self.var_list_elem_struct = saved_list_struct;
        self.closure_cell_vars = saved_cell_vars;
        self.closure_cell_handles = saved_cell_handles;
        self.func_symtab = saved_symtab;
        self._gen_ctx = saved_gen_ctx;
    }
    return fn;
}

impl NaIRGenPass._instantiate_generic_for_target(
    func_name: str, tag_node: uni.UniNode
) -> (ir.Function | None) {
    try {
        import from jaclang.compiler.type_system.types {
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
    sig = ability.signature if ability is not None else None;
    if sig is None {
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
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    spec_name = f"__jac_mono_{func_name}_{safe}";
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
    safe = re.sub(r"[^0-9A-Za-z_]", "_", "_".join(parts));
    spec_name = f"__jac_mono_{owner_arch}_{method_name}_{safe}";
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
    full_name = f"{arch_name}.{method_name}";
    struct_type = self.struct_types.get(arch_name);
    sig = ability.signature;
    if struct_type is None or sig is None or ability.is_static {
        self.emit(E5092, node_override=ability, kind="method", name=full_name);
        return None;
    }
    param_types: list = [struct_type.as_pointer()];
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
        return None;
    }
    return fn;
}

impl NaIRGenPass._find_source_ability(
    mod_name: str, func_name: str
) -> (uni.Ability | None) {
    import os;
    import from jaclang.jac0core.codeinfo { resolve_native_module }
    _base = os.path.dirname(self.ir_in.loc.mod_path) if self.ir_in?.loc else None;
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
        _saved_opts = self.prog._compile_options;
        try {
            imported_mod = self.prog.compile(
                full_path, no_cgen=True, symtab_ir_only=True
            );
        } except Exception {
            imported_mod = None;
        } finally {
            self.prog._compile_options = _saved_opts;
        }
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
