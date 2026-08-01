import json;
import os;
import from jaclang.jac0core.modresolver { find_jac_project_root }

glob _cut_cache: dict[str, tuple[float, set[str]]] = {};


def _load_cut(root_dir: str) -> set[str] {
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return set();
    }
    cached = _cut_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return set();
    }
    routes = (
        doc.get("scale", {}).get("microservices", {}).get("routes", {})
        or doc.get("plugins", {}).get("scale", {}).get("microservices", {}).get(
            "routes", {}
        )
    );
    cut: set[str] = {str(k) for k in routes} if isinstance(routes, dict) else set();
    _cut_cache[root_dir] = (mtime, cut);
    return cut;
}


def service_cut_for(source_path: str) -> set[str] {
    if not source_path {
        return set();
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return set();
    }
    return _load_cut(root_dir);
}


def is_service_module_stem(source_path: str, stem: str) -> bool {
    if not stem {
        return False;
    }
    return stem in service_cut_for(source_path);
}


def cut_digest(source_path: str) -> str {
    cut = service_cut_for(source_path);
    if not cut {
        return '';
    }
    return json.dumps(sorted(cut));
}
