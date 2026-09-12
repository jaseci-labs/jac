impl BoundaryAnalysisPass.before_pass -> None {
    self._func_defs = {};
    self._imported_native_funcs = {};
    self._imported_native_modules = {};
}

impl BoundaryAnalysisPass._resolved_native_decl(
    name_node: (UniNode | None)
) -> (Ability | None) {
    if name_node is None or not isinstance(name_node, AstSymbolNode) {
        return None;
    }
    decl = ability_of_symbol(name_node.sym);
    if decl is not None and isinstance(decl.signature, FuncSignature) {
        return decl;
    }
    return None;
}

impl BoundaryAnalysisPass._signature_of_decl(
    decl: (Ability | None)
) -> tuple[(str, list[str], list[str])] {
    ret_type: str = 'int';
    param_types: list[str] = [];
    param_names: list[str] = [];
    if decl is not None and isinstance(decl.signature, FuncSignature) {
        sig = decl.signature;
        all_params: list[ParamVar] = [];
        all_params.extend(sig.posonly_params);
        if sig.params {
            all_params.extend(sig.params);
        }
        all_params.extend(sig.kwonlyargs);
        for p in all_params {
            param_names.append(p.sym_name);
            if p.type_tag {
                param_types.append(self._extract_type_name(p.type_tag.tag));
            } else {
                param_types.append('int');
            }
        }
        if sig.return_type {
            ret_type = self._extract_type_name(sig.return_type);
        }
    }
    return (ret_type, param_types, param_names);
}

impl BoundaryAnalysisPass._get_context(nd: UniNode) -> InteropContext {
    import from jaclang.compiler.frontend.constant { CodeContext }
    cs = nd.codespace();
    if cs == CodeContext.NATIVE {
        return InteropContext.NATIVE;
    }
    if cs == CodeContext.CLIENT {
        return InteropContext.CLIENT;
    }
    return InteropContext.SERVER;
}

impl BoundaryAnalysisPass._extract_type_name(expr: (UniNode | None)) -> str {
    if (expr is None) {
        return 'int';
    }
    if isinstance(expr, Name) {
        return expr.value;
    }
    if isinstance(expr, Token) {
        return expr.value;
    }

    if isinstance(expr, AtomTrailer) {
        target_name = self._extract_type_name(expr.target);
        if expr.right {
            inner = self._extract_subscript_inner(expr.right);
            if inner {
                return f"{target_name}[{inner}]";
            }
        }
        return target_name;
    }

    if isinstance(expr, BinaryExpr) {
        left = self._extract_type_name(expr.left);
        right = self._extract_type_name(expr.right);
        return f"{left} | {right}";
    }
    return 'int';
}

impl BoundaryAnalysisPass._in_native_module -> bool {
    if not (self.ir_in and self.ir_in.loc) {
        return False;
    }
    return self.ir_in.decided_codespace == 'native';
}

impl BoundaryAnalysisPass._native_source_module_of(
    mod: (Module | None)
) -> (str | None) {
    import os;
    if mod is None or mod is self.ir_in or mod.loc is None or not mod.loc.mod_path {
        return None;
    }
    if not (self.ir_in and self.ir_in.loc and self.ir_in.loc.mod_path) {
        return None;
    }
    try {
        rel = str(
            os.path.relpath(
                os.path.abspath(mod.loc.mod_path),
                os.path.dirname(os.path.abspath(self.ir_in.loc.mod_path))
            )
        );
    } except ValueError {
        return None;
    }
    if rel.startswith('..') {
        return None;
    }
    if rel.endswith('.jac') {
        return rel;
    }
    return None;
}

impl BoundaryAnalysisPass._register_native_absorb(nd: Import) -> None {
    import from jaclang.compiler.frontend.constant { SymbolAccess }
    item = nd.items[0];
    if not (isinstance(item, ModulePath) and item.path) {
        return;
    }
    module_name = '.'.join(p.value for p in item.path);
    if not module_name {
        return;
    }
    facts = nd.boundary_facts;
    native_path = facts.native_absorb_path if facts else None;
    if not native_path {
        return;
    }
    inc_mod = nd.absorbed_mod;
    if inc_mod is None {
        return;
    }
    import_context = self._get_context(nd);
    is_native_ctx = import_context == InteropContext.NATIVE or self._in_native_module();
    manifest = self.ir_in.gen.interop_manifest;
    for (name, sym) in inc_mod.names_in_scope.items() {
        if sym.access == SymbolAccess.PRIVATE or not sym.defn {
            continue;
        }
        defn0 = sym.defn[0];
        if defn0.find_parent_of_type(Import) is not None {
            continue;
        }
        src = self._native_source_module_of(defn0.find_parent_of_type(Module))
            or native_path;
        self._imported_native_funcs[name] = (src, import_context);
        if (is_native_ctx and name not in manifest.bindings) {
            decl = self._resolved_native_decl(defn0);
            (ret_type, param_types, param_names) = self._signature_of_decl(decl);
            manifest.bindings[name] = InteropBinding(
                name=name,
                source_context=InteropContext.NATIVE,
                callers={InteropContext.NATIVE},
                ret_type=ret_type,
                param_types=param_types,
                param_names=param_names,
                ast_node=decl,
                source_module=src
            );
        }
    }
}

impl BoundaryAnalysisPass._caller_context(
    nd: Import, import_context: InteropContext
) -> InteropContext {
    """Interop context of the caller site: client wins, then native.""";
    if (nd.in_client_context()) {
        return InteropContext.CLIENT;
    }
    if (import_context == InteropContext.NATIVE or self._in_native_module()) {
        return InteropContext.NATIVE;
    }
    return InteropContext.SERVER;
}

