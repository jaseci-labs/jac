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
    self.context_root = None;
    self.context_key = "";
    self.contexts = {};
    self.internal = False;
}

impl JacProgram.iface_registry(self: JacProgram) -> IfaceRegistry {
    if self._iface is not None {
        return self._iface;
    }
    import from jaclang.compiler.frontend.host { active_host }
    return active_host().iface_registry_for(self);
}

impl JacProgram.native_units(self: JacProgram) -> NativeUnitRegistry {
    if self._natives is not None {
        return self._natives;
    }
    import from jaclang.compiler.frontend.host { active_host }
    return active_host().native_units_for(self);
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
    self.analysis.forget_module(displaced);
    work = self.analysis.placement_work;
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
    if self.context_root is None {
        for context in list(self.contexts.values()) {
            if context is not self {
                context.invalidate_module(resolved_path);
            }
        }
    }
    old_module = self.mod.hub.get(resolved_path);
    if old_module is not None {
        self.analysis.forget_module(old_module);
    }
    work = self.analysis.placement_work;
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

    import from jaclang.compiler.frontend.host { active_host }
    active_host().forget_program_products(self, resolved_path);
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
                for k in [prog_root->:Kid:->]
                if k is not released
            ],
            pos_update=False
        );
        del [edge released<-:ScopeChild:<-];
        if [prog_root->:Kid:->] {
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
    import from jaclang.compiler.types.stubcat.reader { CatModule }
    resolved_path = os.path.realpath(source_path);
    import from jaclang.compiler.frontend.host { active_host }
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
    import from jaclang.compiler.driver.compilation_context { program_for }
    target_program = program_for(resolved_path, self);
    target_hub = target_program.mod.hub;

    if (resolved_path in self.mod.hub and not self.is_hub_entry_fresh(resolved_path)) {
        self.invalidate_module(resolved_path);
    }
    mod: uni.Module;
    if resolved_path in self.mod.hub
        and not (need_tree and isinstance(self.mod.hub[resolved_path], CatModule)) {
        mod = self.mod.hub[resolved_path];
    } elif resolved_path in target_hub
        and not (need_tree and isinstance(target_hub[resolved_path], CatModule)) {
        mod = target_hub[resolved_path];
    } else {
        if resolved_path.endswith('.pyi') {
            import from jaclang.compiler.driver.pass_driver { run_pass }
            import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
            src = use_str or active_host().read_source(source_path);
            (mod, _stub_errors) = active_host().parse_python(src, source_path, self);
            mod.stub_only = True;

            self.install_module(resolved_path, mod);
            self.note_stub_tree_served(resolved_path);
            self.resolve_absorb_imports(mod);
            run_pass(SymTabBuildPass, mod, self);
            events = self.analysis.cache_events;
            events["stub_ingest"] = events.get("stub_ingest", 0) + 1;
        } else {
            saved_options = self.options;
            try {
                mod = self.compile(
                    source_path,
                    use_str=use_str,
                    options=self.options.for_symbols(need_tree)
                );
            } finally {
                self.options = saved_options;
            }
        }
        if not isinstance(mod, CatModule) {
            target_program.install_module(resolved_path, mod);
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
    active_host().note_program_dependency(self, resolved_path);
    return mod;
}

impl JacProgram.hub_key(path: str) -> str {
    return os.path.realpath(path);
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
    if self._compiler is not None {
        return self._compiler;
    }
    import from jaclang.compiler.frontend.host { active_host }
    return active_host().compiler_for(self);
}

impl JacProgram.stub_catalog(self: JacProgram) -> (StubCatalog | None) {
    if self._stub_trees_served {
        return None;
    }
    if self._stub_catalog is None {
        import from jaclang.compiler.frontend.host { active_host }
        catalog = active_host().stub_catalog_for(self);
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
    self.analysis.placement_work = None;
    self.type_evaluator = None;
    if clear_hub {
        self.mod.hub.clear();
        self.analysis.reset_module_state();
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
            for kid in [nd->:Kid:->] {
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
    self: JacProgram, collect: bool = True, retain_stubs: bool = True
) -> None {
    import os;
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }

    if self.context_root is None {
        for context in list(self.contexts.values()) {
            if context is not self {
                context.release_compile_closure(
                    collect=False, retain_stubs=retain_stubs
                );
            }
        }
        self.contexts.clear();
        self.context_key = '';
    }
    self.hub.reset(retain_stubs=retain_stubs);
    self.mod = self.hub.mod;
    self.deps.clear();
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    host.release_program_products(self, retain_stubs);
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
    if not retain_stubs {
        self._stub_catalog = None;
    }
    self._stub_trees_served = False;
    self.diags.clear();
    self.scratch.clear();
    self.analysis.reset_module_state();
    if collect {
        host.collect_released_memory();
    }
}

impl JacProgram.find_module(self: JacProgram, path: str) -> (uni.Module | None) {
    found = self.mod.hub.get(path);
    if found is not None {
        return found;
    }
    keyed = JacProgram.hub_key(path);
    found = self.mod.hub.get(keyed);
    if found is not None {
        return found;
    }
    if self.context_root is None {
        for context in self.contexts.values() {
            if context is not self and context.options.entry_point == keyed {
                return context.find_module(keyed);
            }
        }
    }
    return None;
}

impl JacProgram.execution_hubs(self: JacProgram) -> list[dict[str, uni.Module]] {
    """Enumerate loaded runtime metadata; source analysis uses only its own hub.""";
    import from jaclang.compiler.frontend.host { active_host }
    hubs: list[dict[str, uni.Module]] = [self.mod.hub];
    internal = active_host().internal_program(self);
    if internal is not None and internal is not self {
        hubs.append(internal.mod.hub);
    }
    return hubs;
}

impl JacProgram.parse_str(
    self: JacProgram,
    source_str: str,
    file_path: str,
    cancel_token: (CancelToken | None) = None
) -> uni.Module {
    mod = self.parse_source(source_str, file_path, cancel_token);
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
    cancel_token: (CancelToken | None) = None,
    options: (CompileOptions | None) = None
) -> uni.Module {
    if (options is None) {
        options = CompileOptions(
            symtab_ir_only=symtab_ir_only, no_cgen=no_cgen, cancel_token=cancel_token
        );
    }
    import from jaclang.compiler.frontend.host { active_host }
    mod = active_host().compile_module(self, file_path, use_str, options);
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
    import from jaclang.compiler.frontend.host { active_host }
    return active_host().build_module(self, file_path, use_str);
}

impl JacProgram.declared_codespace(self: JacProgram, file_path: str) -> str {
    import from jaclang.compiler.driver.boundary_classify { _default_codespace_for }
    import from jaclang.compiler.frontend.codeinfo { is_client_by_location }
    import from jaclang.compiler.native_scope { package_host_edge }
    import from jaclang.compiler.placement.placement_facts { native_only, native_unit }
    import from jaclang.compiler.placement.placement_pins {
        config_kind_space,
        effective_module_pin
    }
    opts = self.options;
    if native_only(file_path) {
        return 'native';
    }
    if is_client_by_location(file_path) {
        return 'client';
    }
    pinned = effective_module_pin(file_path, self);
    if pinned in ('client', 'native') {
        return pinned;
    }
    unit_compile = bool(opts is not None and opts.native_unit);
    if native_unit(file_path, unit_compile, self) {
        return 'native';
    }
    if self.internal or (unit_compile and package_host_edge(file_path)) {
        return '';
    }
    forced = opts.force_codespace if opts is not None else '';
    if not forced
        and opts is not None
        and opts.aot_mode
        and _default_codespace_for(self) == 'native' {
        forced = 'native';
    }
    if forced {
        return forced;
    }
    kind_space = config_kind_space(
        file_path, opts.app_kind if opts is not None else ''
    );
    return kind_space if kind_space in ('client', 'native') else '';
}

impl JacProgram.infers_native_codespace(self: JacProgram, file_path: str) -> bool {
    import from jaclang.compiler.driver.boundary_classify { _default_codespace_for }
    opts = self.options;
    if opts is not None and opts.no_cgen {
        return False;
    }
    if opts is not None and opts.native_unit {
        import from jaclang.compiler.native_scope {
            in_native_scope_path,
            package_host_edge
        }
        if in_native_scope_path(file_path) {
            return True;
        }
        if package_host_edge(file_path) {
            return False;
        }
    }
    return not self.internal and _default_codespace_for(self) == 'native';
}

impl JacProgram.parse_source(
    self: JacProgram,
    source_str: str,
    file_path: str,
    cancel_token: (CancelToken | None) = None
) -> uni.Module {
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.driver.boundary_classify {
        _coerce_client_module,
        _coerce_native_module
    }
    import from jaclang.compiler.frontend.host { active_host }
    had_error = False;
    run_codespace_infer = False;
    infer_native = False;
    if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
        (parsed, had_error) = active_host().parse_python(source_str, file_path, self);
    } else {
        retired = active_host().path_facts(file_path).retired_marker;
        if retired == "native" {
            raise ValueError(
                f"{file_path}: the .na.jac marker was retired in 0.35 -- rename "
                "the file to .jac; native placement is inferred (or forced by "
                "'jac build --native' / 'jac build --as native'). See 'jac guide "
                "reference/language/native-pathway'."
            );
        }
        if retired == "client" {
            raise ValueError(
                f"{file_path}: the .cl.jac marker was retired -- rename the "
                "file to .jac; client placement is inferred from JSX/npm "
                "imports (override via [placement.pins] in jac.toml). Run "
                "'jac fix placement' to migrate the project."
            );
        }
        import from jaclang.compiler.frontend.parser.frontend {
            annex_sources,
            parse_woven
        }
        codespace = self.declared_codespace(file_path);
        infer_native = not codespace and self.infers_native_codespace(file_path);
        (parsed, had_error) = parse_woven(
            source_str,
            file_path,
            self,
            annex_sources(file_path),
            early_context=codespace or ('' if infer_native else 'server')
        );
        if (codespace == 'client') {
            _coerce_client_module(parsed);
        } elif (codespace == 'native') {
            _coerce_native_module(parsed);
            active_host().record_native_coverage(parsed.loc.mod_path, 'native');
        } elif codespace == 'server' {
            parsed.set_code_context(CodeContext.SERVER);
        } else {
            run_codespace_infer = True;
        }
    }
    hub_key = self.hub_key(parsed.loc.mod_path);
    if had_error {
        parsed.parse_failed = True;
        self.install_module(hub_key, parsed);
        return parsed;
    }
    if self.mod.main.stub_only {
        old_hub = self.mod.hub;
        self.reset_module_root(uni.ProgramModule(main_mod=parsed));

        self.mod.hub.clear();
        self.mod.hub.update(old_hub);
    }
    self.install_module(hub_key, parsed);

    if run_codespace_infer and infer_native {
        _native_unit_opt = bool(self.options is not None and self.options.native_unit);
        import from jaclang.compiler.placement.placement_solver {
            native_default_verdict
        }
        (_na_ok, _na_why) = native_default_verdict(parsed, self, _native_unit_opt);
        if _na_ok {
            _coerce_native_module(parsed);
            parsed.codespace_inferred = True;
            active_host().record_native_coverage(parsed.loc.mod_path, 'native');
        } elif _na_why == 'previously-demoted' {
            import from jaclang.compiler.placement.placement_pins {
                native_demotion_code
            }
            active_host().record_native_coverage(
                parsed.loc.mod_path,
                'demoted',
                native_demotion_code(os.path.realpath(parsed.loc.mod_path), self),
                _na_why
            );
        } else {
            active_host().record_native_coverage(
                parsed.loc.mod_path, 'server', '', _na_why
            );
        }
    }
    return parsed;
}

impl JacProgram.resolve_absorb_imports(self: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.frontend.unitree { find_python_scope_node_of }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None {
            for item in imp.items {
                if (
                    isinstance(item, uni.ModulePath) and item.path and not item.alias
                ) {
                    imp.jac_detected = imp.is_jac;
                    break;
                }
            }
        }
        if not imp.is_absorb {
            continue;
        }
        if (find_python_scope_node_of(imp) is None) {
            continue;
        }
        path_node = imp.items[0];
        if not isinstance(path_node, uni.ModulePath) {
            continue;
        }
        resolved = path_node.resolve_relative_path();
        module: (uni.Module | None) = None;
        try {
            module = self.load_dependency_module(
                resolved, importer_path=mod.loc.mod_path
            );
        } except Exception {
            module = None;
        }
        imp.absorbed_mod = module;
    }
}

impl JacProgram.stamp_access_check_facts(self: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.frontend.host { active_host }
    project = active_host().project_defaults();
    mod.access_enforced = bool(project is not None and project.check.enforce_access);
}

impl JacProgram.stamp_native_import_facts(self: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.driver.boundary_classify { native_only_import_target }
    import os;
    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    needs_native = mod.decided_codespace == 'native'
        or ModuleFacts.has_native_context_stmts(mod);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, self);
        imp.native_only_drop = needs_native
            and target is not None
            and (os.sep + 'jaclang' + os.sep) not in os.path.abspath(target);
    }
}

