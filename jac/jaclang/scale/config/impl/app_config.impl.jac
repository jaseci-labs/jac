impl deployed_tree(entry_path: str) -> tuple[str, str] {
    folder = os.path.dirname(entry_path) or '.';
    cfg = get_config_for_dir(folder);
    if cfg is None or not cfg.is_workspace or cfg.project_root is None {
        return (folder, os.path.basename(entry_path));
    }
    base = Path(cfg.project_root).resolve();
    try {
        return (str(base), Path(entry_path).resolve().relative_to(base).as_posix());
    } except ValueError {
        return (folder, os.path.basename(entry_path));
    }
}

impl AppConfig.get_code_path -> Path {
    return Path(self.code_folder);
}