impl BoundaryAnalysisPass.enter_import with Import entry {
    import_context = self._get_context(here);
    facts = here.boundary_facts;
    if (here.from_loc and isinstance(here.from_loc, ModulePath)) {
        from_loc = here.from_loc;
        module_name = from_loc.dot_path_str;
        if (not module_name and from_loc.path) {
            module_name = '.'.join(p.value for p in from_loc.path);
        }
        if module_name {
            import from jaclang.compiler.driver.boundary_classify {
                CrossAppKind,
                classify_cross_app_import
            }
            native_path = facts.native_from_path if facts else None;
            kind = classify_cross_app_import(here, self.ir_in.gen.interop_manifest);
            is_sv = kind == CrossAppKind.SERVICE_BRIDGE;
            if (is_sv and not native_path) {
                sv_module_name = from_loc.base_module_name;
                self._register_sv_import(here, sv_module_name, InteropContext.SERVER);
            }
            if here.items and not is_sv {
                if (facts and facts.pinned_server) {
                    _pin_caller = self._caller_context(here, import_context);
                    self._register_sv_import(
                        here, from_loc.base_module_name, _pin_caller
                    );
                } elif (facts and facts.client_native_edge) {
                    self._register_na_client_import(here);
                } else {
                    self._register_client_bridged_import(here);
                }
            }
            if (native_path and here.items) {
                manifest = self.ir_in.gen.interop_manifest;
                for item in here.items {
                    if isinstance(item, ModuleItem) {
                        func_name = item.name.value;
                        _item_sym = item.name.sym
                            if isinstance(item.name, AstSymbolNode)
                            else None;
                        _src = self._native_source_module_of(
                            _item_sym.defn[0].find_parent_of_type(Module)
                        )
                            if (_item_sym and _item_sym.defn)
                            else None;
                        _src = _src or native_path;
                        self._imported_native_funcs[func_name] = (_src, import_context);

                        is_native_ctx = (
                            import_context == InteropContext.NATIVE
                            or self._in_native_module()
                        );
                        if (is_native_ctx and func_name not in manifest.bindings) {
                            _decl = self._resolved_native_decl(item.name);
                            (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                            binding = InteropBinding(
                                name=func_name,
                                source_context=InteropContext.NATIVE,
                                callers={InteropContext.NATIVE},
                                ret_type=_rt,
                                param_types=_pts,
                                param_names=_pns,
                                ast_node=_decl,
                                source_module=_src
                            );
                            manifest.bindings[func_name] = binding;
                        }
                    }
                }
            }
        }
    }

    if (not here.from_loc)
        and here.is_absorb
        and here.items
        and (not here.clib_decls) {
        self._register_native_absorb(here);
        return;
    }

    if (not here.from_loc) and here.items and (not here.clib_decls) {
        for item in here.items {
            if isinstance(item, ModulePath) and item.path {
                whole_name = '.'.join(p.value for p in item.path);
                item_path = facts.native_item_paths.get(whole_name) if facts else None;
                if (whole_name and item_path) {
                    self._imported_native_modules[whole_name] = (
                        item_path,
                        import_context
                    );
                }
            }
        }
    }
}

impl BoundaryAnalysisPass._register_sv_import(
    nd: Import, module_name: str, caller_ctx: InteropContext
) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    facts = nd.boundary_facts;
    source_abilities: dict[(str, Ability)] = facts.sv_abilities if facts else {};
    source_walkers: dict[(str, Archetype)] = facts.sv_walkers if facts else {};
    manifest = self.ir_in.gen.interop_manifest;
    cross_app = import_crosses_apps(nd);
    provider_app = (import_provider_app(nd) or '') if cross_app else '';
    provider_route = import_provider_route(nd) if provider_app else '';
    provider_mod = self._provider_module_of(nd);
    parsed_mod: (Module | None) = None;
    if provider_mod is None or provider_mod.stub_only {
        parsed_mod = self._parsed_provider_of(nd);
    }
    for item in nd.items {
        if not isinstance(item, ModuleItem) {
            continue;
        }
        sym_name = item.name.value;
        local_name = item.alias.sym_name if item.alias else sym_name;
        walker_node = source_walkers.get(sym_name);
        if walker_node is None and provider_mod is not None {
            found = self._find_archetype(provider_mod, sym_name);
            if isinstance(found, Archetype) and found.arch_kind == 'walker' {
                walker_node = found;
            }
        }
        if walker_node is None and parsed_mod is not None {
            found = self._find_archetype(parsed_mod, sym_name);
            if isinstance(found, Archetype) and found.arch_kind == 'walker' {
                walker_node = found;
            }
        }
        if walker_node is not None {
            walker_mod = walker_node.find_parent_of_type(Module);
            self._collect_boundary_type(walker_node.sym_name, walker_mod);
            (param_names, param_types) = self._extract_walker_has_fields(walker_node);
            binding = InteropBinding(
                name=sym_name,
                source_context=InteropContext.SERVER,
                callers={caller_ctx},
                ret_type=walker_node.sym_name,
                param_types=param_types,
                param_names=param_names,
                ast_node=walker_node,
                source_module=module_name,
                type_scope=walker_mod.loc.mod_path if walker_mod else '',
                kind='walker',
                provider_app=provider_app
            );
            manifest.bindings[local_name] = binding;
            continue;
        }
        ability_node: (Ability | None) = source_abilities.get(sym_name);
        if ability_node is None and provider_mod is not None {
            ability_node = ability_of_symbol(provider_mod.lookup(sym_name));
        }
        if ability_node is None and parsed_mod is not None {
            ability_node = self._find_ability(parsed_mod, sym_name);
        }
        if ability_node is None
            and (cross_app or caller_ctx == InteropContext.CLIENT) {
            type_mod = (
                provider_mod
                    if (provider_mod is not None and not provider_mod.stub_only)
                    else parsed_mod
            );
            if self._register_type_import(nd, item, type_mod, caller_ctx) {
                continue;
            }
        }
        if provider_app {
            self._check_provider_pub(nd, item);
        }
        (ret_type, param_types, param_names) = self._signature_of_decl(ability_node);
        binding = InteropBinding(
            name=sym_name,
            source_context=InteropContext.SERVER,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability_node,
            source_module=module_name,
            kind='function',
            provider_app=provider_app
        );
        manifest.bindings[local_name] = binding;
    }
    if provider_app and provider_route {
        manifest.provider_routes[provider_app] = provider_route;
    }
    self._record_app_edge(nd);
}

