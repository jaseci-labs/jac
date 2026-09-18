import json;
import os;

import from pathlib { Path }
import from jaclang.jac0core.sealed { MANIFEST_NAME }

glob SERVE_MANIFEST_REL: str = os.path.join(".jac", "serve_manifest.json"),
     CLIENT_DIST_REL: str = os.path.join(".jac", "client", "dist"),
     NATIVE_DIR_REL: str = os.path.join(".jac", "native"),
     _MODULE_KEYS_CACHE: dict[str, tuple[float, set]] = {};


def _image_module_keys(img_root: str) -> set {
    mf = os.path.join(img_root, "_precompiled", MANIFEST_NAME);
    try {
        mtime = os.path.getmtime(mf);
    } except OSError {
        return set();
    }
    cached = _MODULE_KEYS_CACHE.get(img_root);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    keys = set();
    try {
        data: dict[str, any] = json.loads(Path(mf).read_text(encoding="utf-8"));
        if isinstance(data, dict) {
            modules = data.get("modules");
            if isinstance(modules, dict) {
                keys = set(modules.keys());
            }
            `entry = data.get("entry");
            if isinstance(`entry, dict) and isinstance(`entry.get("path"), str) {
                keys.add(`entry["path"]);
            }
        }
    } except Exception {
        keys = set();
    }
    _MODULE_KEYS_CACHE[img_root] = (mtime, keys);
    return keys;
}


def _image_key(abs_path: str, img_root: str) -> str {
    rel = os.path.relpath(abs_path, img_root).replace(os.sep, "/");
    return rel[:-3] + ".jac" if rel.endswith(".py") else rel;
}


def _image_roots(abs_path: str) -> Iterator[tuple[str, bool]] {
    nested = False;
    d = os.path.dirname(abs_path);
    while True {
        if os.path.isfile(os.path.join(d, "_precompiled", MANIFEST_NAME)) {
            yield (d, nested);
        }
        if os.path.isfile(os.path.join(d, "jac.toml")) {
            nested = True;
        }
        parent = os.path.dirname(d);
        if parent == d {
            break;
        }
        d = parent;
    }
}


def sealed_root_for(path: str) -> (str | None) {
    abs_path = os.path.normpath(os.path.abspath(path));
    for (img_root, _) in _image_roots(abs_path) {
        if _image_key(abs_path, img_root) in _image_module_keys(img_root) {
            return img_root;
        }
    }
    return None;
}


def unlisted_image_root(path: str) -> (str | None) {
    abs_path = os.path.normpath(os.path.abspath(path));
    nearest = next(_image_roots(abs_path), None);
    if nearest is None {
        return None;
    }
    (img_root, nested) = nearest;
    if nested or _image_key(abs_path, img_root) in _image_module_keys(img_root) {
        return None;
    }
    return img_root;
}


def serve_manifest_for(path: str) -> (dict[str, any] | None) {
    import from jaclang.runtime.prepared { prepared_manifest }
    prepared = prepared_manifest(path);
    if prepared is not None {
        return prepared;
    }
    img_root = sealed_root_for(path);
    if img_root is None {
        return None;
    }
    mf = os.path.join(img_root, SERVE_MANIFEST_REL);
    if not os.path.isfile(mf) {
        return None;
    }
    try {
        data: dict[str, any] = json.loads(Path(mf).read_text(encoding="utf-8"));
    } except Exception {
        return None;
    }
    if not isinstance(data, dict) {
        return None;
    }
    relative = os.path.relpath(path, img_root).replace(os.sep, '/');
    return data.get('module_manifests', {}).get(relative);
}


def client_dist_for(path: str) -> (Path | None) {
    import from jaclang.runtime.prepared { application_for }
    prepared = application_for(path);
    if prepared is not None and prepared.client_dist and not prepared.dev {
        return Path(prepared.client_dist);
    }
    img_root = sealed_root_for(path);
    if img_root is None {
        return None;
    }
    dist = Path(img_root) / CLIENT_DIST_REL;
    if dist.is_dir() and any(dist.`glob("client.*.js")) {
        return dist;
    }
    return None;
}
