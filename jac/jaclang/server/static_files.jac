import from pathlib { Path }
import from jaclang.project.kinds { kind_has_client }
import from jaclang.runtime.runtime { JacRuntime as Jac }


def client_dist_index(client_dist: str) -> (Path | None) {
    if not client_dist {
        return None;
    }
    index = Path(client_dist) / 'index.html';
    return index if index.is_file() else None;
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