impl BoundaryAnalysisPass._register_na_client_import(nd: Import) -> None {
    if nd.is_typed {
        return;
    }
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    import from jaclang.compiler.passes.wasm_contract {
        function_contract,
        host_contracts
    }
    import from jaclang.compiler.frontend.diagnostics { E5083, E5100 }
    if not nd.from_loc or not nd.items {
        return;
    }
    facts = nd.boundary_facts;
    resolved_path = facts.from_loc_resolved if facts else None;
    if resolved_path is None or not resolved_path {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    stem = native_wasm_stem(resolved_path);
    for existing in manifest.client_native_imports {
        other = existing.source_module or '';
        if other and other != resolved_path and native_wasm_stem(other) == stem {
            self.emit(
                E5083, node_override=nd, stem=stem, path=resolved_path, other=other
            );
            break;
        }
    }
    for item in nd.items {
        if not isinstance(item, ModuleItem) {
            continue;
        }
        sym_name = item.name.value;
        local_name = item.alias.sym_name if item.alias else sym_name;
        decl = self._resolved_native_decl(item.name);
        if decl is None {
            target = facts.na_target_decls.get(sym_name) if facts else None;
            if target is not None {
                decl = target;
            } elif facts and sym_name in facts.na_unmappable_targets {
                self.emit(E5100, node_override=item, name=sym_name, module=stem);
                continue;
            }
        }
        if decl is None {
            continue;
        }
        contract = function_contract(decl);
        manifest.native_host_imports[stem] = host_contracts(
            decl.find_parent_of_type(Module), self.prog
        );
        (ret_type, param_types, param_names) = self._signature_of_decl(decl);
        manifest.bindings[local_name] = InteropBinding(
            name=sym_name,
            source_context=InteropContext.NATIVE,
            callers={InteropContext.CLIENT},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=decl,
            source_module=resolved_path,
            native_contract=contract
        );
    }
}

impl BoundaryAnalysisPass._register_client_bridged_import(nd: Import) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    facts = nd.boundary_facts;
    cross_app = import_crosses_apps(nd);
    if cross_app {
        for item in nd.items {
            if isinstance(item, ModuleItem) {
                self._check_provider_pub(nd, item);
            }
        }
        self._record_app_edge(nd);
    }
    if not facts or not is_client_boundary_import(nd) {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    module_name = nd.from_loc.base_module_name if nd.from_loc else '';
    provider_app = (import_provider_app(nd) or '') if cross_app else '';
    provider_route = import_provider_route(nd) if provider_app else '';
    for item in nd.items {
        if not isinstance(item, ModuleItem) {
            continue;
        }
        sym_name = item.name.value;
        local_name = item.alias.sym_name if item.alias else sym_name;
        ability = facts.bridged_decls.get(sym_name);
        if ability is None {
            source_mod = self._provider_module_of(nd);
            if source_mod is not None
                and classify_client_import_item(source_mod, item)
                    != ClientImportVerdict.CLIENT {
                self._register_type_import(nd, item, source_mod, InteropContext.CLIENT);
            }
            continue;
        }
        (ret_type, param_types, param_names) = self._signature_of_decl(ability);
        manifest.bindings[local_name] = InteropBinding(
            name=sym_name,
            source_context=InteropContext.SERVER,
            callers={InteropContext.CLIENT},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability,
            source_module=module_name,
            kind='function',
            provider_app=provider_app
        );
    }
    if provider_app and provider_route {
        manifest.provider_routes[provider_app] = provider_route;
    }
}

impl BoundaryAnalysisPass._register_type_import(
    nd: Import,
    item: ModuleItem,
    source_mod: (Module | None),
    caller_ctx: InteropContext
) -> bool {
    import from jaclang.compiler.driver.boundary_classify { import_provider_app }
    info = self._collect_boundary_type(item.name.value, source_mod);
    if info is None or info.kind not in ('obj', 'enum', 'node', 'edge') {
        return False;
    }
    if caller_ctx == InteropContext.SERVER and info.kind in ('node', 'edge') {
        self._reject_owned_type_import(nd, item, info.kind);
        return True;
    }
    local_name = item.alias.sym_name if item.alias else item.name.value;
    self.ir_in.gen.interop_manifest.bindings[local_name] = InteropBinding(
        name=item.name.value,
        source_context=InteropContext.SERVER,
        callers={caller_ctx},
        ret_type=item.name.value,
        source_module=nd.from_loc.base_module_name if nd.from_loc else '',
        type_scope=(source_mod or self.ir_in).loc.mod_path,
        kind='type',
        provider_app=import_provider_app(nd) or ''
    );
    return True;
}

impl BoundaryAnalysisPass._provider_module_of(nd: Import) -> (Module | None) {
    import from jaclang.compiler.driver.boundary_classify {
        bridgeable_import_target,
        symbol_linked_source_module
    }
    facts = nd.boundary_facts;
    if facts is not None {
        decls = list(facts.sv_walkers.values()) + list(facts.sv_abilities.values());
        for decl in decls {
            linked = decl.find_parent_of_type(Module);
            if linked is not None {
                return linked;
            }
        }
    }
    linked_mod = symbol_linked_source_module(nd);
    if linked_mod is not None and linked_mod is not self.ir_in {
        return linked_mod;
    }
    resolved = bridgeable_import_target(nd);
    if resolved is None {
        return None;
    }
    return self.prog.load_dependency_module(resolved, need_tree=True);
}

impl BoundaryAnalysisPass._record_app_edge(nd: Import) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        module_app,
        import_provider_app
    }
    provider_app = import_provider_app(nd);
    if provider_app is None {
        return;
    }
    consumer_app = module_app(self.ir_in) or '';
    if provider_app == consumer_app {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    app_edge = (consumer_app, provider_app);
    if app_edge not in manifest.app_edges {
        manifest.app_edges.append(app_edge);
    }
    if consumer_app {
        self._check_app_cycle(nd, consumer_app, provider_app);
    }
}

