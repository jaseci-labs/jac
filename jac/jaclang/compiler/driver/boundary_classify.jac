import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.placement.workspace {
    AppSpec,
    app_for_path,
    workspace_for_path
}

def _coerce_module(module: uni.Module, context: CodeContext) {
    module.set_code_context(context);
}

def _coerce_client_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.CLIENT);
}

def _coerce_native_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.NATIVE);
}

def _stamp_context_element(elem: uni.UniNode, context: CodeContext) {
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

def hub_module_for_path(path: str, prog: object) -> (uni.Module | None) {
    hub: (dict[str, uni.Module] | None) = prog?.mod?.hub;
    if hub is None or not hub {
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

def module_has_client_top(module: (uni.Module | None)) -> bool {
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

def is_server_anchored_module(module: (uni.Module | None)) -> bool {
    if module is None {
        return True;
    }
    anchor_path = module.loc.mod_path or '';
    if anchor_path and is_service_app_entry(anchor_path) {
        return True;
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_kind is not None {
            return True;
        }
    }
    if module.get_all_sub_nodes(uni.PyInlineCode) {
        return True;
    }
    for stmt in module.body {
        if isinstance(stmt, uni.TypedCtxBlock) {
            return True;
        }
    }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls or imp.is_virtual_jac or imp.has_string_path {
            continue;
        }
        if imp.from_loc is None {
            return True;
        }
        resolved = imp.from_loc.resolve_relative_path();
        if not isinstance(resolved, str) or not resolved.endswith('.jac') {
            import from jaclang.compiler.driver.modresolver { is_client_npm_import }
            if is_client_npm_import(
                imp.from_loc.dot_path_str, module.loc.mod_path or ''
            ) {
                continue;
            }
            return True;
        }
    }
    return False;
}

def module_own_native_anchor(module: (uni.Module | None)) -> bool {
    import from jaclang.compiler.frontend.constant { OwnershipKind }
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

def module_demoted_native(path: str) -> bool {
    import from jaclang.compiler.placement.placement_pins { _is_demoted_native }
    return _is_demoted_native(os.path.realpath(path));
}


def plain_native_import_target(nd: uni.Import, prog: object) -> (str | None) {
    import from jaclang.compiler.placement.placement_pins {
        _is_demoted_native,
        effective_module_pin
    }
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
    import jaclang;
    jaclang_root = os.path.realpath(os.path.dirname(str(jaclang.__file__)));
    if (
        real_resolved.startswith(jaclang_root + os.sep)
        and (os.sep + 'na_stdlib' + os.sep) not in real_resolved
    ) {
        return None;
    }
    if _is_demoted_native(real_resolved) {
        return None;
    }
    if effective_module_pin(resolved) == 'native' {
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

def import_declares_native_target(nd: uni.Import) -> bool {
    import from jaclang.compiler.placement.placement_pins { effective_module_pin }
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
    return effective_module_pin(resolved) == 'native';
}

def native_only_import_target(nd: uni.Import, prog: object) -> (str | None) {
    import from jaclang.compiler.placement.placement_pins { effective_module_pin }
    resolved = plain_native_import_target(nd, prog);
    if resolved is None {
        return None;
    }
    if effective_module_pin(resolved) == 'native' {
        return resolved;
    }
    target = hub_module_for_path(resolved, prog);
    if target is not None and module_own_native_anchor(target) {
        return resolved;
    }
    return None;
}

def is_client_native_edge_import(nd: uni.Import, prog: object) -> bool {
    if nd.code_context == CodeContext.CLIENT {} elif nd.code_context
        == CodeContext.SERVER
        and module_has_client_top(nd.find_parent_of_type(uni.Module)) {} else {
        return False;
    }
    return plain_native_import_target(nd, prog) is not None;
}

enum ClientImportVerdict {
    CLIENT = "client",
    BRIDGED = "bridged",
    DEAD = "dead",
    UNKNOWN = "unknown"
}

enum CrossAppKind {
    LOCAL = "local",
    CLIENT_BRIDGE = "client_bridge",
    SERVICE_BRIDGE = "service_bridge",
    NATIVE_BIND = "native_bind"
}

def bridgeable_import_target(nd: uni.Import) -> (str | None) {
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

def is_service_app_entry(path: str) -> bool {
    import from jaclang.compiler.placement.workspace { app_for_path }
    if not path {
        return False;
    }
    app = app_for_path(path);
    return app is not None and app.has_server;
}

def module_app(module: (uni.Module | None)) -> (str | None) {
    if module is None {
        return None;
    }
    return module.app;
}

def import_consumer_app(nd: uni.Import) -> (str | None) {
    return module_app(nd.find_parent_of_type(uni.Module));
}

def same_workspace(consumer_path: str, provider_path: str) -> bool {
    cws = workspace_for_path(consumer_path);
    pws = workspace_for_path(provider_path);
    if cws is None or pws is None {
        return False;
    }
    return os.path.realpath(cws.toml_path) == os.path.realpath(pws.toml_path);
}

def import_provider_spec(nd: uni.Import) -> (AppSpec | None) {
    resolved = bridgeable_import_target(nd);
    if resolved is None {
        return None;
    }
    consumer_path = nd.loc.mod_path if nd.loc else '';
    if not consumer_path or not same_workspace(consumer_path, resolved) {
        return None;
    }
    provider_app = app_for_path(resolved);
    if provider_app is None or not provider_app.has_server {
        return None;
    }
    consumer_mod = nd.find_parent_of_type(uni.Module);
    if module_app(consumer_mod) == provider_app.name {
        return None;
    }
    return provider_app;
}

def import_provider_app(nd: uni.Import) -> (str | None) {
    spec = import_provider_spec(nd);
    return spec.name if spec is not None else None;
}

def import_provider_route(nd: uni.Import) -> str {
    spec = import_provider_spec(nd);
    return spec.effective_route() if spec is not None else '';
}

def import_crosses_apps(nd: uni.Import) -> bool {
    provider = import_provider_app(nd);
    return provider is not None and provider != import_consumer_app(nd);
}

def is_service_bridge_import(nd: uni.Import) -> bool {
    if bridgeable_import_target(nd) is None {
        return False;
    }
    if nd.codespace() == CodeContext.CLIENT {
        return False;
    }
    return import_crosses_apps(nd);
}

def classify_cross_app_import(
    nd: uni.Import, manifest: (object | None)
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

def is_client_boundary_import(nd: uni.Import) -> bool {
    return classify_cross_app_import(nd, None) == CrossAppKind.CLIENT_BRIDGE;
}

def symbol_linked_source_module(nd: uni.Import) -> (uni.Module | None) {
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

def _import_item_declaration(
    source_mod: uni.Module, item: uni.ModuleItem
) -> (uni.ContextAwareNode | None) {
    if not isinstance(item.name, uni.Name) {
        return None;
    }
    wanted = item.name.sym_name;
    for stmt in source_mod.body {
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        owner_name = stmt?.name_ref?.sym_name or stmt?.name?.value;
        if owner_name == wanted {
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

def classify_client_import_item(
    source_mod: uni.Module, item: object
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
    if isinstance(owner, uni.Ability) {
        consumer = item.find_parent_of_type(uni.Module);
        provider_app = module_app(source_mod);
        authenticated_endpoint = (
            owner.access is not None
            and owner.access.tag.name in (Tok.KW_PRIV, Tok.KW_PROT)
            and consumer is not None
            and bool(provider_app)
            and module_app(consumer) == provider_app
            and same_workspace(consumer.loc.mod_path, source_mod.loc.mod_path)
        );
        if (
            not owner.is_method
            and owner.access is not None
            and (owner.access.tag.name == Tok.KW_PUB or authenticated_endpoint)
        ) {
            return ClientImportVerdict.BRIDGED;
        }
        return ClientImportVerdict.DEAD;
    }
    if isinstance(owner, (uni.Archetype, uni.Enum, uni.TypeAlias)) {
        return ClientImportVerdict.BRIDGED;
    }
    return ClientImportVerdict.DEAD;
}

def import_binds_client_native(nd: uni.Import, manifest: object) -> bool {
    import from jaclang.compiler.frontend.codeinfo { InteropContext, InteropManifest }
    if nd.from_loc is None or not nd.items {
        return False;
    }
    if nd.is_service_import or nd.is_typed or nd.is_virtual_jac {
        return False;
    }
    if not isinstance(manifest, InteropManifest) or not manifest.bindings {
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
        local_name = item.alias.sym_name
            if item.alias is not None
            else getattr(item.name, 'value', str(item.name));
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

def _default_codespace_for(target_program: JacProgram) -> str {
    import from jaclang.compiler.frontend.codeinfo { effective_default_codespace }
    opts = target_program.options;
    if opts is not None and opts.default_codespace {
        return opts.default_codespace;
    }
    return effective_default_codespace();
}
