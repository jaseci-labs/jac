impl asset_extensions -> set[str] {
    return set(client_assets_config(get_config()).get('custom_extensions', []))
        or DEFAULT_ASSET_EXTENSIONS;
}

impl resolve_static_base(base_path: str) -> Path {
    base_path_dir = Path(base_path) if base_path else Path.cwd();
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (resolved, _) = project_root_result;
        return resolved;
    }
    return base_path_dir;
}

impl client_dist_index(client_dist: str) -> (Path | None) {
    if not client_dist {
        return None;
    }
    index = Path(client_dist) / 'index.html';
    return index if index.is_file() else None;
}

impl static_roots(
    base_path: str, client_dist: str = ''
) -> tuple[list[Path], list[Path], list[Path]] {
    base = resolve_static_base(base_path);
    roots: list[Path] = [];
    dists: list[Path] = [];
    asset_dirs: list[Path] = [];
    if client_dist {
        dists.append(Path(client_dist));
    }
    cfg = get_config_for_dir(str(base));
    if cfg is not None {
        app_root = Path(client_app_root(cfg, base));
        if app_root != base {
            roots.append(app_root);
        }
        dists.append(client_app_dir_for(cfg) / 'dist');
        asset_dirs.append(client_assets_dir(cfg, base));
    }
    roots.append(base);
    base_dist = base / '.jac' / 'client' / 'dist';
    if base_dist not in dists {
        dists.append(base_dist);
    }
    for root_dir in roots {
        if root_dir / 'assets' not in asset_dirs {
            asset_dirs.append(root_dir / 'assets');
        }
    }
    return (roots, dists, asset_dirs);
}

impl _within_assets(rel: str) -> str {
    return rel[len('assets/'):] if rel.startswith('assets/') else rel;
}

impl _climbs(rel: str) -> bool {
    return '..' in Path(rel).parts;
}

impl _contained_file(within: Path, candidate: Path) -> bool {
    if not (candidate.exists() and candidate.is_file()) {
        return False;
    }
    return within.resolve() in candidate.resolve().parents;
}

impl find_static_candidate(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None) {
    rel = relative_path.lstrip('/');
    if _climbs(rel) {
        return None;
    }
    (roots, dists, asset_dirs) = static_roots(base_path, client_dist);
    file_name = Path(rel).name;

    bases: list[tuple[Path, str]] = [(dist, rel) for dist in dists];
    for root_dir in roots {
        bases.append((root_dir / 'dist', rel));
    }
    for asset_dir in asset_dirs {
        bases.append((asset_dir, _within_assets(rel)));
    }
    for (base, sub_path) in bases {
        for candidate in (base / sub_path, base / file_name) {
            if _contained_file(base, candidate) {
                return candidate;
            }
        }
    }
    return None;
}

impl find_root_asset(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None) {
    rel = relative_path.lstrip('/');
    if not rel
        or _climbs(rel)
        or Path(rel).suffix.lower() not in ROOT_ASSET_EXTENSIONS {
        return None;
    }
    (project_roots, dists, asset_dirs) = static_roots(base_path, client_dist);
    file_name = Path(rel).name;
    roots: list[Path] = list(dists) + list(asset_dirs);
    for root_dir in project_roots {
        for sub in ('dist', 'public', 'src') {
            roots.append(root_dir / sub);
        }
    }
    for asset_root in roots {
        for candidate in (asset_root / rel, asset_root / file_name) {
            if _contained_file(asset_root, candidate) {
                return candidate;
            }
        }
    }
    return None;
}

impl is_asset_request(
    path: str, cl_route_path: str, reserved_prefixes: (list[str] | None) = None
) -> bool {
    if path == '/' or path.startswith('/static/') {
        return False;
    }
    if path.startswith(cl_route_path) {
        return False;
    }
    reserved = reserved_prefixes
        if reserved_prefixes is not None
        else [
            '/function/',
            '/walker/',
            '/user/',
            '/functions',
            '/walkers',
            '/protected'
        ];
    for prefix in reserved {
        if path.startswith(prefix) {
            return False;
        }
    }
    return Path(path).suffix in asset_extensions();
}

impl sibling_app_dist(config: any, name: str, base_path: str) -> (Path | None) {
    if config is None or not config.is_workspace {
        return None;
    }
    app = config.app(name);
    if app is None {
        return None;
    }
    served = config.app_for_path(Jac.get_full_target_path() or "");
    if served is not None and served.name == app.name {
        return None;
    }
    if not kind_has_client(config.resolved_kind(app)) {
        return None;
    }
    root_dir = str(config.project_root) if config.project_root else base_path;
    if not root_dir {
        return None;
    }
    dist = Path(root_dir) / 'dist' / app.name;
    return dist if (dist / 'index.html').is_file() else None;
}

impl sibling_app_file(dist: Path, rel: str) -> Path {
    candidate = (dist / rel) if rel else (dist / 'index.html');
    try {
        resolved = candidate.resolve();
        inside = resolved == dist.resolve() or dist.resolve() in resolved.parents;
    } except Exception {
        inside = False;
    }
    if inside and candidate.is_file() {
        return candidate;
    }
    return dist / 'index.html';
}

impl sibling_app_names(config: any, base_path: str) -> list[str] {
    if config is None or not config.is_workspace {
        return [];
    }
    return [
        name
        for name in config.apps.keys()
        if sibling_app_dist(config, name, base_path) is not None
    ];
}

impl served_host(host: str) -> str {
    import from urllib.parse { urlparse }
    try {
        name = urlparse(f'//{host.strip()}').hostname or '';
    } except ValueError {
        return '';
    }
    return name.rstrip('.').lower();
}

impl robots_override(site_url: str, host: str, site_hosts: list[str]) -> (str | None) {
    import from urllib.parse { urlparse }
    canonical = served_host(urlparse(site_url.strip()).netloc);
    if not canonical {
        return None;
    }
    name = served_host(host);
    if name and name in {canonical} | {served_host(h) for h in site_hosts} {
        return None;
    }
    if name not in _seo_logged {
        _seo_logged.add(name);
        logger.warning(
            f"/robots.txt on host {host!r} answers 'Disallow: /': it is not the "
            f"host of [client.seo] site_url {site_url!r}. If this host serves "
            "production, add it to [client.seo] site_hosts."
        );
    }
    return DISALLOW_ALL_ROBOTS;
}

impl robots_response(
    request: Request, base_path: str, entry_path: str = ''
) -> (Response | None) {
    if request.method != 'GET' or request.url.path.lstrip('/') != ROBOTS_PATH {
        return None;
    }
    base = resolve_static_base(base_path);
    if entry_path and not Path(entry_path).is_absolute() {
        entry_path = str(base / entry_path);
    }
    import from jaclang.project.config { ServeConfigError }
    try {
        seo = client_seo_config(get_config_for_dir(str(base)), entry_path);
    } except ServeConfigError as err {
        if str(err) not in _seo_logged {
            _seo_logged.add(str(err));
            logger.error(f"/robots.txt is served as built: {err}");
        }
        return None;
    }
    host = request.url.netloc or str(request.headers.get('host') or '');
    blocked = robots_override(
        str(seo.get('site_url') or ''), host, list(seo.get('site_hosts', []))
    );
    if blocked is None {
        return None;
    }
    resp = Response(content=blocked, media_type='text/plain; charset=utf-8');
    resp.headers.set('Cache-Control', 'no-cache');
    return resp;
}
