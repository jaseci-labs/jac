import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.driver.program { JacProgram }

def _coerce_module(module: uni.Module, context: CodeContext) {
    module.decided_codespace = context.value;
    for elem in module.body {
        if isinstance(elem, uni.ContextAwareNode) {
            elem.code_context = context;
            if (isinstance(elem, uni.ModuleCode) and elem.body) {
                for inner in elem.body {
                    if isinstance(inner, uni.ContextAwareNode) {
                        inner.code_context = context;
                    }
                }
            }
        }
    }
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
    if anchor_path {
        import from jaclang.compiler.placement.service_cut { is_service_module_stem }
        anchor_stem = os.path.basename(anchor_path);
        if anchor_stem.endswith('.jac') {
            anchor_stem = anchor_stem[:-4];
        }
        if is_service_module_stem(anchor_path, anchor_stem) {
            return True;
        }
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

def module_demoted_native(path: str, prog: object = None) -> bool {
    import from jaclang.compiler.placement.placement_pins { module_native_demoted }
    return module_native_demoted(os.path.realpath(path), prog);
}


def plain_native_import_target(nd: uni.Import, prog: object) -> (str | None) {
    import from jaclang.compiler.placement.placement_pins {
        module_native_demoted,
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
    if module_native_demoted(real_resolved, prog) {
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

def is_client_boundary_import(nd: uni.Import) -> bool {
    return (
        nd.code_context == CodeContext.CLIENT
        and not nd.is_service_import
        and not nd.is_typed
        and not nd.is_virtual_jac
        and nd.from_loc is not None
        and bool(nd.items)
        and nd.from_loc.resolve_relative_path().endswith('.jac')
    );
}

def symbol_linked_source_module(nd: uni.Import) -> (uni.Module | None) {
    for item in nd.items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            continue;
        }
        sym = item.name.sym;
        if sym is None or sym.decl is None {
            continue;
        }
        linked = sym.decl.find_parent_of_type(uni.Module);
        if linked is not None {
            return linked;
        }
    }
    return None;
}

def _import_item_owner_decl(
    source_mod: uni.Module, item: uni.ModuleItem
) -> (uni.ContextAwareNode | None) {
    if not isinstance(item.name, uni.Name) {
        return None;
    }
    sym = source_mod.lookup(item.name.sym_name);
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
    owner = _import_item_owner_decl(source_mod, item);
    if owner is None or isinstance(owner, uni.Import) {
        return ClientImportVerdict.UNKNOWN;
    }
    if owner.code_context == CodeContext.CLIENT {
        return ClientImportVerdict.CLIENT;
    }
    if isinstance(owner, uni.Ability) {
        if (
            not owner.is_method
            and owner.access is not None
            and owner.access.tag.name == Tok.KW_PUB
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
