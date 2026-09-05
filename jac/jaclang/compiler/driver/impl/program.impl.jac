impl JacProgram.init(
    self: JacProgram, main_mod: (uni.ProgramModule | None) = None
) -> None {
    self.hub: ModuleHub = ModuleHub(mod=main_mod or uni.ProgramModule());
    self.deps: DepGraph = DepGraph();
    self.diags: DiagLedger = DiagLedger();
    self.scratch: BuildScratch = BuildScratch();
    self.analysis: AnalysisCaches = AnalysisCaches();
    self.options: CompileOptions = CompileOptions();
    self.mod: uni.ProgramModule = self.hub.mod;
    self.errors_had: list[Alert] = self.diags.errors;
    self.warnings_had: list[Alert] = self.diags.warnings;
    self.mtir_map: dict[(str, Info)] = self.analysis.mtir_map;
    self.type_evaluator: (TypeEvaluator | None) = None;
    self._compiler: (JacCompiler | None) = None;
    self._iface: any = None;
}

impl JacProgram.iface_registry(self: JacProgram) -> any {
    reg = self._iface;
    if reg is None {
        import from jaclang.compiler.driver.ifacecache { IfaceRegistry }
        reg = IfaceRegistry(prog=self);
        self._iface = reg;
    }
    return reg;
}

impl JacProgram.hub_cache_stamp(self: JacProgram, resolved_path: str) -> None {
    self.hub.stamp(resolved_path);
}

impl JacProgram.install_module(
    self: JacProgram, resolved_path: str, mod: uni.Module
) -> None {
    displaced = self.hub.install(resolved_path, mod);
    if displaced is None {
        return;
    }
    te = self.type_evaluator;
    if te is not None {
        te.forget_module(resolved_path);
    }
}

impl JacProgram.is_hub_entry_fresh(self: JacProgram, resolved_path: str) -> bool {
    return self.hub.is_fresh(resolved_path);
}

impl JacProgram.record_dependency(
    self: JacProgram, importer_path: str, target_path: str
) -> None {
    self.deps.record(importer_path, target_path);
}

impl JacProgram.transitive_dependents(self: JacProgram, target_path: str) -> set[str] {
    return self.deps.transitive_dependents(target_path);
}

impl JacProgram.invalidate_module(self: JacProgram, resolved_path: str) -> None {
    self.hub.evict(resolved_path);
    if resolved_path in self.analysis.placement_summaries {
        del self.analysis.placement_summaries[resolved_path];
    }

    te = self.type_evaluator;
    if te is not None {
        try {
            te.forget_module(resolved_path);
        } except AttributeError {
            self.type_evaluator = None;
        }
    }

    if self._iface is not None {
        self._iface.forget(resolved_path);
    }
    self.deps.forget(resolved_path);
}

impl JacProgram.release_module(self: JacProgram, resolved_path: str) -> None {
    released = self.hub.mod.hub.get(resolved_path) or self.find_module(resolved_path);
    self.invalidate_module(resolved_path);
    self.drop_module_alerts(resolved_path);
    prog_root = self.mod;
    main = prog_root.main_mod;
    if (main is not None and JacProgram.hub_key(main.loc.mod_path) == resolved_path) {
        released = released or main;
        prog_root.main_mod = None;
    }
    if released is not None {
        if prog_root.main_mod is released {
            prog_root.main_mod = None;
        }
        prog_root.set_kids(
            [
                k
                for k in prog_root.kid
                if k is not released
            ],
            pos_update=False
        );
        del [edge released<-:ScopeChild:<-];
        if prog_root.kid {
            (first_tok, last_tok) = prog_root.resolve_tok_range();
            prog_root.loc.update_token_range(first_tok, last_tok);
        } else {
            empty_tok = uni.EmptyToken();
            prog_root.loc.update_token_range(empty_tok, empty_tok);
        }
    }
}

