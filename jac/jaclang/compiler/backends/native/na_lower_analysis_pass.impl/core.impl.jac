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

impl NativeLowering._run_impl_capability_demotions -> (
    dict[int, list[tuple[uni.UniNode, str, str, str | None]]] | None
) {
    import from jaclang.compiler.passes.capability_check_pass {
        native_capability_violations,
        partition_native_capability_violations
    }
    _viols = native_capability_violations(self.module);
    if _viols {
        (_fatal_viols, _demotable) = partition_native_capability_violations(_viols);
        if _fatal_viols {
            if not self.module.native_viols_reported {
                _report = list(_fatal_viols);
                for _unit_viols in _demotable.values() {
                    _report.extend(_unit_viols);
                }
                for (_vnode, _vkind, _vname, _vhelp) in _report {
                    self.emit(
                        E5090,
                        node_override=_vnode,
                        kind=_vkind,
                        name=_vname,
                        help_text=_vhelp
                    );
                }
            }
            return None;
        }
        return _demotable;
    }
    return {};
}

impl NativeLowering._run_impl_native_stmts -> list[uni.ElementStmt] {
    return ModuleFacts.iter_context_stmts(self.module, CodeContext.NATIVE);
}

impl NativeLowering._predemote_capability_unit_report(
    viols: list[tuple[uni.UniNode, str, str, str | None]]
) -> int {
    _local_mark = len(self.ctx.errors_had);
    for (_vnode, _vkind, _vname, _vhelp) in viols {
        self.emit(
            E5090, node_override=_vnode, kind=_vkind, name=_vname, help_text=_vhelp
        );
    }
    return _local_mark;
}

