import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
impl take_native_lowering(
    module: uni.Module, prog: JacProgram, ctx: CompileContext
) -> NativeLowering {
    found = _READY.pop(id(module), None);
    if found is None or found.module is not module {
        found = NativeLowering(module=module, prog=prog, ctx=ctx);
    }
    found.ctx = ctx;
    return found;
}

impl NaLowerAnalysisPass._run_impl(ir_in: uni.Module) -> uni.Module {
    _READY.clear();
    _READY[id(ir_in)] = NativeLowering(module=ir_in, prog=self.prog, ctx=self.ctx);
    return ir_in;
}

impl NaLowerAnalysisPass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
}

impl NativeLowering._own_prefix -> str {
    return self._unit_prefix;
}

impl NativeLowering._prefix_of_path(path: str) -> str {
    found = self._unit_prefixes.get(path);
    if found is None {
        import os as _pp_os;
        import from jaclang.compiler.frontend.codeinfo { native_unit_prefix }
        found = native_unit_prefix(_pp_os.path.realpath(path));
        self._unit_prefixes[path] = found;
    }
    return found;
}

impl NativeLowering._prefix_of_module(mod: (uni.Module | None)) -> str {
    if mod is None or mod is self.module or not (mod?.loc and mod.loc.mod_path) {
        return self._own_prefix();
    }
    return self._prefix_of_path(mod.loc.mod_path);
}

impl NativeLowering._symbol_for(
    name: str, owner: (uni.Module | None) = None, is_pub: bool = False
) -> str {
    import from jaclang.compiler.frontend.codeinfo {
        native_def_symbol,
        native_symbol_name,
        native_unit_identity,
        native_unit_spelling
    }
    module = owner if owner is not None else self.module;
    name = native_unit_spelling(name, module.loc.mod_path);
    bundled_library = native_unit_identity(module.loc.mod_path).startswith(
        "jaclang/runtime/na_stdlib/"
    );
    if is_pub and not bundled_library {
        return native_def_symbol(name);
    }
    return native_symbol_name(self._prefix_of_module(owner), name);
}

impl NativeLowering._record_export(
    name: str, symbol: str, kind: str, is_pub: bool = False
) -> None {
    self._unit_exports[name] = NativeExport(
        name=name, symbol=symbol, kind=kind, is_pub=is_pub
    );
    if is_pub {
        self._pub_symbols.add(symbol);
    }
}

impl NativeLowering._note_native_dep(path: str) -> None {
    import os as _nd_os;
    real = _nd_os.path.realpath(path);
    own_path = _nd_os.path.realpath(self.module.loc.mod_path)
        if self.module?.loc
        else "";
    if real == own_path or real in self._native_dep_paths {
        return;
    }
    self._native_dep_paths.append(real);
}

impl NativeLowering._is_catalog_module(mod: uni.Module) -> bool {
    return mod?.cat_id is not None;
}

impl NativeLowering._full_ast_of(full_path: str) -> (uni.Module | None) {
    import os as _fa_os;
    key = _fa_os.path.realpath(full_path);
    found = self._full_ast_cache.get(key);
    if found is not None {
        return found;
    }
    try {
        mod = self.prog.load_dependency_module(key, need_tree=True);
    } except Exception as exc {
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if env_na_debug() {
            import sys as _fa_sys;
            _fa_sys.stderr.write(
                f"NA_DEBUG full AST of {key} raised {type(exc).__name__}: {exc}\n"
            );
        }
        return None;
    }
    if mod is None or self._is_catalog_module(mod) {
        import from jaclang.compiler.driver.compile_options { env_na_debug }
        if env_na_debug() {
            import sys as _fa_sys;
            _fa_sys.stderr.write(
                f"NA_DEBUG full AST of {key} unavailable ({type(mod).__name__})\n"
            );
        }
        return None;
    }
    self._full_ast_cache[key] = mod;
    return mod;
}

