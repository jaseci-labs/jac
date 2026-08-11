import from pathlib { Path }
import from jaclang.project.config { find_project_root, get_config }


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
    config = get_config();
    client_cfg = config.get_plugin_config('client') if config else None;
    assets_config = client_cfg.get('assets', {}) if client_cfg else {};
    custom = set(assets_config.get('custom_extensions', []));
    return custom or DEFAULT_ASSET_EXTENSIONS;
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

def find_static_candidate(base_path: str, relative_path: str) -> (Path | None) {
    base = resolve_static_base(base_path);
    rel = relative_path.lstrip('/');
    file_name = Path(rel).name;
    candidates = [
        base / '.jac' / 'client' / 'dist' / rel,
        base / '.jac' / 'client' / 'dist' / file_name,
        base / 'dist' / rel,
        base / 'dist' / file_name,
        base / 'assets' / rel,
        base / 'assets' / file_name
    ];
    for candidate in candidates {
        if candidate.exists() and candidate.is_file() {
            resolved = candidate.resolve();
            if base.resolve() not in resolved.parents {
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
