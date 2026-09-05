import from pathlib { Path }
import from jaclang.client.config_loader { JacClientConfig }
import from jaclang.client.targets.registry { client_app_dir_for, client_app_root }
import from jaclang.project.config { find_project_root, get_config, get_config_for_dir }
import from jaclang.project.kinds { kind_has_client }
import from jaclang.runtime.runtime { JacRuntime as Jac }


glob DEFAULT_ASSET_EXTENSIONS: set[str] = {
         '.png',
         '.jpg',
         '.jpeg',
         '.gif',
         '.webp',
         '.svg',
         '.ico',
         '.woff',
         '.woff2',
         '.ttf',
         '.otf',
         '.eot',
         '.mp4',
         '.webm',
         '.mp3',
         '.wav',
         '.css',
         '.js',
         '.json'
     };


def asset_extensions -> set[str] {
    return JacClientConfig().get_asset_extensions() or DEFAULT_ASSET_EXTENSIONS;
}

def resolve_static_base(base_path: str) -> Path {
    base_path_dir = Path(base_path) if base_path else Path.cwd();
    project_root_result = find_project_root(base_path_dir);
    if project_root_result {
        (resolved, _) = project_root_result;
        return resolved;
    }
    return base_path_dir;
}

def client_dist_index(client_dist: str) -> (Path | None) {
    if not client_dist {
        return None;
    }
    index = Path(client_dist) / 'index.html';
    return index if index.is_file() else None;
}

def static_roots(
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
        asset_dirs.append(JacClientConfig(base).get_assets_dir());
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

def _within_assets(rel: str) -> str {
    return rel[len('assets/'):] if rel.startswith('assets/') else rel;
}

def find_static_candidate(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None) {
    (roots, dists, asset_dirs) = static_roots(base_path, client_dist);
    rel = relative_path.lstrip('/');
    file_name = Path(rel).name;
    candidates: list[tuple[Path, Path]] = [];
    for dist in dists {
        candidates.append((dist, dist / rel));
        candidates.append((dist, dist / file_name));
    }
    for root_dir in roots {
        candidates.append((root_dir, root_dir / 'dist' / rel));
        candidates.append((root_dir, root_dir / 'dist' / file_name));
    }
    for asset_dir in asset_dirs {
        candidates.append((asset_dir, asset_dir / _within_assets(rel)));
        candidates.append((asset_dir, asset_dir / file_name));
    }
    for (within, candidate) in candidates {
        if candidate.exists() and candidate.is_file() {
            resolved = candidate.resolve();
            if within.resolve() not in resolved.parents {
                continue;
            }
            return candidate;
        }
    }
    return None;
}

glob ROOT_ASSET_EXTENSIONS: set[str] = DEFAULT_ASSET_EXTENSIONS
         | {'.pdf', '.txt', '.xml'};


def find_root_asset(
    base_path: str, relative_path: str, client_dist: str = ''
) -> (Path | None) {
    rel = relative_path.lstrip('/');
    if not rel or Path(rel).suffix.lower() not in ROOT_ASSET_EXTENSIONS {
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
            if not (candidate.exists() and candidate.is_file()) {
                continue;
            }
            resolved = candidate.resolve();
            if asset_root.resolve() not in resolved.parents {
                continue;
            }
            return candidate;
        }
    }
    return None;
}

def is_asset_request(
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


def sibling_app_dist(config: any, name: str, base_path: str) -> (Path | None) {
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

def sibling_app_file(dist: Path, rel: str) -> Path {
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

def sibling_app_names(config: any, base_path: str) -> list[str] {
    if config is None or not config.is_workspace {
        return [];
    }
    return [
        name
        for name in config.apps.keys()
        if sibling_app_dist(config, name, base_path) is not None
    ];
}
