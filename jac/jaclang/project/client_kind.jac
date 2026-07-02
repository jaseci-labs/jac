import os;

def _config_for(mod_path: str) -> any {
    try {
        import from pathlib { Path }
        import from jaclang.project.config { get_config_for_path }
        return get_config_for_path(Path(os.path.dirname(os.path.abspath(mod_path))));
    } except ImportError {
        return None;
    }
}

def resolve_client_kind_context(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> tuple[str, (str | None)] {
    if explicit_kind != "web" {
        proj_root = explicit_root;
        if proj_root is None {
            cfg = _config_for(mod_path);
            if cfg and cfg.project_root {
                proj_root = str(cfg.project_root);
            }
        }
        return (explicit_kind, proj_root);
    }
    cfg = _config_for(mod_path);
    if not cfg or cfg.project_root is None {
        return ("web", None);
    }
    return (cfg.project.client_kind or "web", str(cfg.project_root));
}

def mobui_module_exempt(mod_path: str, project_root: (str | None)) -> bool {
    if mod_path.endswith(".cl.jac") and not mod_path.endswith(".native.cl.jac") {
        return True;
    }

    if not project_root {
        return True;
    }
    real_mod = os.path.normcase(os.path.realpath(mod_path));
    real_root = os.path.normcase(os.path.realpath(project_root));
    return not real_mod.startswith(real_root + os.sep);
}

def mobui_enforced_for(
    mod_path: str, explicit_kind: str = "web", explicit_root: (str | None) = None
) -> bool {
    (kind, proj_root) = resolve_client_kind_context(
        mod_path, explicit_kind, explicit_root
    );
    if kind != "mobui" {
        return False;
    }
    return not mobui_module_exempt(mod_path, proj_root);
}
