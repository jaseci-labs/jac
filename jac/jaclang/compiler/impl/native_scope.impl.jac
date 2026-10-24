impl package_host_edge(mod_path: str) -> bool {
    identity = native_unit_identity(mod_path);
    if not identity.startswith("jaclang/") or identity.startswith("jaclang/runtime/") {
        return False;
    }
    import from jaclang.compiler.placement.placement_facts {
        native_lowered,
        native_unit
    }
    return not native_lowered(mod_path)
        and not native_unit(mod_path, native_unit_compile=True);
}

impl scope_allows_inferred_path(mod_path: str) -> bool {
    return not native_unit_compile_active() or not package_host_edge(mod_path);
}

impl binds_bare_arch_names(mod_path: str) -> bool {
    rel = target_package_rel(mod_path) if mod_path else None;
    if rel is None {
        return False;
    }
    rel = rel.lstrip("/");
    if rel.endswith(".pyi")
        or (rel.startswith("runtime/") and rel.count("/") == 1)
        or rel in KERNEL_ABI_CONTRACT_REL
        or rel in kernel_unit_rels() {
        return True;
    }
    if rel.startswith("runtime/") {
        return False;
    }
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    return host.is_native_only_source(rel) or host.is_native_lowered_source(rel);
}

impl scope_modules -> list[str] {
    spec = active_kernel_target();
    if spec is not None {
        return list(spec.scope_modules);
    }
    return [e.module for e in NATIVE_SCOPE];
}

impl kernel_root_module -> str {
    spec = active_kernel_target();
    return spec.root_module if spec is not None else KERNEL_ROOT_MODULE;
}

impl native_scope_path_suffixes -> list[str] {
    gen = kernel_target_generation();
    if _SCOPE_SUFFIX_GEN[0] != gen {
        _SCOPE_SUFFIX_CACHE.clear();
        for module in scope_modules() {
            rel = module.replace("jaclang.", "", 1).replace(".", "/") + ".jac";
            _SCOPE_SUFFIX_CACHE.append("jaclang/" + rel);
        }
        _SCOPE_SUFFIX_GEN[0] = gen;
    }
    return _SCOPE_SUFFIX_CACHE;
}

impl in_native_scope_path(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    p = mod_path.replace(os.sep, "/");
    for suf in native_scope_path_suffixes() {
        if p.endswith(suf) {
            return True;
        }
    }
    return False;
}

impl scope_module_path(module: str) -> str {
    rel = module.replace("jaclang.", "", 1).replace(".", os.sep) + ".jac";
    return os.path.join(target_pkg_root(), rel);
}

impl native_scope_paths -> list[str] {
    return [scope_module_path(m) for m in scope_modules()];
}

impl kernel_root_path -> str {
    return scope_module_path(kernel_root_module());
}
