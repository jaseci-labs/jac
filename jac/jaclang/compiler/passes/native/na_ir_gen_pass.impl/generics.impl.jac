"""TypeVar-function monomorphization.

A generic def (`def f[T](...)`) registers as a template in `generic_fns`
and declares no symbol. Each callsite structurally unifies the declared
parameter types against the checker-solved argument types to bind the type
params, then stamps (memoized per solved-type key) a specialized private
copy whose body lowers with the binding active: `_lower_type` substitutes
bound TypeVars and every mangle-driven helper reads through `_mangled_of`,
which rewrites bound TypeVar names inside mangled type keys. No boxing;
the callsite links the specialized copy like any direct call.
"""

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
    args = nd.params or [];
    for (i, p) in enumerate(params) {
        if i >= len(args) {
            break;
        }
        a = args[i];
        if not isinstance(a, uni.Expr) or isinstance(a, uni.KWPair) {
            continue;
        }
        decl_t = p.name.type if p?.name and p.name is not None else None;
        if decl_t is None and p?.type_tag and p.type_tag is not None {
            decl_t = p.type_tag.tag.type if p.type_tag?.tag else None;
        }
        unify(decl_t, a.type);
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
    if self._ability_is_generator(ability) {
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=func_name,
            help_text="Generic generator functions are not monomorphized yet; declare a concrete element type."
        );
        return None;
    }
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
    _errs0 = len(self.errors_had);
    try {
        fn = self._stamp_mono_fn(ability, spec_name);
    } finally {
        self._mono_solution = saved_sol;
        self._mono_mangle_map = saved_map;
    }
    if fn is not None and len(self.errors_had) == _errs0 {
        self._mono_fns[key] = fn;
        return fn;
    }
    return fn;
}

impl NaIRGenPass._stamp_mono_fn(
    ability: uni.Ability, spec_name: str
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
    }
    return fn;
}