impl JacProgram.load_dependency_module(
    self: JacProgram,
    source_path: str,
    importer_path: (str | None) = None,
    use_str: (str | None) = None,
    need_tree: bool = False
) -> uni.Module {
    import from pathlib { Path }

    resolved_path = str(Path(source_path).resolve());
    if resolved_path.endswith('.pyi') {
        catalog = self.stub_catalog();
        if catalog is not None {
            cat_mod = catalog.module_for_path(resolved_path);
            if cat_mod is not None {
                if importer_path is not None {
                    self.record_dependency(importer_path, resolved_path);
                }
                return cat_mod;
            }
        }
    }
    compiler = self._get_compiler();
    target_program = compiler.selfhost.resolve(resolved_path, self);
    target_hub = target_program.mod.hub;

    if (resolved_path in self.mod.hub and not self.is_hub_entry_fresh(resolved_path)) {
        self.invalidate_module(resolved_path);
    }
    if (
        resolved_path in target_hub
        and target_program is not self
        and not target_program.is_hub_entry_fresh(resolved_path)
    ) {
        target_program.invalidate_module(resolved_path);
    }

    mod: uni.Module;
    if resolved_path in self.mod.hub {
        mod = self.mod.hub[resolved_path];
    } elif resolved_path in target_hub
        and (
            target_program is self
            or target_program.analysis.analyses_run.provides(
                target_hub[resolved_path], 'TypeOf'
            )
        ) {
        mod = target_hub[resolved_path];
    } else {
        if resolved_path in target_hub {
            events = self.analysis.cache_events;
            events["untyped_foreign_tree_skipped"] = (
                events.get("untyped_foreign_tree_skipped", 0) + 1
            );
        }
        if resolved_path.endswith('.pyi') {
            import ast as py_ast;
            import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
            import from jaclang.compiler.driver.pass_driver { run_pass }
            import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
            import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
            src = use_str or read_file_with_encoding(source_path);
            uni_source = uni.Source(src, source_path);
            mod = run_pass(
                PyastBuildPass,
                uni.PythonModuleAst(py_ast.parse(src), orig_src=uni_source,),
                self
            ).ir_out;
            mod.stub_only = True;

            target_program.install_module(resolved_path, mod);
            compiler.note_stub_tree_served(resolved_path, self);
            compiler.resolve_absorb_imports(mod, self);
            run_pass(SymTabBuildPass, mod, self);
        } else {
            import from jaclang.compiler.driver.compile_options {
                CompileOptions as _DepOpts
            }
            mod = self.compile(
                source_path,
                use_str=use_str,
                options=(
                    _DepOpts(no_cgen=True, symtab_ir_only=True, need_full_ast=True)
                        if need_tree
                        else _DepOpts(no_cgen=True, symtab_ir_only=True, iface_ok=True)
                )
            );
        }
        if not hasattr(mod, "cat_kids") {
            target_program.install_module(resolved_path, mod);
        }
    }

    if importer_path is not None {
        self.record_dependency(importer_path, resolved_path);
        if need_tree {
            importer = self.find_module(JacProgram.hub_key(importer_path));
            if importer is not None and resolved_path not in importer.ct_file_deps {
                importer.ct_file_deps.append(resolved_path);
            }
        }
    }
    try {
        self.iface_registry().note_dep(resolved_path);
    } except Exception {}
    return mod;
}

impl JacProgram.hub_key(path: str) -> str {
    import from pathlib { Path }
    return str(Path(path).resolve());
}

impl JacProgram.has_failed_parse(self: JacProgram, path: str) -> bool {
    mod = self.mod.hub.get(JacProgram.hub_key(path));
    return mod is not None and mod.parse_failed;
}

impl JacProgram.drop_module_alerts(self: JacProgram, resolved_path: str) -> None {
    self.diags.drop_module(resolved_path);
}

impl JacProgram.reset_module_root(
    self: JacProgram, module_root: uni.ProgramModule
) -> None {
    self.hub.mod = module_root;
    self.mod = module_root;
}

impl JacProgram._get_compiler(self: JacProgram) -> JacCompiler {
    if self._compiler {
        return self._compiler;
    }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    self._compiler = JacCompiler();
    return self._compiler;
}

impl JacProgram.stub_catalog(self: JacProgram) -> any {
    return self._get_compiler().stub_catalog();
}

impl JacProgram.get_type_evaluator(self: JacProgram) -> TypeEvaluator {
    import from jaclang.compiler.types.type_evaluator { TypeEvaluator }
    if not self.type_evaluator {
        self.type_evaluator = TypeEvaluator(program=self);
    }
    return self.type_evaluator;
}

impl JacProgram.clear_type_system(self: JacProgram, clear_hub: bool = False) -> None {
    self.type_evaluator = None;
    if clear_hub {
        self.mod.hub.clear();
        return;
    }

    for mod in self.mod.hub.values() {
        if mod.stub_only {
            continue;
        }
        stack: list[uni.UniNode] = [mod];
        while stack {
            nd = stack.pop();
            if isinstance(nd, uni.Expr) {
                nd.type = None;
                nd.narrowed_type = None;
                nd.coerce_to = None;
            }
            for kid in nd.kid {
                stack.append(kid);
            }
        }
    }
}

