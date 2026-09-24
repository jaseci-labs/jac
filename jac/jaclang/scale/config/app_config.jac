import os;
import from pathlib { Path }
import from jaclang.project.config { get_config_for_path }


def deployed_tree(entry_path: str) -> tuple[str, str] {
    import from jaclang.scale.config.config_loader { JacScaleConfig }
    folder = os.path.dirname(entry_path) or '.';
    fallback = (folder, os.path.basename(entry_path));
    cfg = get_config_for_path(Path(folder));
    if cfg is None or cfg.project_root is None {
        return fallback;
    }
    base = Path(cfg.project_root).resolve();
    if base == Path(folder).resolve() {
        return fallback;
    }
    if not JacScaleConfig(base).microservices_declared() {
        return fallback;
    }
    try {
        return (str(base), Path(entry_path).resolve().relative_to(base).as_posix());
    } except ValueError {
        return fallback;
    }
}


obj AppConfig {
    has code_folder: str,
        file_name: str = 'none',
        app_name: (str | None) = None,
        testing: bool = False,
        no_image: bool = False;

    def get_code_path -> Path {
        return Path(self.code_folder);
    }
}