impl NativeLowering._dep_iface(imported_mod: uni.Module) -> (NativeIface | None) {
    if not (imported_mod?.loc and imported_mod.loc.mod_path) {
        return None;
    }
    path = imported_mod.loc.mod_path;
    if not self._dep_is_native_unit(imported_mod, path) {
        return None;
    }
    opts = self.prog.options;
    if opts.no_ir_cache and not os.path.isfile(self.module.loc.mod_path or "") {
        import copy;
        opts = copy.copy(opts);
        opts.no_ir_cache = False;
    }
    ent = self.prog.native_units().ensure(
        path,
        compile_on_miss=True,
        options=opts,
        check_deps=False,
        products=not opts.no_cgen
    );
    return ent.iface if ent is not None else None;
}

impl NativeLowering._dep_is_native_unit(imported_mod: uni.Module, path: str) -> bool {
    """Only a dependency that placement makes native has products to consult.
    Lowering any other import on a cache miss would compile the Python
    lane's modules as native units, once per consumer.""";
    if imported_mod.gen.native_iface is not None
        or imported_mod.decided_codespace == 'native' {
        return True;
    }
    import from jaclang.compiler.placement.placement_facts { native_unit }
    return native_unit(path, self.prog.options.native_unit, self.prog);
}

impl NativeLowering._load_native_unit_module(path: str) -> (uni.Module | None) {
    import os as _lu_os;
    real = _lu_os.path.realpath(path);
    found = self.prog.mod.hub.get(real);
    if found is not None and found.decided_codespace == 'native' {
        return found;
    }
    if not _lu_os.path.isfile(real) {
        return None;
    }
    import from jaclang.compiler.driver.compile_options { CompileOptions as _UnitOpts }
    saved = self.prog.options;
    try {
        return self.prog.compile(
            real,
            options=_UnitOpts(
                no_cgen=True,
                symtab_ir_only=True,
                aot_mode=True,
                default_codespace='native',
                force_codespace='native',
                native_unit=True
            )
        );
    } finally {
        self.prog.options = saved;
    }
}

impl NativeLowering._is_kernel_unit -> bool {
    import from jaclang.compiler.frontend.codeinfo { is_kernel_unit_path }
    return bool(self.module?.loc) and is_kernel_unit_path(self.module.loc.mod_path);
}

impl NativeLowering._permuted_walk_order(
    mods: list[tuple[str, uni.Module]]
) -> list[tuple[str, uni.Module]] {
    _spec = self.prog.options.native_module_walk_order or "";
    if not _spec {
        return mods;
    }
    if _spec == "reverse" {
        return list(reversed(mods));
    }
    if _spec.startswith("shuffle:") {
        import random as _wo_random;
        _out = list(mods);
        _wo_random.Random(int(_spec.split(":", 1)[1])).shuffle(_out);
        return _out;
    }
    raise ValueError(f"unknown native_module_walk_order: {_spec!r}");
}

impl NativeLowering._extract_import_module_name(imp: uni.Import) -> (str | None) {
    if imp.clib_decls {
        return None;
    }
    if not imp.from_loc or not isinstance(imp.from_loc, uni.ModulePath) {
        if imp.items {
            for it in imp.items {
                if isinstance(it, uni.ModulePath) and it.path {
                    return '.'.join(getattr(p, 'value', str(p)) for p in it.path);
                }
            }
        }
        return None;
    }

    if imp.clib_decls {
        return None;
    }
    if imp.from_loc.string_path_value is not None {
        return None;
    }
    mod_name = imp.from_loc?.dot_path_str;
    if not mod_name and imp.from_loc?.path and imp.from_loc.path {
        mod_name = '.'.join(getattr(p, 'value', str(p)) for p in imp.from_loc.path);
    }
    return mod_name;
}

