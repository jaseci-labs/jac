import from pathlib { Path }
import from jaclang.jac0core.cache_paths { get_cache_home }

impl cache_home -> Path {
    return get_cache_home();
}

impl ensure_root -> Path {
    base = cache_home();
    try {
        base.mkdir(parents=True, exist_ok=True);
        tag = base / CACHEDIR_TAG;

        if tag.is_file() and tag.read_text(encoding="utf-8") == CACHEDIR_TAG_TEXT {
            tag.unlink();
        }
    } except (OSError, UnicodeError) {}
    return base;
}

impl ensure_cache_dir(path: Path) -> Path {
    try {
        path.mkdir(parents=True, exist_ok=True);
        tag = path / CACHEDIR_TAG;
        if not tag.exists() {
            tag.write_text(CACHEDIR_TAG_TEXT, encoding="utf-8");
        }
    } except OSError {}
    return path;
}