impl BoundaryAnalysisPass._bridge_targets(mod: Module) -> list[tuple[(str, str)]] {
    import from jaclang.compiler.driver.boundary_classify {
        bridgeable_import_target,
        module_app,
        import_provider_app
    }
    consumer_app = module_app(mod) or '';
    targets: list[tuple[(str, str)]] = [];
    for imp in mod.get_all_sub_nodes(Import) {
        provider_app = import_provider_app(imp);
        if provider_app is None or provider_app == consumer_app {
            continue;
        }
        resolved = bridgeable_import_target(imp);
        if resolved is None {
            continue;
        }
        targets.append((provider_app, resolved));
    }
    return targets;
}

impl BoundaryAnalysisPass._check_app_cycle(
    nd: Import, consumer_app: str, provider_app: str
) -> None {
    import from jaclang.compiler.driver.boundary_classify { bridgeable_import_target }
    import from jaclang.compiler.frontend.diagnostics { E5104 }
    start = bridgeable_import_target(nd);
    if start is None {
        return;
    }
    visited: set[str] = set();
    stack: list[tuple[(str, list[str])]] = [(start, [consumer_app, provider_app])];
    while stack {
        (path, chain) = stack.pop();
        if path in visited {
            continue;
        }
        visited.add(path);
        mod = self._provider_module_of(nd) if path == start else None;
        if mod is None {
            mod = self.prog.load_dependency_module(path, need_tree=True);
        }
        if mod is None {
            continue;
        }
        for (app, target_path) in self._bridge_targets(mod) {
            if app == consumer_app {
                self.emit(E5104, node_override=nd, cycle=' -> '.join(chain + [app]));
                return;
            }
            if app in chain {
                continue;
            }
            stack.append((target_path, chain + [app]));
        }
    }
}

impl BoundaryAnalysisPass._find_ability(mod: Module, target: str) -> (Ability | None) {
    for stmt in mod.body {
        if isinstance(stmt, Ability) and stmt.sym_name == target {
            return stmt;
        }
    }
    return None;
}

impl BoundaryAnalysisPass._parsed_provider_of(nd: Import) -> (Module | None) {
    import os;
    import from jaclang.compiler.driver.boundary_classify { bridgeable_import_target }
    target = bridgeable_import_target(nd);
    if not target or not os.path.isfile(str(target)) {
        return None;
    }
    return self.prog.load_dependency_module(str(target), need_tree=True);
}

impl BoundaryAnalysisPass._reject_owned_type_import(
    nd: Import, item: ModuleItem, kind: str
) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        module_app,
        import_provider_app
    }
    import from jaclang.compiler.frontend.diagnostics { E5108 }
    consumer = module_app(self.ir_in) or self.ir_in.name;
    self.emit(
        E5108,
        node_override=item,
        consumer=consumer,
        name=item.name.value,
        kind=kind,
        provider=import_provider_app(nd) or ''
    );
}

impl BoundaryAnalysisPass._check_provider_pub(nd: Import, item: ModuleItem) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        ClientImportVerdict,
        classify_client_import_item,
        module_app,
        import_provider_app
    }
    import from jaclang.compiler.symbol_utils {
        decl_has_access,
        import_target_pinned_server
    }
    import from jaclang.compiler.frontend.diagnostics { E5106 }
    provider_mod = self._provider_module_of(nd);
    if provider_mod is None {
        return;
    }
    verdict = classify_client_import_item(provider_mod, item);
    if verdict == ClientImportVerdict.UNKNOWN and provider_mod.stub_only {
        parsed = self._parsed_provider_of(nd);
        if parsed is not None {
            verdict = classify_client_import_item(parsed, item);
        }
    }
    if verdict != ClientImportVerdict.DEAD {
        return;
    }
    if import_target_pinned_server(nd) and decl_has_access(provider_mod, item) {
        return;
    }
    consumer = module_app(self.ir_in) or self.ir_in.name;
    self.emit(
        E5106,
        node_override=item,
        consumer=consumer,
        name=item.name.value,
        provider=import_provider_app(nd) or ''
    );
}

