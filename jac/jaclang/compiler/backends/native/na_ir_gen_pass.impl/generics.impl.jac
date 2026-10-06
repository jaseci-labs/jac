import from jaclang.compiler.passes.layout_pass { native_type_key }

impl NaIRGenPass._ct_native_const(v: CtValue, nd: uni.Expr) -> (ir.Value | None) {
    out: (ir.Value | None) = None;
    if isinstance(v, CtBool) {
        out = ir.Constant(ir.IntType(1), 1 if v.value else 0);
    } elif isinstance(v, CtInt) {
        if v.mag {
            return None;
        }
        out = ir.Constant(ir.IntType(64), v.small);
    } elif isinstance(v, CtFloat) {
        out = ir.Constant(ir.DoubleType(), v.value);
    } elif isinstance(v, CtStr) {
        out = self._make_global_string(v.value);
    } elif isinstance(v, CtBytes) {
        out = self._make_global_bytes(v.value);
    } elif isinstance(v, CtNone) {
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
    if not self.lower._ct_origin(nd) {
        return None;
    }
    (ok, v) = self.lower._ct_value_with_bindings(nd);
    if not ok or v is None {
        return None;
    }
    return self._ct_native_const(v, nd);
}

impl NaIRGenPass._instantiate_generic(
    nd: uni.FuncCall, func_name: str
) -> (ir.Function | None) {
    ability = self.generic_fns[func_name];
    solution = self.lower._solve_generic_call(ability, nd);
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
    ct_bind = self.lower._solve_ct_args(ability, nd);
    if ct_bind is None {
        return None;
    }
    _mangles: dict[str, str] = {};
    for (k, v) in solution.items() {
        _mangles[k] = native_type_key(v) if v?.mangle else "any";
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
    saved_sol = self.lower._mono_solution;
    saved_map = self.lower._mono_mangle_map;
    saved_ct = self.lower._ct_bindings;
    self.lower._mono_solution = solution;
    self.lower._mono_mangle_map = _mangles;
    self.lower._ct_bindings = dict(ct_bind);
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self.lower._mono_solution = saved_sol;
        self.lower._mono_mangle_map = saved_map;
        self.lower._ct_bindings = saved_ct;
    }
    return fn;
}

impl NaIRGenPass._stamp_mono_fn(
    ability: uni.Ability, spec_name: str, memo_key: str
) -> (ir.Function | None) {
    self.lower._record_generic_definition(ability);
    name = ability.name_ref.sym_name if ability.name_ref else "unnamed";
    sig = ability.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return None;
    }
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        param_types.append(self._resolve_jac_type(p));
    }
    ret_type = self._resolve_jac_type(sig.return_type);
    fnty = ir.FunctionType(ret_type, param_types);
    fn = ir.Function(self.llvm_module, fnty, name=spec_name);
    fn.linkage = "private";
    for (i, p) in enumerate(sig.get_parameters()) {
        fn.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self._mono_fns[memo_key] = fn;
    self.lower._record_ret_facts(spec_name, sig);

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
    _tgt_params: list[Parameter] = tag_t.parameters or [];
    solution: dict[str, TypeBase] = {};
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
    _mangles: dict[str, str] = {};
    for (k, v) in solution.items() {
        _mangles[k] = native_type_key(v) if v?.mangle else "any";
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
    saved_sol = self.lower._mono_solution;
    saved_map = self.lower._mono_mangle_map;
    self.lower._mono_solution = solution;
    self.lower._mono_mangle_map = _mangles;
    try {
        fn = self._stamp_mono_fn(ability, spec_name, key);
    } finally {
        self.lower._mono_solution = saved_sol;
        self.lower._mono_mangle_map = saved_map;
    }
    return fn;
}

impl NaIRGenPass._instantiate_generic_method(
    nd: uni.FuncCall, owner_arch: str, method_name: str
) -> (ir.Function | None) {
    ability = self._generic_methods[f"{owner_arch}.{method_name}"];
    solution = self.lower._solve_generic_call(ability, nd);
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
    _mangles: dict[str, str] = {};
    for (k, v) in solution.items() {
        _mangles[k] = native_type_key(v) if v?.mangle else "any";
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
    saved_sol = self.lower._mono_solution;
    saved_map = self.lower._mono_mangle_map;
    self.lower._mono_solution = solution;
    self.lower._mono_mangle_map = _mangles;
    try {
        fn = self._stamp_mono_method(ability, owner_arch, method_name, spec_name, key);
    } finally {
        self.lower._mono_solution = saved_sol;
        self.lower._mono_mangle_map = saved_map;
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
    self.lower._record_generic_definition(ability);
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
        param_types.append(self._resolve_jac_type(p));
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

