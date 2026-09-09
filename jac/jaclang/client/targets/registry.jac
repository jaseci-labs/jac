import from typing { Optional }
import from pathlib { Path }
import type from jaclang.project.apps { AppConfig }

glob KIND_TARGET: dict[str, str] = {
         "web-app": "web",
         "js-package": "web",
         "web-static": "static",
         "desktop": "desktop",
         "mobile": "mobile"
     };

def client_workspace_app(config: any, entry_path: str = "") -> AppConfig | None {
    return config.app_for_target(entry_path) if config is not None else None;
}

def client_app_dir_for(config: any, entry_path: str = "") -> Path {
    base = config.get_client_dir();
    app = client_workspace_app(config, entry_path);
    return base / app.name if app is not None else base;
}

def client_app_root(config: any, project_dir: Path, entry_path: str = "") -> Path {
    app = client_workspace_app(config, entry_path);
    if app is None or config.project_root is None {
        return project_dir;
    }
    app_root = app.root_dir(str(config.project_root));
    return Path(app_root) if app_root else project_dir;
}

class ClientTarget {
    has name: str,
        project_dir: Optional[Path] = None,
        requires_setup: bool = False,
        config_section: str = "",
        required_dependencies: list[str] = [],
        output_dir: Optional[Path] = None;

    def setup(self: ClientTarget, project_dir: Path) -> None abst;
    def build(
        self: ClientTarget,
        entry_file: Path,
        project_dir: Path,
        platform: Optional[str] = None
    ) -> Path abst;

    def dev(
        self: ClientTarget,
        entry_file: Path,
        project_dir: Path,
        port: int = 8000,
        api_port: int = 0
    ) -> None abst;

    def start(
        self: ClientTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None abst;
}

obj TargetRegistry {
    has _targets: dict[str, ClientTarget] = {};

    def register(target: ClientTarget) -> None;
    def get(name: str) -> Optional[ClientTarget];
    def get_all -> list[ClientTarget];
    def clear -> None;
}

def target_for_kind(kind: str, project_dir: Path) -> ClientTarget;
def target_for_app(app: AppConfig, project_dir: Path) -> ClientTarget;

glob _registry: TargetRegistry | None = None;

def get_target_registry -> TargetRegistry {
    import from jaclang.client.targets.registry { TargetRegistry }
    if _registry is None {
        _registry = TargetRegistry();

        import from jaclang.client.targets.register { register_targets }
        register_targets();
    }
    return _registry;
}
