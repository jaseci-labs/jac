impl _coerce_module(module: uni.Module, context: CodeContext) {
    module.set_code_context(context);
}

impl _coerce_client_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.CLIENT);
}

impl _coerce_native_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.NATIVE);
}

impl _stamp_context_element(elem: uni.UniNode, context: CodeContext) {
    if not isinstance(elem, uni.ContextAwareNode) {
        return;
    }
    elem.code_context = context;
    if (isinstance(elem, uni.ModuleCode) and elem.body) {
        for inner in elem.body {
            if isinstance(inner, uni.ContextAwareNode) {
                inner.code_context = context;
            }
        }
    }
}

impl hub_module_for_path(path: str, prog: JacProgram) -> (uni.Module | None) {
    hub = prog.mod.hub;
    if not hub {
        return None;
    }
    if path in hub {
        return hub[path];
    }
    abs_path = os.path.abspath(path);
    if abs_path in hub {
        return hub[abs_path];
    }
    normalized = os.path.normcase(os.path.realpath(abs_path));
    for (hub_path, hub_mod) in hub.items() {
        if os.path.normcase(os.path.realpath(os.path.abspath(hub_path)))
            == normalized {
            return hub_mod;
        }
    }
    return None;
}

impl module_has_client_top(module: (uni.Module | None)) -> bool {
    if module is None {
        return False;
    }
    for stmt in module.body {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            return True;
        }
    }
    return False;
}

impl ability_delegates_to_model(ab: uni.Ability) -> bool {
    if isinstance(ab.body, uni.Expr) {
        return True;
    }
    if isinstance(ab.body, uni.ImplDef) and isinstance(ab.body.body, uni.Expr) {
        return True;
    }
    sig = ab.signature;
    return (
        isinstance(sig, uni.FuncSignature)
        and sig.return_type is not None
        and isinstance(sig.return_type, uni.BinaryExpr)
        and isinstance(sig.return_type.op, uni.Token)
        and sig.return_type.op.name == Tok.KW_BY
    );
}

impl is_server_anchored_module(module: (uni.Module | None)) -> bool {
    if module is None {
        return True;
    }
    anchor_path = module.loc.mod_path or '';
    if anchor_path and is_service_app_entry(anchor_path) {
        return True;
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_kind is not None and not ModuleFacts.is_test_code(arch) {
            return True;
        }
    }
    for inline_py in module.get_all_sub_nodes(uni.PyInlineCode) {
        if not ModuleFacts.is_test_code(inline_py) {
            return True;
        }
    }
    for stmt in ModuleFacts.iter_placement_stmts(module) {
        if isinstance(stmt, uni.TypedCtxBlock) {
            return True;
        }
    }
    for ab in module.get_all_sub_nodes(uni.Ability) {
        if ability_delegates_to_model(ab) and not ModuleFacts.is_test_code(ab) {
            return True;
        }
    }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls
            or imp.is_virtual_jac
            or imp.has_string_path
            or ModuleFacts.is_test_code(imp) {
            continue;
        }
        if classify_import(imp).world == 'py' {
            return True;
        }
    }
    return False;
}

impl classify_import(imp: uni.Import) -> BareImportVerdict {
    if imp.from_loc is None {
        return BareImportVerdict();
    }
    if imp.is_jac {
        return BareImportVerdict(
            world='jac', rule='jac module', path=imp.from_loc.resolve_relative_path()
        );
    }
    return classify_bare_import(imp.from_loc.dot_path_str, imp.loc.mod_path or '');
}

impl module_own_native_anchor(module: (uni.Module | None)) -> bool {
    if module is None {
        return False;
    }
    for tag in module.get_all_sub_nodes(uni.SubTag) {
        if tag.ownership != OwnershipKind.NONE {
            return True;
        }
    }
    for stmt in module.body {
        if isinstance(stmt, uni.Import) and stmt.has_clib_decls {
            return True;
        }
    }
    return False;
}