impl JacProgram.stamp_app_facts(self: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    opts = self.options;
    mod_path = mod.loc.mod_path if mod.loc else '';
    mod.jac_project_root = host.project_root(mod_path) if mod_path else None;
    ws = host.workspace(mod_path) if mod_path else None;
    app = host.app_for_path(mod_path) if ws is not None else None;
    if app is None and ws is not None and opts.target_app {
        app = ws.apps.get(opts.target_app);
    }
    mod.app = app.name if app is not None else None;
    mod.app_root = ws.project_root if (app is not None and ws is not None) else None;
    target_kind = opts.app_kind if (opts is not None and opts.app_kind) else '';
    if app is not None {
        mod.app_kind = app.kind;
    } elif target_kind {
        mod.app_kind = target_kind;
    } else {
        mod.app_kind = '';
    }
    import from jaclang.project.app_kinds { UI_MOBUI }
    override_ui = opts.ui if (opts is not None and opts.ui) else '';
    ui = override_ui or (app.ui if app is not None else '');
    if ui == UI_MOBUI {
        enforced_root: (str | None) = None;
        if override_ui and opts.project_root {
            enforced_root = opts.project_root;
        }
        if enforced_root is None and ws is not None {
            enforced_root = ws.project_root;
        }
        if enforced_root is None {
            enforced_root = mod.jac_project_root;
        }
        mod.mobui_enforced_root = enforced_root;
    } else {
        mod.mobui_enforced_root = None;
    }
}