impl NativeLowering._register_imported_struct_types_discover -> tuple[
    list[tuple[str, uni.Module]], dict[str | None, list[str]], dict[str, bool]
] {
    import os;
    import from jaclang.compiler.frontend.codeinfo {
        resolve_native_module,
        is_bundled_native_module
    }

    processed_modules: set[str] = set();
    imported_mods: list[tuple[str, uni.Module]] = [];

    entry_base = os.path.dirname(os.path.abspath(self.module.loc.mod_path))
        if (self.module?.loc)
        else os.getcwd();

    _native_ids: set = {
        id(_s) for _s in ModuleFacts.iter_context_stmts(self.module, CodeContext.NATIVE)
    };
    _has_native_code: bool = len(_native_ids) > 0;
    _nested_native = ModuleFacts.iter_nested_imports(self.module, CodeContext.NATIVE);
    for _nested_imp in _nested_native {
        _native_ids.add(id(_nested_imp));
    }
    wq: list[tuple[str, str, str | None, bool]] = [];
    for imp in ModuleFacts.iter_module_imports(self.module) + _nested_native {
        mod_name = self._extract_import_module_name(imp);
        if not mod_name {
            continue;
        }
        if (not imp.from_loc) and (not imp.is_absorb) {
            if not _has_native_code {
                continue;
            }
            if not is_bundled_native_module(mod_name) {
                _item0 = next(
                    (
                        i
                        for i in imp.items
                        if isinstance(i, uni.ModulePath)
                    ),
                    None
                );
                if (
                    id(imp) not in _native_ids
                    or _item0 is None
                    or resolve_native_module(mod_name, entry_base)[1] is None
                ) {
                    continue;
                }
            }
        }
        wq.append((mod_name, entry_base, None, bool(imp.is_typed)));
    }

    _self_key = (
        os.path.realpath(self.module.loc.mod_path) if (self.module?.loc) else None
    );

    _canon_src: dict[str, any] = {};
    dep_edges: dict[str | None, list[str]] = {};
    typed_only: dict[str, bool] = {};
    qi = 0;
    while qi < len(wq) {
        (mod_name, cur_base, parent_key, typed) = wq[qi];
        qi += 1;
        assert mod_name is not None;
        (src_mod_str, full_path) = resolve_native_module(mod_name, cur_base);
        if src_mod_str is None or full_path is None {
            continue;
        }
        if _self_key is not None and os.path.realpath(full_path) == _self_key {
            continue;
        }
        abs_key = os.path.abspath(full_path);
        if parent_key in dep_edges {
            dep_edges[parent_key].append(abs_key);
        } else {
            dep_edges[parent_key] = [abs_key];
        }
        typed_only[abs_key] = typed and typed_only.get(abs_key, True);
        if abs_key in processed_modules {
            continue;
        }

        imported_mod = self.prog.mod.hub.get(full_path);
        if imported_mod is None {
            imported_mod = self.prog.mod.hub.get(abs_key);
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
            import from jaclang.compiler.driver.compile_options { env_na_debug }
            if env_na_debug() {
                import sys as _ti_sys;
                _ti_sys.stderr.write(
                    f"NA_DEBUG typed import {full_path} has no AST in {self.module.loc.mod_path}\n"
                );
            }
            continue;
        }
        self._ensure_dep_inference(imported_mod);
        processed_modules.add(abs_key);
        _canon_src[abs_key] = src_mod_str;
        imported_mods.append((src_mod_str, imported_mod));
        import from jaclang.compiler.driver.compile_options { env_na_debug as _ti_dbg }
        if _ti_dbg() {
            import sys as _ti_sys2;
            _n_arch = sum(
                1
                for _st in ModuleFacts.iter_context_stmts(imported_mod)
                if isinstance(_st, uni.Archetype)
            );
            _ti_sys2.stderr.write(
                f"NA_DEBUG typed walk {os.path.basename(self.module.loc.mod_path)} <- "
                f"{os.path.basename(abs_key)} {type(imported_mod).__name__} "
                f"body={len(imported_mod.body)} archetypes={_n_arch} "
                f"codespace={imported_mod.decided_codespace} typed_only={typed}\n"
            );
        }

        sub_base = os.path.dirname(os.path.abspath(full_path));
        for sub_imp in ModuleFacts.iter_module_imports(imported_mod)
            + ModuleFacts.iter_nested_imports(imported_mod, CodeContext.NATIVE) {
            sub_name = self._extract_import_module_name(sub_imp);
            if sub_name {
                wq.append(
                    (sub_name, sub_base, abs_key, typed or bool(sub_imp.is_typed))
                );
            }
        }
    }

    self._foreign_modules = [m for (_s, m) in imported_mods];
    return (imported_mods, dep_edges, typed_only);
}

impl NativeLowering._register_imported_struct_types_note_deps(
    dep_edges: dict[str | None, list[str]], typed_only: dict[str, bool]
) -> None {
    _dep_seen: set[str] = set();
    _dep_todo: list[str] = list(dep_edges.get(None, []));
    while _dep_todo {
        _direct = _dep_todo.pop(0);
        if _direct in _dep_seen {
            continue;
        }
        _dep_seen.add(_direct);
        if typed_only.get(_direct, False) {
            import from jaclang.compiler.placement.placement_facts {
                native_unit as _typed_native_unit
            }
            import from jaclang.compiler.frontend.codeinfo {
                native_unit_compile_active as _typed_nuc
            }
            if _typed_native_unit(_direct, _typed_nuc()) {
                self._note_native_dep(_direct);
            }
            continue;
        }
        _direct_mod = self.prog.mod.hub.get(_direct);
        _has_own_code = (
            _direct_mod is None
            or self._is_catalog_module(_direct_mod)
            or any(
                not isinstance(s, uni.Import)
                for s in ModuleFacts.iter_context_stmts(_direct_mod)
            )
        );
        if _has_own_code {
            self._note_native_dep(_direct);
        } else {
            """A module made only of imports and includes is a re-export
            surface: the units behind it are what this module links to.""";
            _dep_todo.extend(dep_edges.get(_direct, []));
        }
    }
}

impl NativeLowering._walk_imported_module_stmts(
    imported_mod: uni.Module
) -> list[uni.ElementStmt] {
    return ModuleFacts.iter_context_stmts(imported_mod);
}