impl plain_native_import_target(nd: uni.Import, prog: JacProgram) -> (str | None) {
    if (
        nd.is_service_import
        or nd.is_typed
        or nd.is_virtual_jac
        or nd.from_loc is None
        or not nd.items
    ) {
        return None;
    }
    resolved = nd.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    real_resolved = os.path.realpath(resolved);
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    jaclang_root = os.path.realpath(jaclang_pkg_root());
    if (
        real_resolved.startswith(jaclang_root + os.sep)
        and (os.sep + 'na_stdlib' + os.sep) not in real_resolved
    ) {
        return None;
    }
    if effective_module_pin(resolved, prog) == 'native' {
        return resolved;
    }
    target = hub_module_for_path(resolved, prog);
    if target is None {
        import from jaclang.compiler.placement.placement_solver { _materialize_module }
        target = _materialize_module(resolved, prog);
    }
    if target is None {
        return None;
    }
    if (
        target.decided_codespace == 'native'
        or target.declares_codespace(CodeContext.NATIVE)
        or module_own_native_anchor(target)
    ) {
        return resolved;
    }
    return None;
}

impl import_declares_native_target(
    nd: uni.Import, prog: (JacProgram | None) = None
) -> bool {
    if nd.from_loc is None {
        return False;
    }
    try {
        resolved = nd.from_loc.resolve_relative_path();
    } except Exception {
        return False;
    }
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return False;
    }
    return effective_module_pin(resolved, prog) == 'native';
}

impl native_only_import_target(nd: uni.Import, prog: JacProgram) -> (str | None) {
    resolved = plain_native_import_target(nd, prog);
    if resolved is None {
        return None;
    }
    if effective_module_pin(resolved, prog) == 'native' {
        return resolved;
    }
    target = hub_module_for_path(resolved, prog);
    if target is not None and module_own_native_anchor(target) {
        return resolved;
    }
    return None;
}

impl _python_side_emits(stmt: uni.UniNode, native_module: bool) -> bool {
    owner = stmt.top_element or stmt;
    if not isinstance(owner, uni.ContextAwareNode) {
        return True;
    }
    if owner.code_context == CodeContext.CLIENT and not owner.codespace_dual {
        return False;
    }
    if owner.code_context != CodeContext.NATIVE {
        return True;
    }
    if isinstance(owner, uni.Test) {
        return False;
    }
    return native_module;
}

impl python_side_name_refs(mod: uni.Module) -> set[str] {
    native_module = mod.decided_codespace == 'native';
    emitted: list[uni.UniNode] = [];
    for (body, _strip) in ModuleFacts.iter_woven_segments(mod) {
        for stmt in body {
            if not isinstance(stmt, uni.Import)
                and _python_side_emits(stmt, native_module) {
                emitted.append(stmt);
            }
        }
    }
    names: set[str] = set();
    for stmt in emitted {
        in_imports: set[int] = set();
        for imp in stmt.get_all_sub_nodes(uni.Import) {
            in_imports.update(id(nm) for nm in imp.get_all_sub_nodes(uni.Name));
        }
        for nm in stmt.get_all_sub_nodes(uni.Name) {
            if id(nm) not in in_imports {
                names.add(nm.value);
            }
        }
    }
    return names;
}

impl import_bound_names(nd: uni.Import) -> list[str] {
    bound: list[str] = [];
    for item in nd.items {
        if isinstance(item, uni.ModuleItem) {
            bound.append(
                item.alias.sym_name if item.alias is not None else item.name.value
            );
        }
    }
    for decl in nd.clib_decls or [] {
        if isinstance(decl, uni.Archetype) {
            bound.append(decl.name.value);
        } elif isinstance(decl, uni.Ability) and decl.name_ref is not None {
            bound.append(decl.name_ref.sym_name);
        }
    }
    return bound;
}

impl clib_decl_type_names(nd: uni.Import) -> set[str] {
    names: set[str] = set();
    for decl in nd.clib_decls or [] {
        for nm in decl.get_all_sub_nodes(uni.Name) {
            names.add(nm.value);
        }
    }
    return names;
}

