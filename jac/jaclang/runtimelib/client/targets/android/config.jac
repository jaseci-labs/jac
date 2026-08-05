import from pathlib { Path }

def load_android_cfg(project_dir: Path) -> dict {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        android_cfg = cfg.get_section("client.android");
        if not android_cfg {
            client = cfg.get_section("client") or {};
            android_cfg = client.get("android") if isinstance(client, dict) else {};
        }
        if not isinstance(android_cfg, dict) {
            android_cfg = {};
        }
        return android_cfg;
    } except Exception {
        return {};
    }
}

def load_client_cfg(project_dir: Path) -> dict {
    try {
        import from jaclang.project.config { JacConfig }
        cfg = JacConfig.load(project_dir / "jac.toml");
        client = cfg.get_section("client") or {};
        return client if isinstance(client, dict) else {};
    } except Exception {
        return {};
    }
}

def resolve_package_name(project_dir: Path) -> str {
    cfg = load_android_cfg(project_dir);
    pkg = cfg.get("package") or cfg.get("application_id");
    if pkg {
        return str(pkg);
    }
    return "dev.jac.generated";
}

def resolve_type_check(project_dir: Path) -> bool {
    val = load_android_cfg(project_dir).get("type_check");
    if val is None {
        return True;
    }
    return bool(val);
}

def apply_android_cfg_to_model(model: any, project_dir: Path) {
    model.intent.package_name = resolve_package_name(project_dir);
    android_cfg = load_android_cfg(project_dir);
    if android_cfg.get("app_name") {
        model.intent.app_name = str(android_cfg["app_name"]);
    }
    if android_cfg.get("backend_url") {
        model.intent.backend_url = str(android_cfg["backend_url"]);
    }
}