impl JacProgram.release_native_dep_units(self: JacProgram) -> None {
    for (path, unit) in self.scratch.na_dep_units.items() {
        if isinstance(unit, str) {
            continue;
        }
        try {
            keyed = JacProgram.hub_key(path);
        } except Exception {
            keyed = path;
        }
        probes: list[str] = [keyed];
        if path != keyed {
            probes.append(path);
        }
        for probe in probes {
            if self.mod.hub.get(probe) is unit {
                self.invalidate_module(probe);
            }
        }
        try {
            gen = unit.gen;
        } except Exception {
            continue;
        }
        gen.native_engine = None;
        gen.llvm_ir = None;
        gen.native_bitcode = None;
    }
    self.scratch.na_dep_units.clear();
    self.scratch.na_unverified_live.clear();
    self.scratch.na_verdict_resolving.clear();
}

impl JacProgram.release_check_caches(self: JacProgram) -> None {
    ev = self.type_evaluator;
    if ev is None {
        return;
    }
    ev._flow_node_type_cache.clear();
    ev._flow_key_type_cache.clear();
    ev._and_narrowing_overrides.clear();
    ev._strict_site_cache.clear();
    ev._sv_async_syms_cache.clear();
    ev._loop_written_keys_cache.clear();
    ev._type_guard_probes.clear();
}

impl JacProgram.release_compile_closure(
    self: JacProgram, collect: bool = True
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    self.release_native_dep_units();
    self.hub.reset();
    self.mod = self.hub.mod;
    self.deps.clear();
    self.type_evaluator = None;
    self.diags.clear();
    self.scratch.clear();
    self.analysis.analyses_run.clear();
    if self._iface is not None {
        self._iface.on_closure_release();
    }
    if collect and unit_collect_budget.due() {
        import gc;
        gc.collect();
    }
}

impl JacProgram._search_hubs(self: JacProgram) -> list[dict[(str, uni.Module)]] {
    hubs: list[dict[(str, uni.Module)]] = [self.mod.hub];
    internal = self._get_compiler().selfhost.program;
    if internal is not self {
        hubs.append(internal.mod.hub);
    }
    return hubs;
}

impl JacProgram.find_module(self: JacProgram, path: str) -> (uni.Module | None) {
    import os;
    hubs = self._search_hubs();
    for hub in hubs {
        if path in hub {
            return hub[path];
        }
    }

    try {
        keyed = JacProgram.hub_key(path);
    } except Exception {
        keyed = path;
    }
    if keyed != path {
        for hub in hubs {
            if keyed in hub {
                return hub[keyed];
            }
        }
    }

    normalized = os.path.normcase(path);
    for hub in hubs {
        for (hub_path, mod) in hub.items() {
            if os.path.normcase(hub_path) == normalized {
                return mod;
            }
        }
    }
    return None;
}

impl JacProgram.get_bytecode(
    self: JacProgram, full_target: str
) -> (types.CodeType | None) {
    return self._get_compiler().get_bytecode(full_target, self);
}

impl JacProgram.get_client_artifact(
    self: JacProgram, full_target: str
) -> (ClientArtifact | None) {
    return self._get_compiler().get_client_artifact(full_target, self);
}

impl JacProgram.parse_str(
    self: JacProgram,
    source_str: str,
    file_path: str,
    cancel_token: (Event | None) = None
) -> uni.Module {
    mod = self._get_compiler().parse_str(source_str, file_path, self, cancel_token);
    if self.deps.tracking {
        try {
            self.deps.record_module(mod);
        } except Exception {}
    }
    return mod;
}

impl JacProgram.compile(
    self: JacProgram,
    file_path: str,
    use_str: (str | None) = None,
    no_cgen: bool = False,
    symtab_ir_only: bool = False,
    cancel_token: (Event | None) = None,
    options: (CompileOptions | None) = None
) -> uni.Module {
    if (options is None) {
        options = CompileOptions(
            symtab_ir_only=symtab_ir_only, no_cgen=no_cgen, cancel_token=cancel_token
        );
    }
    mod = self._get_compiler().compile(
        file_path=file_path, target_program=self, use_str=use_str, options=options
    );
    if self.deps.tracking {
        try {
            self.deps.record_module(mod);
        } except Exception {}
    }
    return mod;
}

impl JacProgram.build(
    self: JacProgram, file_path: str, use_str: (str | None) = None
) -> uni.Module {
    return self._get_compiler().build(file_path, self, use_str);
}

impl JacProgram.run_schedule(
    self: JacProgram,
    mod: uni.Module,
    passes: list[type[Transform]],
    cancel_token: (Event | None) = None
) -> None {
    self._get_compiler().run_schedule(mod, self, passes, cancel_token);
}
