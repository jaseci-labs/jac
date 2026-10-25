def scalar_llvm_type(`entry: JacTypeEntry) -> ir.Type;

def _source_param_names(func: ir.Function) -> list[str];

def _native_emitter_of(suffix: str) -> (object | None);

impl NaIRGenPass.postinit -> None {
    import os as _ni_os;

    self._imports = ImportedFunctions(lowering=self);
    self.scope.source = self._imports;

    self.loop_links = LoopLinks.of(self.module);

    _ni_opts = self.prog.options;
    self._rc_debug_codegen = bool(_ni_opts.rc_debug_codegen);
    _ni_src: str = self.module.loc.mod_path if self.module.loc else "";
    _ni_mod_name: str = _ni_os.path.basename(_ni_src) if _ni_src else "jac_native";
    self._llvm_module = ir.Module(name=_ni_mod_name, context=ir.Context());
    _ni_target = active_host().native_fact(
        FACT_TARGET, _ni_opts.native_target or ""
    ).split(
        FACT_SEP
    );
    self.llvm_module.data_layout = _ni_target[0];
    self.llvm_module.triple = _ni_target[1];

    self._unit_prefix = native_unit_prefix(_ni_src) if _ni_src else "jac_native";

    if _ni_src and _ni_opts.native_debug {
        _ni_src_dir: str = _ni_os.path.dirname(_ni_os.path.abspath(_ni_src));
        try {
            self.di_file = self.llvm_module.add_debug_info(
                "DIFile", {"filename": _ni_mod_name, "directory": _ni_src_dir}
            );
            self.di_cu = self.llvm_module.add_debug_info(
                "DICompileUnit",
                {
                    "language": ir.DIToken("DW_LANG_C"),
                    "file": self.di_file,
                    "producer": "jac native compiler",
                    "runtimeVersion": 0,
                    "isOptimized": False,
                    "emissionKind": ir.DIToken("FullDebug"),

                },
                is_distinct=True
            );
        } except Exception {
            self.di_file = None;
            self.di_cu = None;
        }
    }

    _byte_ptr = ir.IntType(8).as_pointer();
    self._type_map = {};

    for _scalar in JAC_TYPE_REGISTRY.scalar_entries() {
        if _scalar.name == "str" {
            continue;
        }
        self.type_map[_scalar.name] = scalar_llvm_type(_scalar);
    }
    self.type_map["str"] = (
        _byte_ptr if self._target_is_wasm() else self._str_desc_type()
    );
    self.type_map["LiteralString"] = self.type_map["str"];
    self.type_map["Region"] = _byte_ptr;

    self.type_map["type"] = _byte_ptr;

    self._complex_struct_type = self.llvm_module.context.get_identified_type(
        "JacComplex"
    );
    self.complex_struct_type.set_body(ir.DoubleType(), ir.DoubleType());
    self.type_map["complex"] = self.complex_struct_type.as_pointer();

    self._range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));
    self.type_map["range"] = self.range_struct_type.as_pointer();

    self._slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self._jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));
}

impl NaIRGenPass._run_impl(ir_in: uni.Module) -> uni.Module {
    try {
        self._lower_module();
    } except Exception as _lower_exc {
        self._internal_error(
            self.module,
            "module",
            os.path.basename(self.module.loc.mod_path),
            _lower_exc
        );
    }
    if self._deps_deferred {
        return self.module;
    }
    self._settle_module();
    return self.module;
}

impl NaIRGenPass._static_refusals(owner: uni.UniNode) -> (list[NativeRefusal] | None) {
    if self._legality is None {
        return None;
    }
    return self._legality.units.get(id(owner));
}

impl NaIRGenPass._settle_module -> None {
    if self._internal_errors {
        self.ctx.errors_had.extend(self._internal_errors);
        self._internal_errors = [];
        return;
    }
    refusal = settle_native_module(
        self.module, self.prog, self.ctx.errors_had, self.ctx.warnings_had
    );
    if refusal is not None and self._legality is not None {
        self._legality.refuse_module(refusal);
    }
}

impl NaIRGenPass._internal_error(
    nd: uni.UniNode, kind: str, name: str, exc: Exception, mark: int = 0
) -> None {
    if isinstance(exc, NativeRefused) {
        self.emit(E5092, node_override=nd, kind=kind, name=f"{name} ({exc})");
        return;
    }
    if self._na_debug_on() {
        import sys;
        sys.stderr.write(f"NA_DEBUG raise {name}: {type(exc).__name__}: {exc}\n");
    }
    if len(self.ctx.errors_had) > mark {
        return;
    }
    mark = len(self.ctx.errors_had);
    self.emit(
        E9003,
        node_override=nd,
        kind=kind,
        name=name,
        details=f"{type(exc).__name__}: {exc}"
    );
    self._internal_errors.extend(self.ctx.errors_had[mark:]);
    del self.ctx.errors_had[mark:];
}

impl NaIRGenPass._lower_module -> None {
    self._legality = build_native_legality(self.module, self.prog);
    self._claimed_units = set();
    self._internal_errors = [];
    if self._legality.module {
        if not self.module.native_viols_reported {
            for _refusal in self._legality.module {
                if _refusal.site is not None {
                    self.emit(
                        E5090,
                        node_override=_refusal.site,
                        kind=_refusal.kind,
                        name=_refusal.name,
                        help_text=_refusal.help
                    );
                }
            }
        }
        return;
    }
    if self._defer_missing_deps() {
        self._deps_deferred = True;
        return;
    }
    self._settle_dep_ifaces();

    self._emit_rc_helpers();

    self._process_clib_imports(self.module);

    self._register_enums(self.module);

    self._forward_declare_archetype_names(self.module);

    self._register_imported_struct_types();
    self._declare_pending_clib_globals();
    self._declare_pending_clib_abilities();
    self._declare_clib_definitions();
    self._register_globals(self.module);
    self._register_entry_globals(self.module);

    self._register_enum_methods(self.module, declare=True);
    self._register_archetypes(self.module);
    self._register_enum_methods(self.module, declare=False);

    _entry_nodes: list[uni.ModuleCode] = [];
    for stmt in ModuleFacts.iter_context_stmts(self.module, CodeContext.NATIVE) {
        if (
            isinstance(stmt, uni.Ability)
            and stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature)
        ) {
            self._codegen_ability(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            _entry_nodes.append(stmt);
        } elif isinstance(stmt, uni.Test) {
            self._codegen_test(stmt);
        }
    }
    self._emit_clib_definitions();
    self._emit_clib_data_inits();
    self._propagate_seam_demotions();
    _unclaimed = False;
    for (_ck, _crefusals) in self._legality.units.items() {
        if _ck in self._claimed_units or _ck in self._legality.reached {
            continue;
        }
        for _refusal in _crefusals {
            if _refusal.late or _refusal.site is None {
                continue;
            }
            _unclaimed = True;
            self.emit(
                E5090,
                node_override=_refusal.site,
                kind=_refusal.kind,
                name=_refusal.name,
                help_text=_refusal.help
            );
        }
    }
    if _unclaimed {
        return;
    }
    self._codegen_entry(_entry_nodes);
    self._finalize_trace_lookup();
    self._finish_osp_reclaim_hook();

    if self.has_native_code {
        if self.ctx.errors_had or self._internal_errors {
            return;
        }
        if not self.scope.binds_function("__jac_glob_init") {
            self._emit_glob_init_func();
        }
        self._volatilize_setjmp_locals();
        self._exc_context_cache = {};
        self.module.gen.ir_module = self.llvm_module;
        self.module.gen.llvm_ir = self.llvm_module;
        self.module.gen.native_deps = list(self._native_dep_paths);
        self.module.gen.native_fallbacks = native_fallbacks(
            self._lowering_issues,
            [
                func.name.removesuffix(DEMOTED_SUFFIX)
                for func in self.llvm_module.functions
                if not func.is_declaration and func.name.endswith(DEMOTED_SUFFIX)
            ]
        );

        import os;
        if self.prog.options.rc_stats {
            _rc_total = self.rc_retains_emitted + self.rc_releases_emitted;
            _rc_known = _rc_total + self.rc_ops_elided;
            _rc_pct = (100.0 * self.rc_ops_elided / _rc_known) if _rc_known else 0.0;
            _rc_free = " rc-free" if _rc_total == 0 else "";
            import sys;
            _rc_arena = (
                f" arena={self.rc_region_allocs}" if self.rc_region_allocs else ""
            );
            _rc_stk = (
                f" promoted={self.rc_stack_promotions}"
                    if self.rc_stack_promotions
                    else ""
            );
            sys.stderr.write(
                f"rc-stats [{os.path.basename(self.module.loc.mod_path)}] "
                f"gc={self._gc_mode()} retains={self.rc_retains_emitted} "
                f"releases={self.rc_releases_emitted} "
                f"elided={self.rc_ops_elided} coverage={_rc_pct:.1f}%"
                f"{_rc_stk}{_rc_arena}{_rc_free}\n"
            );
        }
        _ir_dump_path = self.prog.options.dump_ir_path or "";
        if _ir_dump_path {
            with open(_ir_dump_path, "w") as _f {
                _f.write(str(self.llvm_module));
            }
        }

        self._export_native_layout();
        self._export_native_iface();
    }
}

impl NaIRGenPass._record_lowering_issue(issue: NativeLoweringIssue) -> None {
    self._lowering_issues.append(issue);
    issue.record(self.llvm_module);
}

impl NaIRGenPass._glob_init_symbols -> tuple[list[str], list[str]] {
    computed: list[str] = [];
    for init_tuple in self._global_init_nodes {
        global_var = self.global_vars.get(init_tuple[0]);
        if global_var is not None and global_var.name not in computed {
            computed.append(global_var.name);
        }
    }
    reads: list[str] = [];
    init_fn = self.scope.function("__jac_glob_init");
    if isinstance(init_fn, ir.Function) {
        for block in init_fn.blocks {
            for instr in block.instructions {
                if not isinstance(instr, ir.Instruction) {
                    continue;
                }
                for operand in instr.operands {
                    if isinstance(operand, ir.GlobalVariable)
                        and operand.initializer is None
                        and operand.name not in reads {
                        reads.append(operand.name);
                    }
                }
            }
        }
    }
    return (computed, reads);
}

impl NaIRGenPass._export_native_iface -> None {
    import os as _ni_os;

    mod_path = self.module.loc.mod_path if self.module?.loc else "";
    iface = NativeIface(
        module=native_module_key(mod_path) if mod_path else "",
        prefix=self._own_prefix(),
        headerless=self._nogc_headerless()
    );
    layout = self.module.gen.native_layout;
    iface.layout = layout;
    for (name, ex) in self._unit_exports.items() {
        sig: (NativeFuncLayout | None) = None;
        if layout is not None {
            sig = layout.functions.get(name) or layout.methods.get(name);
        }
        if sig is not None {
            ex.param_types = list(sig.param_types);
            ex.param_names = list(sig.param_names);
            ex.ret_type = sig.ret_type;
        }
        fn = self.scope.function(name);
        if isinstance(fn, ir.Function) {
            decl = self._linked_callee_decl(fn);
            if decl is not None and isinstance(decl.signature, uni.FuncSignature) {
                import json;
                ex.param_defaults = [
                    json.dumps(
                        [
                            [tok.name, tok.value]
                            for tok in p.value.flatten()
                            if isinstance(tok, uni.Token)
                        ]
                    )
                        if p.value is not None
                        else "" for p in decl.signature.get_parameters()
                ];
            }
            _borrowed = self.borrow_param_args.get(fn.name, set());
            ex.ownership = [
                "borrow" if i in _borrowed else "own" for i in range(len(fn.args))
            ];
        }
        spelled = native_unit_spelling(name, mod_path);
        ex.name = spelled;
        iface.exports[spelled] = ex;
    }
    import json;
    for (cname, native_body) in self._build_class_layouts().items() {
        body: dict[str, any] = json.loads(
            native_unit_spelling(json.dumps(native_body), mod_path)
        );
        _raw_fields: dict[str, any] = body.get("fields", {});
        _field_slots: dict[str, NativeFieldSlot] = {};
        for (fname, fd) in _raw_fields.items() {
            _field_slots[fname] = NativeFieldSlot.from_dict(fd);
        }
        _raw_bases: list[any] = body.get("bases", []);
        _raw_vtable: list[any] = body.get("vtable", []);
        iface.classes[native_unit_spelling(cname, mod_path)] = NativeClassLayout(
            name=cname,
            size=int(body.get("size", 0)),
            tag=int(body.get("tag", 0)),
            tag_offset=int(body.get("tag_offset", -1)),
            fields=_field_slots,
            bases=[str(_b) for _b in _raw_bases],
            vtable=[str(_v) for _v in _raw_vtable],
            is_node=bool(body.get("is_node", False))
        );
    }
    for (ename, members) in self.enum_string_values.items() {
        if self._enum_source_name.get(ename, self.module.name) == self.module.name {
            iface.enums[ename] = [str(m) for m in members];
        }
    }
    if self.scope.binds_function("__jac_glob_init") and mod_path {
        iface.init_symbol = native_glob_init_name(mod_path);
    }
    entry_fn = self.scope.function("jac_entry");
    if entry_fn is not None {
        iface.entry_symbol = str(entry_fn.name);
    }
    iface.demoted = sorted(
        self._demoted_names | {issue.symbol for issue in self._lowering_issues}
    );
    iface.clib_paths = list(self.module.gen._clib_paths or []);
    iface.python_imports = [
        binding.name for binding in self.module.gen.interop_manifest.native_imports
    ];
    iface.clib_symbol_lib = dict(self.module.gen._clib_symbol_lib or {});
    iface.deps = list(self._native_dep_paths);
    init_symbols = self._glob_init_symbols();
    iface.runtime_globals = init_symbols[0];
    iface.init_reads = init_symbols[1];
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_capture }
        iface.coverage = na_coverage_capture(mod_path) if mod_path else {};
    } except Exception {
        iface.coverage = {};
    }
    self.module.gen.native_iface = iface;
    self.module.gen.native_deps = list(self._native_dep_paths);
}

impl NaIRGenPass._build_class_layouts -> dict[str, any] {
    _classes: dict[str, any] = self._build_jc_layout().get("classes", {});
    return dict(_classes);
}

impl NaIRGenPass._own_prefix -> str {
    return self._unit_prefix;
}

impl NaIRGenPass._prefix_of_path(path: str) -> str {
    found = self._unit_prefixes.get(path);
    if found is None {
        import os as _pp_os;
        import from jaclang.compiler.frontend.codeinfo { native_unit_prefix }
        found = native_unit_prefix(real_path(path));
        self._unit_prefixes[path] = found;
    }
    return found;
}

impl NaIRGenPass._prefix_of_module(mod: (uni.Module | None)) -> str {
    if mod is None or mod is self.module or not (mod?.loc and mod.loc.mod_path) {
        return self._own_prefix();
    }
    return self._prefix_of_path(mod.loc.mod_path);
}

impl NaIRGenPass._symbol_for(
    name: str, owner: (uni.Module | None) = None, is_pub: bool = False
) -> str {
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

impl NaIRGenPass._record_export(
    name: str, symbol: str, kind: str, is_pub: bool = False
) -> None {
    self._unit_exports[name] = NativeExport(
        name=name, symbol=symbol, kind=kind, is_pub=is_pub
    );
    if is_pub {
        self._pub_symbols.add(symbol);
    }
}

impl NaIRGenPass._note_native_dep(path: str) -> None {
    import os as _nd_os;
    real = real_path(path);
    own_path = real_path(self.module.loc.mod_path) if self.module?.loc else "";
    if real == own_path or real in self._native_dep_paths {
        return;
    }
    self._native_dep_paths.append(real);
}

impl NaIRGenPass._is_catalog_module(mod: uni.Module) -> bool {
    return mod?.cat_id is not None;
}

impl NaIRGenPass._full_ast_of(full_path: str) -> (uni.Module | None) {
    import os as _fa_os;
    key = real_path(full_path);
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

impl NaIRGenPass._dep_iface(imported_mod: uni.Module) -> (NativeIface | None) {
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
    return active_host().native_dep_iface(self.prog, path, opts);
}

impl NaIRGenPass._defer_missing_deps -> bool {
    if not active_host().native_dep_discovery_open(self.prog) {
        return False;
    }
    imported_mods = self._native_imports(transitive=False);
    for (_, imported_mod) in imported_mods {
        self._dep_iface(imported_mod);
    }
    self._discover_kernel_deps(imported_mods);
    return active_host().native_deps_deferred(self.prog);
}

impl NaIRGenPass._settle_dep_ifaces -> None {
    for (_, imported_mod) in self._native_imports() {
        self._dep_iface(imported_mod);
    }
}

impl NaIRGenPass._discover_kernel_deps(
    imported_mods: list[tuple[str, uni.Module]]
) -> None {
    rels: list[str] = [];
    wants_fmt = any(
        fv.format_spec is not None
        for fv in self.module.get_all_sub_nodes(uni.FormattedValue)
    );
    fmt_methods = {"hex", "fromhex", "join", "lower", "upper", "split"};
    for call in self.module.get_all_sub_nodes(uni.FuncCall) {
        if wants_fmt {
            break;
        }
        target = call.target;
        if isinstance(target, uni.Name) {
            wants_fmt = target.sym_name == "int";
        } elif isinstance(target, uni.AtomTrailer)
            and isinstance(target.right, uni.Name) {
            wants_fmt = target.right.sym_name in fmt_methods;
        }
    }
    if wants_fmt {
        rels.append(FMT_KERNEL_REL);
    }
    uses_osp = any(
        arch.arch_kind is not None and arch.arch_kind in ("node", "edge", "walker")
        for arch in self.module.get_all_sub_nodes(uni.Archetype)
    );
    for (_, imported_mod) in imported_mods {
        if uses_osp {
            break;
        }
        for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.CLIENT
                and not stmt.codespace_dual
            ) {
                continue;
            }
            if isinstance(stmt, uni.Archetype)
                and stmt.name is not None
                and stmt.arch_kind is not None {
                uses_osp = True;
                break;
            }
        }
    }
    if uses_osp {
        rels.extend([OSP_KERNEL_REL, OSP_GRAPH_REL]);
    }
    this_path = real_path(self.module.loc.mod_path or "");
    for rel in rels {
        path = kernel_unit_path(rel);
        if real_path(path) == this_path {
            continue;
        }
        unit = self._load_native_unit_module(path);
        if unit is not None {
            self._dep_iface(unit);
        }
    }
}

impl NaIRGenPass._dep_is_native_unit(imported_mod: uni.Module, path: str) -> bool {
    import os;
    if imported_mod.gen.native_iface is not None
        or imported_mod.decided_codespace == 'native'
        or real_path(path) in self._native_dep_paths {
        return True;
    }

    return native_unit(path, self.prog.options.native_unit, self.prog);
}

impl NaIRGenPass._load_native_unit_module(path: str) -> (uni.Module | None) {
    import os as _lu_os;
    real = real_path(path);
    found = self.prog.mod.hub.get(real);
    if found is not None and found.decided_codespace == 'native' {
        return found;
    }
    if not _lu_os.path.isfile(real) {
        return None;
    }

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

impl NaIRGenPass._is_kernel_unit -> bool {
    return bool(self.module?.loc) and is_kernel_unit_path(self.module.loc.mod_path);
}

impl NaIRGenPass._stub_refused_unit(
    full_name: str,
    func: ir.Function,
    refusals: list[NativeRefusal],
    keep_func: bool = False
) -> bool {
    if not refusals {
        return False;
    }
    if self.prog.options.native_required_for(self.module.loc.mod_path)
        or (
            self._lacks_python_body(full_name) and not self._owner_required(full_name)
        ) {
        for _refusal in refusals {
            if _refusal.site is None {
                continue;
            }
            self.emit(
                E5090 if _refusal.code == "E5090" else E5092,
                node_override=_refusal.site,
                kind=_refusal.kind,
                name=_refusal.name,
                help_text=_refusal.help
            );
        }
    }
    self._place_unit_python(full_name, func, refusals, keep_func=keep_func);
    return True;
}

impl NaIRGenPass._rename_demoted_symbol(name: str, func: ir.Function) -> None {
    self._demoted_names.add(name);
    self._unit_exports.pop(name, None);
    try {
        self.llvm_module.globals.pop(func.name, None);
        func.name = f"{func.name}{DEMOTED_SUFFIX}";
        self.llvm_module.globals[func.name] = func;
    } except Exception {}
}

impl NaIRGenPass._propagate_seam_demotions -> None {
    if not self._seam_stub_ids {
        return;
    }
    method_names = {id(fn): name for (name, fn) in self.method_funcs.items()};
    owners: list[tuple[str, ir.Function, uni.Ability, bool]] = [];
    for (_fid, _linked) in self._linked_fn_decls.items() {
        _linked_fn = _linked[0];
        _linked_decl = _linked[1];
        if _linked_fn is None
            or not _linked_fn.blocks
            or id(_linked_fn) in self._seam_stub_ids {
            continue;
        }
        if id(_linked_fn) in method_names {
            owners.append(
                (method_names[id(_linked_fn)], _linked_fn, _linked_decl, True)
            );
        } elif _linked_decl.name_ref is not None
            and self.scope.function(_linked_decl.name_ref.sym_name) is _linked_fn {
            owners.append(
                (_linked_decl.name_ref.sym_name, _linked_fn, _linked_decl, False)
            );
        }
    }
    changed = True;
    while changed {
        changed = False;
        for (name, func, decl, is_method) in owners {
            if id(func) in self._seam_stub_ids {
                continue;
            }
            _owner_seen: set[int] = set();
            reached = self._reaches_seam_stub(func, _owner_seen);
            if reached is None {
                continue;
            }
            mark = len(self.ctx.errors_had);
            self.emit(
                E5092,
                node_override=decl,
                kind="function",
                name=reached,
                help_text=f"'{reached}' demoted to its Python-only implementation "
                f"(native seam), so '{name}' cannot reach it natively; hoist the "
                f"blocking construct out of '{reached}' or move '{name}' off the "
                f"native pathway."
            );
            if self._demote_method_if_unlowerable(name, func, mark, keep_func=is_method)
                and not is_method {
                self._rename_demoted_symbol(name, func);
            }
            changed = True;
        }
    }
    for (symbol, nd) in list(self._native_test_nodes.items()) {
        _test_fn = self.llvm_module.globals.get(symbol);
        if not isinstance(_test_fn, ir.Function)
            or id(_test_fn) in self._seam_stub_ids {
            continue;
        }
        _test_seen: set[int] = set();
        reached = self._reaches_seam_stub(_test_fn, _test_seen);
        if reached is None {
            continue;
        }
        mark = len(self.ctx.errors_had);
        self.emit(
            E5092,
            node_override=nd,
            kind="function",
            name=reached,
            help_text=f"'{reached}' demoted to its Python-only implementation "
            f"(native seam); the test runs in the server codespace instead."
        );
        self._demote_native_test(nd, _test_fn, mark);
    }
}

impl NaIRGenPass._reaches_seam_stub(func: ir.Function, seen: set[int]) -> (str | None) {
    seen.add(id(func));
    for blk in func.blocks {
        for instr in blk.instructions {
            if not isinstance(instr, ir.Instruction) {
                continue;
            }
            for op in instr.operands {
                if not isinstance(op, ir.Function) or id(op) in seen {
                    continue;
                }
                if id(op) in self._seam_stub_ids {
                    linked = self._linked_fn_decls.get(id(op));
                    if linked is not None and linked[1].name_ref is not None {
                        return linked[1].name_ref.sym_name;
                    }
                    return op.name.removesuffix(DEMOTED_SUFFIX);
                }
                if op.blocks and op.linkage in ("private", "internal") {
                    found = self._reaches_seam_stub(op, seen);
                    if found is not None {
                        return found;
                    }
                }
            }
        }
    }
    return None;
}

impl NaIRGenPass._llvm_type_str(ty: ir.Type, pointee_names: dict[str, str]) -> str {
    _opt_pt = self._opt_payload_of(ty);
    if _opt_pt is not None {
        return "opt." + self._llvm_type_str(_opt_pt, pointee_names);
    }
    if self._str_desc_ty is not None and ty == self._str_desc_ty {
        return self._str_desc_kind();
    }
    if isinstance(ty, ir.IntType) {
        return f"i{ty.width}";
    }
    if isinstance(ty, ir.DoubleType) {
        return "f64";
    }
    if isinstance(ty, ir.FloatType) {
        return "f32";
    }
    if isinstance(ty, ir.VoidType) {
        return "void";
    }
    if isinstance(ty, ir.PointerType) {
        if ty?.pointee {
            if isinstance(ty.pointee, ir.IntType) and ty.pointee.width == 8 {
                return "i8*";
            }
            return pointee_names.get(str(ty.pointee), "ptr");
        }
        return "ptr";
    }
    return "i64";
}

impl NaIRGenPass._layout_pointee_names -> dict[str, str] {
    names: dict[str, str] = {};
    for (sname, stype) in self.struct_types.items() {
        names.setdefault(str(stype), f"{sname}*");
    }
    for (ename, ltype) in self.list_types.items() {
        names.setdefault(str(ltype), f"List.{ename}*");
    }
    for ttype in self.tuple_types.values() {
        names.setdefault(str(ttype), "Tuple*");
    }
    for dtype in self.dict_types.values() {
        names.setdefault(str(dtype), f"{dtype.name}*");
    }
    for setype in self.set_types.values() {
        names.setdefault(str(setype), f"{setype.name}*");
    }
    return names;
}

impl NaIRGenPass._export_native_layout -> None {
    layout = NativeModuleLayout(str_headerless=self._nogc_headerless());
    pointee_names = self._layout_pointee_names();
    struct_names: dict[str, str] = {};
    for (sname, stype) in self.struct_types.items() {
        struct_names.setdefault(str(stype), sname);
    }
    tuple_keys: dict[str, str] = {};
    for (tkey, ttype) in self.tuple_types.items() {
        tuple_keys.setdefault(str(ttype), tkey);
    }

    for (arch_name, field_indices) in self.struct_field_indices.items() {
        field_types = self.struct_field_types.get(arch_name, {});
        fields: list[NativeFieldInfo] = [];
        field_enums = self.struct_field_enum_type.get(arch_name, {});
        elem_keys = self.struct_field_elem_keys.get(arch_name, {});
        _foreign_flds = self.struct_field_foreign.get(arch_name, set());
        for (fname, idx) in sorted(field_indices.items(), key=lambda (x) { x[1]; }) {
            ftype = field_types.get(fname);
            llvm_t = self._llvm_type_str(ftype, pointee_names)
                if ftype is not None
                else "i64";

            is_fn_ptr = False;
            fn_param_types: (list[str] | None) = None;
            fn_ret_type: (str | None) = None;
            if (
                ftype is not None
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            ) {
                is_fn_ptr = True;
                fn_param_types = [
                    self._llvm_type_str(a, pointee_names) for a in ftype.pointee.args
                ];
                fn_ret_type = self._llvm_type_str(
                    ftype.pointee.return_type, pointee_names
                );
            }
            fields.append(
                NativeFieldInfo(
                    name=fname,
                    llvm_type=llvm_t,
                    index=idx,
                    enum_type=field_enums.get(fname),
                    is_func_ptr=is_fn_ptr,
                    func_param_types=fn_param_types,
                    func_ret_type=fn_ret_type,
                    elem_keys=elem_keys.get(fname),
                    foreign=fname in _foreign_flds
                )
            );
        }
        layout.structs[arch_name] = NativeStructLayout(
            name=arch_name,
            fields=fields,
            has_vtable=self._arch_has_vtable(arch_name),
            accessors=self._exported_accessors(arch_name)
        );
    }

    for (enum_name, entries) in self.enum_string_values.items() {
        _enum_members: list[tuple[str, any, int]] = [];
        for _member in entries {
            _member_value: any = _member[1];
            _enum_members.append((_member[0], _member_value, _member[2]));
        }
        layout.enums[enum_name] = NativeEnumLayout(
            name=enum_name, is_string_valued=True, members=_enum_members
        );
    }

    for (tkey, ttype) in self.tuple_types.items() {
        elem_types = [self._llvm_type_str(e, pointee_names) for e in ttype.elements];
        _no_hints: list[str | None] = [];
        for _ in elem_types {
            _no_hints.append(None);
        }
        layout.tuples[tkey] = NativeTupleLayout(
            key=tkey, element_types=elem_types, element_struct_hints=_no_hints
        );
    }

    method_names = set(self.method_funcs.keys());
    for (fname, func) in self.scope.function_entries() {
        if fname.startswith("__") or fname == "jac_entry" or fname in method_names {
            continue;
        }
        if str(func.linkage) in ("internal", "private") {
            continue;
        }
        if fname in self._clib_symbol_lib and self.clib_extern_fns.get(fname) is func {
            continue;
        }
        param_types = [
            self._llvm_type_str(a, pointee_names) for a in func.function_type.args
        ];
        param_names = _source_param_names(func);
        ret_type = self._llvm_type_str(func.function_type.return_type, pointee_names);
        ret_struct: (str | None) = None;
        ret_tuple: (NativeTupleLayout | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            ret_struct = struct_names.get(
                str(func.function_type.return_type.pointee_type)
            );

            tkey = tuple_keys.get(str(func.function_type.return_type.pointee_type))
                if ret_type.startswith("Tuple")
                else None;
            if tkey is not None {
                ret_tuple = layout.tuples.get(tkey);
                if ret_tuple is not None {
                    hints = self._ret_tuple_hints(fname, ret_tuple);
                    if hints is not None {
                        ret_tuple = NativeTupleLayout(
                            key=ret_tuple.key,
                            element_types=ret_tuple.element_types,
                            element_struct_hints=hints
                        );
                        layout.tuples[tkey] = ret_tuple;
                    }
                }
            }
        }

        ret_enum: (str | None) = None;
        if ret_type in ("i64", "opt.i64") {
            _rkey = self.func_ret_type_key.get(fname);
            if _rkey is not None {
                if _rkey in self.enum_types {
                    ret_enum = _rkey;
                } elif "|" in _rkey {
                    _rnon = [
                        s.strip()
                        for s in _rkey.split("|")
                        if s.strip() not in ("None", "NoneType")
                    ];
                    if len(_rnon) == 1 and _rnon[0] in self.enum_types {
                        ret_enum = _rnon[0];
                    }
                }
            }
        }

        ret_elem: (list[str | None] | None) = None;
        if (
            ret_type.startswith("List.")
            or ret_type.startswith("Dict.")
            or ret_type.startswith("Set.")
        ) {
            ret_elem = self.func_ret_elem_keys.get(fname);
        }
        layout.functions[fname] = NativeFuncLayout(
            name=func.name,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct,
            ret_tuple_layout=ret_tuple,
            ret_enum_type=ret_enum,
            ret_elem_keys=ret_elem
        );
    }

    for (mname, func) in self.method_funcs.items() {
        if mname in self._native_skipped_methods {
            continue;
        }
        param_types = [
            self._llvm_type_str(a, pointee_names) for a in func.function_type.args
        ];
        param_names = _source_param_names(func);
        ret_type = self._llvm_type_str(func.function_type.return_type, pointee_names);
        ret_struct: (str | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            ret_struct = struct_names.get(
                str(func.function_type.return_type.pointee_type)
            );
        }
        layout.methods[mname] = NativeFuncLayout(
            name=mname,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct
        );
    }

    for (ename, ltype) in self.list_types.items() {
        layout.list_elem_types[f"List.{ename}"] = ename;
    }

    for (tname, tsymbol, tdesc, tline) in self.native_tests {
        layout.tests.append(
            NativeTestLayout(name=tname, symbol=tsymbol, description=tdesc, line=tline)
        );
    }
    self.module.gen.native_layout = layout;
}

impl NaIRGenPass._exported_accessors(arch_name: str) -> dict[(str, dict[(str, str)])] {
    out: dict[(str, dict[(str, str)])] = {};
    lay = self._arch_layout(arch_name);
    if lay is None {
        return out;
    }
    for slot in lay.method_index {
        parts = slot.rsplit(".", 1);
        if len(parts) != 2 or parts[1] not in ACCESSOR_SLOT_SUFFIX.values() {
            continue;
        }
        fn = self._resolve_method(arch_name, slot);
        if fn is None or fn.name in self._native_skipped_methods {
            continue;
        }
        if parts[0] not in out {
            out[parts[0]] = {};
        }
        out[parts[0]][parts[1]] = fn.name;
    }
    return out;
}

impl NaIRGenPass._ret_tuple_hints(
    fname: str, ret_tuple: any
) -> (list[str | None] | None) {
    if not isinstance(ret_tuple, NativeTupleLayout) {
        return None;
    }
    keys = self.func_ret_elem_keys.get(fname);
    if not keys or len(keys) != len(ret_tuple.element_types) {
        return None;
    }
    hints: list[str | None] = [];
    _any = False;
    for k in keys {
        hint: (str | None) = None;
        if k is not None {
            if k in self.struct_types {
                hint = k;
            } elif k.startswith("list[") and k.endswith("]") {
                _inner = k[5:-1];
                if _inner in self.struct_types {
                    hint = _inner;
                }
            }
        }
        if hint is not None {
            _any = True;
        }
        hints.append(hint);
    }
    return hints if _any else None;
}

impl NaIRGenPass._has_own_code(mod: (uni.Module | None)) -> bool {
    return mod is None
        or self._is_catalog_module(mod)
        or any(
            not isinstance(s, uni.Import) or clib_block_defines(s)
            for s in ModuleFacts.iter_context_stmts(mod)
        );
}

impl NaIRGenPass._declares_native_visible(mod: uni.Module) -> bool {
    for stmt in ModuleFacts.iter_context_stmts(mod) {
        if isinstance(stmt, uni.Import) and not stmt.clib_decls {
            continue;
        }
        if isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual {
            continue;
        }
        return True;
    }
    return False;
}

impl NaIRGenPass._native_imports(
    transitive: bool = True
) -> list[tuple[str, uni.Module]] {
    import os;

    if transitive and self._native_imports_walked {
        return self._native_import_walk;
    }
    processed_modules: set[str] = set();
    imported_mods: list[tuple[str, uni.Module]] = [];
    manifest = self.module.gen.interop_manifest;
    self._glob_import_sources = {};
    self._native_import_items = [];

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
    wq: list[tuple[str, str, str | None, bool, bool]] = [];
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
        wq.append(
            (mod_name, entry_base, None, bool(imp.is_typed), bool(imp.is_comptime))
        );

        if imp.from_loc and imp.items {
            _bound_path = resolve_native_module(mod_name, entry_base)[1];
            if _bound_path is not None {
                for _it in imp.items {
                    if isinstance(_it, uni.ModuleItem) and _it.alias is None {
                        self._glob_import_sources[_it.name.value] = real_path(
                            _bound_path
                        );
                    }
                    if isinstance(_it, uni.ModuleItem) {
                        self._native_import_items.append(
                            (_it, real_path(_bound_path), mod_name)
                        );
                    }
                }
            }
        }
    }

    _self_key = real_path(self.module.loc.mod_path) if (self.module?.loc) else None;

    _canon_src: dict[str, any] = {};
    walked: dict[str, uni.Module] = {};
    dep_edges: dict[str, list[str]] = {};
    typed_only: dict[str, bool] = {};
    runtime_edges: dict[str, list[str]] = {};
    qi = 0;
    while qi < len(wq) {
        (mod_name, cur_base, parent_key, typed, ct_edge) = wq[qi];
        qi += 1;
        assert mod_name is not None;
        (src_mod_str, full_path) = resolve_native_module(mod_name, cur_base);
        if src_mod_str is None or full_path is None {
            continue;
        }
        if _self_key is not None and real_path(full_path) == _self_key {
            continue;
        }
        abs_key = os.path.abspath(full_path);
        _edge_from = parent_key or "";
        if _edge_from in dep_edges {
            dep_edges[_edge_from].append(abs_key);
        } else {
            dep_edges[_edge_from] = [abs_key];
        }
        typed_only[abs_key] = typed and typed_only.get(abs_key, True);
        if not ct_edge {
            runtime_edges.setdefault(_edge_from, []).append(abs_key);
        }
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
        processed_modules.add(abs_key);
        walked[abs_key] = imported_mod;
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

        if not transitive and self._has_own_code(imported_mod) {
            continue;
        }
        sub_base = os.path.dirname(os.path.abspath(full_path));
        for sub_imp in ModuleFacts.iter_module_imports(imported_mod)
            + ModuleFacts.iter_nested_imports(imported_mod, CodeContext.NATIVE) {
            sub_name = self._extract_import_module_name(sub_imp);
            if sub_name {
                wq.append(
                    (
                        sub_name,
                        sub_base,
                        abs_key,
                        typed or bool(sub_imp.is_typed),
                        bool(sub_imp.is_comptime)
                    )
                );
            }
        }
    }

    self._foreign_modules = [m for (_s, m) in imported_mods];
    self._typed_only_imports = {
        k
        for (k, v) in typed_only.items()
        if v
    };

    runtime_reached: set[str] = set();
    _rt_todo: list[str] = list(runtime_edges.get("", []));
    while _rt_todo {
        _rt = _rt_todo.pop();
        if _rt not in runtime_reached {
            runtime_reached.add(_rt);
            _rt_todo.extend(runtime_edges.get(_rt, []));
        }
    }

    _dep_seen: set[str] = set();
    _dep_todo: list[str] = list(dep_edges.get("", []));
    while _dep_todo {
        _direct = _dep_todo.pop(0);
        if _direct in _dep_seen {
            continue;
        }
        _dep_seen.add(_direct);
        if _direct not in runtime_reached {
            continue;
        }

        if not self._has_own_code(
            walked.get(_direct) or self.prog.mod.hub.get(_direct)
        ) {
            _dep_todo.extend(dep_edges.get(_direct, []));
            continue;
        }
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
        self._note_native_dep(_direct);
    }

    walk = self._permuted_walk_order(imported_mods);
    if transitive {
        self._native_import_walk = walk;
        self._native_imports_walked = True;
    }
    return walk;
}

impl NaIRGenPass._register_imported_struct_types -> None {
    import os;

    imported_mods = self._native_imports();
    for (_, imported_mod) in imported_mods {
        if self._declares_native_visible(imported_mod) {
            self._ensure_dep_inference(imported_mod);
        }
    }

    _defined: dict[str, set[str]] = {};
    for (_, _gmod) in imported_mods {
        if _gmod?.loc and _gmod.loc.mod_path {
            _names: set[str] = set();
            for _st in ModuleFacts.iter_context_stmts(_gmod) {
                if isinstance(_st, uni.GlobalVars) {
                    for _ga in _st.assignments {
                        for _gt in (
                            _ga.target
                                if isinstance(_ga.target, (list, tuple))
                                else [_ga.target]
                        ) {
                            _gn = self._get_name(_gt);
                            if _gn is not None {
                                _names.add(_gn);
                            }
                        }
                    }
                }
            }
            _defined[real_path(_gmod.loc.mod_path)] = _names;
        }
    }
    self._glob_import_sources = {
        _gname: _gpath
        for (_gname, _gpath) in self._glob_import_sources.items()
        if _gname in _defined.get(_gpath, set())
    };
    self._check_native_import_names(imported_mods);

    for (_, imported_mod) in imported_mods {
        self._process_clib_imports(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_type_names(imported_mod);
    }

    self._declare_pending_clib_globals();
    self._declare_pending_clib_abilities();

    for (_, imported_mod) in imported_mods {
        self._register_imported_hierarchy(imported_mod);
    }

    adopt_imported_bases(self.module, header_identity=not self._nogc_headerless());
    self._report_unreachable_overrides();

    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_types(imported_mod);
    }

    for (_, imported_mod) in imported_mods {
        _imp_path = os.path.abspath(imported_mod.loc.mod_path)
            if imported_mod?.loc
            else "";
        self._walk_imported_module_abilities(
            imported_mod, with_fn_verdicts=(_imp_path not in self._typed_only_imports)
        );
    }
}

impl NaIRGenPass._permuted_walk_order(
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
        _out = list(mods);
        _state = int(_spec.split(":", 1)[1]) % 2147483648;
        _i = len(_out) - 1;
        while _i > 0 {
            _state = (_state * 1103515245 + 12345) % 2147483648;
            _j = _state % (_i + 1);
            _held = _out[_i];
            _out[_i] = _out[_j];
            _out[_j] = _held;
            _i -= 1;
        }
        return _out;
    }
    raise ValueError(f"unknown native_module_walk_order: {_spec!r}");
}

impl NaIRGenPass._extract_import_module_name(imp: uni.Import) -> (str | None) {
    if imp.clib_decls {
        return None;
    }
    if not imp.from_loc or not isinstance(imp.from_loc, uni.ModulePath) {
        if imp.items {
            for it in imp.items {
                if isinstance(it, uni.ModulePath) and it.path {
                    return '.'.join([p.value for p in it.path]);
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
        mod_name = '.'.join([p.value for p in imp.from_loc.path]);
    }
    return mod_name;
}

impl NaIRGenPass._walk_imported_module_type_names(imported_mod: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            aname = self._arch_key(stmt) if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
            }
        } elif isinstance(stmt, uni.Enum) {
            ename = stmt.name.value if stmt.name else None;
            if ename is not None and ename not in self._enum_source_name {
                self._enum_source_name[ename] = imported_mod.name;
            }
        }
    }

    record_interface_twins(imported_mod, self.prog);
}

impl NaIRGenPass._walk_imported_module_types(imported_mod: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
            and not stmt.codespace_dual
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._register_imported_archetype(stmt);

            _aname = self._arch_key(stmt) if stmt.name else None;
            if (_aname is not None) and (stmt.arch_kind is not None) {
                self.imported_osp_archs[_aname] = (stmt.arch_kind, imported_mod.name);
            }
        } elif isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt, quiet=True);
            for method in self._enum_methods(stmt) {
                self._forward_declare_method(stmt.name.value, method, imported=True);
            }
        } elif isinstance(stmt, uni.GlobalVars) {
            _imp_path = imported_mod.loc.mod_path if imported_mod?.loc else "";
            self._register_imported_globals(stmt, _imp_path);
        }
    }
}

impl NaIRGenPass._walk_imported_module_abilities(
    imported_mod: uni.Module, with_fn_verdicts: bool = True
) -> None {
    _imp_iface = self._dep_iface(imported_mod);
    _imp_layout = _imp_iface.layout if _imp_iface is not None else None;
    if _imp_layout is None {
        _imp_layout = imported_mod.gen.native_layout;
    }
    if _imp_layout is None and imported_mod?.loc and imported_mod.loc.mod_path {
        import os as _wl_os;
        _wl_raw = imported_mod.loc.mod_path;
        for _wl_key in (_wl_raw, _wl_os.path.abspath(_wl_raw), real_path(_wl_raw)) {
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
            _wl_internal = bool(active_host().native_fact(FACT_SEALED_RUNTIME, ""));
        }
    }
    _imp_fn_unavail: (set | None) = None;
    if with_fn_verdicts {
        _imp_fn_unavail = self._imported_function_demotions(imported_mod);
    }
    for _imp_arch in ModuleFacts.iter_context_stmts(imported_mod) {
        if not isinstance(_imp_arch, uni.Archetype)
            or _imp_arch.body is None
            or _imp_arch.name is None {
            continue;
        }
        _ia_name = self._arch_key(_imp_arch);
        for _imp_stmt in (ModuleFacts.unwrap_body(_imp_arch) or []) {
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
                    self._native_skipped_methods.add(_im_full);
                }
            }
        }

        for (_ia_slot, _ia_var, _ia_acc) in archetype_accessors(_imp_arch) {
            _im_full = f"{_ia_name}.{_ia_slot}";
            if (_imp_layout is not None and _im_full not in _imp_layout.methods)
                or (_imp_layout is None and _wl_internal) {
                self._native_skipped_methods.add(_im_full);
            }
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
            self._forward_declare_archetype_methods(stmt);
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
        if isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt, _imp_fn_unavail, _imp_layout);
        }
    }
}

impl NaIRGenPass._forward_declare_archetype_methods(arch: uni.Archetype) -> None {
    aname = self._arch_key(arch) if arch.name else None;
    if aname is None or arch.body is None {
        return;
    }
    for stmt in (ModuleFacts.unwrap_body(arch) or []) {
        if isinstance(stmt, uni.Ability) {
            if stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature) {
                self._forward_declare_method(aname, stmt, imported=True);
                if stmt.name_ref is not None {
                    self._record_linked_decl(
                        self.method_funcs.get(f"{aname}.{stmt.name_ref.sym_name}"), stmt
                    );
                }
            } elif isinstance(stmt.signature, uni.EventSignature)
                and (arch.arch_kind is not None) {
                self._forward_declare_event_method(aname, stmt);
                self._emit_osp_thunk(aname, stmt);
            }
        }
    }
    for (_slot, _accvar, _acc) in archetype_accessors(arch) {
        self._forward_declare_method(aname, _acc, field=_accvar, imported=True);
    }
}

impl NaIRGenPass._register_imported_hierarchy(imported_mod: uni.Module) -> None {
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
            _cons_reg.set_mro(_name, _mro);
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

impl NaIRGenPass._register_imported_archetype(arch: uni.Archetype) -> None {
    aname = self._arch_key(arch) if arch.name else None;
    if aname is None {
        return;
    }

    _arch_src = real_path(arch.loc.mod_path) if arch.loc.mod_path else "";
    _seen_src = self._struct_source_mod.get(aname);
    if _seen_src is not None and _arch_src and _seen_src != _arch_src {
        import from jaclang.compiler.frontend.host { active_host }
        active_host().note(
            f"native struct name collision -- '{aname}' from "
            f"{_arch_src} shadows the one from {_seen_src}; skipping "
            f"re-registration",
            style="warning"
        );
        return;
    }
    if _arch_src {
        self._struct_source_mod[aname] = _arch_src;
    }

    if aname not in self.struct_types {
        struct_type = self.llvm_module.context.get_identified_type(aname);
        self.struct_types[aname] = struct_type;
    }

    if aname in self._struct_bodies_done {
        return;
    }

    for _anc in self._mro_of(aname) {
        if (
            _anc != aname
            and _anc in self.arch_ast_map
            and _anc not in self._struct_bodies_done
        ) {
            _anc_arch = self.arch_ast_map[_anc];
            if isinstance(_anc_arch, uni.Archetype) {
                self._register_imported_archetype(_anc_arch);
            }
        }
    }
    if aname in self._struct_bodies_done {
        return;
    }
    self._struct_bodies_done.add(aname);

    self._codegen_archetype(arch, imported=True);
}

impl NaIRGenPass._register_imported_globals(
    nd: uni.GlobalVars, source_path: str = ""
) -> None {
    if bool(nd.access and nd.access.tag.name == Tok.KW_PRIV) {
        return;
    }
    import os;
    real_source = real_path(source_path) if source_path else "";
    aliases: dict[str, list[str]] = {};
    for (item, path, _) in self._native_import_items {
        alias = self._get_name(item.alias) if item.alias is not None else None;
        if alias is not None and path == real_source {
            aliases.setdefault(item.name.value, []).append(alias);
        }
    }
    _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
    _owner = nd.find_parent_of_type(uni.Module);
    for assign in nd.assignments {
        targets = assign.target
            if isinstance(assign.target, (list, tuple))
            else [(assign.target)];
        for target in targets {
            var_name = self._get_name(target);
            if var_name is None {
                continue;
            }
            _bound = self._glob_import_sources.get(var_name);
            names: list[str] = [];
            if var_name not in self.global_vars
                and (_bound is None or not real_source or real_source == _bound) {
                names.append(var_name);
            }
            for alias in aliases.get(var_name, []) {
                if alias not in self.global_vars {
                    names.append(alias);
                }
            }
            if not names {
                continue;
            }
            var_type: ir.Type = ir.IntType(64);
            if assign.type_tag and assign.type_tag.tag {
                if (
                    self._quiet_glob_type(assign.type_tag.tag) is None
                    and not self._glob_native_use_exists(target)
                ) {
                    continue;
                }
                var_type = self._resolve_jac_type(assign.type_tag.tag);
            } elif assign.value is not None {
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }
            symbol = self._symbol_for(var_name, _owner, _is_pub);
            declared = self.llvm_module.globals.get(symbol);
            if isinstance(declared, ir.GlobalVariable) {
                global_var = declared;
            } else {
                global_var = ir.GlobalVariable(self.llvm_module, var_type, name=symbol);
                global_var.linkage = "external";
            }
            for name in names {
                self.global_vars[name] = global_var;
                self.global_var_types[name] = var_type;
                if source_path {
                    self._global_origins[name] = source_path;
                }
            }
            self.has_native_code = True;
        }
    }
}

impl NaIRGenPass._forward_declare_imported_ability(
    nd: uni.Ability, unavailable: (set | None) = None, imp_layout: any = None
) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else None;
    if name is None {
        return;
    }
    _owner = nd.find_parent_of_type(uni.Module);
    _owner_name = _owner.name if _owner is not None else "";
    _owner_path = real_path(_owner.source.file_path) if _owner is not None else "";
    if _owner is not None and self._module_function_known((_owner_path, name)) {
        return;
    }
    _bound = self.scope.binds_function(name);
    if _bound {
        if not _owner_name
            or self.scope.binds_function(f"{_owner_name}.{name}")
            or self._func_def_mod.get(name) == _owner_name
            or (
                bool(nd.access and nd.access.tag.name == Tok.KW_PUB)
                and self._symbol_for(name, _owner, True) == name
            ) {
            return;
        }
    }

    if nd.body is None {
        return;
    }
    if bool(nd.access and nd.access.tag.name == Tok.KW_PRIV) {
        return;
    }
    _layout = imp_layout if isinstance(imp_layout, NativeModuleLayout) else None;
    if not nd.type_params {
        _fd_unlisted = _layout is not None
            and not name.startswith("__")
            and name not in _layout.functions;
        _fd_demoted = (unavailable is not None and name in unavailable) or _fd_unlisted;
        if _fd_demoted {
            if _owner_name {
                self._native_skipped_methods.add(f"{_owner_name}.{name}");
            }
            if not _bound {
                self._native_skipped_methods.add(name);
            }
            if _owner is not None {
                self._native_skipped_import_origin.setdefault(name, set()).add(
                    _owner_path
                );
            }
            return;
        }
    }
    pending = PendingImport(
        decl=nd, layout=_layout, module_key=(_owner_path, name), binds_bare=not _bound
    );
    if _owner is not None and self._declares_lazily(nd) {
        self._defer_import(pending, _owner_name);
    } else {
        self._declare_import(pending);
    }
}

impl NaIRGenPass._declares_lazily(nd: uni.Ability) -> bool {
    return isinstance(nd.signature, uni.FuncSignature)
        and not nd.type_params
        and not nd.is_comptime
        and not nd.decorators
        and not self._ability_has_ct_params(nd)
        and not self._ability_is_generator(nd);
}

impl NaIRGenPass._defer_import(pending: PendingImport, owner_name: str) -> None {
    imports = self._imports;
    assert imports is not None;
    name = pending.module_key[1];
    if pending.binds_bare {
        imports.by_name[name] = pending;
        if owner_name {
            self._func_def_mod[name] = owner_name;
        }
    }
    if owner_name {
        imports.by_name[f"{owner_name}.{name}"] = pending;
    }
    imports.by_key[pending.module_key] = pending;
}

impl NaIRGenPass._declare_import(pending: PendingImport) -> (ir.Function | None) {
    nd = pending.decl;
    name = pending.module_key[1];
    _owner = nd.find_parent_of_type(uni.Module);
    _owner_name = _owner.name if _owner is not None else "";
    imports = self._imports;
    assert imports is not None;
    imports.forget(pending, _owner_name);
    scope = self.scope;
    self.scope = scope.outermost();

    binds_bare = pending.binds_bare and self.scope.functions.get(name) is None;
    try {
        _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
        _already = self.llvm_module.globals.get(
            self._symbol_for(name, _owner, _is_pub)
        );
        if isinstance(_already, ir.Function) {
            if _owner_name {
                self.scope.bind_function(f"{_owner_name}.{name}", _already);
            }
            if binds_bare {
                self.scope.bind_function(name, _already);
                if _owner_name {
                    self._func_def_mod[name] = _owner_name;
                }
            }
            if _owner is not None {
                self._module_functions[pending.module_key] = _already;
            }
            self._record_linked_decl(_already, nd);
            return _already;
        }

        _prev = self.scope.functions.get(name);
        _prev_def_mod = self._func_def_mod.get(name);
        _prev_ret_type = self.func_ret_type_key.get(name);
        _prev_ret_elems = self.func_ret_elem_keys.get(name);
        self._maybe_declare_ability(nd, pending.layout);
        func = self._module_functions.get(pending.module_key);
        self._record_linked_decl(func, nd);
        if not binds_bare {
            if _prev is not None {
                self.scope.bind_function(name, _prev);
            } else {
                self.scope.unbind_function(name);
            }
            _restore_entry(self._func_def_mod, name, _prev_def_mod);
            _restore_entry(self.func_ret_type_key, name, _prev_ret_type);
            _restore_entry(self.func_ret_elem_keys, name, _prev_ret_elems);
        }
        return func;
    } finally {
        self.scope = scope;
    }
}

impl NaIRGenPass._module_function(key: tuple[str, str]) -> (ir.Function | None) {
    found = self._module_functions.get(key);
    if found is not None {
        return found;
    }
    imports = self._imports;
    pending = imports.by_key.get(key) if imports is not None else None;
    return self._declare_import(pending) if pending is not None else None;
}

impl NaIRGenPass._module_function_known(key: tuple[str, str]) -> bool {
    imports = self._imports;
    return key in self._module_functions
        or (imports is not None and key in imports.by_key);
}

impl NaIRGenPass._record_linked_decl(
    func: (ir.Function | None), decl: uni.Ability
) -> None {
    if func is None or id(func) in self._linked_fn_decls {
        return;
    }
    self._linked_fn_decls[id(func)] = (func, decl);
}

impl NaIRGenPass._ensure_dep_inference(dep_mod: uni.Module) -> None {
    if self.prog.analysis.provides(dep_mod, AnalysisFact.TYPE_OF) {
        return;
    }

    if not require(self.prog, dep_mod, CompilationProduct.ANALYSIS) {
        raise NativeRefused(
            f"Native dependency analysis failed: {dep_mod.loc.mod_path}"
        );
    }
}

impl NaIRGenPass._imported_function_demotions(
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

impl NaIRGenPass._check_native_import_names(
    imported_mods: list[tuple[str, uni.Module]]
) -> None {
    import os;

    by_path: dict[str, uni.Module] = {};
    for (_, _mod) in imported_mods {
        if _mod?.loc and _mod.loc.mod_path {
            by_path[real_path(_mod.loc.mod_path)] = _mod;
        }
    }
    for (item, path, mod_name) in self._native_import_items {
        name = item.name.value if item.name else None;
        src = by_path.get(path);
        if name is None
            or name == "*"
            or src is None
            or not path.endswith(".jac")
            or stdlib_intercepted(mod_name, name) {
            continue;
        }
        if any(
            _imp.is_absorb
                or any(
                    isinstance(_i, uni.ModuleItem) and _i.name.value == "*"
                    for _i in (_imp.items or [])
                ) for _imp in src.get_all_sub_nodes(uni.Import)
        ) {
            continue;
        }
        if lookup_symtab(src, name, None) is None {
            self.emit(E1145, node_override=item, name=name, module=mod_name);
        }
    }
}

impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    imports = ModuleFacts.iter_module_imports(module)
        + ModuleFacts.iter_nested_imports(module, CodeContext.NATIVE);
    for stmt in imports {
        if not stmt.clib_decls {
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
            continue;
        }

        _paths_before = len(self._clib_paths);
        if stmt.from_loc is not None and stmt.from_loc.path {
            _name_components: list[str] = [];
            for path_part in stmt.from_loc.path {
                if isinstance(path_part, uni.String) {
                    raw = path_part.value;

                    if (len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'") {
                        raw = raw[1:-1];
                    }

                    self._clib_paths.append(raw);
                } elif isinstance(path_part, uni.Name) {
                    _name_components.append(path_part.value);
                }
            }
            if _name_components {
                self._clib_paths.append(
                    self._resolve_clib_lib_name(_name_components, stmt.from_loc.level)
                );
            }
        }

        _cur_lib = self._clib_paths[-1]
            if len(self._clib_paths) > _paths_before
            else None;

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                self._declare_clib_struct(decl);
            }
        }

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                self._define_clib_struct(decl);
            }
        }

        self._clib_detect_vtable_structs();

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.GlobalVars) {
                for assign in decl.assignments {
                    self._pending_clib_globals.append((assign, _cur_lib, module));
                    target = assign.target[0] if assign.target else None;
                    if _cur_lib is not None and isinstance(target, uni.Name) {
                        self._clib_symbol_lib[target.sym_name] = _cur_lib;
                    }
                }
            }
        }

        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Ability) {
                fn_name: str = decl.name_ref.sym_name if decl.name_ref else "";
                if fn_name and module is not self.module {
                    self._foreign_clib_abilities.setdefault(fn_name, decl);
                }

                _is_empty_list = isinstance(decl.body, list) and not decl.body;
                if decl.body is not None and not _is_empty_list {
                    if module is not self.module {
                        self._pending_clib_abilities.append(decl);
                        if fn_name {
                            self.clib_extern_names.add(fn_name);
                        }
                        continue;
                    }
                    if fn_name {
                        self._clib_definitions[fn_name] = decl;
                    }
                    if c_variadic_param(decl.signature) is not None {
                        continue;
                    }
                }
                self._pending_clib_abilities.append(decl);
                if fn_name {
                    self.clib_extern_names.add(fn_name);
                    if _cur_lib is not None {
                        self._clib_symbol_lib[fn_name] = _cur_lib;
                    }
                }
            }
        }

        if self._clib_paths {
            self.module.gen._clib_paths = list(self._clib_paths);
            self.module.gen._clib_symbol_lib = dict(self._clib_symbol_lib);
            self.has_native_code = True;
        }
    }
}

impl NaIRGenPass._declare_pending_clib_globals -> None {
    pending = self._pending_clib_globals;
    self._pending_clib_globals = [];
    for (assign, lib, owner) in pending {
        self._declare_clib_global(assign, lib, owner);
    }
}

impl NaIRGenPass._declare_clib_struct(decl: uni.Archetype) -> (str | None) {
    arch_name = decl.name.value if decl.name else None;
    if arch_name is None {
        return None;
    }
    self.struct_types[arch_name] = self.llvm_module.context.get_identified_type(
        arch_name
    );
    self.clib_struct_names.add(arch_name);
    self.has_native_code = True;
    return arch_name;
}

impl NaIRGenPass._define_clib_struct(decl: uni.Archetype) -> None {
    arch_name = decl.name.value if decl.name else None;
    if arch_name is None or arch_name not in self.struct_types {
        return;
    }
    self._codegen_archetype(decl);

    stype = self.struct_types[arch_name];
    if stype?.elements and stype.elements {
        total_bits = 0;
        all_int = True;
        for elem in stype.elements {
            if isinstance(elem, ir.IntType) {
                total_bits += elem.width;
            } else {
                all_int = False;
                break;
            }
        }
        if all_int and 0 < total_bits <= 64 {
            abi_bits = 8;
            while abi_bits < total_bits {
                abi_bits *= 2;
            }
            self.clib_struct_abi_types[arch_name] = ir.IntType(abi_bits);
        }
    }
}

impl NaIRGenPass._ensure_clib_struct(t: any) -> (str | None) {
    arch = foreign_struct_of_type(t);
    if arch is None or arch.name is None {
        return None;
    }
    name = arch.name.value;
    if name not in self.clib_struct_names {
        self._declare_clib_struct(arch);
        self._define_clib_struct(arch);
    }
    return name;
}

impl NaIRGenPass._declare_pending_clib_abilities -> None {
    pending = self._pending_clib_abilities;
    self._pending_clib_abilities = [];
    for ability in pending {
        self._declare_clib_ability(ability);
    }
}

impl NaIRGenPass._resolve_clib_lib_name(components: list[str], level: int) -> str {
    triple = str(self.llvm_module.triple or "").lower();
    if ("darwin" in triple)
        or ("apple" in triple)
        or ("macos" in triple)
        or ("ios" in triple) {
        prefix = "lib";
        ext = ".dylib";
        origin_token = "@loader_path";
    } elif ("windows" in triple)
        or ("win32" in triple)
        or ("mingw" in triple)
        or ("msvc" in triple) {
        prefix = "";
        ext = ".dll";
        origin_token = ".";
    } else {
        prefix = "lib";
        ext = ".so";
        origin_token = "$ORIGIN";
    }
    stem = components[-1];
    subdir_parts = components[:-1];
    filename = prefix + stem + ext;
    if subdir_parts or level > 0 {
        rel = "/".join(subdir_parts + [filename]) if subdir_parts else filename;
        return origin_token + "/" + rel;
    }

    return filename;
}

impl NaIRGenPass._ensure_emitters -> dict[str, object] {
    if self._native_emitters is not None {
        return self._native_emitters;
    }

    emitters: dict[str, object] = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _made = _native_emitter_of(_suffix);
        if _made is not None {
            emitters[_tn] = _made;
        }
    }
    self._native_builtin_emitter = _pn.NativeBuiltinEmitter();
    self._native_emitters = emitters;
    return emitters;
}

impl NaIRGenPass._primitive_method_names(type_name: str) -> set[str] {
    if self._primitive_method_name_cache is None {
        self._primitive_method_name_cache = {};
    }
    _cached = self._primitive_method_name_cache.get(type_name);
    if _cached is not None {
        return _cached;
    }
    _names: set[str] = set();
    for _n in active_host().native_fact(FACT_PRIMITIVE_METHODS, type_name).split(",") {
        if _n {
            _names.add(_n);
        }
    }
    self._primitive_method_name_cache[type_name] = _names;
    return _names;
}

impl NaIRGenPass._primitive_method_takes_kwargs(
    type_name: str, method_name: str
) -> bool {
    return (type_name, method_name)
        in {("list", "sort"), ("str", "splitlines"), ("bytes", "decode")};
}

impl NaIRGenPass._dispatch_primitive_method(
    type_name: str,
    method_name: str,
    target: ir.Value,
    args: list[ir.Value],
    type_key: str,
    kwargs: (dict[str, uni.UniNode] | None) = None,
    kw_node: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    target = self._str_norm(target);
    originals = list(args);
    args = [self._str_borrow(_a) for _a in args];

    _emitter = self._ensure_emitters().get(type_name);
    if not isinstance(_emitter, PrimitiveEmitter) {
        return None;
    }
    _pm_instance = method_name in _emitter.method_names();
    _pm_static = method_name in _emitter.static_names();
    _pm_native_only = (
        (isinstance(_emitter, _pm_pn.NativeStrEmitter) and method_name == "decode")
        or (isinstance(_emitter, _pm_pn.NativeListEmitter) and method_name == "del_at")
        or (isinstance(_emitter, _pm_pn.NativeDictEmitter) and method_name == "remove")
    );
    if not _pm_instance and not _pm_static and not _pm_native_only {
        return None;
    }
    if kwargs and not self._primitive_method_takes_kwargs(type_name, method_name) {
        self.emit(
            E5092,
            node_override=kw_node,
            kind="keyword argument for native method",
            name=f"{method_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = NativeEmitCtx(pass_ref=self, type_key=type_key, call_kwargs=(kwargs or {}));
    if isinstance(kw_node, uni.FuncCall)
        and isinstance(kw_node.target, uni.AtomTrailer) {
        _ctx.receiver_node = kw_node.target.target;
    }
    try {
        result: (ir.Value | None) = None;
        if isinstance(_emitter, _pm_pn.NativeStrEmitter) and method_name == "decode" {
            result = _emitter.emit_decode(_ctx, target, args);
        } elif isinstance(_emitter, _pm_pn.NativeListEmitter)
            and method_name == "del_at" {
            result = _emitter.emit_del_at(_ctx, target, args);
        } elif isinstance(_emitter, _pm_pn.NativeDictEmitter)
            and method_name == "remove" {
            result = _emitter.emit_remove(_ctx, target, args);
        } elif _pm_instance {
            result = _emitter.dispatch(method_name, _ctx, target, args);
        } else {
            raise TypeError(
                f"emit_{method_name}() takes 3 positional arguments but 4 were given"
            );
        }
        if result is not None {
            self._consume_str_args(originals);
        }
        return result;
    } except Exception as _pm_exc {
        if self._na_debug_on() {
            import sys as _pm_sys;
            _pm_sys.stderr.write(
                f"NA_DEBUG primitive {type_name}.{method_name}: "
                f"{type(_pm_exc).__name__}: {_pm_exc}\n"
            );
        }
        self.emit(
            E5092,
            node_override=kw_node,
            kind="primitive method",
            name=f"{type_name}.{method_name}",
            help_text=f"The emitter for this builtin method raised "
            f"{type(_pm_exc).__name__} on the operands it was given, which "
            "means an argument did not reach the shape it expects -- most "
            "often a container or tuple where a scalar or string is "
            f"required. Original error: {_pm_exc}"
        );
        return None;
    }
}

impl NaIRGenPass._dispatch_builtin(
    func_name: str,
    args: list[ir.Value],
    kwargs: (dict[str, uni.UniNode] | None) = None,
    kw_node: (uni.UniNode | None) = None,
    type_key: str = "",
    arg_nodes: (list[uni.UniNode] | None) = None
) -> (ir.Value | None) {
    originals = list(args);
    args = [self._str_borrow(_a) for _a in args];
    self._ensure_emitters();
    if (
        func_name == "str"
        and len(args) == 1
        and self._opt_payload_of(args[0].type) is not None
    ) {
        return self._emit_optional_str(args[0], arg_nodes[0] if arg_nodes else None);
    }
    _builtin_emitter = self._native_builtin_emitter;
    if not isinstance(_builtin_emitter, PrimitiveEmitter)
        or func_name not in _builtin_emitter.static_names() {
        return None;
    }
    if kwargs and func_name not in ("sorted", "min", "max") {
        self.emit(
            E5092,
            node_override=kw_node,
            kind="keyword argument for native builtin",
            name=f"{func_name}({', '.join(kwargs.keys())}=...)"
        );
        return None;
    }
    _ctx = NativeEmitCtx(
        pass_ref=self,
        type_key=type_key,
        call_kwargs=(kwargs or {}),
        arg_nodes=(arg_nodes or []),
        call_node=kw_node
    );
    result: (ir.Value | None) = _builtin_emitter.dispatch_static(func_name, _ctx, args);
    if result is not None {
        self._consume_str_args(originals);
    }
    return result;
}

impl NaIRGenPass._split_call_kwargs(nd: uni.FuncCall) -> dict[str, uni.UniNode] {
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

impl NaIRGenPass._ct_ctor_slots(target: uni.UniNode) -> list[tuple[str, uni.UniNode]] {
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

impl NaIRGenPass.run_walk with uni.Module entry {
    self.module = self._run_impl(here);
    if self.ctx.errors_had {
        self._publish_lowering_failure(here);
    }
}

impl NaIRGenPass._publish_lowering_failure(here: uni.Module) -> None {
    active_host().native_lowering_failed(
        self.prog,
        here.loc.mod_path,
        "Native module lowering failed:\n"
            + "\n".join(alert.pretty_print() for alert in self.ctx.errors_had)
    );
}

impl scalar_llvm_type(`entry: JacTypeEntry) -> ir.Type {
    if `entry.is_float {
        return ir.FloatType() if `entry.width == 32 else ir.DoubleType();
    }
    return ir.IntType(`entry.width);
}

impl _source_param_names(func: ir.Function) -> list[str] {
    names: list[str] = [];
    for arg in func.args {
        (stem, _, suffix) = arg.name.rpartition(".");
        names.append(stem if stem and suffix.isdigit() else arg.name);
    }
    return names;
}

impl _native_emitter_of(suffix: str) -> (object | None) {
    if suffix == "IntEmitter" {
        return _pn.NativeIntEmitter();
    }
    if suffix == "FloatEmitter" {
        return _pn.NativeFloatEmitter();
    }
    if suffix == "BoolEmitter" {
        return _pn.NativeBoolEmitter();
    }
    if suffix == "ComplexEmitter" {
        return _pn.NativeComplexEmitter();
    }
    if suffix == "StrEmitter" {
        return _pn.NativeStrEmitter();
    }
    if suffix == "BytesEmitter" {
        return _pn.NativeBytesEmitter();
    }
    if suffix == "ListEmitter" {
        return _pn.NativeListEmitter();
    }
    if suffix == "DictEmitter" {
        return _pn.NativeDictEmitter();
    }
    if suffix == "SetEmitter" {
        return _pn.NativeSetEmitter();
    }
    if suffix == "FrozensetEmitter" {
        return _pn.NativeFrozensetEmitter();
    }
    if suffix == "TupleEmitter" {
        return _pn.NativeTupleEmitter();
    }
    if suffix == "RangeEmitter" {
        return _pn.NativeRangeEmitter();
    }
    if suffix == "BuiltinEmitter" {
        return _pn.NativeBuiltinEmitter();
    }
    return None;
}