impl is_client_native_edge_import(
    nd: uni.Import, prog: JacProgram, client_tops: (dict[str, bool] | None) = None
) -> bool {
    if nd.code_context == CodeContext.CLIENT {} elif nd.code_context
        == CodeContext.SERVER
        and _has_client_top(nd.find_parent_of_type(uni.Module), client_tops) {} else {
        return False;
    }
    return plain_native_import_target(nd, prog) is not None;
}

impl _has_client_top(
    module: (uni.Module | None), client_tops: (dict[str, bool] | None)
) -> bool {
    if client_tops is None or module is None {
        return module_has_client_top(module);
    }
    key = module.loc.mod_path;
    if key not in client_tops {
        client_tops[key] = module_has_client_top(module);
    }
    return client_tops[key];
}

impl bridgeable_import_target(nd: uni.Import) -> (str | None) {
    if (
        nd.from_loc is None
        or not nd.items
        or nd.is_typed
        or nd.is_virtual_jac
        or nd.has_clib_decls
    ) {
        return None;
    }
    try {
        resolved = nd.from_loc.resolve_relative_path();
    } except Exception {
        return None;
    }
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    import from jaclang.compiler.frontend.codeinfo { is_shared_runtime_module }
    if is_shared_runtime_module(resolved) {
        return None;
    }
    return resolved;
}

impl is_service_app_entry(path: str) -> bool {
    if not path {
        return False;
    }
    app = active_host().app_for_path(path);
    return app is not None and app.has_server;
}

impl module_app(module: (uni.Module | None)) -> (str | None) {
    if module is None {
        return None;
    }
    return module.app;
}

impl import_consumer_app(nd: uni.Import) -> (str | None) {
    return module_app(nd.find_parent_of_type(uni.Module));
}

impl same_workspace(consumer_path: str, provider_path: str) -> bool {
    host = active_host();
    cws = host.workspace(consumer_path);
    pws = host.workspace(provider_path);
    if cws is None or pws is None {
        return False;
    }
    if cws.toml_path == pws.toml_path {
        return True;
    }
    return os.path.realpath(cws.toml_path) == os.path.realpath(pws.toml_path);
}

impl import_provider_spec(nd: uni.Import) -> (AppSpec | None) {
    resolved = bridgeable_import_target(nd);
    if resolved is None {
        return None;
    }
    consumer_path = nd.loc.mod_path if nd.loc else '';
    if not consumer_path or not same_workspace(consumer_path, resolved) {
        return None;
    }
    provider_app = active_host().app_for_path(resolved);
    if provider_app is None or not provider_app.has_server {
        return None;
    }
    consumer_mod = nd.find_parent_of_type(uni.Module);
    if module_app(consumer_mod) == provider_app.name {
        return None;
    }
    return provider_app;
}

impl import_provider_app(nd: uni.Import) -> (str | None) {
    spec = import_provider_spec(nd);
    return spec.name if spec is not None else None;
}

impl import_provider_route(nd: uni.Import) -> str {
    spec = import_provider_spec(nd);
    return spec.effective_route() if spec is not None else '';
}

impl import_crosses_apps(nd: uni.Import) -> bool {
    provider = import_provider_app(nd);
    return provider is not None and provider != import_consumer_app(nd);
}

impl is_service_bridge_import(nd: uni.Import) -> bool {
    if bridgeable_import_target(nd) is None {
        return False;
    }
    if nd.codespace() == CodeContext.CLIENT {
        return False;
    }
    return import_crosses_apps(nd);
}

impl classify_cross_app_import(
    nd: uni.Import, manifest: (InteropManifest | None)
) -> CrossAppKind {
    kind = CrossAppKind.LOCAL;
    if bridgeable_import_target(nd) is not None {
        if is_service_bridge_import(nd) {
            kind = CrossAppKind.SERVICE_BRIDGE;
        } elif manifest is not None and import_binds_client_native(nd, manifest) {
            kind = CrossAppKind.NATIVE_BIND;
        } elif nd.code_context == CodeContext.CLIENT {
            kind = CrossAppKind.CLIENT_BRIDGE;
        }
    }
    facts = nd.boundary_facts;
    if facts is not None
        and (
            manifest is not None or facts.cross_app_kind == CrossAppKind.LOCAL.value
        ) {
        facts.cross_app_kind = kind.value;
    }
    return kind;
}

