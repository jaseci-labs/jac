import from pathlib { Path }
import type from jaclang.project.config { JacConfig }
import type from jaclang.project.apps { AppConfig }

def client_workspace_app(
    config: JacConfig | None, entry_path: str = ""
) -> AppConfig | None {
    return config.app_for_target(entry_path) if config is not None else None;
}

def client_app_dir_for(config: JacConfig, entry_path: str = "") -> Path {
    base = config.get_client_dir();
    app = client_workspace_app(config, entry_path);
    return base / app.name if app is not None else base;
}

def client_app_root(
    config: JacConfig, project_dir: Path, entry_path: str = ""
) -> Path {
    app = client_workspace_app(config, entry_path);
    if app is None or config.project_root is None {
        return project_dir;
    }
    return Path(app.entry_path(str(config.project_root))).parent;
}
