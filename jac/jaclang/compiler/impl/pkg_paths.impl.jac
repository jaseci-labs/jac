impl target_pkg_root -> str {
    return package_root();
}

impl _target_root_real -> str {
    if _ROOT_REAL {
        return _ROOT_REAL[0];
    }
    pkg = target_pkg_root();
    if not pkg {
        return "\x00";
    }
    _ROOT_REAL.append(os.path.realpath(pkg) + os.sep);
    return _ROOT_REAL[0];
}

impl is_target_package_path(path: str) -> bool {
    if not path {
        return False;
    }
    try {
        return os.path.realpath(path).startswith(_target_root_real());
    } except (OSError, ValueError) {
        return False;
    }
}

impl target_package_rel(path: str) -> (str | None) {
    pkg = _target_root_real();
    try {
        rp = os.path.realpath(path);
    } except (OSError, ValueError) {
        return None;
    }
    if not rp.startswith(pkg) {
        return None;
    }
    return rp[len(pkg):].replace(os.sep, "/");
}

impl package_host_edge(mod_path: str) -> bool {
    identity = native_unit_identity(mod_path);
    if not identity.startswith("jaclang/") or identity.startswith("jaclang/runtime/") {
        return False;
    }
    import from jaclang.compiler.placement.placement_facts { native_unit }
    return not native_unit(mod_path, native_unit_compile=True);
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
        or rel in kernel_unit_rels() {
        return True;
    }
    if rel.startswith("runtime/") {
        return False;
    }
    import from jaclang.compiler.frontend.host { active_host }
    host = active_host();
    return host.is_native_only_source(rel);
}