impl NativeLowering._register_imported_hierarchy(imported_mod: uni.Module) -> None {
    """An imported module's registry also holds the layouts it took from its
    own imports, and those can be older objects than the ones their defining
    module holds now: a unit's tree is laid out afresh whenever the link plan
    reloads it, while a sibling lowered earlier keeps the layouts it adopted
    then. `_codegen_archetype` reads an archetype's slots from its defining
    module and `adopt_imported_bases` rewrites the object this registry holds,
    so the two must be one object: the defining module's layout replaces any
    copy that reached this registry first.""";
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _imp_reg = get_layout_registry(imported_mod, self.prog);
    _cons_reg = get_layout_registry(self.module, self.prog);
    _owned = set(_imp_reg.local_names) - set(_cons_reg.local_names);
    for (_name, _parents) in _imp_reg.class_parents.items() {
        if _name in _owned
            or _name not in _cons_reg.class_parents
            or (_name in _imp_reg.layouts and _name not in _cons_reg.layouts) {
            _cons_reg.class_parents[_name] = _parents;
        }
    }
    for (_name, _pmods) in _imp_reg.parent_mods.items() {
        if _name in _owned or _name not in _cons_reg.parent_mods {
            _cons_reg.parent_mods[_name] = _pmods;
        }
    }
    for (_name, _mro) in _imp_reg.mro_order.items() {
        _have = _cons_reg.mro_order.get(_name);
        if _name in _owned
            or _have is None
            or (_name in _imp_reg.layouts and _name not in _cons_reg.layouts)
            or len(_mro) > len(_have) {
            _cons_reg.mro_order[_name] = _mro;
        }
    }
    for (_name, _lay) in _imp_reg.layouts.items() {
        if _name in _owned or _name not in _cons_reg.layouts {
            _cons_reg.layouts[_name] = _lay;
        }
    }

    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            _aname = self._arch_key(stmt) if stmt.name else None;
            if (_aname is not None) and (_aname not in self.arch_ast_map) {
                self.arch_ast_map[_aname] = stmt;
            }
        }
    }
}

impl NativeLowering._ensure_dep_inference(dep_mod: uni.Module) -> None {
    if self.prog.analysis.analyses_run.provides(dep_mod, AnalysisFact.TYPE_OF) {
        return;
    }
    import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
    if not require_product(self.prog, dep_mod, CompilationProduct.ANALYSIS) {
        raise RuntimeError(
            f"Native dependency analysis failed: {dep_mod.loc.mod_path}"
        );
    }
}

impl NativeLowering._imported_function_demotions(
    imported_mod: uni.Module
) -> (set | None) {
    if imported_mod.gen.native_iface is not None {
        return set(imported_mod.gen.native_iface.demoted);
    }
    iface = self._dep_iface(imported_mod);
    if iface is not None {
        return set(iface.demoted);
    }
    return None;
}

impl NativeLowering._primitive_method_takes_kwargs(
    type_name: str, method_name: str
) -> bool {
    return (type_name, method_name)
        in {("list", "sort"), ("str", "splitlines"), ("bytes", "decode")};
}

impl NativeLowering._split_call_kwargs(nd: uni.FuncCall) -> dict[str, uni.UniNode] {
    out: dict[str, uni.UniNode] = {};
    for param in (nd.params or []) {
        if isinstance(param, uni.KWPair) and param.key is not None {
            out[param.key.sym_name] = param.value;
        }
    }
    for (ct_name, ct_expr) in self._ct_ctor_slots(nd.target) {
        out[ct_name] = ct_expr;
    }
    return out;
}

impl NativeLowering._ct_ctor_slots(target: uni.UniNode) -> list[tuple[str, uni.UniNode]] {
    out: list[tuple[str, uni.UniNode]] = [];
    if not isinstance(target, uni.AtomTrailer) or target.is_attr {
        return out;
    }
    if not isinstance(target.right, uni.IndexSlice) or target.right.is_range {
        return out;
    }
    t = target.target.type;
    if not isinstance(t, ClassType) {
        return out;
    }
    shared = t.shared;
    if not shared.ct_params {
        return out;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, uni.Archetype) {
        return out;
    }
    s0 = target.right.slices[0] if target.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list[uni.UniNode] = `list(head.values)
        if isinstance(head, uni.TupleVal)
        else ([head] if head else []);
    for (i, tp) in enumerate(arch.type_params or []) {
        if tp.is_comptime and i < len(vals) {
            out.append((tp.name.value, vals[i], ));
        }
    }
    return out;
}