impl NativeLowering._walk_imported_module_skips(stmt: uni.UniNode) -> bool {
    if (
        isinstance(stmt, uni.ContextAwareNode)
        and stmt.code_context == CodeContext.CLIENT
        and not stmt.codespace_dual
    ) {
        return True;
    }
    return False;
}

impl NativeLowering._walk_imported_module_types_note_osp(
    stmt: uni.Archetype, imported_mod: uni.Module
) -> None {
    _aname = self._arch_key(stmt) if stmt.name else None;
    if (_aname is not None) and (stmt.arch_kind is not None) {
        self.imported_osp_archs[_aname] = (stmt.arch_kind, imported_mod.name);
    }
}

impl NativeLowering._walk_imported_module_abilities_verdicts(
    imported_mod: uni.Module, with_fn_verdicts: bool
) -> tuple[any, bool, (set | None)] {
    _imp_iface = self._dep_iface(imported_mod);
    _imp_layout = _imp_iface.layout if _imp_iface is not None else None;
    if _imp_layout is None {
        _imp_layout = imported_mod.gen.native_layout;
    }
    if _imp_layout is None and imported_mod?.loc and imported_mod.loc.mod_path {
        import os as _wl_os;
        _wl_raw = imported_mod.loc.mod_path;
        for _wl_key in (
            _wl_raw,
            _wl_os.path.abspath(_wl_raw),
            _wl_os.path.realpath(_wl_raw)
        ) {
            _wl_slim = self.prog.hub.artifacts.get(_wl_key);
            if _wl_slim is not None and _wl_slim.native_layout is not None {
                _imp_layout = _wl_slim.native_layout;
                break;
            }
        }
    }

    _wl_internal = False;
    if _imp_layout is None and imported_mod?.loc and imported_mod.loc.mod_path {
        import os as _wl_os2;

        _wl_abs = _wl_os2.path.abspath(imported_mod.loc.mod_path);
        _wl_jac_internal = not self.prog.options.native_required_for(_wl_abs)
            and imported_mod.decided_codespace != 'native'
            and (_wl_os2.sep + "jaclang" + _wl_os2.sep) in _wl_abs
            and (_wl_os2.sep + "na_stdlib" + _wl_os2.sep) not in _wl_abs;
        if _wl_jac_internal {
            try {
                import from jaclang.jac0core { sealed as _wl_sealed }
                _wl_internal = _wl_sealed._jaclang_image() is not None;
            } except Exception {
                _wl_internal = False;
            }
        }
    }
    _imp_fn_unavail: (set | None) = None;
    if with_fn_verdicts {
        _imp_fn_unavail = self._imported_function_demotions(imported_mod);
    }
    return (_imp_layout, _wl_internal, _imp_fn_unavail);
}

impl NativeLowering._walk_imported_module_abilities_skipped(
    imported_mod: uni.Module,
    _imp_layout: any,
    _wl_internal: bool,
    _imp_fn_unavail: (set | None)
) -> list[str] {
    out: list[str] = [];
    for _imp_arch in ModuleFacts.iter_context_stmts(imported_mod) {
        if not isinstance(_imp_arch, uni.Archetype)
            or _imp_arch.body is None
            or _imp_arch.name is None {
            continue;
        }
        _ia_name = self._arch_key(_imp_arch);
        for _imp_stmt in _imp_arch.body {
            if (
                isinstance(_imp_stmt, uni.Ability)
                and _imp_stmt.name_ref
                and isinstance(_imp_stmt.signature, uni.FuncSignature)
            ) {
                _im_full = f"{_ia_name}.{_imp_stmt.name_ref.sym_name}";
                if (
                    _imp_layout is not None
                    and _im_full not in _imp_layout.methods
                    and not _imp_stmt.type_params
                )
                    or (_imp_layout is None and _wl_internal)
                    or (_imp_fn_unavail is not None and _im_full in _imp_fn_unavail) {
                    out.append(_im_full);
                }
            }
        }

        for (_ia_slot, _ia_var, _ia_acc) in archetype_accessors(_imp_arch) {
            _im_full = f"{_ia_name}.{_ia_slot}";
            if (_imp_layout is not None and _im_full not in _imp_layout.methods)
                or (_imp_layout is None and _wl_internal) {
                out.append(_im_full);
            }
        }
    }
    return out;
}