impl JacProgram.stamp_boundary_facts(self: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        ClientImportVerdict,
        _default_codespace_for,
        classify_client_import_item,
        import_declares_native_target,
        is_client_boundary_import,
        is_client_native_edge_import
    }
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.frontend.unitree { ability_of_symbol }
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    import from jaclang.compiler.placement.placement_pins { config_module_pin }

    base_dir = '.';
    if mod.loc {
        base_dir = os.path.dirname(mod.loc.mod_path);
    }
    _sb_opts = self.options;
    in_native_mod = mod.loc is not None
        and (
            mod.decided_codespace == 'native'
            or (
                _sb_opts is not None
                and _sb_opts.aot_mode
                and not self.internal
                and _default_codespace_for(self) == 'native'
            )
        );

    def resolve_native(module_name: str, inferred_ok: bool) -> (str | None) {
        (src_mod_str, full_path) = resolve_native_module(
            module_name, base_dir, allow_inferred=inferred_ok
        );
        return os.path.realpath(full_path) if full_path is not None else src_mod_str;
    }

    def source_mod_for(resolved_path: (str | None)) -> (uni.Module | None) {
        if resolved_path is None or not os.path.isfile(resolved_path) {
            return None;
        }
        return self.load_dependency_module(
            resolved_path, importer_path=mod.loc.mod_path, need_tree=True
        );
    }

    def collect_abilities(nd: uni.UniNode, out: dict[(str, uni.Ability)]) {
        if isinstance(nd, uni.Ability) and nd.sym_name {
            out[nd.sym_name] = nd;
        }
        for k in [nd->:Kid:->] {
            collect_abilities(k, out);
        }
    }

    def collect_walkers(nd: uni.UniNode, out: dict[(str, uni.Archetype)]) {
        if isinstance(nd, uni.Archetype) and nd.sym_name {
            if nd.arch_kind == 'walker' {
                out[nd.sym_name] = nd;
            }
        }
        for k in [nd->:Kid:->] {
            collect_walkers(k, out);
        }
    }

    def imported_names(imp: uni.Import) -> set[str] {
        names: set[str] = set();
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                names.add(item.name.value);
            }
        }
        return names;
    }

    def stamp_sv_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        abilities: dict[(str, uni.Ability)] = {};
        walkers: dict[(str, uni.Archetype)] = {};
        try {
            collect_abilities(src, abilities);
        } except Exception {}
        try {
            collect_walkers(src, walkers);
        } except Exception {}
        for name in wanted {
            wk_decl = walkers.get(name);
            if wk_decl is not None {
                facts.sv_walkers[name] = wk_decl;
                continue;
            }
            ab_decl = abilities.get(name);
            if ab_decl is not None {
                facts.sv_abilities[name] = ab_decl;
            }
        }
    }

    def stamp_na_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        for decl in src.body {
            if not isinstance(decl, (uni.Ability, uni.Archetype, uni.Enum)) {
                continue;
            }
            name = decl.sym_name;
            if (
                not name
                or name not in wanted
                or name in facts.na_target_decls
                or name in facts.na_unmappable_targets
            ) {
                continue;
            }
            if isinstance(decl, uni.Ability)
                and isinstance(decl.signature, uni.FuncSignature) {
                facts.na_target_decls[name] = decl;
            } else {
                facts.na_unmappable_targets.append(name);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(uni.Import) {
        facts = uni.ImportBoundaryFacts();
        nd.boundary_facts = facts;
        native_ctx = nd.codespace() == CodeContext.NATIVE;

        if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
            module_name = nd.from_loc.dot_path_str;
            if (not module_name and nd.from_loc.path) {
                module_name = '.'.join(p.value for p in nd.from_loc.path);
            }
            if module_name {
                cl_na_edge = is_client_native_edge_import(nd, self);
                facts.client_native_edge = cl_na_edge;
                na_intent = (
                    native_ctx
                    or in_native_mod
                    or import_declares_native_target(nd, self)
                    or cl_na_edge
                );
                facts.native_from_path = resolve_native(module_name, na_intent);
                try {
                    facts.from_loc_resolved = nd.from_loc.resolve_relative_path();
                } except Exception {
                    facts.from_loc_resolved = None;
                }
                facts.is_service = nd.is_service_import;
                if (facts.is_service and not facts.native_from_path) {
                    stamp_sv_decls(nd, facts);
                }
                if (cl_na_edge and nd.items) {
                    stamp_na_decls(nd, facts);
                }
                if (
                    nd.items
                    and not facts.is_service
                    and not cl_na_edge
                    and is_client_boundary_import(nd)
                ) {
                    linked_mod = source_mod_for(facts.from_loc_resolved);
                    if linked_mod is not None {
                        for item in nd.items {
                            if not isinstance(item, uni.ModuleItem) {
                                continue;
                            }
                            verdict = classify_client_import_item(linked_mod, item);
                            if verdict != ClientImportVerdict.BRIDGED {
                                continue;
                            }
                            sym_name = item.name.value;
                            decl = ability_of_symbol(linked_mod.lookup(sym_name));
                            if decl is not None {
                                facts.bridged_decls[sym_name] = decl;
                            }
                        }
                    }
                }
            }
        }

        if ((not nd.from_loc) and nd.is_absorb and nd.items and (not nd.clib_decls)) {
            item = nd.items[0];
            if (isinstance(item, uni.ModulePath) and item.path) {
                module_name = '.'.join(p.value for p in item.path);
                if module_name {
                    na_intent = (
                        native_ctx
                        or in_native_mod
                        or import_declares_native_target(nd, self)
                    );
                    facts.native_absorb_path = resolve_native(module_name, na_intent);
                }
            }
            continue;
        }

        if ((not nd.from_loc) and nd.items and (not nd.clib_decls)) {
            for item in nd.items {
                if (isinstance(item, uni.ModulePath) and item.path) {
                    whole_name = '.'.join(p.value for p in item.path);
                    eligible = is_bundled_native_module(whole_name)
                        or (item.alias is None and len(item.path) == 1);
                    if (whole_name and eligible) {
                        na_intent = (
                            native_ctx
                            or in_native_mod
                            or import_declares_native_target(nd, self)
                        );
                        item_path = resolve_native(whole_name, na_intent);
                        if item_path {
                            facts.native_item_paths[whole_name] = item_path;
                        }
                    }
                }
            }
        }
    }
}