impl BoundaryAnalysisPass._extract_walker_has_fields(
    walker_nd: any
) -> tuple[list[str], list[str]] {
    names: list[str] = [];
    types: list[str] = [];
    if (not walker_nd) or (not walker_nd.body) {
        return (names, types);
    }
    body_items = walker_nd.body
        if isinstance(walker_nd.body, list)
        else [walker_nd.body];
    for item in body_items {
        has_vars: list[HasVar] = [];
        if isinstance(item, HasVar) {
            has_vars = [item];
        } elif isinstance(item, ArchHas) {
            has_vars = [
                k
                for k in item.kid
                if isinstance(k, HasVar)
            ];
        }
        for hv in has_vars {
            fname = hv.name.value;
            ftype: str = 'Any';
            if hv.type_tag and hv.type_tag.tag {
                ftype = self._extract_type_name(hv.type_tag.tag);
            }
            names.append(fname);
            types.append(ftype);
        }
    }
    return (names, types);
}

impl BoundaryAnalysisPass._parse_imported_archetype(
    type_name: str, search_mods: list[Module]
) -> (Archetype | Enum | None) {
    import os;
    for mod in search_mods {
        for imp in mod.get_all_sub_nodes(Import) {
            for item in (imp.items or []) {
                if not isinstance(item, ModuleItem) {
                    continue;
                }
                local = item.alias.sym_name if item.alias else item.name.value;
                if local != type_name {
                    continue;
                }
                try {
                    target = item.from_mod_path.resolve_relative_path();
                } except Exception {
                    continue;
                }
                if not target or not os.path.isfile(str(target)) {
                    continue;
                }
                parsed = self.prog.load_dependency_module(str(target), need_tree=True);
                if parsed is None {
                    continue;
                }
                found = self._find_archetype(parsed, item.name.value);
                if found is not None {
                    return found;
                }
            }
        }
    }
    return None;
}

impl BoundaryAnalysisPass._find_archetype(
    nd: UniNode, target: str
) -> (Archetype | Enum | None) {
    if (isinstance(nd, (Archetype, Enum)) and nd.sym_name == target) {
        return nd;
    }
    for k in nd.kid {
        found = self._find_archetype(k, target);
        if found is not None {
            return found;
        }
    }
    return None;
}

impl BoundaryAnalysisPass.enter_ability with Ability entry {
    if (
        here.sym_name
        and isinstance(here.signature, FuncSignature)
        and here.find_parent_of_type(Ability) is None
        and here.find_parent_of_type(LambdaExpr) is None
    ) {
        nd_cc = here.code_context;
        ctx: InteropContext = InteropContext.SERVER;
        if nd_cc == CodeContext.NATIVE {
            ctx = InteropContext.NATIVE;
        } elif nd_cc == CodeContext.CLIENT {
            ctx = InteropContext.CLIENT;
        } else {
            ctx = self._get_context(here);
        }
        self._func_defs[here.sym_name] = (ctx, here);
    }
}

