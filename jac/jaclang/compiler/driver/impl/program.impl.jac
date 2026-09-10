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
    self._stub_catalog = None;
    self._stub_trees_served = False;
    self._iface = None;
    self._natives = None;
}

impl JacProgram.iface_registry(self: JacProgram) -> IfaceRegistry {
    reg = self._iface;
    if reg is None {
        import from jaclang.compiler.driver.ifacecache { IfaceRegistry }
        reg = IfaceRegistry(prog=self);
        self._iface = reg;
    }
    return reg;
}

impl JacProgram.native_units(self: JacProgram) -> NativeUnitRegistry {
    reg = self._natives;
    if reg is None {
        import from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
        reg = NativeUnitRegistry(prog=self);
        self._natives = reg;
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
    work = self.analysis.placement_state.get('work');
    if work is not None {
        work.forget(displaced);
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
    work = self.analysis.placement_state.get('work');
    if work is not None {
        work.forget_path(resolved_path);
    }
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

    if self._natives is not None {
        self._natives.forget(resolved_path);
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
    if resolved_path in self.mod.hub and not self.is_hub_entry_fresh(resolved_path) {
        self.invalidate_module(resolved_path);
    }
    mod: uni.Module;
    found = self.mod.hub.get(resolved_path);
    if found is not None and not (need_tree and hasattr(found, "cat_kids")) {
        mod = found;
    } else {
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

            self.install_module(resolved_path, mod);
            compiler.note_stub_tree_served(resolved_path, self);
            compiler.resolve_absorb_imports(mod, self);
            run_pass(SymTabBuildPass, mod, self);
            events = self.analysis.cache_events;
            events["stub_ingest"] = events.get("stub_ingest", 0) + 1;
        } else {
            import from jaclang.compiler.driver.compile_options {
                CompileOptions as _DepOpts
            }
            saved_options = self.options;
            try {
                mod = self.compile(
                    source_path,
                    use_str=use_str,
                    options=(
                        _DepOpts(no_cgen=True, symtab_ir_only=True, need_full_ast=True)
                            if need_tree
                            else _DepOpts(
                                no_cgen=True, symtab_ir_only=True, iface_ok=True
                            )
                    )
                );
            } finally {
                self.options = saved_options;
            }
        }
        if not hasattr(mod, "cat_kids") {
            self.install_module(resolved_path, mod);
        }
    }

    if importer_path is not None {
        self.record_dependency(importer_path, resolved_path);
        if need_tree {
            importer = self.find_module(JacProgram.hub_key(importer_path));
            if importer is not None {
                importer.record_comptime_dependency(resolved_path);
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

impl JacProgram.stub_catalog(self: JacProgram) -> (StubCatalog | None) {
    if self._stub_trees_served {
        return None;
    }
    if self._stub_catalog is None {
        catalog = self._get_compiler().stub_catalog();
        if catalog is not None {
            self._stub_catalog = catalog.for_session();
        }
    }
    return self._stub_catalog;
}

impl JacProgram.get_type_evaluator(self: JacProgram) -> TypeEvaluator {
    import from jaclang.compiler.types.type_evaluator { TypeEvaluator }
    if not self.type_evaluator {
        self.type_evaluator = TypeEvaluator(program=self);
    }
    return self.type_evaluator;
}

impl JacProgram.clear_type_system(self: JacProgram, clear_hub: bool = False) -> None {
    self.analysis.placement_state.pop('work', None);
    self.type_evaluator = None;
    if clear_hub {
        self.mod.hub.clear();
        return;
    }
    self.scrub_hub_types();
}

impl JacProgram.scrub_hub_types(self: JacProgram) -> None {
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
                nd.ct_value = None;
            }
            for kid in nd.kid {
                stack.append(kid);
            }
        }
    }
}

impl JacProgram.release_check_caches(self: JacProgram) -> None {
    ev = self.type_evaluator;
    if ev is None {
        return;
    }
    ev.release_check_caches();
}

impl JacProgram.release_compile_closure(
    self: JacProgram, collect: bool = True
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    units = len(
        {
            id(mod)
            for mod in self.mod.hub.values()
            if not mod.is_raised_from_py
        }
    );
    self.hub.reset();
    self.mod = self.hub.mod;
    self.deps.clear();
    if self._natives is not None and self._natives.session is None {
        self._natives.clear();
    }
    for gen in self.hub.artifacts.values() {
        gen.native_object = None;
        gen.native_bitcode = None;
    }
    ev = self.type_evaluator;
    if ev is not None {
        ev.release_compile_caches();
    }
    self.type_evaluator = None;
    ev = None;
    self._stub_catalog = None;
    self._stub_trees_served = False;
    self.diags.clear();
    self.scratch.clear();
    self.analysis.analyses_run.clear();
    self.analysis.placement_state.pop('work', None);
    self.analysis.early_passes.clear();
    if self._iface is not None {
        self._iface.on_closure_release();
    }
    events = self.analysis.cache_events;
    events["unit_release"] = events.get("unit_release", 0) + units;
    if collect and unit_collect_budget.due(units) {
        events["unit_collect"] = events.get("unit_collect", 0) + 1;
        import gc;
        gc.collect();
    }
}

impl JacProgram.find_module(self: JacProgram, path: str) -> (uni.Module | None) {
    found = self.mod.hub.get(path);
    if found is not None {
        return found;
    }
    return self.mod.hub.get(JacProgram.hub_key(path));
}

impl JacProgram.execution_hubs(self: JacProgram) -> list[dict[str, uni.Module]] {
    """Enumerate loaded runtime metadata; source analysis uses only its own hub.""";
    hubs: list[dict[str, uni.Module]] = [self.mod.hub];
    internal = self._get_compiler().selfhost.peek_program();
    if internal is not None and internal is not self {
        hubs.append(internal.mod.hub);
    }
    return hubs;
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