impl JacProgram.ingest_comptime_producers(
    self: JacProgram, mod_targ: uni.Module, file_path: str
) -> None {
    if mod_targ is None or self.internal {
        return;
    }
    saved_opts = self.options;
    here_real = os.path.realpath(str(file_path));
    try {
        for imp in mod_targ.get_all_sub_nodes(uni.Import) {
            if not imp.is_comptime or imp.from_loc is None or imp.is_virtual_jac {
                continue;
            }
            try {
                target = imp.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if not isinstance(target, str) or not target.endswith('.jac') {
                continue;
            }
            if not os.path.isfile(target) or os.path.realpath(target) == here_real {
                continue;
            }
            try {
                self.load_dependency_module(
                    target, importer_path=file_path, need_tree=True
                );
            } except Exception as ct_ingest_err {
                import logging as _ct_logging;
                _ct_logging.getLogger(__name__).debug(
                    f"comptime producer {target} of {file_path} "
                    f"could not be ingested: {ct_ingest_err}"
                );
            }
        }
    } finally {
        self.options = saved_opts;
    }
}

impl JacProgram.run_schedule(
    self: JacProgram,
    mod: uni.Module,
    passes: PassSchedule,
    cancel_token: (CancelToken | None) = None
) -> None {
    import from jaclang.compiler.driver.pipeline { execute_passes }
    execute_passes(self, mod, passes, cancel_token);
}

impl JacProgram.count_module_blocking_errors(self: JacProgram, mod_path: str) -> int {
    count = 0;
    for e in self.errors_had {
        if e.code is None or not e.code.blocks_codegen {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == mod_path {
            count += 1;
        }
    }
    return count;
}

impl JacProgram.count_module_errors(self: JacProgram, mod_path: str) -> int {
    count = 0;
    for e in self.errors_had {
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == mod_path {
            count += 1;
        }
    }
    return count;
}

impl JacProgram.module_scoped_errors(self: JacProgram, mod_path: str) -> bool {
    import from jaclang.compiler.frontend.diagnostics { Category }
    norm = os.path.normpath(mod_path);

    prefix = (norm[:-4] if norm.endswith('.jac') else norm) + '.';
    for e in self.errors_had {
        if e.code is None or e.code.category not in (Category.CODEGEN, Category.ICE) {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == norm or e_path.startswith(prefix) {
            return True;
        }
    }
    return False;
}

impl JacProgram.note_stub_tree_served(self: JacProgram, path: str) -> None {
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    if self._stub_trees_served or host.stub_catalog_for(self) is not None {
        return;
    }
    if host.in_typeshed_tree(path) {
        self._stub_trees_served = True;
    }
}