impl BoundaryAnalysisPass.enter_func_call with FuncCall entry {
    if isinstance(here.target, Name) and here.target.value == "bind_na_host" {
        import from jaclang.compiler.passes.wasm_contract { check_host_call }
        import from jaclang.compiler.frontend.diagnostics { E5110 }
        try {
            check_host_call(here, self.prog);
        } except ValueError as e {
            self.emit(E5110, node_override=here, details=str(e));
        }
    }
    if (
        isinstance(here.target, Name)
        and here.target.sym is not None
        and here.target.sym.decl is not None
    ) {
        _decl_ab = here.target.sym.decl.find_parent_of_type(Ability);
        if (
            _decl_ab is not None and _decl_ab.find_parent_of_type(Ability) is not None
        ) {
            return;
        }
    }
    func_name = None;
    if isinstance(here.target, Name) {
        func_name = here.target.value;
    } elif isinstance(here.target, NameAtom) {
        func_name = here.target.sym_name;
    } elif isinstance(here.target, AtomTrailer) and here.target.is_attr {
        base = here.target.target;
        base_name = None;
        if isinstance(base, Name) {
            base_name = base.value;
        } elif isinstance(base, NameAtom) {
            base_name = base.sym_name;
        }
        if base_name is not None and base_name in self._imported_native_modules {
            right = here.target.right;
            right_name: (str | None) = None;
            if isinstance(right, AstSymbolNode) {
                right_name = right.sym_name;
            }
            if not right_name and isinstance(right, Token) {
                right_name = right.value;
            }

            _is_native_ctx = (
                self._get_context(here) == InteropContext.NATIVE
                or self._in_native_module()
            );
            if isinstance(right_name, str) and right_name and _is_native_ctx {
                (mod_path, _ctx) = self._imported_native_modules[base_name];
                _mfst = self.ir_in.gen.interop_manifest;
                if right_name not in _mfst.bindings {
                    _decl = self._resolved_native_decl(here.target.right);
                    (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                    _mfst.bindings[right_name] = InteropBinding(
                        name=right_name,
                        source_context=InteropContext.NATIVE,
                        callers={InteropContext.NATIVE},
                        ret_type=_rt,
                        param_types=_pts,
                        param_names=_pns,
                        ast_node=_decl,
                        source_module=mod_path
                    );
                } else {
                    _mfst.bindings[right_name].callers.add(InteropContext.NATIVE);
                }
            }
            return;
        }
        func_name = base_name;
    }
    if not func_name {
        return;
    }
    caller_ctx = self._get_context(here);
    manifest = self.ir_in.gen.interop_manifest;
    if (func_name in self._imported_native_funcs) {
        (source_module, import_ctx) = self._imported_native_funcs[func_name];
        if (caller_ctx == InteropContext.NATIVE or self._in_native_module()) {
            if (func_name not in manifest.bindings) {
                _decl = self._resolved_native_decl(here.target);
                (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                binding = InteropBinding(
                    name=func_name,
                    source_context=InteropContext.NATIVE,
                    callers={InteropContext.NATIVE},
                    ret_type=_rt,
                    param_types=_pts,
                    param_names=_pns,
                    ast_node=_decl,
                    source_module=source_module
                );
                manifest.bindings[func_name] = binding;
            } else {
                manifest.bindings[func_name].callers.add(InteropContext.NATIVE);
            }
        }
        return;
    }
    if (func_name not in self._func_defs) {
        return;
    }
    (callee_ctx, callee_node) = self._func_defs[func_name];
    if (caller_ctx == callee_ctx) {
        return;
    }
    if (func_name in manifest.bindings) {
        manifest.bindings[func_name].callers.add(caller_ctx);
    } else {
        (ret_type, param_types, param_names) = self._signature_of_decl(callee_node);
        binding = InteropBinding(
            name=func_name,
            source_context=callee_ctx,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=callee_node
        );
        manifest.bindings[func_name] = binding;
    }
}

impl BoundaryAnalysisPass._extract_subscript_inner(expr: (UniNode | None)) -> str {
    if expr is None {
        return '';
    }

    if isinstance(expr, Name) {
        return expr.value;
    }
    if isinstance(expr, Token) {
        return expr.value;
    }

    if isinstance(expr, IndexSlice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }

    if isinstance(expr, Slice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }

    if isinstance(expr, (ListVal, TupleVal)) {
        if expr.values {
            parts = [self._extract_type_name(v) for v in expr.values];
            return ', '.join(
                p
                for p in parts
                if p
            );
        }
    }
    return '';
}

impl BoundaryAnalysisPass._extract_all_subscript_types(
    expr: (UniNode | None)
) -> list[str] {
    if expr is None {
        return [];
    }
    result: list[str] = [];
    if isinstance(expr, (Name, Token)) {
        result.extend(self._extract_all_type_names(expr));
        return result;
    }
    if isinstance(expr, (ListVal, TupleVal)) {
        for v in expr.values {
            result.extend(self._extract_all_type_names(v));
        }
        return result;
    }

    for k in expr.kid {
        result.extend(self._extract_all_subscript_types(k));
    }
    return result;
}

impl BoundaryAnalysisPass._extract_all_type_names(expr: (UniNode | None)) -> list[str] {
    prims = {
        'str',
        'int',
        'float',
        'bool',
        'None',
        'Any',
        'list',
        'dict',
        'tuple',
        'set',
        'frozenset',
        'bytes',
        'object',
        'type',
        'JsxElement'
    };
    if expr is None {
        return [];
    }
    if isinstance(expr, Name) {
        if expr.value not in prims {
            return [expr.value];
        }
        return [];
    }
    if isinstance(expr, Token) {
        if expr.value not in prims {
            return [expr.value];
        }
        return [];
    }

    if isinstance(expr, BuiltinType) {
        return [];
    }

    if isinstance(expr, AtomTrailer) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.target));
        if expr.right {
            result.extend(self._extract_all_subscript_types(expr.right));
        }
        return result;
    }

    if isinstance(expr, BinaryExpr) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.left));
        result.extend(self._extract_all_type_names(expr.right));
        return result;
    }
    return [];
}

