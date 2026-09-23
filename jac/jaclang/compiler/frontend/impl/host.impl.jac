impl HostServices.session -> Iterator[None] {
    import from jaclang.project.workspace { workspace_scope }
    import from jaclang.compiler.driver.wiring { wiring_scope }
    with workspace_scope(), wiring_scope() {
        yield ;
    }
}

impl HostServices.project_defaults -> (ProjectDefaults | None) {
    if self._defaults_active {
        return self._last_defaults;
    }
    self._defaults_active = True;
    try {
        cfg: any = None;
        try {
            import from jaclang.project.config { get_config }
            cfg = get_config();
        } except Exception {
            return None;
        }
        if cfg is None {
            import from jaclang.project.config { JacConfig }
            cfg = JacConfig();
        }
        self._last_defaults = project_defaults_of(cfg);
        return self._last_defaults;
    } finally {
        self._defaults_active = False;
    }
}

impl HostServices.check_settings(target_app: str) -> CheckSettings {
    cfg: any = None;
    try {
        import from jaclang.project.config { get_config }
        cfg = get_config();
    } except Exception {
        return CheckSettings();
    }
    if cfg is None {
        return CheckSettings();
    }
    if target_app and isinstance(cfg.apps, dict) and target_app in cfg.apps {
        try {
            cfg = cfg.effective_for_app(target_app);
        } except Exception {}
    }
    return check_settings_of(cfg.check);
}

impl HostServices.project_facts(path: str) -> (ProjectFacts | None) {
    import from pathlib { Path }
    try {
        import from jaclang.project.config { get_config_for_path }
        cfg = get_config_for_path(Path(path));
    } except Exception {
        return None;
    }
    if cfg is None or cfg.project_root is None {
        return None;
    }
    project_root = str(cfg.project_root);
    cached = self._facts.get(project_root);
    if cached is not None and cached[0] is cfg {
        return cached[1];
    }
    facts = ProjectFacts(
        project_root=project_root,
        check=check_settings_of(cfg.check),
        arch_closed=list(cfg.arch.closed),
        client_framework=cfg.client.framework if cfg.client else "react"
    );
    self._facts[project_root] = (cfg, facts);
    return facts;
}

impl HostServices.workspace(path: str) -> (WorkspaceSpec | None) {
    if not path {
        return None;
    }
    import from jaclang.project.workspace { workspace_for_path }
    return workspace_for_path(path);
}

impl HostServices.app_for_path(path: str) -> (AppSpec | None) {
    import from jaclang.project.workspace { app_for_path }
    return app_for_path(path);
}

impl HostServices.project_root(path: str) -> (str | None) {
    import from jaclang.project.modresolver { find_jac_project_root }
    return find_jac_project_root(path);
}

impl HostServices.declared_dependencies(
    module_path: str, fallback_app: str
) -> (list[str] | None) {
    import from pathlib { Path }
    try {
        import from jaclang.project.config { get_config_for_path }
        cfg = get_config_for_path(Path(module_path));
    } except Exception {
        return None;
    }
    if cfg is None {
        return None;
    }
    names: list[str] = [*cfg.dependencies, *cfg.dev_dependencies];
    owner = cfg.app_for_path(str(Path(module_path).resolve()));
    app_name = owner.name if owner is not None else fallback_app;
    if app_name and app_name in cfg.apps {
        try {
            app_cfg = cfg.effective_for_app(app_name);
            names.extend([*app_cfg.dependencies, *app_cfg.dev_dependencies]);
        } except Exception {}
    }
    return [str(n) for n in names];
}

impl HostServices.resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[str, str] {
    import from jaclang.project.modresolver { resolve_module }
    return resolve_module(target, base_path, string_spec=string_spec);
}

impl HostServices.is_path_alias(target: str, base_path: str) -> bool {
    import from jaclang.project.modresolver { is_path_alias_import }
    return is_path_alias_import(target, base_path);
}

impl HostServices.is_untyped_third_party(path: str) -> bool {
    import from jaclang.project.modresolver { is_untyped_third_party_module }
    return is_untyped_third_party_module(path);
}

impl HostServices.in_typeshed_tree(path: str) -> bool {
    import from jaclang.project.modresolver { in_typeshed_tree }
    return in_typeshed_tree(path);
}

impl HostServices.sibling_declaration(js_path: str) -> (str | None) {
    import from jaclang.project.modresolver { sibling_declaration_file }
    return sibling_declaration_file(js_path);
}

impl HostServices.has_npm_package(spec: str, base_path: str) -> bool {
    import from jaclang.project.modresolver { has_client_npm_package }
    return has_client_npm_package(spec, base_path);
}

impl HostServices.resolve_npm_package(spec: str, base_path: str) -> (str | None) {
    import from jaclang.project.modresolver { resolve_client_npm_package }
    return resolve_client_npm_package(spec, base_path);
}

impl HostServices.npm_declarations(spec: str, base_path: str) -> (str | None) {
    import from jaclang.project.modresolver { resolve_client_npm_declarations }
    return resolve_client_npm_declarations(spec, base_path);
}