impl NativeLowering._register_imported_globals_symbol(
    nd: uni.GlobalVars, var_name: str
) -> str {
    _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
    _owner = nd.find_parent_of_type(uni.Module);
    return self._symbol_for(var_name, _owner, _is_pub);
}

impl NativeLowering._forward_declare_imported_ability_demoted(
    nd: uni.Ability, name: str, unavailable: (set | None), imp_layout: any
) -> (bool | None) {
    if nd.body is None {
        return None;
    }
    if bool(nd.access and nd.access.tag.name == Tok.KW_PRIV) {
        """A private function of another module is not callable from here;
        it neither declares nor marks its name as demoted.""";
        return None;
    }
    if not nd.type_params {
        _fd_demoted = (unavailable is not None and name in unavailable)
            or (
                imp_layout is not None
                and not name.startswith("__")
                and name not in imp_layout.functions
            );
        if _fd_demoted {
            return True;
        }
    }
    return False;
}

impl NativeLowering._process_clib_imports_stmts(module: uni.Module) -> list[uni.Import] {
    return ModuleFacts.iter_module_imports(module)
        + ModuleFacts.iter_nested_imports(module, CodeContext.NATIVE);
}

impl NativeLowering._process_clib_imports_note_modules(
    stmt: uni.Import, module: uni.Module
) -> None {
    if stmt.items {
        for item in stmt.items {
            import os;
            import from jaclang.compiler.passes.capability_check_pass {
                classify_native_import
            }
            import from jaclang.compiler.frontend.codeinfo {
                is_bundled_native_module,
                resolve_native_module
            }
            (mod_name, _supported) = classify_native_import(item);
            if _supported and mod_name is not None {
                self._native_stdlib_modules.add(mod_name);
                if is_bundled_native_module(mod_name) {
                    self._native_module_imports.add(mod_name);
                }
            } elif mod_name is not None
                and is_bundled_native_module(mod_name) {
                self._native_module_imports.add(mod_name);
            } elif (
                mod_name is not None
                and not stmt.is_absorb
                and isinstance(item, uni.ModulePath)
            ) {
                _mb = os.path.dirname(os.path.abspath(module.loc.mod_path))
                    if module?.loc
                    else '.';
                if resolve_native_module(mod_name, _mb)[1] is not None {
                    self._native_module_imports.add(mod_name);
                }
            }
        }
    }
}

impl NativeLowering._process_clib_imports_lib_parts(
    stmt: uni.Import
) -> tuple[list[str], list[str]] {
    _raw_paths: list[str] = [];
    _name_components: list[str] = [];
    if stmt.from_loc is not None and stmt.from_loc.path {
        for path_part in stmt.from_loc.path {
            if isinstance(path_part, uni.String) {
                raw = path_part.value;

                if (len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'") {
                    raw = raw[1:-1];
                }

                _raw_paths.append(raw);
            } elif isinstance(path_part, uni.Name) {
                _name_components.append(path_part.value);
            }
        }
    }
    return (_raw_paths, _name_components);
}

impl NativeLowering._process_clib_imports_has_body(decl: uni.Ability) -> bool {
    _is_empty_list = isinstance(decl.body, list) and not decl.body;
    return decl.body is not None and not _is_empty_list;
}

impl NativeLowering._ensure_emitters_items -> list[tuple[str, str]] {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    return JAC_TYPE_REGISTRY.emitter_items();
}

impl NativeLowering._dispatch_builtin_takes_kwargs(func_name: str) -> bool {
    return func_name in ("sorted", "min", "max");
}