impl BoundaryAnalysisPass._collect_boundary_type(
    type_name: str, source_mod: (Module | None)
) -> (BoundaryTypeInfo | None) {
    prims = {
        'str',
        'int',
        'float',
        'bool',
        'None',
        'Any',
        'list',
        'dict',
        'tuple',
        'set',
        'frozenset',
        'bytes',
        'object',
        'type',
        'JsxElement'
    };
    if type_name in prims {
        return None;
    }
    manifest = self.ir_in.gen.interop_manifest;
    scope = source_mod.loc.mod_path if source_mod else self.ir_in.loc.mod_path;
    scope_names = manifest.boundary_type_names.setdefault(scope, {});
    if type_name in scope_names {
        return manifest.boundary_types[scope_names[type_name]];
    }

    search_mods: list[Module] = [];
    if source_mod {
        search_mods.append(source_mod);
    }
    search_mods.append(self.ir_in);
    arch_node: (Archetype | Enum | None) = None;
    for mod in search_mods {
        sym = mod.sym_tab.lookup(type_name, deep=True) if mod.sym_tab else None;
        if sym and sym.defn {
            candidate: (UniNode | None) = sym.defn[0];
            if isinstance(candidate, NameAtom) and candidate.parent {
                candidate = candidate.parent;
            }

            if isinstance(candidate, (Archetype, Enum)) {
                arch_node = candidate;
                break;
            }

            resolved = resolved_decl_of(sym);
            if resolved is not None {
                target = resolved.name_of;
                if isinstance(target, (Archetype, Enum)) {
                    arch_node = target;
                    break;
                }
            }
        }
    }

    if arch_node is None {
        for mod in search_mods {
            try {
                arch_node = self._find_archetype(mod, type_name);
            } except Exception {
                arch_node = None;
            }
            if arch_node is not None {
                break;
            }
        }
    }
    if arch_node is None {
        arch_node = self._parse_imported_archetype(type_name, search_mods);
    }
    if arch_node is None {
        return None;
    }

    import from jaclang.compiler.frontend.codeinfo { endpoint_key }
    arch_mod = arch_node.find_parent_of_type(Module) or source_mod or self.ir_in;
    type_id = endpoint_key(arch_mod, 'type', arch_node.sym_name);
    scope_names[type_name] = type_id;
    manifest.boundary_type_names.setdefault(arch_mod.loc.mod_path, {})[
        arch_node.sym_name
    ] = type_id;
    if type_id in manifest.boundary_types {
        return manifest.boundary_types[type_id];
    }

    if isinstance(arch_node, Archetype) {
        _ak = arch_node.arch_kind;
        kind: str = "obj";
        if (isinstance(_ak, str) and _ak in ("node", "edge", "walker")) {
            kind = _ak;
        }
        fields: list[tuple[(str, str)]] = [];
        fdefaults: dict[(str, any)] = {};
        nested: list[str] = [];
        for base in arch_node.base_classes {
            nested.extend(self._extract_all_type_names(base));
        }

        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                has_vars: list[HasVar] = [];
                if isinstance(item, HasVar) {
                    has_vars = [item];
                } elif isinstance(item, ArchHas) {
                    has_vars = [
                        k
                        for k in item.kid
                        if isinstance(k, HasVar)
                    ];
                }
                for hv in has_vars {
                    field_name = hv.sym_name;
                    field_type = "Any";
                    if hv.type_tag {
                        field_type = self._extract_type_name(hv.type_tag.tag);
                        for nested_type in self._extract_all_type_names(
                            hv.type_tag.tag
                        ) {
                            if nested_type != type_name {
                                nested.append(nested_type);
                            }
                        }
                    }
                    fields.append((field_name, field_type));
                    if hv.value is not None {
                        (rep, val) = self._literal_default(hv.value);
                        if rep {
                            fdefaults[field_name] = val;
                        }
                    }
                }
            }
        }
        info = BoundaryTypeInfo(
            name=arch_node.sym_name,
            kind=kind,
            type_id=type_id,
            type_scope=arch_mod.loc.mod_path,
            fields=fields,
            field_defaults=fdefaults,
            nested_types=nested
        );
        manifest.boundary_types[type_id] = info;

        for nt in nested {
            self._collect_boundary_type(nt, arch_mod);
        }
        return info;
    }

    if isinstance(arch_node, Enum) {
        members: list[tuple[(str, any)]] = [];
        next_auto = 1;
        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                if isinstance(item, Assignment) {
                    member_name = '';
                    member_val = None;
                    targets = item.target
                        if isinstance(item.target, list)
                        else [item.target];
                    for tgt in targets {
                        if isinstance(tgt, AstSymbolNode) {
                            member_name = tgt.sym_name;
                            break;
                        }
                    }
                    if item.value {
                        if isinstance(item.value, MultiString) {
                            if item.value.strings {
                                s = item.value.strings[0];
                                raw = s.value if isinstance(s, String) else str(s);
                                if isinstance(raw, str) {
                                    member_val = raw.strip('"').strip("'");
                                } else {
                                    member_val = raw;
                                }
                            }
                        } elif isinstance(item.value, Token) {
                            member_val = item.value.value;
                            try {
                                member_val = int(item.value.value);
                                next_auto = member_val + 1;
                            } except ValueError {}
                        }
                    } else {
                        member_val = next_auto;
                        next_auto += 1;
                    }
                    if member_name {
                        members.append((member_name, member_val));
                    }
                }
            }
        }
        info = BoundaryTypeInfo(
            name=arch_node.sym_name,
            kind="enum",
            type_id=type_id,
            type_scope=arch_mod.loc.mod_path,
            enum_members=members
        );
        manifest.boundary_types[type_id] = info;
        return info;
    }
    return None;
}

impl BoundaryAnalysisPass._literal_default(
    expr: (UniNode | None)
) -> tuple[(bool, any)] {
    if isinstance(expr, Null) {
        return (True, None);
    }
    if isinstance(expr, (Bool, Int, Float)) {
        return (True, expr.lit_value);
    }
    if isinstance(expr, MultiString) {
        for part in expr.strings {
            if not isinstance(part, String) {
                return (False, None);
            }
        }
    }
    if isinstance(expr, (String, MultiString)) {
        val = expr.lit_value;
        return (True, val) if isinstance(val, str) else (False, None);
    }
    if (
        isinstance(expr, UnaryExpr)
        and expr.op.value == '-'
        and isinstance(expr.operand, (Int, Float))
    ) {
        return (True, -expr.operand.lit_value);
    }
    if isinstance(expr, (ListVal, TupleVal)) {
        items = [];
        for v in (expr.values or []) {
            (rep, val) = self._literal_default(v);
            if not rep {
                return (False, None);
            }
            items.append(val);
        }
        return (True, items);
    }
    if isinstance(expr, DictVal) {
        entries = {};
        for kv in expr.kv_pairs {
            if not isinstance(kv, KVPair) or kv.key is None {
                return (False, None);
            }
            if isinstance(kv.key, Name) {
                (krep, kval) = (True, kv.key.value);
            } else {
                (krep, kval) = self._literal_default(kv.key);
            }
            (vrep, vval) = self._literal_default(kv.value);
            if (not krep or not vrep or not isinstance(kval, str)) {
                return (False, None);
            }
            entries[kval] = vval;
        }
        return (True, entries);
    }
    return (False, None);
}

impl BoundaryAnalysisPass.after_pass -> None {
    import from jaclang.compiler.frontend.diagnostics { E5093 }
    import from jaclang.runtime.scalars { sized_scalar_names }
    manifest = self.ir_in.gen.interop_manifest;

