impl _resolve_root(local_dir: Path) -> Path {
    try {
        return local_dir.resolve();
    } except (OSError, ValueError) {
        _logger.warning(
            f"could not resolve asset root {str(local_dir)!r}, using unresolved path"
        );
        return local_dir;
    }
}

impl _assets_dir(project_root: Path) -> Path {
    cfg = get_config_for_dir(str(project_root));
    return client_assets_dir(cfg, project_root);
}

impl _public_dirs(project_root: Path) -> list[Path] {
    cfg = get_config_for_dir(str(project_root));
    app_root = Path(client_app_root(cfg, project_root));
    dirs = [app_root / "public"] if app_root != project_root else [];
    dirs.append(project_root / "public");
    return dirs;
}

impl asset_root_table(project_root: Path, client_dist: Path) -> list[AssetRoot] {
    assets = _assets_dir(project_root);
    roots: list[tuple[str, Path]] = [("static/assets", assets)];
    if str(client_dist) not in ("", ".") {
        roots += [("static", client_dist), ("", client_dist)];
    }
    roots += [("", public) for public in _public_dirs(project_root)];
    roots.append(("", assets));
    return [
        AssetRoot(url_prefix=prefix, resolved_dir=_resolve_root(base))
        for (prefix, base) in roots
    ];
}

impl _remainder(url_path: str, prefix: str) -> (str | None) {
    p = prefix.strip("/");
    if p == "" {
        rel = url_path.lstrip("/");
        if rel.startswith("static/") {
            return None;
        }
        return rel;
    }
    marker = "/" + p;
    if url_path == marker {
        return "";
    }
    if url_path.startswith(marker + "/") {
        return url_path[len(marker) + 1:];
    }
    return None;
}

impl resolve_asset(table: list[AssetRoot], url_path: str) -> (Path | None) {
    for r in table {
        rel = _remainder(url_path, r.url_prefix);
        if not rel {
            continue;
        }
        try {
            resolved = (r.resolved_dir / rel).resolve();
        } except (OSError, ValueError) {
            continue;
        }
        if resolved.is_relative_to(r.resolved_dir) and resolved.is_file() {
            return resolved;
        }
    }
    return None;
}

impl asset_cache_policy(target: Path) -> str {
    cacheable = target.suffix.lower() not in (".html", ".htm", "");
    return "public, max-age=3600, must-revalidate" if cacheable else "no-cache";
}