impl is_client_boundary_import(nd: uni.Import) -> bool {
    return classify_cross_app_import(nd, None) == CrossAppKind.CLIENT_BRIDGE;
}

impl symbol_linked_source_module(nd: uni.Import) -> (uni.Module | None) {
    importer = nd.find_parent_of_type(uni.Module);
    for item in nd.items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            continue;
        }
        sym = item.name.sym;
        if sym is None or sym.decl is None {
            continue;
        }
        if sym.decl.find_parent_of_type(uni.ModuleItem) is not None {
            continue;
        }
        linked = sym.decl.find_parent_of_type(uni.Module);
        if linked is not None and linked is not importer {
            return linked;
        }
    }
    return None;
}

impl _declared_name(stmt: uni.ContextAwareNode) -> (str | None) {
    if isinstance(stmt, uni.Ability) {
        return stmt.name_ref.sym_name if stmt.name_ref is not None else None;
    }
    if isinstance(stmt, (uni.Archetype, uni.Enum, uni.TypeAlias, uni.Test)) {
        return stmt.name.value;
    }
    if isinstance(stmt, uni.ModuleCode) and stmt.name is not None {
        return stmt.name.value;
    }
    return None;
}

impl _import_item_declaration(
    source_mod: uni.Module, item: uni.ModuleItem
) -> (uni.ContextAwareNode | None) {
    if not isinstance(item.name, uni.Name) {
        return None;
    }
    wanted = item.name.sym_name;
    for stmt in source_mod.body {
        if isinstance(stmt, uni.ContextAwareNode) and _declared_name(stmt) == wanted {
            return stmt;
        }
    }
    sym = source_mod.lookup(wanted);
    if sym is None or sym.decl is None {
        return None;
    }
    cur: (uni.UniNode | None) = sym.decl;
    while cur is not None and not isinstance(cur, uni.Module) {
        if isinstance(cur, uni.ContextAwareNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl classify_client_import_item(
    source_mod: uni.Module, item: uni.UniNode
) -> ClientImportVerdict {
    if not isinstance(item, uni.ModuleItem) {
        return ClientImportVerdict.UNKNOWN;
    }
    owner = _import_item_declaration(source_mod, item);
    if owner is None or isinstance(owner, uni.Import) {
        return ClientImportVerdict.UNKNOWN;
    }
    if owner.code_context == CodeContext.CLIENT {
        return ClientImportVerdict.CLIENT;
    }
    if isinstance(owner, (uni.Ability, uni.Archetype)) and owner.surface_kind {
        return ClientImportVerdict.BRIDGED
            if owner.exposure != SymbolAccess.PRIVATE
            else ClientImportVerdict.DEAD;
    }
    if isinstance(owner, uni.Ability) {
        return ClientImportVerdict.DEAD;
    }
    if isinstance(owner, (uni.Archetype, uni.Enum, uni.TypeAlias)) {
        return ClientImportVerdict.BRIDGED;
    }
    return ClientImportVerdict.DEAD;
}

impl import_binds_client_native(
    nd: uni.Import, manifest: (InteropManifest | None)
) -> bool {
    if nd.from_loc is None or not nd.items {
        return False;
    }
    if nd.is_service_import or nd.is_typed or nd.is_virtual_jac {
        return False;
    }
    if manifest is None or not manifest.bindings {
        return False;
    }
    try {
        resolved_path = nd.from_loc.resolve_relative_path();
    } except Exception {
        return False;
    }
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        local_name = item.alias.sym_name if item.alias is not None else item.name.value;
        binding = manifest.bindings.get(local_name);
        if (
            binding is not None
            and binding.source_context == InteropContext.NATIVE
            and (InteropContext.CLIENT in binding.callers)
            and binding.source_module == resolved_path
        ) {
            return True;
        }
    }
    return False;
}

impl _default_codespace_for(target_program: JacProgram) -> str {
    opts = target_program.options;
    if opts is not None and opts.default_codespace {
        return opts.default_codespace;
    }
    return effective_default_codespace();
}