    ctypes_wire: set = {'int', 'float', 'bool', 'str'} | set(sized_scalar_names());
    for binding in manifest.bindings.values() {
        crosses_ctypes = (
            binding.source_context == InteropContext.SERVER
            and InteropContext.NATIVE in binding.callers
        );
        if not crosses_ctypes {
            continue;
        }
        err_node = binding.ast_node
            if isinstance(binding.ast_node, UniNode)
            else self.ir_in;
        for (i, pt) in enumerate(binding.param_types) {
            if pt not in ctypes_wire {
                pname = binding.param_names[i]
                    if i < len(binding.param_names)
                    else str(i);
                self.emit(
                    E5093,
                    node_override=err_node,
                    type=pt,
                    what=f"parameter '{pname}'",
                    name=binding.name
                );
            }
        }
        if binding.ret_type not in ctypes_wire and binding.ret_type != 'None' {
            self.emit(
                E5093,
                node_override=err_node,
                type=binding.ret_type,
                what="the return",
                name=binding.name
            );
        }
    }

    for binding in manifest.server_exports_to_client {
        if binding.ast_node and isinstance(binding.ast_node, Ability) {
            cl_src_mod: (Module | None) = None;
            walk_node: (UniNode | None) = binding.ast_node;
            while walk_node {
                if isinstance(walk_node, Module) {
                    cl_src_mod = walk_node;
                    break;
                }
                walk_node = walk_node.parent;
            }
            binding.type_scope = cl_src_mod.loc.mod_path
                if cl_src_mod
                else self.ir_in.loc.mod_path;
            sig = binding.ast_node.signature;
            if isinstance(sig, FuncSignature) {
                if sig.return_type {
                    for tn in self._extract_all_type_names(sig.return_type) {
                        self._collect_boundary_type(tn, cl_src_mod);
                    }
                }
                for p in sig.params {
                    if isinstance(p, ParamVar) and p.type_tag {
                        for tn in self._extract_all_type_names(p.type_tag.tag) {
                            self._collect_boundary_type(tn, cl_src_mod);
                        }
                    }
                }
            }
        }
    }

    for binding in manifest.server_exports_to_server {
        source_mod_obj: (Module | None) = None;
        if (binding.ast_node and isinstance(binding.ast_node, Ability)) {
            walker_node: (UniNode | None) = binding.ast_node;
            while walker_node {
                if isinstance(walker_node, Module) {
                    source_mod_obj = walker_node;
                    break;
                }
                walker_node = walker_node.parent;
            }
            sig = binding.ast_node.signature;
            binding.type_scope = source_mod_obj.loc.mod_path if source_mod_obj else '';
            if isinstance(sig, FuncSignature) {
                if sig.return_type {
                    for tn in self._extract_all_type_names(sig.return_type) {
                        self._collect_boundary_type(tn, source_mod_obj);
                    }
                }
                for p in sig.params {
                    if isinstance(p, ParamVar) and p.type_tag {
                        for tn in self._extract_all_type_names(p.type_tag.tag) {
                            self._collect_boundary_type(tn, source_mod_obj);
                        }
                    }
                }
            }
        }
    }

    has_client = False;
    if self.ir_in and self.ir_in.body {
        for item in self.ir_in.body {
            if item.in_client_context() {
                has_client = True;
                break;
            }
        }
    }
    if has_client and self.ir_in and self.ir_in.body {
        for item in self.ir_in.body {
            if (
                isinstance(item, (Archetype, Enum))
                and not item.in_client_context()
                and not item.in_native_context()
            ) {
                self._collect_boundary_type(item.sym_name, None);
            }
        }
    }

    import from jaclang.compiler.frontend.codeinfo { endpoint_key }
    for binding in self.ir_in.gen.interop_manifest.bindings.values() {
        if binding.ast_node is None or binding.kind == 'type' {
            continue;
        }
        source = binding.ast_node.find_parent_of_type(Module);
        if source is None {
            continue;
        }
        kind = "func" if binding.kind == "function" else binding.kind;
        binding.endpoint_id = endpoint_key(source, kind, binding.name);
    }

    self._record_access_levels(manifest);
}

impl BoundaryAnalysisPass._record_access_levels(manifest: any) -> None {
    if not (self.ir_in and self.ir_in.body) {
        return;
    }
    for item in self.ir_in.body {
        if isinstance(item, Ability) and item?.sym_name {
            is_pub = item.access is not None and item.access.tag.name == Tok.KW_PUB;
            manifest.func_access[item.sym_name] = not is_pub;
        } elif isinstance(item, Archetype) and item?.sym_name {
            is_walker = bool(item?.arch_type) and item.arch_type?.name == Tok.KW_WALKER;
            if is_walker {
                is_pub = item.access is not None and item.access.tag.name == Tok.KW_PUB;
                manifest.walker_access[item.sym_name] = not is_pub;
            }
        }
    }
}


impl BoundaryAnalysisPass.enter_atom_trailer with AtomTrailer entry {
    if not here.is_attr or self._get_context(here) != InteropContext.CLIENT {
        return;
    }
    import from jaclang.compiler.types.types { ClassType }
    target_type = here.target.narrowed_type or here.target.type;
    scope = target_type.shared.symbol_table
        if isinstance(target_type, ClassType)
        else None;
    if isinstance(scope, Archetype) and scope.in_native_context() {
        import from jaclang.compiler.frontend.diagnostics { E5112 }
        self.emit(E5112, node_override=here, name=scope.sym_name);
    }
}
